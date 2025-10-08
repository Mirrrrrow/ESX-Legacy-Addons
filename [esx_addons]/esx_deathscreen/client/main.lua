local firstSpawn, isDead = true, false

---@param seconds number?
---@return string, string
local function formatTime(seconds)
    seconds = tonumber(seconds)
    if seconds <= 0 then return '00', '00' end

    local hours = string.format('%02.f', math.floor(seconds / 3600))
    local mins = string.format('%02.f', math.floor(seconds / 60 - (hours * 60)))
    local secs = string.format('%02.f', math.floor(seconds - hours * 3600 - mins * 60))

    return mins, secs
end

local function drawGenericTextThisFrame()
    SetTextFont(4)
    SetTextScale(0.0, 0.5)
    SetTextColour(255, 255, 255, 255)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(true)
end

---@param text string
local function drawTimerText(text)
    drawGenericTextThisFrame()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.8)
end

local function drawDistressText()
    SetTextFont(4)
    SetTextScale(0.5, 0.5)
    SetTextColour(200, 50, 50, 255)
    SetTextDropshadow(0.1, 3, 27, 27, 255)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(TranslateCap('distress_send'))
    EndTextCommandDisplayText(0.446, 0.77)
end

---@param remainingTime number
---@param canPayFine boolean
---@return string
local function getBleedoutText(remainingTime, canPayFine)
    local text = TranslateCap('respawn_bleedout_in', formatTime(remainingTime))

    if not Config.EarlyRespawnFine then
        text = text .. TranslateCap('respawn_bleedout_prompt')
    elseif canPayFine then
        text = text .. TranslateCap('respawn_bleedout_fine', ESX.Math.GroupDigits(Config.EarlyRespawnFineAmount))
    end

    return text
end

---@param timeHeld number
---@param canPayFine boolean
---@return number, boolean, boolean
local function listenToRespawnInput(timeHeld, canPayFine)
    if not IsControlJustPressed(0, 38) then return 0, false, false end

    timeHeld += 1

    if timeHeld >= 120 then
        if Config.EarlyRespawnFine and canPayFine then return timeHeld, true, true end
        return timeHeld, true, false
    end

    return timeHeld, false, false
end

---@return { coords: vector3, heading: number }
local function getNearestRespawnPoint()
    local playerCoords = GetEntityCoords(ESX.PlayerData.ped)
    local closestPoint, closestDistance = nil, math.huge

    for _, point in pairs(Config.RespawnPoints) do
        local distance = #(playerCoords - vector3(point.x, point.y, point.z))
        if distance < closestDistance then
            closestPoint = point
            closestDistance = distance
        end
    end

    return closestPoint or { coords = playerCoords, heading = GetEntityHeading(ESX.PlayerData.ped) }
end

---@param point { coords: vector3, heading: number }
local function respawnPed(point)
    local ped = ESX.PlayerData.ped

    local coords, heading = point.coords, point.heading
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, heading, 1, false)
    SetPlayerInvincible(ped, false)
    ClearPedBloodDamage(ped)

    if Config.DeathAnim.enabled then
        FreezeEntityPosition(ped, false)
    end

    TriggerEvent('esx_basicneeds:resetStatus')
    TriggerServerEvent('esx:onPlayerSpawn')
    TriggerEvent('esx:onPlayerSpawn')
    TriggerEvent('playerSpawned')
end

local function sendDistressSignal()
    ESX.ShowNotification(TranslateCap('distress_sent'))
    TriggerServerEvent('esx_ambulancejob:onPlayerDistress')
end

local function bleedout()
    TriggerServerEvent('esx_ambulancejob:setDeathStatus', false)
    TriggerServerEvent('esx_ambulancejob:removeItemsAfterRPDeath')

    local respawnPoint = getNearestRespawnPoint()
    ESX.SetPlayerData('loadout', {})

    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do Wait(0) end

    respawnPed(respawnPoint)

    DoScreenFadeIn(800)
end

local function startDeathTimer()
    local canPayFine = Config.EarlyRespawnFine and ESX.AwaitServerCallback('esx_ambulancejob:canUseEarlyRespawn')

    local earlyRespawnTimer, bleedoutTimer = ESX.Math.Round(Config.EarlyRespawnTimer / 1000), ESX.Math.Round(Config.BleedoutTimer / 1000)

    local timeHeld = 0
    local lastTick = GetGameTimer()
    local distressSignalSent = false
    CreateThread(function()
        while isDead do
            local now = GetGameTimer()
            local deltaTime = now - lastTick

            -- Update timer every 1s
            if deltaTime >= 1000 then
                lastTick = now

                if earlyRespawnTimer > 0 then
                    earlyRespawnTimer -= 1
                elseif bleedoutTimer > 0 then
                    bleedoutTimer -= 1
                end
            end

            local drawText
            if earlyRespawnTimer > 0 then
                drawText = TranslateCap('respawn_available_in', formatTime(earlyRespawnTimer))
            elseif bleedoutTimer > 0 then
                drawText = getBleedoutText(bleedoutTimer, canPayFine)

                local shouldRespawn, shouldPayFine
                timeHeld, shouldRespawn, shouldPayFine = listenToRespawnInput(timeHeld, canPayFine)

                if shouldRespawn then
                    if shouldPayFine then
                        TriggerServerEvent('esx_ambulancejob:payFine')
                    end

                    CreateThread(bleedout)
                    break
                end
            else
                CreateThread(bleedout)
                break
            end

            drawTimerText(drawText)

            if not distressSignalSent then
                drawDistressText()

                if IsControlJustReleased(0, 47) then
                    distressSignalSent = true

                    sendDistressSignal()
                end
            end

            Wait(0)
        end
    end)
end

local function startDeathLoop()
    CreateThread(function()
        while isDead do
            DisableAllControlActions(0)
            EnableControlAction(0, 47, true)  -- G
            EnableControlAction(0, 245, true) -- T
            EnableControlAction(0, 38, true)  -- E

            ProcessCamControls()

            Wait(0)
        end
    end)
end

local function loadDeathAnimation()
    local deathAnim = Config.DeathAnim
    if not deathAnim.enabled then return end

    local dict, name, fadeIn, fadeOut, flags, playbackRate = deathAnim.dict, deathAnim.name, deathAnim.fadeIn, deathAnim.fadeOut, deathAnim.flags, deathAnim.playbackRate

    local coords                                           = GetEntityCoords(ESX.PlayerData.ped)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, 0.0, 0.0, false)

    ESX.Streaming.RequestAnimDict(dict)
    TaskPlayAnim(ESX.PlayerData.ped, dict, name, fadeIn, fadeOut,
        -1, flags, playbackRate, false, false, false)
    FreezeEntityPosition(ESX.PlayerData.ped, true)

    CreateThread(function()
        while isDead do
            if not IsEntityPlayingAnim(ESX.PlayerData.ped, dict, name, 3) then
                TaskPlayAnim(ESX.PlayerData.ped, dict, name, fadeIn, fadeOut,
                    -1, flags, playbackRate, false, false, false)
            end
            Wait(0)
        end

        RemoveAnimDict(dict)
    end)
end

local function onPlayerDeath()
    isDead = true
    ESX.CloseContext()

    ClearTimecycleModifier()
    SetTimecycleModifier("REDMIST_blend")
    SetTimecycleModifierStrength(0.7)
    SetExtraTimecycleModifier("fp_vig_red")
    SetExtraTimecycleModifierStrength(1.0)
    SetPedMotionBlur(ESX.PlayerData.ped, true)

    TriggerServerEvent('esx_ambulancejob:setDeathStatus', true)

    StartDeathCam()
    startDeathTimer()
    startDeathLoop()

    loadDeathAnimation()
end

AddEventHandler('esx:onPlayerDeath', onPlayerDeath)
AddEventHandler('esx:onPlayerSpawn', function()
    if firstSpawn then
        firstSpawn = false
        return
    end

    isDead = false
    ClearTimecycleModifier()
    SetPedMotionBlur(ESX.PlayerData.ped, false)
    ClearExtraTimecycleModifier()
    StopDeathCam()
end)

RegisterNetEvent('esx:onPlayerLogout', function()
    firstSpawn = true
end)

RegisterNetEvent('esx_ambulancejob:revive', function()
    if GetInvokingResource() then return end

    DoScreenFadeOut(800)
    while not IsScreenFadedOut() do Wait(0) end

    local coords = GetEntityCoords(ESX.PlayerData.ped)
    local formattedCoords = { x = ESX.Math.Round(coords.x, 1), y = ESX.Math.Round(coords.y, 1), z = ESX.Math.Round(coords.z, 1) }

    respawnPed({
        coords = formattedCoords,
        heading = 0.0
    })

    DoScreenFadeIn(800)
end)
