---@param playerId number
---@param state boolean
local function setDeathState(playerId, state)
    if not playerId or state == nil then return end

    Player(playerId).state:set('isDead', state, true)
end

RegisterNetEvent('esx_ambulancejob:setDeathStatus', function(isDead)
    local xPlayer = ESX.GetPlayerFromId(source)
    if type(isDead) ~= 'boolean' then return end

    MySQL.update.await('UPDATE users SET is_dead = ? WHERE identifier = ?', { isDead, xPlayer.getIdentifier() })

    setDeathState(source, isDead)

    if not isDead then
        local ambulancePlayers = ESX.GetExtendedPlayers('job', 'ambulance')
        for _, xTarget in pairs(ambulancePlayers) do
            xTarget.triggerEvent('esx_ambulancejob:PlayerNotDead', source)
        end
    end
end)

if Config.EarlyRespawnFine then
    ESX.RegisterServerCallback('esx_ambulancejob:checkBalance', function(playerId, cb)
        local xPlayer = ESX.GetPlayerFromId(playerId)
        local bankBalance = xPlayer.getAccount('bank').money

        cb(bankBalance >= Config.EarlyRespawnFineAmount)
    end)

    RegisterNetEvent('esx_ambulancejob:payFine', function()
        local xPlayer = ESX.GetPlayerFromId(source)
        local fineAmount = Config.EarlyRespawnFineAmount

        xPlayer.showNotification(TranslateCap('respawn_bleedout_fine_msg', ESX.Math.GroupDigits(fineAmount)))
        xPlayer.removeAccountMoney('bank', fineAmount, 'Respawn Fine')
    end)
end
