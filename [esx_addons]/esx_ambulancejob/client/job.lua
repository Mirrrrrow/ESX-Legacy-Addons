local CurrentAction, CurrentActionMsg, CurrentActionData = nil, '', {}
local HasAlreadyEnteredMarker, LastHospital, LastPart, LastPartNum
local isBusy, deadPlayers, deadPlayerBlips, isOnDuty = false, {}, {}, false
IsInShopMenu = false

local function revivePlayer(closestPlayer)
	isBusy = true

	ESX.TriggerServerCallback('esx_ambulancejob:getItemAmount', function(quantity)
		if quantity == 0 then return ESX.ShowNotification(TranslateCap('not_enough_medikit')) end

		local closestPlayerPed = GetPlayerPed(closestPlayer)
		local closestPlayerSrc = GetPlayerServerId(closestPlayer)

		if not Player(closestPlayerSrc).state.isDead then return ESX.ShowNotification(TranslateCap('player_not_unconscious')) end

		local playerPed = ESX.PlayerData.ped
		local lib, anim = 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest'
		ESX.ShowNotification(TranslateCap('revive_inprogress'))

		for i = 1, 15 do
			Wait(900)

			ESX.Streaming.RequestAnimDict(lib, function()
				TaskPlayAnim(playerPed, lib, anim, 8.0, -8.0, -1, 0, 0.0, false, false, false)
				RemoveAnimDict(lib)
			end)
		end

		TriggerServerEvent('esx_ambulancejob:removeItem', 'medikit')
		TriggerServerEvent('esx_ambulancejob:revive', GetPlayerServerId(closestPlayer))

		isBusy = false
	end, 'medikit')
end

local function fastTravel(coords, heading)
	local playerPed = ESX.PlayerData.ped

	DoScreenFadeOut(800)

	while not IsScreenFadedOut() do
		Wait(500)
	end

	ESX.Game.Teleport(playerPed, coords, function()
		DoScreenFadeIn(800)

		if heading then
			SetEntityHeading(playerPed, heading)
		end
	end)
end

function OpenAmbulanceActionsMenu()
	local elements = {
		{ unselectable = true,   icon = 'fas fa-shirt',             title = TranslateCap('ambulance') },
		{ icon = 'fas fa-shirt', title = TranslateCap('cloakroom'), value = 'cloakroom' }
	}

	if Config.EnablePlayerManagement and ESX.PlayerData.job.grade_name == 'boss' then
		elements[#elements + 1] = {
			icon = 'fas fa-ambulance',
			title = TranslateCap('boss_actions'),
			value = 'boss_actions'
		}
	end

	ESX.OpenContext('right', elements, function(_, element)
		if element.value == 'cloakroom' then
			OpenCloakroomMenu()
		elseif element.value == 'boss_actions' then
			TriggerEvent('esx_society:openBossMenu', 'ambulance', function(_, menu)
				menu.close()
			end, { wash = false })
		end
	end)
end

local mobileAmbulanceElements = {
	{ unselectable = true,       icon = 'fas fa-ambulance',        title = TranslateCap('ambulance') },
	{ icon = 'fas fa-ambulance', title = TranslateCap('ems_menu'), value = 'citizen_interaction' }
}

function OpenMobileAmbulanceActionsMenu()
	ESX.OpenContext('right', mobileAmbulanceElements, function(_, mobileAmbulanceElement)
		if mobileAmbulanceElement.value == 'citizen_interaction' then
			local actions = {
				{ unselectable = true,     icon = 'fas fa-ambulance',                 title = mobileAmbulanceElement.title },
				{ icon = 'fas fa-syringe', title = TranslateCap('ems_menu_revive'),   value = 'revive' },
				{ icon = 'fas fa-bandage', title = TranslateCap('ems_menu_small'),    value = 'small' },
				{ icon = 'fas fa-bandage', title = TranslateCap('ems_menu_big'),      value = 'big' },
				{ icon = 'fas fa-car',     title = TranslateCap('ems_menu_putincar'), value = 'put_in_vehicle' },
				{ icon = 'fas fa-syringe', title = TranslateCap('ems_menu_search'),   value = 'search' },
			}

			ESX.OpenContext('right', actions, function(_, action)
				if isBusy then return end
				local closestPlayer, closestDistance = ESX.Game.GetClosestPlayer()

				if action.value == 'search' then
					TriggerServerEvent('esx_ambulancejob:svsearch')
				elseif closestPlayer == -1 or closestDistance > 1.0 then
					ESX.ShowNotification(TranslateCap('no_players'))
				else
					if action.value == 'revive' then
						revivePlayer(closestPlayer)
					elseif action.value == 'small' then
						ESX.TriggerServerCallback('esx_ambulancejob:getItemAmount', function(quantity)
							if quantity == 0 then return ESX.ShowNotification(TranslateCap('not_enough_bandage')) end
							local closestPlayerPed = GetPlayerPed(closestPlayer)
							local health = GetEntityHealth(closestPlayerPed)

							if health <= 0 then
								return ESX.ShowNotification(TranslateCap('player_not_conscious'))
							end

							local playerPed = PlayerPedId()

							isBusy = true
							ESX.ShowNotification(TranslateCap('heal_inprogress'))
							TaskStartScenarioInPlace(playerPed, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
							Wait(10000)
							ClearPedTasks(playerPed)

							TriggerServerEvent('esx_ambulancejob:removeItem', 'bandage')
							TriggerServerEvent('esx_ambulancejob:heal', GetPlayerServerId(closestPlayer), 'small')
							ESX.ShowNotification(TranslateCap('heal_complete', GetPlayerName(closestPlayer)))
							isBusy = false
						end, 'bandage')
					elseif action.value == 'big' then
						ESX.TriggerServerCallback('esx_ambulancejob:getItemAmount', function(quantity)
							if quantity == 0 then return ESX.ShowNotification(TranslateCap('not_enough_medikit')) end
							local closestPlayerPed = GetPlayerPed(closestPlayer)
							local health = GetEntityHealth(closestPlayerPed)

							if health <= 0 then
								return ESX.ShowNotification(TranslateCap('player_not_conscious'))
							end

							local playerPed = PlayerPedId()

							isBusy = true
							ESX.ShowNotification(TranslateCap('heal_inprogress'))
							TaskStartScenarioInPlace(playerPed, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
							Wait(10000)
							ClearPedTasks(playerPed)

							TriggerServerEvent('esx_ambulancejob:removeItem', 'medikit')
							TriggerServerEvent('esx_ambulancejob:heal', GetPlayerServerId(closestPlayer), 'big')
							ESX.ShowNotification(TranslateCap('heal_complete', GetPlayerName(closestPlayer)))
							isBusy = false
						end, 'medikit')
					elseif action.value == 'put_in_vehicle' then
						TriggerServerEvent('esx_ambulancejob:putInVehicle', GetPlayerServerId(closestPlayer))
					end
				end
			end)
		end
	end)
end

AddEventHandler('esx_ambulancejob:hasEnteredMarker', function(hospital, part, partNum)
	if part == 'AmbulanceActions' then
		CurrentAction = part
		CurrentActionMsg = TranslateCap('actions_prompt')
		CurrentActionData = {}
	elseif part == 'Pharmacy' then
		CurrentAction = part
		CurrentActionMsg = TranslateCap('open_pharmacy')
		CurrentActionData = {}
	elseif part == 'Vehicles' then
		CurrentAction = part
		CurrentActionMsg = TranslateCap('garage_prompt')
		CurrentActionData = { hospital = hospital, partNum = partNum }
	elseif part == 'Helicopters' then
		CurrentAction = part
		CurrentActionMsg = TranslateCap('helicopter_prompt')
		CurrentActionData = { hospital = hospital, partNum = partNum }
	elseif part == 'FastTravelsPrompt' then
		local travelItem = Config.Hospitals[hospital][part][partNum]

		CurrentAction = part
		CurrentActionMsg = travelItem.Prompt
		CurrentActionData = { to = travelItem.To.coords, heading = travelItem.To.heading }
	end

	ESX.TextUI(CurrentActionMsg)
end)

AddEventHandler('esx_ambulancejob:hasExitedMarker', function()
	if not isInShopMenu then
		ESX.CloseContext()
	end

	ESX.HideUI()
	CurrentAction = nil
end)

local cloakroomMainElements = {
	{ unselectable = true,   icon = 'fas fa-shirt',                     title = TranslateCap('cloakroom') },
	{ icon = 'fas fa-shirt', title = TranslateCap('ems_clothes_civil'), value = 'citizen_wear' },
	{ icon = 'fas fa-shirt', title = TranslateCap('ems_clothes_ems'),   value = 'ambulance_wear' },
}
function OpenCloakroomMenu()
	ESX.OpenContext('right', cloakroomMainElements, function(_, cloakroomMainElement)
		if cloakroomMainElement.value == 'citizen_wear' then
			ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
				TriggerEvent('skinchanger:loadSkin', skin)
				isOnDuty = false

				for playerId, v in pairs(deadPlayerBlips) do
					RemoveBlip(v)
					deadPlayerBlips[playerId] = nil
				end

				deadPlayers = {}
				if Config.Debug then
					print('[^2INFO^7] Off Duty')
				end
			end)
		elseif cloakroomMainElement.value == 'ambulance_wear' then
			ESX.TriggerServerCallback('esx_skin:getPlayerSkin', function(skin, jobSkin)
				if skin.sex == 0 then
					TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_male)
				else
					TriggerEvent('skinchanger:loadClothes', skin, jobSkin.skin_female)
				end

				isOnDuty = true
				ESX.TriggerServerCallback('esx_ambulancejob:getDeadPlayers', function(_deadPlayers)
					TriggerEvent('esx_ambulancejob:setDeadPlayers', _deadPlayers)
				end)

				if Config.Debug then
					print('[^2INFO^7] Player Sex |^5' .. tostring(skin.sex) .. '^7')
					print('[^2INFO^7] On Duty')
				end
			end)
		end
	end)
end

local cachedPharmacyMenuElements = {}
function OpenPharmacyMenu()
	ESX.OpenContext('right', cachedPharmacyMenuElements, function(_, element)
		local inputElements = {
			{ unselectable = true,          icon = 'fas fa-pills', title = element.title },
			{
				title = 'Amount',
				input = true,
				inputType = 'number',
				inputMin = 1,
				inputMax = 100,
				inputPlaceholder = 'Amount to buy..'
			},
			{ icon = 'fas fa-check-double', title = 'Confirm',     val = 'confirm' }
		}

		ESX.OpenContext('right', inputElements, function(inputMenu)
			local amount = inputMenu.eles[2].inputValue
			if Config.Debug then
				print('[^2INFO^7] Attempting to Give Item - ^5' .. tostring(element.item) .. '^7')
			end

			TriggerServerEvent('esx_ambulancejob:giveItem', element.item, amount)
		end, function()
			OpenPharmacyMenu()
		end)
	end)
end

CreateThread(function()
	local elements = {
		{ unselectable = true, icon = 'fas fa-pills', title = TranslateCap('pharmacy_menu_title') }
	}
	for _, v in pairs(Config.PharmacyItems) do
		elements[#elements + 1] = {
			icon = 'fas fa-pills',
			title = v.title,
			item = v.item
		}
	end

	cachedPharmacyMenuElements = elements

	while true do
		local sleep = 1500

		if ESX.PlayerData.job and ESX.PlayerData.job.name == 'ambulance' then
			local playerCoords = GetEntityCoords(PlayerPedId())
			local isInMarker, hasExited = false, false
			local currentHospital, currentPart, currentPartNum

			for hospitalNum, hospital in pairs(Config.Hospitals) do
				-- Ambulance Actions
				for k, v in ipairs(hospital.AmbulanceActions) do
					local distance = #(playerCoords - v)

					if distance < Config.DrawDistance then
						sleep = 0
						DrawMarker(Config.Marker.type, v, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Marker.x, Config.Marker.y, Config.Marker.z,
							Config.Marker.r, Config.Marker.g, Config.Marker.b, Config.Marker.a, false, false, 2, Config.Marker.rotate, nil,
							nil, false)


						if distance < Config.Marker.x then
							isInMarker, currentHospital, currentPart, currentPartNum = true, hospitalNum, 'AmbulanceActions', k
						end
					end
				end

				-- Pharmacies
				for k, v in ipairs(hospital.Pharmacies) do
					local distance = #(playerCoords - v)

					if distance < Config.DrawDistance then
						sleep = 0
						DrawMarker(Config.Marker.type, v, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, Config.Marker.x, Config.Marker.y, Config.Marker.z,
							Config.Marker.r, Config.Marker.g, Config.Marker.b, Config.Marker.a, false, false, 2, Config.Marker.rotate, nil,
							nil, false)


						if distance < Config.Marker.x then
							isInMarker, currentHospital, currentPart, currentPartNum = true, hospitalNum, 'Pharmacy', k
						end
					end
				end

				-- Vehicle Spawners
				for k, v in ipairs(hospital.Vehicles) do
					local distance = #(playerCoords - v.Spawner)

					if distance < Config.DrawDistance then
						sleep = 0
						DrawMarker(v.Marker.type, v.Spawner, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Marker.x, v.Marker.y, v.Marker.z, v.Marker.r,
							v.Marker.g, v.Marker.b, v.Marker.a, false, false, 2, v.Marker.rotate, nil, nil, false)


						if distance < v.Marker.x then
							isInMarker, currentHospital, currentPart, currentPartNum = true, hospitalNum, 'Vehicles', k
						end
					end
				end

				-- Helicopter Spawners
				for k, v in ipairs(hospital.Helicopters) do
					local distance = #(playerCoords - v.Spawner)

					if distance < Config.DrawDistance then
						sleep = 0
						DrawMarker(v.Marker.type, v.Spawner, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Marker.x, v.Marker.y, v.Marker.z, v.Marker.r,
							v.Marker.g, v.Marker.b, v.Marker.a, false, false, 2, v.Marker.rotate, nil, nil, false)


						if distance < v.Marker.x then
							isInMarker, currentHospital, currentPart, currentPartNum = true, hospitalNum, 'Helicopters', k
						end
					end
				end

				-- Fast Travels (Prompt)
				for k, v in ipairs(hospital.FastTravelsPrompt) do
					local distance = #(playerCoords - v.From)

					if distance < Config.DrawDistance then
						sleep = 0
						DrawMarker(v.Marker.type, v.From, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Marker.x, v.Marker.y, v.Marker.z, v.Marker.r,
							v.Marker.g, v.Marker.b, v.Marker.a, false, false, 2, v.Marker.rotate, nil, nil, false)


						if distance < v.Marker.x then
							isInMarker, currentHospital, currentPart, currentPartNum = true, hospitalNum, 'FastTravelsPrompt', k
						end
					end
				end
			end

			-- Logic for exiting & entering markers
			if isInMarker and not HasAlreadyEnteredMarker or
				(isInMarker and (LastHospital ~= currentHospital or LastPart ~= currentPart or LastPartNum ~= currentPartNum)) then
				if (LastHospital ~= nil and LastPart ~= nil and LastPartNum ~= nil) and
					(LastHospital ~= currentHospital or LastPart ~= currentPart or LastPartNum ~= currentPartNum)
				then
					TriggerEvent('esx_ambulancejob:hasExitedMarker', LastHospital, LastPart, LastPartNum)
					hasExited = true
				end

				HasAlreadyEnteredMarker, LastHospital, LastPart, LastPartNum = true, currentHospital, currentPart, currentPartNum

				TriggerEvent('esx_ambulancejob:hasEnteredMarker', currentHospital, currentPart, currentPartNum)
			end

			if not hasExited and not isInMarker and HasAlreadyEnteredMarker then
				HasAlreadyEnteredMarker = false
				TriggerEvent('esx_ambulancejob:hasExitedMarker', LastHospital, LastPart, LastPartNum)
			end
		end
		Wait(sleep)
	end
end)

CreateThread(function()
	while true do
		local sleep = 1500

		if CurrentAction then
			sleep = 0

			if IsControlJustReleased(0, 38) then
				if CurrentAction == 'AmbulanceActions' then
					OpenAmbulanceActionsMenu()
				elseif CurrentAction == 'Pharmacy' then
					OpenPharmacyMenu()
				elseif CurrentAction == 'Vehicles' then
					OpenVehicleSpawnerMenu('car', CurrentActionData.hospital, CurrentAction, CurrentActionData.partNum)
				elseif CurrentAction == 'Helicopters' then
					OpenVehicleSpawnerMenu('helicopter', CurrentActionData.hospital, CurrentAction, CurrentActionData.partNum)
				elseif CurrentAction == 'FastTravelsPrompt' then
					fastTravel(CurrentActionData.to, CurrentActionData.heading)
				end

				CurrentAction = nil
			end
		end

		local playerCoords = GetEntityCoords(PlayerPedId())

		for _, hospital in pairs(Config.Hospitals) do
			-- Fast Travels
			for k, v in ipairs(hospital.FastTravels) do
				local distance = #(playerCoords - v.From)

				if distance < Config.DrawDistance then
					sleep = 0
					DrawMarker(v.Marker.type, v.From, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, v.Marker.x, v.Marker.y, v.Marker.z, v.Marker.r,
						v.Marker.g, v.Marker.b, v.Marker.a, false, false, 2, v.Marker.rotate, nil, nil, false)


					if distance < v.Marker.x then
						fastTravel(v.To.coords, v.To.heading)
					end
				end
			end
		end
		Wait(sleep)
	end
end)

RegisterNetEvent('esx_ambulancejob:putInVehicle', function()
	local playerPed = ESX.PlayerData.ped
	local vehicle, distance = ESX.Game.GetClosestVehicle()

	if not vehicle or distance > 5 then return end

	local maxSeats, freeSeat = GetVehicleMaxNumberOfPassengers(vehicle)

	for i = maxSeats - 1, 0, -1 do
		if IsVehicleSeatFree(vehicle, i) then
			freeSeat = i
			break
		end
	end

	if freeSeat then
		TaskWarpPedIntoVehicle(playerPed, vehicle, freeSeat)
	end
end)

RegisterNetEvent('esx_ambulancejob:heal', function(healType, quiet)
	local playerPed = ESX.PlayerData.ped
	local maxHealth = GetEntityMaxHealth(playerPed)

	if healType == 'small' then
		local health = GetEntityHealth(playerPed)
		local newHealth = math.min(maxHealth, math.floor(health + maxHealth / 8))
		SetEntityHealth(playerPed, newHealth)
	elseif healType == 'big' then
		SetEntityHealth(playerPed, maxHealth)
	end

	if Config.Debug then
		print('[^2INFO^7] Healing Player - ^5' .. tostring(healType) .. '^7')
	end
	if not quiet then
		ESX.ShowNotification(TranslateCap('healed'))
	end
end)

RegisterNetEvent('esx:setJob', function(job)
	if not isOnDuty or job.name == 'ambulance' then return end
	for playerId, v in pairs(deadPlayerBlips) do
		if Config.Debug then
			print('[^2INFO^7] Removing dead blip - ^5' .. tostring(playerId) .. '^7')
		end

		RemoveBlip(v)
		deadPlayerBlips[playerId] = nil
	end

	isOnDuty = false
end)

RegisterNetEvent('esx_ambulancejob:PlayerDead', function(player)
	if Config.Debug then
		print('[^2INFO^7] Player Dead | ^5' .. tostring(player) .. '^7')
	end

	deadPlayers[player] = 'dead'
end)

RegisterNetEvent('esx_ambulancejob:PlayerNotDead', function(player)
	if deadPlayerBlips[player] then
		RemoveBlip(deadPlayerBlips[player])
		deadPlayerBlips[player] = nil
	end

	if Config.Debug then
		print('[^2INFO^7] Player Alive | ^5' .. tostring(player) .. '^7')
	end

	deadPlayers[player] = nil
end)

RegisterNetEvent('esx_ambulancejob:setDeadPlayers', function(_deadPlayers)
	deadPlayers = _deadPlayers

	if not isOnDuty then return end
	for playerId, v in pairs(deadPlayerBlips) do
		RemoveBlip(v)
		deadPlayerBlips[playerId] = nil
	end

	for playerId, status in pairs(deadPlayers) do
		if Config.Debug then
			print('[^2INFO^7] Player Dead | ^5' .. tostring(playerId) .. '^7')
		end

		if status == 'distress' then
			if Config.Debug then
				print('[^2INFO^7] Creating Distress Blip for Player - ^5' .. tostring(playerId) .. '^7')
			end
			local player = GetPlayerFromServerId(playerId)
			local playerPed = GetPlayerPed(player)
			local blip = AddBlipForEntity(playerPed)

			SetBlipSprite(blip, 303)
			SetBlipColour(blip, 1)
			SetBlipFlashes(blip, true)
			SetBlipCategory(blip, 7)

			BeginTextCommandSetBlipName('STRING')
			AddTextComponentSubstringPlayerName(TranslateCap('blip_dead'))
			EndTextCommandSetBlipName(blip)

			deadPlayerBlips[playerId] = blip
		end
	end
end)

RegisterNetEvent('esx_ambulancejob:PlayerDistressed', function(playerId, playerCoords)
	deadPlayers[playerId] = 'distress'

	if not isOnDuty then return end

	if Config.Debug then
		print('[^2INFO^7] Player Distress Recived - ID:^5' .. tostring(playerId) .. '^7')
	end

	ESX.ShowNotification(TranslateCap('unconscious_found'), 'error', 10000)
	deadPlayerBlips[playerId] = nil

	local blip = AddBlipForCoord(playerCoords.x, playerCoords.y, playerCoords.z)
	SetBlipSprite(blip, Config.DistressBlip.Sprite)
	SetBlipColour(blip, Config.DistressBlip.Color)
	SetBlipScale(blip, Config.DistressBlip.Scale)
	SetBlipFlashes(blip, true)

	BeginTextCommandSetBlipName('STRING')
	AddTextComponentSubstringPlayerName(TranslateCap('blip_dead'))
	EndTextCommandSetBlipName(blip)

	deadPlayerBlips[playerId] = blip
end)

RegisterCommand('ambulance', function(_)
	if ESX.PlayerData.job and ESX.PlayerData.job.name == 'ambulance' and not ESX.PlayerData.dead then
		OpenMobileAmbulanceActionsMenu()
	end
end)
RegisterKeyMapping('ambulance', 'Open Ambulance Actions Menu', 'keyboard', 'F6')
