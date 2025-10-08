local firstSpawn = true
isDead, isSearched, medic = false, false, 0

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
  ESX.PlayerLoaded = true
end)

RegisterNetEvent('esx:onPlayerLogout')
AddEventHandler('esx:onPlayerLogout', function()
  ESX.PlayerLoaded = false
  firstSpawn = true
end)

AddEventHandler('esx:onPlayerSpawn', function()
  if firstSpawn then
    firstSpawn = false
    return
  end
  isDead = false
end)

AddEventHandler('esx:onPlayerDeath', function(data)
  isDead = true
end)

-- Create blips
CreateThread(function()
  for k, v in pairs(Config.Hospitals) do
    local blip = AddBlipForCoord(v.Blip.coords)

    SetBlipSprite(blip, v.Blip.sprite)
    SetBlipScale(blip, v.Blip.scale)
    SetBlipColour(blip, v.Blip.color)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(TranslateCap('blip_hospital'))
    EndTextCommandSetBlipName(blip)
  end
end)

RegisterNetEvent('esx_ambulancejob:clsearch')
AddEventHandler('esx_ambulancejob:clsearch', function(medicId)
  local playerPed = PlayerPedId()

  if isDead then
    local coords = GetEntityCoords(playerPed)
    local playersInArea = ESX.Game.GetPlayersInArea(coords, 50.0)

    for i = 1, #playersInArea, 1 do
      local player = playersInArea[i]
      if player == GetPlayerFromServerId(medicId) then
        medic = tonumber(medicId)
        isSearched = true
        break
      end
    end
  end
end)

RegisterNetEvent('esx_ambulancejob:useItem')
AddEventHandler('esx_ambulancejob:useItem', function(itemName)
  ESX.CloseContext()

  if itemName == 'medikit' then
    local lib, anim = 'anim@heists@narcotics@funding@gang_idle', 'gang_chatting_idle01' -- TODO better animations
    local playerPed = PlayerPedId()

    ESX.Streaming.RequestAnimDict(lib, function()
      TaskPlayAnim(playerPed, lib, anim, 8.0, -8.0, -1, 0, 0, false, false, false)
      RemoveAnimDict(lib)

      Wait(500)
      while IsEntityPlayingAnim(playerPed, lib, anim, 3) do
        Wait(0)
        DisableAllControlActions(0)
      end

      TriggerEvent('esx_ambulancejob:heal', 'big', true)
      ESX.ShowNotification(TranslateCap('used_medikit'))
    end)
  elseif itemName == 'bandage' then
    local lib, anim = 'anim@heists@narcotics@funding@gang_idle', 'gang_chatting_idle01' -- TODO better animations
    local playerPed = PlayerPedId()

    ESX.Streaming.RequestAnimDict(lib, function()
      TaskPlayAnim(playerPed, lib, anim, 8.0, -8.0, -1, 0, 0, false, false, false)
      RemoveAnimDict(lib)

      Wait(500)
      while IsEntityPlayingAnim(playerPed, lib, anim, 3) do
        Wait(0)
        DisableAllControlActions(0)
      end

      TriggerEvent('esx_ambulancejob:heal', 'small', true)
      ESX.ShowNotification(TranslateCap('used_bandage'))
    end)
  end
end)

-- Load unloaded IPLs
if Config.LoadIpl then
  RequestIpl('Coroner_Int_on') -- Morgue
end
