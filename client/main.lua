local QBCore = exports['qb-core']:GetCoreObject()
local inside = false
local currentHouse = nil
local closestHouse
local inRange
local IsLockpicking = false -- repurposed as cleaning-in-progress
local houseObj = {}
local POIOffsets = nil
local usingAdvanced = false
local CurrentCops = 0
local targetEntryZones = {}
local exitZoneId = nil
local furnitureZoneIds = {}
-- forward declarations to allow references before definitions
local cleanSpot
local leaveRobberyHouse
local assignRandomHouse
local houseCleanComplete = false
local houseRouteQueue = nil
local routeIndex = 0
local HousesState = {}

-- Utilities (define before use)
local function deepCopy(t)
    if type(t) ~= 'table' then return t end
    local c = {}
    for k, v in pairs(t) do
        c[k] = deepCopy(v)
    end
    return c
end

local function slugifyLabel(label)
    if not label or type(label) ~= 'string' then return nil end
    local key = label:lower():gsub('%s+', '_'):gsub('[^%w_]', '')
    return key
end
local function buildClientHouseStates()
    HousesState = {}
    local routes = Config.Routes or {}
    local function addPoints(routeName, points)
        for _, item in ipairs(points) do
            local key = slugifyLabel(item.label)
            if key and not HousesState[key] then
                local furn = deepCopy(Config.DefaultFurniture)
                if type(furn) == 'table' then
                    for i = 1, #furn do
                        local f = furn[i]
                        if f then
                            if f.searched == nil then f.searched = false end
                            if f.isBusy == nil then f.isBusy = false end
                        end
                    end
                end
                HousesState[key] = {
                    label = item.label,
                    coords = item.coords,
                    opened = false,
                    tier = Config.DefaultTier,
                    route = routeName,
                    furniture = furn,
                }
            end
        end
    end
    if Config.RandomizeRouteOnJob then
        -- Include all routes so any random selection is available
        for routeName, points in pairs(routes) do
            addPoints(routeName, points)
        end
    elseif Config.ActiveRoute and routes[Config.ActiveRoute] then
        addPoints(Config.ActiveRoute, routes[Config.ActiveRoute])
    else
        for routeName, points in pairs(routes) do
            addPoints(routeName, points)
        end
    end
end

local function slugifyLabel(label)
    if not label or type(label) ~= 'string' then return nil end
    local key = label:lower():gsub('%s+', '_'):gsub('[^%w_]', '')
    return key
end

local function isHouseFullyCleaned(house)
    local furn = HousesState[house] and HousesState[house].furniture
    if not furn then return false end
    for _, v in pairs(furn) do
        if not v.searched then
            return false
        end
    end
    return true
end
local targetEntryZones = {}
local exitZoneId = nil
local furnitureZoneIds = {}

-- Functions

local function DrawText3Ds(x, y, z, text)
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    BeginTextCommandDisplayText('STRING')
    SetTextCentre(true)
    AddTextComponentSubstringPlayerName(text)
    SetDrawOrigin(x, y, z, 0)
    EndTextCommandDisplayText(0.0, 0.0)
    local factor = (string.len(text)) / 370
    DrawRect(0.0, 0.0 + 0.0125, 0.017 + factor, 0.03, 0, 0, 0, 75)
    ClearDrawOrigin()
end

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while (not HasAnimDictLoaded(dict)) do Wait(5) end
end

local function openHouseAnim()
    loadAnimDict('anim@heists@keycard@')
    TaskPlayAnim(PlayerPedId(), 'anim@heists@keycard@', 'exit', 5.0, 1.0, -1, 16, 0, 0, 0, 0)
    Wait(400)
    ClearPedTasks(PlayerPedId())
end

-- Mess props support: minimal version (place props at spot's vector3)
local messPropsByCabin = {}

local function deleteMessPropsForSpot(cabinKey)
    local list = messPropsByCabin[cabinKey]
    if not list then return end
    for i = 1, #list do
        local obj = list[i]
        if obj and DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
    messPropsByCabin[cabinKey] = nil
end

local function cleanupAllMessProps()
    for key, _ in pairs(messPropsByCabin) do
        deleteMessPropsForSpot(key)
    end
end

local function enterRobberyHouse(house)
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.25)
    openHouseAnim()
    Wait(250)
    local coords = { x = HousesState[house].coords.x, y = HousesState[house].coords.y, z = HousesState[house].coords.z - Config.MinZOffset }
    local data = exports['qb-interior']:CreateHouseRobbery(coords)
    if not data then return end
    houseObj = data[1]
    POIOffsets = data[2]
    inside = true
    currentHouse = house
    Wait(500)
    TriggerEvent('qb-weathersync:client:DisableSync')

    -- Create ox_target zones for exit and cleaning spots
    local hx, hy, hz = HousesState[currentHouse]['coords']['x'], HousesState[currentHouse]['coords']['y'], HousesState[currentHouse]['coords']['z'] - Config.MinZOffset
    local exitCoords = vector3(hx + POIOffsets.exit.x, hy + POIOffsets.exit.y, hz + POIOffsets.exit.z)
    exitZoneId = exports.ox_target:addSphereZone({
        coords = exitCoords,
        radius = 0.5,
        debug = Config.DebugZones,
        options = {
            {
                label = 'Leave house',
                icon = 'fa-solid fa-door-open',
                distance = Config.ZoneInteractionDistance or 2.0,
                canInteract = function()
                    if not isHouseFullyCleaned(currentHouse) then
                        return false
                    end
                    return true
                end,
                onSelect = function()
                    leaveRobberyHouse(currentHouse)
                end
            }
        },
        drawSprite = Config.DebugZones
    })

    furnitureZoneIds = {}
    for k, v in pairs(HousesState[currentHouse]['furniture']) do
        local key = k
        local fcoords = vector3(hx + v.coords.x, hy + v.coords.y, hz + v.coords.z)
        local zid = exports.ox_target:addSphereZone({
            coords = fcoords,
            radius = 0.5,
            debug = Config.DebugZones,
            options = {
                {
                    label = v.text,
                    icon = 'fa-solid fa-broom',
                    distance = Config.ZoneInteractionDistance or 2.0,
                    canInteract = function()
                        return not HousesState[currentHouse]['furniture'][key]['searched']
                            and not HousesState[currentHouse]['furniture'][key]['isBusy']
                            and not IsLockpicking
                    end,
                    onSelect = function()
                        cleanSpot(key)
                    end
                }
            },
            drawSprite = Config.DebugZones
        })
        furnitureZoneIds[#furnitureZoneIds+1] = zid
        -- minimal clutter props: place models at spot coords, supports string or array
        if v.props then
            messPropsByCabin[key] = messPropsByCabin[key] or {}
            local models = v.props
            if type(models) == 'string' then models = { models } end
            if type(models) == 'table' then
                for i = 1, #models do
                    local entry = models[i]
                    local modelName, zOffset = nil, v.messZOffset or 0.0
                    if type(entry) == 'string' then
                        modelName = entry
                    elseif type(entry) == 'table' then
                        modelName = entry.model
                        zOffset = entry.zOffset or zOffset
                    end
                    if modelName then
                        local hash = GetHashKey(modelName)
                        RequestModel(hash)
                        local tries = 0
                        while not HasModelLoaded(hash) and tries < 100 do Wait(10); tries = tries + 1 end
                        if HasModelLoaded(hash) then
                            local obj = CreateObject(hash, fcoords.x, fcoords.y, fcoords.z + zOffset, true, false, false)
                            FreezeEntityPosition(obj, true)
                            table.insert(messPropsByCabin[key], obj)
                            SetModelAsNoLongerNeeded(hash)
                        else
                            print(('[gldnrmz-housekeeper] Failed to load mess model "%s"'):format(modelName))
                        end
                    end
                end
            end
        end
    end
end

leaveRobberyHouse = function(house)
    if not isHouseFullyCleaned(house) then
        QBCore.Functions.Notify('You need to finish cleaning before leaving', 'error', 4500)
        return
    end
    local ped = PlayerPedId()
    TriggerServerEvent('InteractSound_SV:PlayOnSource', 'houses_door_open', 0.25)
    openHouseAnim()
    Wait(250)
    -- Remove ox_target zones for exit and furniture
    if exitZoneId then
        exports.ox_target:removeZone(exitZoneId)
        exitZoneId = nil
    end
    if furnitureZoneIds and #furnitureZoneIds > 0 then
        for i = 1, #furnitureZoneIds do
            exports.ox_target:removeZone(furnitureZoneIds[i])
        end
        furnitureZoneIds = {}
    end
    -- remove any remaining clutter props
    cleanupAllMessProps()
    DoScreenFadeOut(250)
    Wait(500)
    exports['qb-interior']:DespawnInterior(houseObj, function()
        TriggerEvent('qb-weathersync:client:EnableSync')
        Wait(250)
        DoScreenFadeIn(250)
        SetEntityCoords(ped, HousesState[house]['coords']['x'], HousesState[house]['coords']['y'], HousesState[house]['coords']['z'] + 0.5, false, false, false, false)
        SetEntityHeading(ped, HousesState[house]['coords']['w'])
        inside = false
        currentHouse = nil
        if houseCleanComplete then
            HousesState[house]['opened'] = false
            assignRandomHouse(house)
            houseCleanComplete = false
        end
    end)
end

cleanSpot = function(cabin)
    local ped = PlayerPedId()
    -- Select animation from config: first emote name, then per-item/type overrides
    local item = HousesState[currentHouse] and HousesState[currentHouse]['furniture'] and HousesState[currentHouse]['furniture'][cabin] or nil
    local typeAnim = item and Config.FurnitureAnimationsByType and Config.FurnitureAnimationsByType[item.type] or nil
    local scenario = (item and item.scenario) or (typeAnim and typeAnim.scenario) or nil
    local animDict = (item and item.animDict) or (typeAnim and typeAnim.animDict) or 'amb@world_human_maid_clean@'
    local animName = (item and item.animName) or (typeAnim and typeAnim.animName) or 'base'
    local animFlag = (item and item.animFlag) or (typeAnim and typeAnim.animFlag) or 17

    if item and item.emote then
        local okHas, has = pcall(function()
            return exports['gldnrmz-housekeeper']:HasCleaningEmote(item.emote)
        end)
        if okHas and has then
            pcall(function() exports['gldnrmz-housekeeper']:StartCleaningEmote(item.emote) end)
        elseif HR_Animations and HR_Animations.Has and HR_Animations.Has(item.emote) then
            HR_Animations.Start(item.emote)
        end
    elseif scenario then
        TaskStartScenarioInPlace(ped, scenario, 0, true)
    else
        loadAnimDict(animDict)
        TaskPlayAnim(ped, animDict, animName, 8.0, 8.0, -1, animFlag, 0, false, false, false)
    end
    TriggerServerEvent('gldnrmz-housekeeper:server:SetBusyState', cabin, currentHouse, true)
    FreezeEntityPosition(ped, true)
    IsLockpicking = true
    local success = lib.progressBar({
        duration = Config.CleaningDuration or 6000,
        label = 'Cleaning...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            car = true,
            combat = true,
            mouse = false,
        }
    })
    if success then
        -- delete clutter props for this spot after cleaning completes
        deleteMessPropsForSpot(cabin)
        local _ = pcall(function() exports['gldnrmz-housekeeper']:StopCleaningEmote(PlayerPedId()) end)
        if HR_Animations and HR_Animations.Stop then HR_Animations.Stop(PlayerPedId()) end
        TriggerServerEvent('gldnrmz-housekeeper:server:cleanFurniture', cabin, currentHouse)
        HousesState[currentHouse]['furniture'][cabin]['searched'] = true
    TriggerServerEvent('gldnrmz-housekeeper:server:SetBusyState', cabin, currentHouse, false)
    FreezeEntityPosition(ped, false)
    IsLockpicking = false
    if isHouseFullyCleaned(currentHouse) and not houseCleanComplete then
        houseCleanComplete = true
        QBCore.Functions.Notify('House fully cleaned. Use the exit and proceed to the next.', 'success', 4500)
    end
    else
        local _ = pcall(function() exports['gldnrmz-housekeeper']:StopCleaningEmote(PlayerPedId()) end)
        if HR_Animations and HR_Animations.Stop then HR_Animations.Stop(PlayerPedId()) end
        TriggerServerEvent('gldnrmz-housekeeper:server:SetBusyState', cabin, currentHouse, false)
        QBCore.Functions.Notify('Cleaning cancelled', 'error', 3500)
        FreezeEntityPosition(ped, false)
        IsLockpicking = false
    end
end

-- Events

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    QBCore.Functions.TriggerCallback('gldnrmz-housekeeper:server:GetHouseStates', function(serverStates)
        if serverStates and next(serverStates) then
            HousesState = serverStates
        else
            buildClientHouseStates()
        end
        -- Register ox_target zones for house entry at doors
        for k, v in pairs(HousesState) do
            local key = k
            local hx, hy, hz = v.coords.x, v.coords.y, v.coords.z
            if not targetEntryZones[key] then
                targetEntryZones[key] = exports.ox_target:addSphereZone({
                    coords = vector3(hx, hy, hz),
                    radius = 1.5,
                    debug = Config.DebugZones,
                    options = {
                        {
                            label = 'Enter for cleaning',
                            icon = 'fa-solid fa-broom',
                            distance = Config.ZoneInteractionDistance or 2.0,
                            canInteract = function()
                                if Config.LimitTime then
                                    local hour = GetClockHours()
                                    if hour < Config.MinimumTime or hour > Config.MaximumTime then
                                        return false
                                    end
                                end
                                return HousesState[key]['opened']
                            end,
                            onSelect = function()
                                enterRobberyHouse(key)
                            end
                        }
                    },
                    drawSprite = Config.DebugZones
                })
            end
        end
    end)
end)

-- Fallback: register entry zones on resource start in case OnPlayerLoaded didn’t fire
CreateThread(function()
    Wait(1000)
    if not HousesState or next(HousesState) == nil then
        buildClientHouseStates()
    end
    for k, v in pairs(HousesState) do
        local key = k
        if not targetEntryZones[key] then
            local hx, hy, hz = v.coords.x, v.coords.y, v.coords.z
            targetEntryZones[key] = exports.ox_target:addSphereZone({
                coords = vector3(hx, hy, hz),
                radius = 1.0,
                debug = Config.DebugZones,
                options = {
                    {
                        label = 'Enter for cleaning',
                        icon = 'fa-solid fa-broom',
                        distance = Config.ZoneInteractionDistance or 2.0,
                        canInteract = function()
                            if Config.LimitTime then
                                local hour = GetClockHours()
                                if hour < Config.MinimumTime or hour > Config.MaximumTime then
                                    return false
                                end
                            end
                            return HousesState[key]['opened']
                        end,
                        onSelect = function()
                            enterRobberyHouse(key)
                        end
                    }
                },
                drawSprite = Config.DebugZones
            })
        end
    end
end)

RegisterNetEvent('gldnrmz-housekeeper:client:ResetHouseState', function(house)
    HousesState[house]['opened'] = false
    for _, v in pairs(HousesState[house]['furniture']) do
        v['searched'] = false
    end
end)

RegisterNetEvent('police:SetCopCount', function(amount)
    CurrentCops = amount
end)

RegisterNetEvent('gldnrmz-housekeeper:client:enterHouse', function(house)
    enterRobberyHouse(house)
end)

RegisterNetEvent('gldnrmz-housekeeper:client:setHouseState', function(house, state)
    HousesState[house]['opened'] = state
end)

RegisterNetEvent('gldnrmz-housekeeper:client:setCabinState', function(house, cabin, state)
    HousesState[house]['furniture'][cabin]['searched'] = state
end)

RegisterNetEvent('gldnrmz-housekeeper:client:SetBusyState', function(cabin, house, bool)
    HousesState[house]['furniture'][cabin]['isBusy'] = bool
end)

-- Cleaning script: lockpick event no longer used
RegisterNetEvent('lockpicks:UseLockpick', function(_)
    QBCore.Functions.Notify('Lockpick is not used for cleaning jobs.', 'error', 3500)
end)

-- Threads


-- Util Command (can be commented out - used for setting new spots in the config)

RegisterCommand('gethroffset', function()
    local coords = GetEntityCoords(PlayerPedId())
    local houseCoords = vector3(
        HousesState[currentHouse]['coords']['x'],
        HousesState[currentHouse]['coords']['y'],
        HousesState[currentHouse]['coords']['z'] - Config.MinZOffset
    )
    if inside then
        local xdist = coords.x - houseCoords.x
        local ydist = coords.y - houseCoords.y
        local zdist = coords.z - houseCoords.z
        print('X: ' .. xdist)
        print('Y: ' .. ydist)
        print('Z: ' .. zdist)
    end
end, false)

-- Mission Ped: sends player to a random house
local missionPed
local missionPedBlip
local assignedHouse
local MissionPedCoords = Config.StartPed

assignRandomHouse = function(excludeHouse)
    -- If no route is active, build one from configured route or all houses
    if not houseRouteQueue or #houseRouteQueue == 0 then
        houseRouteQueue = {}
        if not HousesState or next(HousesState) == nil then
            buildClientHouseStates()
        end
        local selectedRoute = nil
        if Config.RandomizeRouteOnJob and Config.Routes then
            local routeKeys = {}
            for name, points in pairs(Config.Routes) do
                if type(points) == 'table' and #points > 0 then
                    routeKeys[#routeKeys+1] = name
                end
            end
            if #routeKeys > 0 then
                selectedRoute = routeKeys[math.random(1, #routeKeys)]
                --QBCore.Functions.Notify(('Route selected: %s'):format(selectedRoute), 'success', 2500)
            end
        end
        if selectedRoute and Config.Routes[selectedRoute] then
            for _, item in ipairs(Config.Routes[selectedRoute]) do
                local key = slugifyLabel(item.label)
                if key and key ~= excludeHouse and HousesState[key] and HousesState[key].coords then
                    houseRouteQueue[#houseRouteQueue+1] = key
                end
            end
        elseif Config.ActiveRoute and Config.Routes and Config.Routes[Config.ActiveRoute] then
            for _, item in ipairs(Config.Routes[Config.ActiveRoute]) do
                local key = slugifyLabel(item.label)
                if key and key ~= excludeHouse and HousesState[key] and HousesState[key].coords then
                    houseRouteQueue[#houseRouteQueue+1] = key
                end
            end
        else
            for k, v in pairs(HousesState) do
                if v.coords and k ~= excludeHouse then
                    houseRouteQueue[#houseRouteQueue+1] = k
                end
            end
        end
        routeIndex = 0
    end

    -- Advance to next house in the route
    routeIndex = routeIndex + 1
    if routeIndex > #houseRouteQueue then
        QBCore.Functions.Notify('Cleaning route completed. No more houses in queue.', 'success', 4500)
        houseRouteQueue = nil
        routeIndex = 0
        return
    end

    local houseKey = houseRouteQueue[routeIndex]
    local hx = HousesState[houseKey].coords.x
    local hy = HousesState[houseKey].coords.y
    local hz = HousesState[houseKey].coords.z
    SetNewWaypoint(hx, hy)
    local labelText = HousesState[houseKey] and HousesState[houseKey].label or houseKey
    QBCore.Functions.Notify(('Next house (%s) assigned. GPS set.'):format(labelText), 'success', 3500)
    assignedHouse = houseKey
    HousesState[houseKey]['opened'] = true
    -- Ensure entry target exists for the assigned house
    if not targetEntryZones[houseKey] then
        targetEntryZones[houseKey] = exports.ox_target:addSphereZone({
            coords = vector3(hx, hy, hz),
            radius = 0.5,
            debug = Config.DebugZones,
            options = {
                {
                    label = 'Enter for cleaning',
                    icon = 'fa-solid fa-broom',
                    distance = Config.ZoneInteractionDistance or 2.0,
                    canInteract = function()
                        if Config.LimitTime then
                            local hour = GetClockHours()
                            if hour < Config.MinimumTime or hour > Config.MaximumTime then
                                return false
                            end
                        end
                        return HousesState[houseKey]['opened']
                    end,
                    onSelect = function()
                        enterRobberyHouse(houseKey)
                    end
                }
            },
            drawSprite = Config.DebugZones
        })
    end
    local blip = AddBlipForCoord(hx, hy, hz)
    SetBlipSprite(blip, 40)
    SetBlipColour(blip, 2)
    SetBlipScale(blip, 0.9)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Cleaning House')
    EndTextCommandSetBlipName(blip)
    SetBlipRoute(blip, true)
    SetBlipRouteColour(blip, 2)
    CreateThread(function()
        Wait(60000)
        if DoesBlipExist(blip) then RemoveBlip(blip) end
    end)
end

local function spawnMissionPed()
    if missionPed and DoesEntityExist(missionPed) then return end
    local model = joaat('a_m_m_business_01')
    RequestModel(model)
    while not HasModelLoaded(model) do Wait(10) end
    local pedPos = Config.StartPed or vector4(451.43, -1862.87, 27.79, 43.0)
    missionPed = CreatePed(4, model, pedPos.x, pedPos.y, pedPos.z, pedPos.w, false, true)
    SetEntityInvincible(missionPed, true)
    SetBlockingOfNonTemporaryEvents(missionPed, true)
    FreezeEntityPosition(missionPed, true)
    TaskStartScenarioInPlace(missionPed, 'WORLD_HUMAN_CLIPBOARD', 0, true)
    SetModelAsNoLongerNeeded(model)

    -- Create a map blip for the starting ped
    if not missionPedBlip or not DoesBlipExist(missionPedBlip) then
        missionPedBlip = AddBlipForCoord(pedPos.x, pedPos.y, pedPos.z)
        SetBlipSprite(missionPedBlip, Config.StartPedBlipSprite or 480)
        SetBlipColour(missionPedBlip, Config.StartPedBlipColor or 2)
        SetBlipScale(missionPedBlip, Config.StartPedBlipScale or 0.8)
        SetBlipAsShortRange(missionPedBlip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(Config.StartPedBlipName or 'Cleaning Jobs')
        EndTextCommandSetBlipName(missionPedBlip)
    end

    -- Add ox_target interaction to mission ped
    exports.ox_target:addLocalEntity(missionPed, {
        {
            label = 'Talk to foreman',
            icon = 'fa-solid fa-comments',
            onSelect = function()
                local routeActive = houseRouteQueue and #houseRouteQueue > 0 and routeIndex > 0 and routeIndex <= #houseRouteQueue
                lib.registerContext({
                    id = 'gldnrmz-housekeeper-menu',
                    title = 'Cleaning Foreman',
                    options = {
                        {
                            title = 'Start cleaning route',
                            description = 'Get assigned houses to clean',
                            icon = 'fa-solid fa-broom',
                            disabled = routeActive,
                            onSelect = function()
                                if routeActive then
                                    QBCore.Functions.Notify('Finish your current route before requesting a new one', 'error', 4500)
                                    return
                                end
                                houseRouteQueue = {}
                                if not HousesState or next(HousesState) == nil then
                                    buildClientHouseStates()
                                end
                                local selectedRoute = nil
                                if Config.RandomizeRouteOnJob and Config.Routes then
                                    local routeKeys = {}
                                    for name, points in pairs(Config.Routes) do
                                        if type(points) == 'table' and #points > 0 then
                                            routeKeys[#routeKeys+1] = name
                                        end
                                    end
                                    if #routeKeys > 0 then
                                        selectedRoute = routeKeys[math.random(1, #routeKeys)]
                                    end
                                end
                                if selectedRoute and Config.Routes[selectedRoute] then
                                    for _, item in ipairs(Config.Routes[selectedRoute]) do
                                        local key = slugifyLabel(item.label)
                                        if key and HousesState[key] and HousesState[key].coords then
                                            houseRouteQueue[#houseRouteQueue+1] = key
                                        end
                                    end
                                elseif Config.ActiveRoute and Config.Routes and Config.Routes[Config.ActiveRoute] then
                                    for _, item in ipairs(Config.Routes[Config.ActiveRoute]) do
                                        local key = slugifyLabel(item.label)
                                        if key and HousesState[key] and HousesState[key].coords then
                                            houseRouteQueue[#houseRouteQueue+1] = key
                                        end
                                    end
                                else
                                    for k, v in pairs(HousesState) do
                                        if v.coords then
                                            houseRouteQueue[#houseRouteQueue+1] = k
                                        end
                                    end
                                end
                                routeIndex = 0
                                if #houseRouteQueue == 0 then
                                    QBCore.Functions.Notify('No houses configured', 'error', 3500)
                                    return
                                end
                                assignRandomHouse(nil)
                            end
                        },
                        {
                            title = 'Collect payment',
                            description = 'Get paid for completed cleaning',
                            icon = 'fa-solid fa-hand-holding-dollar',
                            onSelect = function()
                                TriggerServerEvent('gldnrmz-housekeeper:server:CollectPayment')
                            end
                        }
                    }
                })
                lib.showContext('gldnrmz-housekeeper-menu')
            end
        }
    })
end

CreateThread(function()
    spawnMissionPed()
end)
