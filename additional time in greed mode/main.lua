local mod = RegisterMod('Additional Time in Greed Mode', 1)
local json = require('json')
local game = Game()

if REPENTOGON then
  mod.lastGreedModeWave = 0
  
  mod.state = {}
  mod.state.greedWaveSecondsAdded = 0
  mod.state.greedBossWaveSecondsAdded = 0
  mod.state.greedierWaveSecondsAdded = 0
  mod.state.greedierBossWaveSecondsAdded = 0
  mod.state.greedTimerEnabled = true
  mod.state.greedierTimerEnabled = true
  
  function mod:onGameStart()
    if mod:HasData() then
      local _, state = pcall(json.decode, mod:LoadData())
      
      if type(state) == 'table' then
        for _, v in ipairs({ 'greedWaveSecondsAdded', 'greedBossWaveSecondsAdded', 'greedierWaveSecondsAdded', 'greedierBossWaveSecondsAdded' }) do
          if math.type(state[v]) == 'integer' and state[v] >= 0 and state[v] <= 300 then
            mod.state[v] = state[v]
          end
        end
        for _, v in ipairs({ 'greedTimerEnabled', 'greedierTimerEnabled' }) do
          if type(state[v]) == 'boolean' then
            mod.state[v] = state[v]
          end
        end
      end
    end
  end
  
  function mod:onGameExit()
    mod:save()
    mod.lastGreedModeWave = 0
  end
  
  function mod:save()
    mod:SaveData(json.encode(mod.state))
  end
  
  function mod:onStartGreedWave()
    mod:doGreedWaveLogic()
  end
  
  function mod:onUpdate()
    if game:IsGreedMode() then
      local level = game:GetLevel()
      local room = level:GetCurrentRoom()
      local roomDesc = level:GetCurrentRoomDesc()
      
      if level.GreedModeWave ~= mod.lastGreedModeWave and
         room:GetType() == RoomType.ROOM_DEFAULT and
         room:GetRoomShape() == RoomShape.ROOMSHAPE_1x2 and
         room:IsCurrentRoomLastBoss() and
         roomDesc.GridIndex == 84
      then
        mod:doGreedWaveLogic()
      end
      
      mod.lastGreedModeWave = level.GreedModeWave
    end
  end
  
  function mod:doGreedWaveLogic()
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    local greedWaveTimer = room:GetGreedWaveTimer()
    
    local timerEnabled
    if game.Difficulty == Difficulty.DIFFICULTY_GREED then
      timerEnabled = mod.state.greedTimerEnabled
    else
      timerEnabled = mod.state.greedierTimerEnabled
    end
    
    if greedWaveTimer > -1 then
      if timerEnabled then
        local secondsAdded
        if level.GreedModeWave >= game:GetGreedBossWaveNum() then -- game:IsGreedBoss / game:IsGreedFinalBoss
          secondsAdded = game.Difficulty == Difficulty.DIFFICULTY_GREED and mod.state.greedBossWaveSecondsAdded or mod.state.greedierBossWaveSecondsAdded
        else
          secondsAdded = game.Difficulty == Difficulty.DIFFICULTY_GREED and mod.state.greedWaveSecondsAdded or mod.state.greedierWaveSecondsAdded
        end
        
        if secondsAdded > 0 then
          room:SetGreedWaveTimer(greedWaveTimer + (secondsAdded * 30))
        end
      else
        room:SetGreedWaveTimer(-1)
        mod:updatePressurePlateSprite()
      end
    else
      if not timerEnabled then
        mod:updatePressurePlateSprite()
      end
    end
  end
  
  function mod:updatePressurePlateSprite()
    local level = game:GetLevel()
    local room = level:GetCurrentRoom()
    
    for i = 0, room:GetGridSize() - 1 do
      local gridEntity = room:GetGridEntity(i)
      if gridEntity and gridEntity:GetType() == GridEntityType.GRID_PRESSURE_PLATE and gridEntity:GetVariant() == PressurePlateVariant.GREED_MODE then
        local sprite = gridEntity:GetSprite()
        local animation = sprite:GetAnimation()
        
        -- don't show OffRedStart
        if animation == 'OffRedStart' then
          if level.GreedModeWave >= game:GetGreedBossWaveNum() then
            sprite:Play('SwitchedSkull', true)
          else
            sprite:Play('Switched', true)
          end
          sprite:SetLastFrame()
        elseif animation == 'OffSkull' then
          sprite:Play('SwitchedSkull', true)
          sprite:SetLastFrame()
        elseif animation == 'OffPentagram' then
          sprite:Play('SwitchedPentagram', true)
          sprite:SetLastFrame()
        end
      end
    end
  end
  
  -- start ModConfigMenu --
  function mod:setupModConfigMenu()
    local category = 'Add Time in Greed' -- Mode
    for _, v in ipairs({ 'Settings' }) do
      ModConfigMenu.RemoveSubcategory(category, v)
    end
    for i, v in ipairs({
                        { title = 'Greed Mode'   , field = 'greedWaveSecondsAdded'   , bossField = 'greedBossWaveSecondsAdded'   , timerField = 'greedTimerEnabled' },
                        { title = 'Greedier Mode', field = 'greedierWaveSecondsAdded', bossField = 'greedierBossWaveSecondsAdded', timerField = 'greedierTimerEnabled' },
                      })
    do
      if i ~= 1 then
        ModConfigMenu.AddSpace(category, 'Settings')
      end
      ModConfigMenu.AddTitle(category, 'Settings', v.title)
      ModConfigMenu.AddSetting(
        category,
        'Settings',
        {
          Type = ModConfigMenu.OptionType.NUMBER,
          CurrentSetting = function()
            return mod.state[v.field]
          end,
          Minimum = 0,
          Maximum = 300, -- 5 minutes
          Display = function()
            return 'Regular wave: +' .. mod.state[v.field] .. ' seconds'
          end,
          OnChange = function(n)
            mod.state[v.field] = n
            mod:save()
          end,
          Info = { 'Add time to the greed mode timer' }
        }
      )
      ModConfigMenu.AddSetting(
        category,
        'Settings',
        {
          Type = ModConfigMenu.OptionType.NUMBER,
          CurrentSetting = function()
            return mod.state[v.bossField]
          end,
          Minimum = 0,
          Maximum = 300,
          Display = function()
            return 'Boss wave: +' .. mod.state[v.bossField] .. ' seconds'
          end,
          OnChange = function(n)
            mod.state[v.bossField] = n
            mod:save()
          end,
          Info = { 'Add time to the greed mode timer' }
        }
      )
      ModConfigMenu.AddSetting(
        category,
        'Settings',
        {
          Type = ModConfigMenu.OptionType.BOOLEAN,
          CurrentSetting = function()
            return mod.state[v.timerField]
          end,
          Display = function()
            return 'Timer: ' .. (mod.state[v.timerField] and 'enabled' or 'disabled')
          end,
          OnChange = function(b)
            mod.state[v.timerField] = b
            mod:save()
          end,
          Info = { 'Enabled: timer + button behave normally', 'Disabled: button must be pressed after each wave' }
        }
      )
    end
  end
  -- end ModConfigMenu --
  
  mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
  mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
  if ModCallbacks.MC_POST_START_GREED_WAVE then -- added in rgon for rep+
    mod:AddCallback(ModCallbacks.MC_POST_START_GREED_WAVE, mod.onStartGreedWave)
  else
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
  end
  
  if ModConfigMenu then
    mod:setupModConfigMenu()
  end
end