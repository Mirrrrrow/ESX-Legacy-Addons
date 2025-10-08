local camera, x, y, cameraRadius, zoom = nil, 0, 0, 5, Config.zoom

local function getShapeTestResultSync(shape)
    local handle, hit, coords, normal, entity
    repeat
        handle, hit, coords, normal, entity = GetShapeTestResult(shape)
    until handle ~= 1 or Wait(0)

    return hit, coords, normal, entity
end

local function processNewPosition(playerCoords)
    x -= GetDisabledControlNormal(0, 1)
    y -= GetDisabledControlNormal(0, 2)

    if y < math.rad(15) then
        y = math.rad(15)
    elseif y > math.rad(90) then
        y = math.rad(90)
    end

    local normalVec = vector3(
        math.sin(y) * math.cos(x),
        math.sin(y) * math.sin(x),
        math.cos(y)
    )

    local position = playerCoords + normalVec * cameraRadius
    local hit, coords = getShapeTestResultSync(StartShapeTestLosProbe(playerCoords.x, playerCoords.y, playerCoords.z, position.x, position.y, position.z, -1, ESX.PlayerData.ped, 7))

    return (hit == 1 and playerCoords + normalVec * (#(playerCoords - coords) - 1)) or position
end

function StartDeathCam()
    camera = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', 0, 0, 0, 0, 0, 0, GetGameplayCamFov(), true, 1)
    RenderScriptCams(true, true, 1000, true, false)
end

function StopDeathCam()
    RenderScriptCams(false, false, 0, false, false)
    DestroyCam(camera --[[@as number]], false)

    camera = nil
end

function ProcessCamControls()
    local playerCoords = GetEntityCoords(ESX.PlayerData.ped)

    if cameraRadius < zoom.max and IsDisabledControlJustPressed(0, 14) then
        cameraRadius += zoom.step
    elseif cameraRadius > zoom.min and IsDisabledControlJustPressed(0, 15) then
        cameraRadius -= zoom.step
    end

    local coords = processNewPosition(playerCoords)
    SetCamCoord(camera --[[@as number]], coords.x, coords.y, coords.z)
    PointCamAtCoord(camera --[[@as number]], playerCoords.x, playerCoords.y, playerCoords.z)
end
