local QBCore = exports['qb-core']:GetCoreObject()

-- Runtime house states built from Config.Routes
local function slugifyLabel(label)
    if not label or type(label) ~= 'string' then return nil end
    return label:lower():gsub('%s+', '_'):gsub('[^%w_]', '')
end

local HouseStates = {}
local PendingPayouts = {}

local function buildHouseStates()
    HouseStates = {}
    local routes = Config.Routes or {}
    local function addPoints(routeName, points)
        for _, item in ipairs(points) do
            local key = slugifyLabel(item.label)
            if key and not HouseStates[key] then
                HouseStates[key] = {
                    label = item.label,
                    coords = item.coords,
                    opened = false,
                    tier = Config.DefaultTier,
                    route = routeName,
                    furniture = (function()
                        local function deepCopy(t)
                            if type(t) ~= 'table' then return t end
                            local c = {}
                            for k, v in pairs(t) do
                                c[k] = deepCopy(v)
                            end
                            return c
                        end
                        return deepCopy(Config.DefaultFurniture)
                    end)(),
                }
            end
        end
    end
    -- Include all routes so any random job selection is valid
    for routeName, points in pairs(routes) do
        addPoints(routeName, points)
    end
end

buildHouseStates()

-- Functions

local function ResetHouseStateTimer(house)
    CreateThread(function()
        local minutes = Config.TimeToCloseDoors or 25
        Wait(minutes * 60000)
        HouseStates[house]['opened'] = false
        for _, v in pairs(HouseStates[house]['furniture']) do
            v['searched'] = false
        end
        TriggerClientEvent('gldnrmz-housekeeper:client:ResetHouseState', -1, house)
    end)
end

-- Callbacks

QBCore.Functions.CreateCallback('gldnrmz-housekeeper:server:GetHouseStates', function(_, cb)
    cb(HouseStates)
end)

-- Events

RegisterNetEvent('gldnrmz-housekeeper:server:SetBusyState', function(cabin, house, bool)
    HouseStates[house]['furniture'][cabin]['isBusy'] = bool
    TriggerClientEvent('gldnrmz-housekeeper:client:SetBusyState', -1, cabin, house, bool)
end)

RegisterNetEvent('gldnrmz-housekeeper:server:enterHouse', function(house)
    local src = source
    if not HouseStates[house]['opened'] then
        ResetHouseStateTimer(house)
        TriggerClientEvent('gldnrmz-housekeeper:client:setHouseState', -1, house, true)
    end
    TriggerClientEvent('gldnrmz-housekeeper:client:enterHouse', src, house)
    HouseStates[house]['opened'] = true
end)

-- Cleaning payout when a spot is cleaned
RegisterNetEvent('gldnrmz-housekeeper:server:cleanFurniture', function(cabin, house)
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    local spotType = HouseStates[house].furniture[cabin].type
    local payoutCfg = Config.CleaningPayouts[spotType]
    local amount = payoutCfg and math.random(payoutCfg.min, payoutCfg.max) or math.random(8, 15)
    PendingPayouts[src] = (PendingPayouts[src] or 0) + amount
    if Config.CleaningLoot then
        local typeCfg = Config.CleaningLoot[spotType]
        if typeCfg and type(typeCfg) == 'table' then
            -- Shape 1: explicit loot entries list
            if typeCfg.loot and type(typeCfg.loot) == 'table' and #typeCfg.loot > 0 then
                local candidates = {}
                for _, entry in ipairs(typeCfg.loot) do
                    local entryChance = (entry.chance or 0)
                    if math.random(1, 100) <= entryChance then
                        table.insert(candidates, entry)
                    end
                end
                if #candidates > 0 then
                    local chosen = candidates[math.random(1, #candidates)]
                    local amountRange = chosen.amount or { min = 1, max = 1 }
                    local qty = math.random(amountRange.min, amountRange.max)
                    player.Functions.AddItem(chosen.item, qty)
                    TriggerClientEvent('QBCore:Notify', src, ('You found %dx %s while cleaning'):format(qty, chosen.item), 'success')
                end
            else
                -- Shape 2: pooled items with a single chance
                local chance = typeCfg.chance or 0
                if math.random(1, 100) <= chance then
                    local pool = typeCfg.items or {}
                    if #pool > 0 then
                        local amountRange = typeCfg.amount or { min = 1, max = 1 }
                        local item = pool[math.random(1, #pool)]
                        local qty = math.random(amountRange.min, amountRange.max)
                        player.Functions.AddItem(item, qty)
                        TriggerClientEvent('QBCore:Notify', src, ('You found %dx %s while cleaning'):format(qty, item), 'success')
                    end
                end
            end
        elseif Config.CleaningLoot.default then
            local lootCfg = Config.CleaningLoot.default
            local routeName = HouseStates[house] and HouseStates[house].route
            if routeName and Config.CleaningLoot.routes and Config.CleaningLoot.routes[routeName] then
                local override = Config.CleaningLoot.routes[routeName]
                lootCfg = setmetatable(override, { __index = Config.CleaningLoot.default })
            end
            local chance = lootCfg.chance or 0
            if math.random(1, 100) <= chance then
                local itemsByType = lootCfg.items_by_type or {}
                local pool = itemsByType[spotType] or {}
                if #pool > 0 then
                    local amountRange = lootCfg.amount or { min = 1, max = 1 }
                    local item = pool[math.random(1, #pool)]
                    local qty = math.random(amountRange.min, amountRange.max)
                    player.Functions.AddItem(item, qty)
                    TriggerClientEvent('QBCore:Notify', src, ('You found %dx %s while cleaning'):format(qty, item), 'success')
                end
            end
        end
    end
    HouseStates[house]['furniture'][cabin]['searched'] = true
    TriggerClientEvent('gldnrmz-housekeeper:client:setCabinState', -1, house, cabin, true)
end)

-- Collect pending payment at mission ped
RegisterNetEvent('gldnrmz-housekeeper:server:CollectPayment', function()
    local src = source
    local player = QBCore.Functions.GetPlayer(src)
    if not player then return end
    local pending = PendingPayouts[src] or 0
    if pending <= 0 then
        TriggerClientEvent('QBCore:Notify', src, 'No pending payment to collect', 'error')
        return
    end
    -- Optional safety: ensure player is near the mission ped
    local pedPos = Config.StartPed or vector4(451.43, -1862.87, 27.79, 43.0)
    local pedVec = vector3(pedPos.x, pedPos.y, pedPos.z)
    local playerPed = GetPlayerPed(src)
    if playerPed and playerPed ~= 0 then
        local px, py, pz = table.unpack(GetEntityCoords(playerPed))
        local dist = #(vector3(px, py, pz) - pedVec)
        if dist > (Config.PaymentCollectDistance or 3.0) then
            TriggerClientEvent('QBCore:Notify', src, 'Return to the foreman to collect your payment', 'error')
            return
        end
    end
    player.Functions.AddMoney('cash', pending, 'house-cleaning')
    PendingPayouts[src] = 0
    TriggerClientEvent('QBCore:Notify', src, ('Collected $%d in cleaning payments'):format(pending), 'success')
end)

RegisterNetEvent('gldnrmz-housekeeper:server:removeAdvancedLockpick', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports['qb-inventory']:RemoveItem(source, 'advancedlockpick', 1, false, 'gldnrmz-housekeeper:server:removeAdvancedLockpick')
end)

RegisterNetEvent('gldnrmz-housekeeper:server:removeLockpick', function()
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then return end
    exports['qb-inventory']:RemoveItem(source, 'lockpick', 1, false, 'gldnrmz-housekeeper:server:removeLockpick')
end)

local function CheckVersion()
	PerformHttpRequest('https://raw.githubusercontent.com/GLDNRMZ/'..GetCurrentResourceName()..'/main/version.txt', function(err, text, headers)
		local currentVersion = GetResourceMetadata(GetCurrentResourceName(), 'version')
		if not text then 
			print('^1[GLDNRMZ] Unable to check version for '..GetCurrentResourceName()..'^0')
			return 
		end
		local result = text:gsub("\r", ""):gsub("\n", "")
		if result ~= currentVersion then
			print('^1[GLDNRMZ] '..GetCurrentResourceName()..' is out of date! Latest: '..result..' | Current: '..currentVersion..'^0')
		else
			print('^2[GLDNRMZ] '..GetCurrentResourceName()..' is up to date! ('..currentVersion..')^0')
		end
	end)
end

Citizen.CreateThread(function()
	-- CheckVersion()
end)
