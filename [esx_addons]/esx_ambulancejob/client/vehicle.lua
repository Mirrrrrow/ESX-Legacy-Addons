local spawnedVehicles = {}

local function deleteSpawnedVehicles()
	while #spawnedVehicles > 0 do
		local vehicle = spawnedVehicles[1]
		ESX.Game.DeleteVehicle(vehicle)
		table.remove(spawnedVehicles, 1)
	end
end

local function waitForVehicleToLoad(modelHash)
	modelHash = (type(modelHash) == 'number' and modelHash or joaat(modelHash))

	if not HasModelLoaded(modelHash) then
		RequestModel(modelHash)

		BeginTextCommandBusyspinnerOn('STRING')
		AddTextComponentSubstringPlayerName(TranslateCap('vehicleshop_awaiting_model'))
		EndTextCommandBusyspinnerOn(4)

		while not HasModelLoaded(modelHash) do
			Wait(0)
			DisableAllControlActions(0)
		end

		BusyspinnerOff()
	end
end

local function storeNearbyVehicle(playerCoords)
	local vehicles = ESX.Game.GetVehiclesInArea(playerCoords, 30.0)

	if not next(vehicles) then
		return ESX.ShowNotification(TranslateCap('garage_store_novehicle'))
	end

	local plates = {}
	local plateToVehicle = {}

	for i = 1, #vehicles do
		local vehicle = vehicles[i]

		-- Make sure the vehicle we're saving is empty, or else it won't be deleted
		if GetVehicleNumberOfPassengers(vehicle) == 0 and IsVehicleSeatFree(vehicle, -1) then
			local plate = ESX.Math.Trim(GetVehicleNumberPlateText(vehicle))
			plates[#plates + 1] = plate
			plateToVehicle[plate] = vehicle
		end
	end

	ESX.TriggerServerCallback('esx_ambulancejob:storeNearbyVehicle', function(plate)
		if not plate then
			return ESX.ShowNotification(TranslateCap('garage_has_notstored'))
		end
		local vehicleId = plateToVehicle[plate]
		local attempts = 0
		ESX.Game.DeleteVehicle(vehicleId)
		isBusy = true

		CreateThread(function()
			BeginTextCommandBusyspinnerOn('STRING')
			AddTextComponentSubstringPlayerName(TranslateCap('garage_storing'))
			EndTextCommandBusyspinnerOn(4)

			while isBusy do
				Wait(100)
			end

			BusyspinnerOff()
		end)

		-- Workaround for vehicle not deleting when other players are near it.
		while DoesEntityExist(vehicleId) do
			Wait(500)
			attempts = attempts + 1

			-- Give up
			if attempts > 30 then
				break
			end

			vehicles = ESX.Game.GetVehiclesInArea(playerCoords, 30.0)
			if #vehicles > 0 then
				for i = 1, #vehicles do
					local vehicle = vehicles[i]
					if ESX.Math.Trim(GetVehicleNumberPlateText(vehicle)) == plate then
						ESX.Game.DeleteVehicle(vehicle)
						break
					end
				end
			end
		end

		isBusy = false
		ESX.ShowNotification(TranslateCap('garage_has_stored'))
	end, plates)
end

local function getAvailableVehicleSpawnPoint(hospital, part, partNum)
	local spawnPoints = Config.Hospitals[hospital][part][partNum].SpawnPoints
	local found, foundSpawnPoint = false, nil

	for i = 1, #spawnPoints, 1 do
		if ESX.Game.IsSpawnPointClear(spawnPoints[i].coords, spawnPoints[i].radius) then
			found, foundSpawnPoint = true, spawnPoints[i]
			break
		end
	end

	if not found then
		ESX.ShowNotification(TranslateCap('garage_blocked'))
		return false
	end

	return true, foundSpawnPoint
end

local vehicleSpawnerElements = {
	{ unselectable = true, icon = "fas fa-car",                       title = TranslateCap('garage_title') },
	{ icon = "fas fa-car", title = TranslateCap('garage_storeditem'), action = 'garage' },
	{ icon = "fas fa-car", title = TranslateCap('garage_storeitem'),  action = 'store_garage' },
	{ icon = "fas fa-car", title = TranslateCap('garage_buyitem'),    action = 'buy_vehicle' }
}

function OpenVehicleSpawnerMenu(type, hospital, part, partNum)
	local playerCoords = GetEntityCoords(ESX.PlayerData.ped)

	ESX.OpenContext("right", vehicleSpawnerElements, function(_, vehicleSpawnerElement)
		if vehicleSpawnerElement.action == "buy_vehicle" then
			local shopElements = {}
			local authorizedVehicles = Config.AuthorizedVehicles[type][ESX.PlayerData.job.grade_name]
			local shopCoords = Config.Hospitals[hospital][part][partNum].InsideShop

			if #authorizedVehicles == 0 then
				return ESX.ShowNotification(TranslateCap('garage_notauthorized'))
			end

			for _, vehicle in ipairs(authorizedVehicles) do
				if IsModelInCdimage(vehicle.model) then
					local vehicleLabel = GetLabelText(GetDisplayNameFromVehicleModel(vehicle.model))

					shopElements[#shopElements + 1] = {
						icon  = 'fas fa-car',
						title = ('%s - <span style="color:green;">%s</span>'):format(vehicleLabel, TranslateCap('shop_item', ESX.Math.GroupDigits(vehicle.price))),
						name  = vehicleLabel,
						model = vehicle.model,
						price = vehicle.price,
						props = vehicle.props,
						type  = type
					}
				end
			end

			if #shopElements == 0 then
				return ESX.ShowNotification(TranslateCap('garage_notauthorized'))
			end

			OpenShopMenu(shopElements, playerCoords, shopCoords)
		elseif vehicleSpawnerElement.action == "garage" then
			local garage = {
				{ unselectable = true, icon = "fas fa-car", title = "Garage" }
			}

			ESX.TriggerServerCallback('esx_vehicleshop:retrieveJobVehicles', function(jobVehicles)
				if #jobVehicles == 0 then
					return ESX.ShowNotification(TranslateCap('garage_empty'))
				end

				local allVehicleProps = {}

				for _, v in ipairs(jobVehicles) do
					local props = json.decode(v.vehicle)

					if IsModelInCdimage(props.model) then
						local vehicleName = GetLabelText(GetDisplayNameFromVehicleModel(props.model))
						local label = ('%s - <span style="color:darkgoldenrod;">%s</span>: '):format(vehicleName, props.plate)

						if v.stored == 1 or v.stored == true then
							label = label .. ('<span style="color:green;">%s</span>'):format(TranslateCap('garage_stored'))
						elseif v.stored == 0 or v.stored == false then
							label = label .. ('<span style="color:darkred;">%s</span>'):format(TranslateCap('garage_notstored'))
						end

						garage[#garage + 1] = {
							icon = 'fas fa-car',
							title = label,
							stored = v.stored,
							model = props.model,
							plate = props.plate
						}

						allVehicleProps[props.plate] = props
					end
				end

				if #garage == 0 then
					return ESX.ShowNotification(TranslateCap('garage_empty'))
				end

				ESX.OpenContext("right", garage, function(_, garageElement)
					if garageElement.stored ~= 1 then return ESX.ShowNotification(TranslateCap('garage_notavailable')) end
					local foundSpawn, spawnPoint = getAvailableVehicleSpawnPoint(hospital, part, partNum)

					if not foundSpawn or not spawnPoint then return end

					ESX.CloseContext()

					local plate = garageElement.plate
					ESX.Game.SpawnVehicle(garageElement.model, spawnPoint.coords, spawnPoint.heading, function(vehicle)
						local vehicleProps = allVehicleProps[plate]
						ESX.Game.SetVehicleProperties(vehicle, vehicleProps)

						TriggerServerEvent('esx_vehicleshop:setJobVehicleState', plate, false)
						ESX.ShowNotification(TranslateCap('garage_released'))
					end)
				end)
			end, type)
		elseif vehicleSpawnerElement.action == "store_garage" then
			storeNearbyVehicle(playerCoords)
		end
	end)
end

function OpenShopMenu(shopElements, restoreCoords, shopCoords)
	IsInShopMenu = true
	local playerPed = ESX.PlayerData.ped

	ESX.OpenContext("right", shopElements, function(_, shopElement)
		local subMenuElements = {
			{ unselectable = true, icon = "fas fa-car", title = shopElement.title },
			{ icon = "fas fa-eye", title = "View",      value = "view" }
		}

		local model = shopElement.model
		ESX.OpenContext("right", subMenuElements, function(_, actionElement)
			if actionElement.value == "view" then
				deleteSpawnedVehicles()
				waitForVehicleToLoad(model)

				ESX.Game.SpawnLocalVehicle(model, shopCoords.xyz, shopCoords.w, function(vehicle)
					table.insert(spawnedVehicles, vehicle)
					TaskWarpPedIntoVehicle(playerPed, vehicle, -1)
					FreezeEntityPosition(vehicle, true)
					SetModelAsNoLongerNeeded(model)

					if shopElement.props then
						ESX.Game.SetVehicleProperties(vehicle, shopElement.props)
					end
				end)

				local carManagementElements = {
					{ unselectable = true,          icon = "fas fa-car",    title = shopElement.title },
					{ icon = "fas fa-check-double", title = "Buy",          value = "buy" },
					{ icon = "fas fa-eye",          title = "Stop Viewing", value = "stop" }
				}

				ESX.OpenContext("right", carManagementElements, function(_, carManagementElement)
					if carManagementElement.value == 'stop' then
						IsInShopMenu = false
						ESX.CloseContext()

						deleteSpawnedVehicles()
						FreezeEntityPosition(playerPed, false)
						SetEntityVisible(playerPed, true, true)

						ESX.Game.Teleport(playerPed, restoreCoords)
					elseif carManagementElement.value == "buy" then
						local newPlate = exports['esx_vehicleshop']:GeneratePlate()
						local vehicle  = GetVehiclePedIsIn(playerPed, false)
						local props    = ESX.Game.GetVehicleProperties(vehicle)
						props.plate    = newPlate

						ESX.TriggerServerCallback('esx_ambulancejob:buyJobVehicle', function(bought)
							if not bought then
								ESX.ShowNotification(TranslateCap('vehicleshop_money'))
								ESX.CloseContext()

								return
							end

							IsInShopMenu = false

							ESX.ShowNotification(TranslateCap('vehicleshop_bought', shopElement.name, ESX.Math.GroupDigits(shopElement.price)))
							ESX.CloseContext()

							deleteSpawnedVehicles()
							FreezeEntityPosition(playerPed, false)
							SetEntityVisible(playerPed, true, true)

							ESX.Game.Teleport(playerPed, restoreCoords)
						end, props, shopElement.type)
					end
				end, function()
					IsInShopMenu = false
					ESX.CloseContext()

					deleteSpawnedVehicles()
					FreezeEntityPosition(playerPed, false)
					SetEntityVisible(playerPed, true, true)

					ESX.Game.Teleport(playerPed, restoreCoords)
				end)
			end
		end)
	end)
end

CreateThread(function()
	while true do
		local sleep = 1500

		if IsInShopMenu then
			sleep = 0
			DisableControlAction(0, 75, true) -- Disable exit vehicle
			DisableControlAction(27, 75, true) -- Disable exit vehicle
		end

		Wait(sleep)
	end
end)
