-- Any target system (ox_target, qb-target, ...) through community_bridge
local Target = exports.community_bridge:Target()

-- Foreman NPC and route tracking. House interiors live in client/house.lua.
Housekeeper = {}

local foreman = Config.Foreman
local ped, foremanBlip

---@type { route: string, houses: { label: string, coords: vector3 }[], index: integer }?
local job
local houseBlip, doorZone

function Housekeeper.notify(description, notifyType)
    lib.notify({ title = locale('notify.title'), description = description, type = notifyType or 'inform' })
end

function Housekeeper.getJob()
    return job
end

---------------------------------------------------------------------------
-- Current house marker
---------------------------------------------------------------------------

local function clearMarker()
    if houseBlip and DoesBlipExist(houseBlip) then RemoveBlip(houseBlip) end
    if doorZone then pcall(Target.RemoveZone, doorZone) end
    houseBlip, doorZone = nil, nil
end

---@param index integer
function Housekeeper.setHouse(index)
    clearMarker()
    if not job then return end
    job.index = index

    local house = job.houses[index]
    local c = house.coords

    houseBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(houseBlip, 40)
    SetBlipColour(houseBlip, 2)
    SetBlipScale(houseBlip, 0.9)
    SetBlipRoute(houseBlip, true)
    SetBlipRouteColour(houseBlip, 2)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('blip.house'))
    EndTextCommandSetBlipName(houseBlip)

    doorZone = 'housekeeper_door'
    Target.AddSphereZone(doorZone, c, 1.0, {
        {
            name = 'housekeeper_enter',
            icon = 'fa-solid fa-broom',
            label = locale('target.enter'),
            distance = Config.InteractDistance,
            canInteract = function() return not Housekeeper.isInside() end,
            onSelect = function() Housekeeper.enter(index, house) end,
        },
    }, Config.Debug)

    Housekeeper.notify(locale('notify.next_house', house.label, index, #job.houses))
end

function Housekeeper.endJob()
    clearMarker()
    job = nil
end

---------------------------------------------------------------------------
-- Foreman menu
---------------------------------------------------------------------------

local function startRoute()
    local route, err = lib.callback.await('gldnrmz-housekeeper:server:startRoute', false)
    if not route then
        return Housekeeper.notify(locale(err or 'error.failed'), 'error')
    end

    job = { route = route, houses = Config.Routes[route], index = 1 }
    Housekeeper.notify(locale('notify.route_started', #job.houses), 'success')
    Housekeeper.setHouse(1)
end

function Housekeeper.quitRoute()
    local confirm = lib.alertDialog({
        header = locale('dialog.quit_title'),
        content = locale('dialog.quit_body'),
        centered = true,
        cancel = true,
    })
    if confirm ~= 'confirm' then return end

    lib.callback.await('gldnrmz-housekeeper:server:quitRoute', false)
    if Housekeeper.isInside() then Housekeeper.exitShell() end
    Housekeeper.endJob()
    Housekeeper.notify(locale('notify.route_quit'))
end

local function collect()
    local amount, err = lib.callback.await('gldnrmz-housekeeper:server:collect', false)
    if not amount then
        return Housekeeper.notify(locale(err or 'error.failed'), 'error')
    end
    Housekeeper.notify(locale('notify.collected', amount), 'success')
end

local function openMenu()
    local status = lib.callback.await('gldnrmz-housekeeper:server:status', false)

    -- Server is the source of truth; drop a stale local route if it ended there.
    if job and not status.route then Housekeeper.endJob() end

    local jobOption = job and {
        title = locale('menu.quit'),
        description = locale('menu.quit_desc', job.index - 1, #job.houses),
        icon = 'fa-solid fa-xmark',
        onSelect = Housekeeper.quitRoute,
    } or {
        title = locale('menu.start'),
        description = locale('menu.start_desc'),
        icon = 'fa-solid fa-broom',
        onSelect = startRoute,
    }

    lib.registerContext({
        id = 'housekeeper_foreman',
        title = locale('menu.title'),
        options = {
            jobOption,
            {
                title = locale('menu.collect'),
                description = locale('menu.collect_desc', status.wages),
                icon = 'fa-solid fa-hand-holding-dollar',
                disabled = status.wages <= 0,
                onSelect = collect,
            },
        },
    })
    lib.showContext('housekeeper_foreman')
end

---------------------------------------------------------------------------
-- Foreman ped (spawned only while nearby)
---------------------------------------------------------------------------

local function despawn()
    if ped and DoesEntityExist(ped) then
        pcall(Target.RemoveLocalEntity, ped)
        DeleteEntity(ped)
    end
    ped = nil
end

local function spawn()
    if ped then return end

    local model = joaat(foreman.model)
    if not pcall(lib.requestModel, model, 10000) then
        return print(('^1[%s] foreman model %s failed to load^7'):format(cache.resource, foreman.model))
    end

    local c = foreman.coords
    ped = CreatePed(4, model, c.x, c.y, c.z, c.w, false, true)
    SetModelAsNoLongerNeeded(model)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanBeTargetted(ped, false)
    if foreman.scenario then TaskStartScenarioInPlace(ped, foreman.scenario, 0, true) end

    Target.AddLocalEntity(ped, {
        {
            name = 'housekeeper_foreman',
            icon = 'fa-solid fa-comments',
            label = locale('target.foreman'),
            distance = foreman.targetDistance,
            onSelect = openMenu,
        },
    })
end

lib.points.new({
    coords = foreman.coords.xyz,
    distance = foreman.spawnDistance,
    onEnter = spawn,
    onExit = despawn,
})

if foreman.blip.enabled then
    local c = foreman.coords
    foremanBlip = AddBlipForCoord(c.x, c.y, c.z)
    SetBlipSprite(foremanBlip, foreman.blip.sprite)
    SetBlipColour(foremanBlip, foreman.blip.color)
    SetBlipScale(foremanBlip, foreman.blip.scale)
    SetBlipAsShortRange(foremanBlip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(locale('blip.foreman'))
    EndTextCommandSetBlipName(foremanBlip)
end

---------------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------------

AddEventHandler('community_bridge:Client:OnPlayerUnload', function()
    if Housekeeper.isInside() then Housekeeper.exitShell(true) end
    Housekeeper.endJob()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= cache.resource then return end
    if Housekeeper.isInside() then Housekeeper.exitShell(true) end
    clearMarker()
    despawn()
    if foremanBlip then RemoveBlip(foremanBlip) end
end)
