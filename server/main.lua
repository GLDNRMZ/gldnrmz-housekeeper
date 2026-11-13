-- Server-authoritative housekeeping job. The client only asks; the server
-- tracks each player's route and checks position, order and timing before
-- paying anything.
local RESOURCE = cache.resource
-- Qbox / QBCore / ESX and any inventory through community_bridge
local Framework = exports.community_bridge:Framework()
local Inventory = exports.community_bridge:Inventory()

local TIMING_GRACE = 750 -- ms of network slack allowed when finishing a spot
local SPOT_COUNT = #Config.Furniture
local SHELL_OFFSET = vec3(0.0, 0.0, Config.ShellZOffset)

---@class HousekeeperJob
---@field cid string
---@field route string
---@field house integer index into Config.Routes[route]
---@field inside boolean
---@field cleaned table<integer, true>
---@field count integer
---@field cleaning? { spot: integer, finishAt: integer }

---@type table<integer, HousekeeperJob>
local jobs = {}
---@type table<string, string> citizenid -> last route handed out
local lastRoute = {}

local routeNames = {}
for name, houses in pairs(Config.Routes) do
    if #houses > 0 then routeNames[#routeNames + 1] = name end
end
table.sort(routeNames)

---------------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------------

local function flag(src, reason)
    print(('^1[%s]^7 %s (%d) rejected: %s'):format(RESOURCE, GetPlayerName(src) or '?', src, reason))
    lib.logger(src, 'housekeeper:rejected', reason)
end

local function notify(src, description, notifyType)
    TriggerClientEvent('ox_lib:notify', src, {
        title = locale('notify.title'),
        description = description,
        type = notifyType or 'inform',
    })
end

---@return string?
local function getCitizenId(src)
    local ok, cid = pcall(Framework.GetPlayerIdentifier, src)
    return ok and cid or nil
end

local function isNear(src, coords, range)
    local ped = GetPlayerPed(src)
    return ped ~= 0 and #(GetEntityCoords(ped) - coords) <= range
end

local function nearForeman(src)
    return isNear(src, Config.Foreman.coords.xyz, Config.Foreman.targetDistance + 3.0)
end

local function roll(range)
    return math.random(range.min, range.max)
end

---@param job HousekeeperJob
local function currentHouse(job)
    return Config.Routes[job.route][job.house]
end

-- Wages are banked per character in resource KVP so they survive relogs,
-- crashes and restarts, and can never be collected by someone else.
local function wageKey(cid) return ('wages:%s'):format(cid) end

local function getWages(cid)
    return GetResourceKvpInt(wageKey(cid))
end

local function setWages(cid, amount)
    if amount > 0 then
        SetResourceKvpInt(wageKey(cid), amount)
    else
        DeleteResourceKvp(wageKey(cid))
    end
end

local function addWages(cid, amount)
    if amount > 0 then setWages(cid, getWages(cid) + amount) end
end

local function pickRoute(cid)
    if Config.FixedRoute and Config.Routes[Config.FixedRoute] then
        return Config.FixedRoute
    end

    local count = #routeNames
    if count == 0 then return end
    if count == 1 then return routeNames[1] end

    local route
    repeat
        route = routeNames[math.random(count)]
    until route ~= lastRoute[cid]
    return route
end

---@return string? label
local function giveLoot(src, spotType)
    local entries = Config.Loot[spotType] or Config.Loot.default
    if not entries then return end

    local hits = {}
    for i = 1, #entries do
        if math.random(100) <= (entries[i].chance or 0) then
            hits[#hits + 1] = entries[i]
        end
    end
    if #hits == 0 then return end

    local pick = hits[math.random(#hits)]
    local count = roll(pick.amount or { min = 1, max = 1 })

    if pick.account then
        Framework.AddAccountBalance(src, pick.account, count)
        return ('$%d'):format(count)
    end

    if not Inventory.CanCarryItem(src, pick.item, count) then
        notify(src, locale('error.inventory_full'), 'error')
        return
    end

    if not Inventory.AddItem(src, pick.item, count) then return end
    local data = Inventory.GetItemInfo(pick.item)
    return ('%dx %s'):format(count, data and data.label or pick.item)
end

---------------------------------------------------------------------------
-- Route lifecycle
---------------------------------------------------------------------------

lib.callback.register('gldnrmz-housekeeper:server:status', function(src)
    local cid = getCitizenId(src)
    local job = jobs[src]
    return {
        wages = cid and getWages(cid) or 0,
        route = job and job.route,
        house = job and job.house,
    }
end)

---@return string|false route, string? errorKey
lib.callback.register('gldnrmz-housekeeper:server:startRoute', function(src)
    local cid = getCitizenId(src)
    if not cid then return false end
    if jobs[src] then return false, 'error.already_working' end
    if not nearForeman(src) then
        flag(src, 'start route away from foreman')
        return false
    end

    local route = pickRoute(cid)
    if not route then return false, 'error.no_routes' end

    jobs[src] = { cid = cid, route = route, house = 1, inside = false, cleaned = {}, count = 0 }
    lastRoute[cid] = route
    return route
end)

lib.callback.register('gldnrmz-housekeeper:server:quitRoute', function(src)
    jobs[src] = nil
    return true
end)

---@return table<integer, true>|false cleaned
lib.callback.register('gldnrmz-housekeeper:server:enterHouse', function(src, houseIndex)
    local job = jobs[src]
    if not job or job.house ~= houseIndex then return false end

    if not isNear(src, currentHouse(job).coords, Config.DoorCheckDistance) then
        flag(src, 'enter house away from door')
        return false
    end

    -- Re-entering (after a crash, death or failed shell) keeps progress, so
    -- spots can never be cleaned twice for the same house.
    job.inside = true
    job.cleaning = nil
    return job.cleaned
end)

---@return { complete: boolean, next?: integer, bonus?: integer }|false
lib.callback.register('gldnrmz-housekeeper:server:leaveHouse', function(src)
    local job = jobs[src]
    if not job or not job.inside or job.count < SPOT_COUNT then return false end

    job.inside = false
    job.cleaning = nil
    job.cleaned = {}
    job.count = 0
    job.house += 1

    if job.house <= #Config.Routes[job.route] then
        return { complete = false, next = job.house }
    end

    local bonus = roll(Config.Payout.routeBonus)
    addWages(job.cid, bonus)
    jobs[src] = nil
    return { complete = true, bonus = bonus }
end)

---------------------------------------------------------------------------
-- Cleaning
---------------------------------------------------------------------------

---@return boolean ok, string? errorKey
lib.callback.register('gldnrmz-housekeeper:server:startClean', function(src, spotIndex)
    local job = jobs[src]
    local spot = Config.Furniture[spotIndex]
    if not job or not job.inside or not spot then return false end
    if job.cleaned[spotIndex] then return false, 'error.already_clean' end
    if job.cleaning then return false, 'error.busy' end

    local spotCoords = currentHouse(job).coords - SHELL_OFFSET + spot.coords
    if not isNear(src, spotCoords, Config.SpotCheckDistance) then
        flag(src, ('clean spot %d out of range'):format(spotIndex))
        return false
    end

    job.cleaning = { spot = spotIndex, finishAt = GetGameTimer() + Config.CleanDuration }
    return true
end)

RegisterNetEvent('gldnrmz-housekeeper:server:cancelClean', function()
    local job = jobs[source]
    if job then job.cleaning = nil end
end)

---@return { count: integer, total: integer, pay: integer }|false
lib.callback.register('gldnrmz-housekeeper:server:finishClean', function(src, spotIndex)
    local job = jobs[src]
    local cleaning = job and job.cleaning
    if not cleaning or cleaning.spot ~= spotIndex then return false end

    job.cleaning = nil
    if GetGameTimer() + TIMING_GRACE < cleaning.finishAt then
        flag(src, ('finished spot %d too early'):format(spotIndex))
        return false
    end

    local spot = Config.Furniture[spotIndex]
    job.cleaned[spotIndex] = true
    job.count += 1

    local pay = roll(Config.Payout.perSpot[spot.type] or Config.Payout.default)
    addWages(job.cid, pay)

    local found = giveLoot(src, spot.type)
    if found then notify(src, locale('notify.found', found), 'success') end

    return { count = job.count, total = SPOT_COUNT, pay = pay }
end)

---------------------------------------------------------------------------
-- Pay
---------------------------------------------------------------------------

---@return integer|false amount, string? errorKey
lib.callback.register('gldnrmz-housekeeper:server:collect', function(src)
    local cid = getCitizenId(src)
    if not cid then return false end
    if not nearForeman(src) then
        flag(src, 'collect wages away from foreman')
        return false
    end

    local wages = getWages(cid)
    if wages <= 0 then return false, 'error.no_wages' end

    setWages(cid, 0)
    if not Framework.AddAccountBalance(src, Config.Payout.account, wages) then
        setWages(cid, wages)
        return false
    end
    return wages
end)

---------------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------------

AddEventHandler('playerDropped', function()
    jobs[source] = nil
end)

AddEventHandler('community_bridge:Server:OnPlayerUnload', function(src)
    jobs[src] = nil
end)
