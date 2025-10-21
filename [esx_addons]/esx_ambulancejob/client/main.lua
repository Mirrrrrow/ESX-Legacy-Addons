IsSearched, Medic = false, false
IsDead = false

local firstSpawn = true

RegisterNetEvent('esx:onPlayerLogout', function()
    firstSpawn = true
end)

AddEventHandler('esx:onPlayerSpawn', function()
    if firstSpawn then
        firstSpawn = false
        return
    end

    IsDead = false
end)

AddEventHandler('esx:onPlayerDeath', function()
    IsDead = true
end)

-- Create blips
CreateThread(function()
    if Config.LoadIpl then
        RequestIpl('Coroner_Int_on')
    end

    for i = 1, #Config.Hospitals do
        local hospital = Config.Hospitals[i]
        local coords = hospital.Blip.coords
        local blip = AddBlipForCoord(coords.x, coords.y, coords.z)

        SetBlipSprite(blip, hospital.Blip.sprite)
        SetBlipScale(blip, hospital.Blip.scale)
        SetBlipColour(blip, hospital.Blip.color)
        SetBlipAsShortRange(blip, true)

        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(TranslateCap('blip_hospital'))
        EndTextCommandSetBlipName(blip)
    end
end)

RegisterNetEvent('esx_ambulancejob:clsearch', function(medicId)
    if not IsDead then return end

    local coords = GetEntityCoords(ESX.PlayerData.ped)
    local playersInArea = ESX.Game.GetPlayersInArea(coords, 50.0)

    for i = 1, #playersInArea, 1 do
        local player = playersInArea[i]
        if player == GetPlayerFromServerId(medicId) then
            MedicPlayerId = tonumber(medicId)
            IsSearched = true
            break
        end
    end
end)

RegisterNetEvent('esx_ambulancejob:useItem', function(itemName)
    ESX.CloseContext()

    if itemName == 'medikit' then
        local lib, anim = 'anim@heists@narcotics@funding@gang_idle', 'gang_chatting_idle01' -- TODO better animations

        ESX.Streaming.RequestAnimDict(lib, function()
            TaskPlayAnim(ESX.PlayerData.ped, lib, anim, 8.0, -8.0, -1, 0, 0, false, false, false)
            RemoveAnimDict(lib)

            Wait(500)
            while IsEntityPlayingAnim(ESX.PlayerData.ped, lib, anim, 3) do
                Wait(0)
                DisableAllControlActions(0)
            end

            TriggerEvent('esx_ambulancejob:heal', 'big', true)
            ESX.ShowNotification(TranslateCap('used_medikit'))
        end)
    elseif itemName == 'bandage' then
        local lib, anim = 'anim@heists@narcotics@funding@gang_idle', 'gang_chatting_idle01' -- TODO better animations

        ESX.Streaming.RequestAnimDict(lib, function()
            TaskPlayAnim(ESX.PlayerData.ped, lib, anim, 8.0, -8.0, -1, 0, 0, false, false, false)
            RemoveAnimDict(lib)

            Wait(500)
            while IsEntityPlayingAnim(ESX.PlayerData.ped, lib, anim, 3) do
                Wait(0)
                DisableAllControlActions(0)
            end

            TriggerEvent('esx_ambulancejob:heal', 'small', true)
            ESX.ShowNotification(TranslateCap('used_bandage'))
        end)
    end
end)
