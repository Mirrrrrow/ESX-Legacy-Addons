local playersHealing, deadPlayers = {}, {}
if GetResourceState('esx_society') ~= 'missing' then
	TriggerEvent('esx_society:registerSociety', 'ambulance', 'Ambulance', 'society_ambulance', 'society_ambulance',
		'society_ambulance', { type = 'public' })
end

local function setDeathState(src, bool)
	if not src or bool == nil then return end

	Player(src).state:set('isDead', bool, true)
end

RegisterNetEvent('esx_ambulancejob:revive', function(playerId)
	playerId = tonumber(playerId) --[[@as number]]
	local xPlayer = source and ESX.Player(source)

	if not xPlayer or xPlayer.getJob().name ~= 'ambulance' then return end

	local xTarget = ESX.Player(playerId)

	if not xTarget then return xPlayer.showNotification(TranslateCap('revive_fail_offline')) end

	if not deadPlayers[playerId] then
		return xPlayer.showNotification(TranslateCap('player_not_unconscious'))
	end

	if Config.ReviveReward > 0 then
		xPlayer.showNotification(TranslateCap('revive_complete_award', xTarget.name, Config.ReviveReward))
		xPlayer.addMoney(Config.ReviveReward, 'Revive Reward')
		xTarget.triggerEvent('esx_ambulancejob:revive')
		setDeathState(xTarget.source, false)
	else
		xPlayer.showNotification(TranslateCap('revive_complete', xTarget.name))
		xTarget.triggerEvent('esx_ambulancejob:revive')
		setDeathState(xTarget.source, false)
	end

	local xMedics = ESX.GetExtendedPlayers('job', 'ambulance')

	for _, xMedic in pairs(xMedics) do
		xMedic.triggerEvent('esx_ambulancejob:PlayerNotDead', playerId)
	end

	deadPlayers[playerId] = nil
end)

AddEventHandler('txAdmin:events:healedPlayer', function(eventData)
	if GetInvokingResource() ~= 'monitor' or type(eventData) ~= 'table' or type(eventData.id) ~= 'number' then
		return
	end

	local playerId = eventData.id
	if not deadPlayers[playerId] then return end

	TriggerClientEvent('esx_ambulancejob:revive', playerId)
	local xMedics = ESX.GetExtendedPlayers('job', 'ambulance')

	for _, xMedic in pairs(xMedics) do
		xMedic.triggerEvent('esx_ambulancejob:PlayerNotDead', playerId)
	end

	deadPlayers[playerId] = nil
end)

RegisterNetEvent('esx:onPlayerDeath', function()
	local playerId = source
	setDeathState(playerId, true)
	deadPlayers[playerId] = 'dead'

	local xMedics = ESX.GetExtendedPlayers('job', 'ambulance')

	for _, xMedic in pairs(xMedics) do
		xMedic.triggerEvent('esx_ambulancejob:PlayerDead', source)
	end
end)

RegisterServerEvent('esx_ambulancejob:svsearch', function()
	TriggerClientEvent('esx_ambulancejob:clsearch', -1, source)
end)

RegisterNetEvent('esx_ambulancejob:onPlayerDistress', function()
	local playerId = source
	local injuredPed = GetPlayerPed(playerId)
	local injuredCoords = GetEntityCoords(injuredPed)

	if deadPlayers[playerId] then
		deadPlayers[playerId] = 'distress'
		local xMedics = ESX.GetExtendedPlayers('job', 'ambulance')

		for _, xMedic in pairs(xMedics) do
			xMedic.triggerEvent('esx_ambulancejob:PlayerDistressed', playerId, injuredCoords)
		end
	end
end)

RegisterNetEvent('esx:onPlayerSpawn', function()
	local playerId = source

	if not deadPlayers[playerId] then return end

	deadPlayers[playerId] = nil
	setDeathState(playerId, false)

	local xMedics = ESX.GetExtendedPlayers('job', 'ambulance')
	for _, xMedic in pairs(xMedics) do
		xMedic.triggerEvent('esx_ambulancejob:PlayerNotDead', playerId)
	end
end)

AddEventHandler('esx:playerDropped', function(playerId)
	if not deadPlayers[playerId] then return end

	deadPlayers[playerId] = nil
	setDeathState(playerId, false)

	local xMedics = ESX.GetExtendedPlayers('job', 'ambulance')
	for _, xMedic in pairs(xMedics) do
		xMedic.triggerEvent('esx_ambulancejob:PlayerNotDead', playerId)
	end
end)

RegisterNetEvent('esx_ambulancejob:heal', function(target, type)
	local xPlayer = ESX.Player(source)

	if xPlayer.getJob().name == 'ambulance' then
		TriggerClientEvent('esx_ambulancejob:heal', target, type)
	end
end)

RegisterNetEvent('esx_ambulancejob:putInVehicle', function(target)
	local xPlayer = ESX.Player(source)

	if xPlayer.getJob().name == 'ambulance' then
		TriggerClientEvent('esx_ambulancejob:putInVehicle', target)
	end
end)

ESX.RegisterServerCallback('esx_ambulancejob:removeItemsAfterRPDeath', function(source, cb)
	local xPlayer = ESX.Player(source)

	if Config.OxInventory and Config.RemoveItemsAfterRPDeath then
		exports.ox_inventory:ClearInventory(xPlayer.source)
		return cb()
	end

	if Config.RemoveCashAfterRPDeath then
		if xPlayer.getMoney() > 0 then
			xPlayer.removeMoney(xPlayer.getMoney(), 'Death')
		end

		if xPlayer.getAccount('black_money').money > 0 then
			xPlayer.setAccountMoney('black_money', 0, 'Death')
		end
	end

	if Config.RemoveItemsAfterRPDeath then
		for i = 1, #xPlayer.inventory, 1 do
			if xPlayer.inventory[i].count > 0 then
				xPlayer.setInventoryItem(xPlayer.inventory[i].name, 0)
			end
		end
	end

	if Config.OxInventory then return cb() end

	local playerLoadout = {}
	if Config.RemoveWeaponsAfterRPDeath then
		for i = 1, #xPlayer.loadout, 1 do
			xPlayer.removeWeapon(xPlayer.loadout[i].name)
		end
	else -- save weapons & restore em' since spawnmanager removes them
		for i = 1, #xPlayer.loadout, 1 do
			table.insert(playerLoadout, xPlayer.loadout[i])
		end

		-- give back wepaons after a couple of seconds
		CreateThread(function()
			Wait(5000)
			for i = 1, #playerLoadout, 1 do
				if playerLoadout[i].label ~= nil then
					xPlayer.addWeapon(playerLoadout[i].name, playerLoadout[i].ammo)
				end
			end
		end)
	end

	cb()
end)

if Config.EarlyRespawnFine then
	ESX.RegisterServerCallback('esx_ambulancejob:checkBalance', function(source, cb)
		local xPlayer = ESX.Player(source)
		local bankBalance = xPlayer.getAccount('bank').money

		cb(bankBalance >= Config.EarlyRespawnFineAmount)
	end)

	RegisterNetEvent('esx_ambulancejob:payFine', function()
		local xPlayer = ESX.Player(source)
		local fineAmount = Config.EarlyRespawnFineAmount

		xPlayer.showNotification(TranslateCap('respawn_bleedout_fine_msg', ESX.Math.GroupDigits(fineAmount)))
		xPlayer.removeAccountMoney('bank', fineAmount, 'Respawn Fine')
	end)
end

ESX.RegisterServerCallback('esx_ambulancejob:getItemAmount', function(source, cb, item)
	local xPlayer = ESX.Player(source)
	local quantity = xPlayer.getInventoryItem(item).count

	cb(quantity)
end)

ESX.RegisterServerCallback('esx_ambulancejob:buyJobVehicle', function(source, cb, vehicleProps, type)
	local xPlayer = ESX.Player(source)
	local price = getPriceFromHash(vehicleProps.model, xPlayer.getJob().grade_name, type)

	if price == 0 then return cb(false) end

	if xPlayer.getMoney() < price then return cb(false) end

	xPlayer.removeMoney(price, 'Job Vehicle Purchase')

	MySQL.insert.await('INSERT INTO owned_vehicles (owner, vehicle, plate, type, job, `stored`) VALUES (?, ?, ?, ?, ?, ?)',
		{ xPlayer.getIdentifier(), json.encode(vehicleProps), vehicleProps.plate, type, xPlayer.getJob().name, true }
	)

	cb(true)
end)

ESX.RegisterServerCallback('esx_ambulancejob:storeNearbyVehicle', function(source, cb, plates)
	local xPlayer = ESX.Player(source)

	local identifier = xPlayer.getIdentifier()
	local plate = MySQL.scalar.await('SELECT plate FROM owned_vehicles WHERE owner = ? AND plate IN (?) AND job = ?',
		{ identifier, plates, xPlayer.getJob().name })

	if not plate then return cb(false) end
	local rowsChanged = MySQL.update.await('UPDATE owned_vehicles SET `stored` = true WHERE owner = ? AND plate = ? AND job = ?',
		{ identifier, plate, xPlayer.getJob().name })

	cb(rowsChanged and plate or false)
end)

local function getPriceFromHash(vehicleHash, jobGrade, type)
	local vehicles = Config.AuthorizedVehicles[type][jobGrade]

	for i = 1, #vehicles do
		local vehicle = vehicles[i]
		if joaat(vehicle.model) == vehicleHash then
			return vehicle.price
		end
	end

	return 0
end

RegisterNetEvent('esx_ambulancejob:removeItem', function(item)
	local xPlayer = ESX.Player(source)
	xPlayer.removeInventoryItem(item, 1)

	if item == 'bandage' then
		xPlayer.showNotification(TranslateCap('used_bandage'))
	elseif item == 'medikit' then
		xPlayer.showNotification(TranslateCap('used_medikit'))
	end
end)

RegisterNetEvent('esx_ambulancejob:giveItem', function(itemName, amount)
	local xPlayer = ESX.Player(source)

	if xPlayer.getJob().name ~= 'ambulance' then
		print(('[^2WARNING^7] Player ^5%s^7 Tried Giving Themselves -> ^5' .. itemName .. '^7!'):format(xPlayer.source))
		return
	elseif (itemName ~= 'medikit' and itemName ~= 'bandage') then
		print(('[^2WARNING^7] Player ^5%s^7 Tried Giving Themselves -> ^5' .. itemName .. '^7!'):format(xPlayer.source))
		return
	end

	if xPlayer.canCarryItem(itemName, amount) then
		xPlayer.addInventoryItem(itemName, amount)
	else
		xPlayer.showNotification(TranslateCap('max_item'))
	end
end)

ESX.RegisterCommand('revive', 'admin', function(_, args)
	args.playerId.triggerEvent('esx_ambulancejob:revive')
end, true, {
	help = TranslateCap('revive_help'),
	validate = true,
	arguments = {
		{ name = 'playerId', help = 'The player id', type = 'player' }
	}
})

ESX.RegisterCommand('reviveall', 'admin', function()
	TriggerClientEvent('esx_ambulancejob:revive', -1)
end, false)

ESX.RegisterUsableItem('medikit', function(source)
	if playersHealing[source] then return end
	local xPlayer = ESX.Player(source)
	xPlayer.removeInventoryItem('medikit', 1)

	playersHealing[source] = true
	TriggerClientEvent('esx_ambulancejob:useItem', source, 'medikit')

	Wait(10000)
	playersHealing[source] = nil
end)

ESX.RegisterUsableItem('bandage', function(source)
	if playersHealing[source] then return end

	local xPlayer = ESX.Player(source)
	xPlayer.removeInventoryItem('bandage', 1)

	playersHealing[source] = true
	TriggerClientEvent('esx_ambulancejob:useItem', source, 'bandage')

	Wait(10000)
	playersHealing[source] = nil
end)

ESX.RegisterServerCallback('esx_ambulancejob:getDeadPlayers', function(source, cb)
	local xPlayer = ESX.Player(source)
	if xPlayer.getJob().name == 'ambulance' then
		cb(deadPlayers)
	end
end)

ESX.RegisterServerCallback('esx_ambulancejob:getDeathStatus', function(source, cb)
	local xPlayer = ESX.Player(source)
	local isDead = MySQL.scalar.await('SELECT is_dead FROM users WHERE identifier = ?', { xPlayer.getIdentifier() })

	cb(isDead == 1)
end)

RegisterNetEvent('esx_ambulancejob:setDeathStatus', function(isDead)
	local xPlayer = ESX.Player(source)

	if type(isDead) ~= 'boolean' then return end

	MySQL.update.await('UPDATE users SET is_dead = ? WHERE identifier = ?', { isDead, xPlayer.getIdentifier() })
	setDeathState(source, isDead)

	if isDead then return end

	local xMedics = ESX.GetExtendedPlayers('job', 'ambulance')
	for _, xMedic in pairs(xMedics) do
		xMedic.triggerEvent('esx_ambulancejob:PlayerNotDead', source)
	end
end)
