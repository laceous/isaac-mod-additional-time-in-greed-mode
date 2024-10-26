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
  
  function mod:onGameStart()
    if mod:HasData() then
      local _, state = pcall(json.decode, mod:LoadData())
      
      if type(state) == 'table' then
        for _, v in ipairs({ 'greedWaveSecondsAdded', 'greedBossWaveSecondsAdded', 'greedierWaveSecondsAdded', 'greedierBossWaveSecondsAdded' }) do
          if math.type(state[v]) == 'integer' and state[v] >= 0 and state[v] <= 300 then
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
        local greedWaveTimer = room:GetGreedWaveTimer()
        
        if greedWaveTimer > -1 then
          local secondsAdded
          if level.GreedModeWave >= game:GetGreedBossWaveNum() then
            secondsAdded = game.Difficulty == Difficulty.DIFFICULTY_GREED and mod.state.greedBossWaveSecondsAdded or mod.state.greedierBossWaveSecondsAdded
          else
            secondsAdded = game.Difficulty == Difficulty.DIFFICULTY_GREED and mod.state.greedWaveSecondsAdded or mod.state.greedierWaveSecondsAdded
          end
          
          if secondsAdded > 0 then
            room:SetGreedWaveTimer(greedWaveTimer + (secondsAdded * 30))
          end
        end
      end
      
      mod.lastGreedModeWave = level.GreedModeWave
    end
  end
  
  -- start ModConfigMenu --
  function mod:setupModConfigMenu()
    local category = 'Add Time in Greed' -- Mode
    for _, v in ipairs({ 'Settings' }) do
      ModConfigMenu.RemoveSubcategory(category, v)
    end
    for i, v in ipairs({
                        { title = 'Greed Mode'   , field = 'greedWaveSecondsAdded'   , bossField = 'greedBossWaveSecondsAdded' },
                        { title = 'Greedier Mode', field = 'greedierWaveSecondsAdded', bossField = 'greedierBossWaveSecondsAdded' },
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
    end
  end
  -- end ModConfigMenu --
  
  mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, mod.onGameStart)
  mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, mod.onGameExit)
  mod:AddCallback(ModCallbacks.MC_POST_UPDATE, mod.onUpdate)
  
  if ModConfigMenu then
    mod:setupModConfigMenu()
  end
end