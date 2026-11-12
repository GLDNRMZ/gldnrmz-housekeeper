-- House interior: shell, clutter props, cleaning spots and the exit door.
local SHELL_OFFSET = vec3(0.0, 0.0, Config.ShellZOffset)
local SPOT_COUNT = #Config.Furniture
local DOOR_DICT = 'anim@heists@keycard@'

---@class HousekeeperInterior
---@field door vector3
---@field origin vector3
---@field objects integer[] shell entities from qb-interior
---@field exitZone? integer
---@field zones table<integer, integer> spot index -> ox_target zone
---@field props table<integer, integer[]> spot index -> clutter entities
---@field cleaned table<integer, true>

---@type HousekeeperInterior?
local inside
local busy = false

function Housekeeper.isInside()
    return inside ~= nil
end

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function deleteAll(entities)
    for i = 1, #entities do
        if DoesEntityExist(entities[i]) then DeleteEntity(entities[i]) end
    end
end

local function allClean()
    if not inside then return false end
    for i = 1, SPOT_COUNT do
        if not inside.cleaned[i] then return false end
    end
    return true
end

local function doorAnim()
    if pcall(lib.requestAnimDict, DOOR_DICT, 2000) then
        TaskPlayAnim(cache.ped, DOOR_DICT, 'exit', 5.0, 1.0, -1, 16, 0, false, false, false)
        RemoveAnimDict(DOOR_DICT)
    end
    TriggerEvent('InteractSound_CL:PlayOnOne', 'houses_door_open', 0.25)
    Wait(400)
    ClearPedTasks(cache.ped)
end

---@return integer[]
local function spawnClutter(spot, pos)
    local entries = spot.props
    if not entries then return {} end
    if type(entries) ~= 'table' or entries.model then entries = { entries } end

    local objects = {}
    for _, entry in ipairs(entries) do
        local model = type(entry) == 'table' and entry.model or entry
        local zOffset = type(entry) == 'table' and entry.zOffset or 0.0
        local hash = joaat(model)

        if pcall(lib.requestModel, hash, 5000) then
            -- Local-only: nobody else needs to see this player's mess.
            local obj = CreateObject(hash, pos.x, pos.y, pos.z + zOffset, false, false, false)
            FreezeEntityPosition(obj, true)
            SetModelAsNoLongerNeeded(hash)
            objects[#objects + 1] = obj
        else
            print(('^3[%s] clutter model %s failed to load^7'):format(cache.resource, model))
        end
    end
    return objects
end

local function clearSpot(i)
    if not inside then return end
    if inside.zones[i] then exports.ox_target:removeZone(inside.zones[i]) end
    if inside.props[i] then deleteAll(inside.props[i]) end
    inside.zones[i], inside.props[i] = nil, nil
end

-- Removes everything this house created. Does not move the player.
local function teardown()
    local state = inside
    if not state then return end
    inside = nil

    if state.exitZone then exports.ox_target:removeZone(state.exitZone) end
    for _, zone in pairs(state.zones) do exports.ox_target:removeZone(zone) end
    for _, props in pairs(state.props) do deleteAll(props) end
    deleteAll(state.objects)
    TriggerEvent('qb-weathersync:client:EnableSync')
end

---@param instant? boolean skip fades and waits (resource stop / logout)
function Housekeeper.exitShell(instant)
    local state = inside
    if not state then return end

    if not instant then
        DoScreenFadeOut(250)
        while not IsScreenFadedOut() do Wait(0) end
    end

    teardown()

    local door = state.door
    SetEntityCoords(cache.ped, door.x, door.y, door.z, false, false, false, false)

    if instant then
        DoScreenFadeIn(0)
        return
    end

    RequestCollisionAtCoord(door.x, door.y, door.z)
    local timeout = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(cache.ped) and GetGameTimer() < timeout do Wait(0) end
    DoScreenFadeIn(250)
end

---------------------------------------------------------------------------
-- Cleaning
---------------------------------------------------------------------------

---@param i integer
local function clean(i)
    if busy or not inside or inside.cleaned[i] then return end
    busy = true

    local spot = Config.Furniture[i]
    local ok, err = lib.callback.await('gldnrmz-housekeeper:server:startClean', false, i)
    if not ok then
        busy = false
        return Housekeeper.notify(locale(err or 'error.failed'), 'error')
    end

    if not inside then
        TriggerServerEvent('gldnrmz-housekeeper:server:cancelClean')
        busy = false
        return
    end

    local pos = inside.origin + spot.coords
    TaskTurnPedToFaceCoord(cache.ped, pos.x, pos.y, pos.z, 500)
    Wait(500)

    local emote = Config.Emotes[spot.emote] or Config.Emotes.clean
    local done = lib.progressBar({
        duration = Config.CleanDuration,
        label = locale('progress.cleaning', spot.label),
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = emote.dict, clip = emote.clip, flag = emote.flag },
        prop = emote.prop,
    })

    if not done then
        TriggerServerEvent('gldnrmz-housekeeper:server:cancelClean')
        busy = false
        return Housekeeper.notify(locale('error.cancelled'), 'error')
    end

    local result = lib.callback.await('gldnrmz-housekeeper:server:finishClean', false, i)
    busy = false
    if not result then return Housekeeper.notify(locale('error.failed'), 'error') end
    if not inside then return end

    inside.cleaned[i] = true
    clearSpot(i)

    if result.count >= result.total then
        Housekeeper.notify(locale('notify.house_clean'), 'success')
    else
        Housekeeper.notify(locale('notify.spot_clean', result.pay, result.count, result.total))
    end
end

---------------------------------------------------------------------------
-- Enter / leave
---------------------------------------------------------------------------

local function leave()
    if busy or not inside then return end
    busy = true

    local result = lib.callback.await('gldnrmz-housekeeper:server:leaveHouse', false)
    if not result then
        busy = false
        return Housekeeper.notify(locale('error.not_finished'), 'error')
    end

    doorAnim()
    Housekeeper.exitShell()
    busy = false

    if not result.complete then
        return Housekeeper.setHouse(result.next)
    end

    Housekeeper.endJob()
    if result.bonus > 0 then
        Housekeeper.notify(locale('notify.route_done_bonus', result.bonus), 'success')
    else
        Housekeeper.notify(locale('notify.route_done'), 'success')
    end
end

-- If the player ends up outside the shell some other way (death, admin
-- teleport), drop the interior so the door works again. Progress is kept.
local function watchDistance(state)
    CreateThread(function()
        while inside == state do
            Wait(2000)
            if inside == state and #(GetEntityCoords(cache.ped) - state.origin) > 50.0 then
                teardown()
                Housekeeper.notify(locale('notify.left_house'))
            end
        end
    end)
end

---@param index integer
---@param house { label: string, coords: vector3 }
function Housekeeper.enter(index, house)
    if busy or inside then return end
    busy = true

    local cleaned = lib.callback.await('gldnrmz-housekeeper:server:enterHouse', false, index)
    if not cleaned then
        busy = false
        return Housekeeper.notify(locale('error.failed'), 'error')
    end

    doorAnim()

    local origin = house.coords - SHELL_OFFSET
    local shell = exports['qb-interior']:CreateHouseRobbery(origin)
    if not shell or not shell[1] then
        DoScreenFadeIn(250)
        busy = false
        return Housekeeper.notify(locale('error.shell_failed'), 'error')
    end

    TriggerEvent('qb-weathersync:client:DisableSync')

    local exit = shell[2].exit
    ---@type HousekeeperInterior
    local state = {
        door = house.coords,
        origin = origin,
        objects = shell[1],
        zones = {},
        props = {},
        cleaned = cleaned,
    }

    state.exitZone = exports.ox_target:addSphereZone({
        coords = origin + vec3(exit.x, exit.y, exit.z),
        radius = 0.75,
        debug = Config.Debug,
        options = {
            {
                name = 'housekeeper_leave',
                icon = 'fa-solid fa-door-open',
                label = locale('target.leave'),
                distance = Config.InteractDistance,
                canInteract = allClean,
                onSelect = leave,
            },
            {
                name = 'housekeeper_abandon',
                icon = 'fa-solid fa-xmark',
                label = locale('target.abandon'),
                distance = Config.InteractDistance,
                canInteract = function() return not allClean() end,
                onSelect = Housekeeper.quitRoute,
            },
        },
    })

    local remaining = 0
    for i, spot in ipairs(Config.Furniture) do
        if not cleaned[i] then
            remaining += 1
            local pos = origin + spot.coords
            state.props[i] = spawnClutter(spot, pos)
            state.zones[i] = exports.ox_target:addSphereZone({
                coords = pos,
                radius = 0.5,
                debug = Config.Debug,
                options = {
                    {
                        name = ('housekeeper_spot_%d'):format(i),
                        icon = 'fa-solid fa-broom',
                        label = spot.label,
                        distance = Config.InteractDistance,
                        canInteract = function() return not busy end,
                        onSelect = function() clean(i) end,
                    },
                },
            })
        end
    end

    inside = state
    busy = false
    watchDistance(state)
    Housekeeper.notify(locale('notify.entered', remaining, SPOT_COUNT))
end

---------------------------------------------------------------------------
-- Placement helper
---------------------------------------------------------------------------

if Config.Debug then
    RegisterCommand('housekeeper_offset', function()
        if not inside then return Housekeeper.notify('Enter a house first', 'error') end
        local o = GetEntityCoords(cache.ped) - inside.origin
        local line = ('vec3(%.2f, %.2f, %.2f)'):format(o.x, o.y, o.z)
        lib.setClipboard(line)
        print(line)
        Housekeeper.notify(('Copied %s'):format(line))
    end, false)
end
