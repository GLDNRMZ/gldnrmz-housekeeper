Config = {}

-- Draws target zones and enables /housekeeper_offset for placing new spots.
Config.Debug = false

---------------------------------------------------------------------------
-- Foreman (starts routes, pays out)
---------------------------------------------------------------------------
Config.Foreman = {
    model = 'a_m_m_business_01',
    coords = vec4(451.43, -1862.87, 26.79, 43.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD',
    spawnDistance = 60.0,  -- ped only exists while a player is this close
    targetDistance = 2.0,
    blip = { enabled = true, sprite = 480, color = 2, scale = 0.8 },
}

---------------------------------------------------------------------------
-- Interior
---------------------------------------------------------------------------
-- The shell is spawned this far below the front door. Furniture offsets
-- below are tuned for qb-interior's CreateHouseRobbery shell.
Config.ShellZOffset = 45.0

Config.InteractDistance = 1.5 -- target distance for doors and spots
Config.DoorCheckDistance = 5.0 -- server: max distance from the door to enter
Config.SpotCheckDistance = 4.0 -- server: max distance from a spot to clean it

Config.CleanDuration = 6000 -- ms per spot

---------------------------------------------------------------------------
-- Pay
---------------------------------------------------------------------------
-- Wages are banked per character and collected from the foreman.
-- They survive relogs and server restarts.
Config.Payout = {
    account = 'cash',
    perSpot = {
        cabin      = { min = 10, max = 20 },
        kitchen    = { min = 15, max = 30 },
        chest      = { min = 10, max = 20 },
        livingroom = { min = 12, max = 25 },
    },
    default = { min = 8, max = 15 },    -- spot types not listed above
    routeBonus = { min = 0, max = 0 },  -- paid once when a whole route is finished
}

---------------------------------------------------------------------------
-- Loot found while cleaning
---------------------------------------------------------------------------
-- Each entry rolls its own chance; if several hit, one of them is picked.
-- Use `item` for an inventory item or `account` for money ('cash' / 'bank').
local commonLoot = {
    { item = 'plastic',    amount = { min = 5, max = 10 },    chance = 25 },
    { item = 'rubber',     amount = { min = 5, max = 10 },    chance = 25 },
    { item = 'metalscrap', amount = { min = 5, max = 10 },    chance = 25 },
    { item = 'steel',      amount = { min = 5, max = 10 },    chance = 25 },
    { item = 'copper',     amount = { min = 5, max = 10 },    chance = 25 },
    { item = 'aluminum',   amount = { min = 5, max = 10 },    chance = 25 },
    { item = 'iron',       amount = { min = 5, max = 10 },    chance = 25 },
    { item = 'bank_card',  amount = { min = 1, max = 1 },     chance = 25 },
    { account = 'cash',    amount = { min = 100, max = 300 }, chance = 25 },
}

-- Keyed by spot type; `default` covers any type without its own table.
Config.Loot = {
    default = commonLoot,
}

---------------------------------------------------------------------------
-- Animations (played through lib.progressBar, props are synced by ox_lib)
---------------------------------------------------------------------------
local sponge = { model = `prop_sponge_01`, bone = 28422, pos = vec3(0.0, 0.0, -0.01), rot = vec3(90.0, 0.0, 0.0) }
local mop = { model = `prop_cs_mop_s`, bone = 28422, pos = vec3(0.0, 0.0, 0.12), rot = vec3(0.0, 0.0, 0.0) }
local broom = { model = `prop_tool_broom`, bone = 28422, pos = vec3(-0.01, 0.04, -0.03), rot = vec3(0.0, 0.0, 0.0) }

Config.Emotes = {
    clean  = { dict = 'timetable@floyd@clean_kitchen@base', clip = 'base', flag = 51, prop = sponge },
    clean2 = { dict = 'amb@world_human_maid_clean@', clip = 'base', flag = 51, prop = sponge },
    broom  = { dict = 'anim@amb@drug_field_workers@rake@male_a@base', clip = 'base', flag = 17, prop = broom },
    mop    = { dict = 'move_mop', clip = 'idle_scrub_small_player', flag = 51, prop = mop },
}

---------------------------------------------------------------------------
-- Spots to clean in every house (offsets from the shell origin)
---------------------------------------------------------------------------
-- `props` spawns local clutter on the spot until it's cleaned. It can be a
-- model name, a list of names, or { model = 'name', zOffset = 0.1 } entries.
Config.Furniture = {
    { type = 'cabin',      coords = vec3(4.15, 7.82, 1.0),    label = 'Clean cabinet', emote = 'clean' },
    { type = 'cabin',      coords = vec3(5.95, 9.34, 1.0),    label = 'Dust closet',   emote = 'clean' },
    { type = 'kitchen',    coords = vec3(-1.03, 0.78, 1.0),   label = 'Wipe counter',  emote = 'clean' },
    { type = 'chest',      coords = vec3(7.41, 4.00, 0.63),   label = 'Polish chest',  emote = 'clean' },
    { type = 'cabin',      coords = vec3(0.58, 1.48, 0.99),   label = 'Clean counter', emote = 'clean',  props = 'p_car_keys_01' },
    { type = 'cabin',      coords = vec3(5.94, 3.00, 0.86),   label = 'Clean cabinet', emote = 'clean',  props = 'prop_fib_ashtray_01' },
    { type = 'kitchen',    coords = vec3(-1.64, -1.06, 0.98), label = 'Scrub sink',    emote = 'clean',  props = 'v_ret_fh_plate2' },
    { type = 'kitchen',    coords = vec3(-4.35, -0.64, 1.0),  label = 'Clean shelves', emote = 'clean' },
    { type = 'kitchen',    coords = vec3(-5.69, 1.56, 0.83),  label = 'Clean table',   emote = 'clean',  props = 'prop_rub_litter_8' },
    { type = 'livingroom', coords = vec3(-6.90, 4.42, 1.0),   label = 'Dust shelves',  emote = 'clean2' },
    { type = 'livingroom', coords = vec3(-6.98, 7.91, 1.0),   label = 'Dust shelves',  emote = 'clean2' },
    { type = 'livingroom', coords = vec3(-4.92, 3.84, 0.06),  label = 'Sweep floor',   emote = 'broom',  props = 'prop_rub_litter_01' },
    { type = 'cabin',      coords = vec3(5.25, 6.40, 0.78),   label = 'Make bed',      emote = 'clean',  props = 'prop_ld_shirt_01' },
    { type = 'livingroom', coords = vec3(-3.71, 6.94, 0.60),  label = 'Wipe table',    emote = 'clean',  props = 'prop_cs_beer_box' },
    { type = 'cabin',      coords = vec3(1.66, 9.76, 0.5),    label = 'Clean toilet',  emote = 'clean' },
    { type = 'livingroom', coords = vec3(-6.98, 6.14, 1.06),  label = 'Wipe TV',       emote = 'clean2' },
    { type = 'cabin',      coords = vec3(2.31, 7.64, 1.15),   label = 'Clean shower',  emote = 'clean2' },
    { type = 'cabin',      coords = vec3(2.83, 0.51, 0.04),   label = 'Take out trash', emote = 'clean2', props = 'prop_rub_binbag_03b' },
    { type = 'kitchen',    coords = vec3(-1.93, 1.44, 0.06),  label = 'Mop floor',     emote = 'mop',    props = 'prop_rub_litter_01' },
}

---------------------------------------------------------------------------
-- Routes
---------------------------------------------------------------------------
-- Set to a route name to always hand out that route; nil picks a random one
-- (never the same route twice in a row for a character).
Config.FixedRoute = nil

Config.Routes = {
    route1 = {
        { label = 'Mirror Park Blvd 1', coords = vec3(1228.86, -725.41, 60.80) },
        { label = 'Mirror Park Blvd 2', coords = vec3(1222.79, -697.04, 60.80) },
        { label = 'Mirror Park Blvd 3', coords = vec3(1221.39, -668.83, 63.49) },
        { label = 'Mirror Park Blvd 4', coords = vec3(1206.88, -620.22, 66.44) },
        { label = 'Mirror Park Blvd 5', coords = vec3(1203.69, -598.96, 68.06) },
        { label = 'Mirror Park Blvd 6', coords = vec3(1200.84, -575.72, 69.14) },
        { label = 'Mirror Park Blvd 7', coords = vec3(1204.48, -557.80, 69.62) },
    },
    route2 = {
        { label = 'East Mirror Dr 1', coords = vec3(1241.33, -566.36, 69.66) },
        { label = 'East Mirror Dr 2', coords = vec3(1240.51, -601.72, 69.78) },
        { label = 'East Mirror Dr 3', coords = vec3(1250.73, -620.92, 69.57) },
        { label = 'East Mirror Dr 4', coords = vec3(1265.68, -648.63, 68.12) },
        { label = 'East Mirror Dr 5', coords = vec3(1270.92, -683.63, 66.03) },
        { label = 'East Mirror Dr 6', coords = vec3(1264.67, -702.75, 64.91) },
        { label = 'East Mirror Dr 7', coords = vec3(1250.78, -515.57, 69.35) },
        { label = 'East Mirror Dr 8', coords = vec3(1251.46, -494.1, 69.91) },
        { label = 'East Mirror Dr 9', coords = vec3(1259.6, -480.21, 70.19) },
        { label = 'East Mirror Dr 10', coords = vec3(1265.67, -458.11, 70.52) },
        { label = 'East Mirror Dr 11', coords = vec3(1262.35, -429.87, 70.01) },
    },
    route3 = {
        { label = 'Nikola Pl 1', coords = vec3(1303.16, -527.42, 71.46) },
        { label = 'Nikola Pl 2', coords = vec3(1328.56, -536.0, 72.44) },
        { label = 'Nikola Pl 3', coords = vec3(1348.43, -546.73, 73.89) },
        { label = 'Nikola Pl 4', coords = vec3(1373.27, -555.63, 74.69) },
        { label = 'Nikola Pl 5', coords = vec3(1389.02, -569.54, 74.5) },
        { label = 'Nikola Pl 6', coords = vec3(1386.32, -593.52, 74.49) },
        { label = 'Nikola Pl 7', coords = vec3(1367.23, -606.59, 74.71) },
        { label = 'Nikola Pl 8', coords = vec3(1341.35, -597.35, 74.7) },
        { label = 'Nikola Pl 9', coords = vec3(1323.33, -583.22, 73.25) },
        { label = 'Nikola Pl 10', coords = vec3(1301.04, -574.23, 71.73) },
    },
    route4 = {
        { label = 'West Mirror Drive 1', coords = vec3(1114.05, -391.22, 68.95) },
        { label = 'West Mirror Drive 2', coords = vec3(1014.60, -469.24, 64.51) },
        { label = 'West Mirror Drive 3', coords = vec3(970.12, -502.26, 62.14) },
        { label = 'West Mirror Drive 4', coords = vec3(946.01, -518.88, 60.63) },
        { label = 'West Mirror Drive 5', coords = vec3(924.35, -526.06, 59.79) },
        { label = 'West Mirror Drive 6', coords = vec3(893.17, -540.66, 58.51) },
        { label = 'West Mirror Drive 7', coords = vec3(1029.21, -408.61, 66.14) },
        { label = 'West Mirror Drive 8', coords = vec3(1010.47, -423.40, 65.35) },
        { label = 'West Mirror Drive 9', coords = vec3(988.01, -433.55, 63.89) },
        { label = 'West Mirror Drive 10', coords = vec3(967.38, -451.86, 62.79) },
    },
    route5 = {
        { label = 'West Mirror Drive 11', coords = vec3(944.21, -463.37, 61.40) },
        { label = 'West Mirror Drive 12', coords = vec3(922.03, -477.96, 61.08) },
        { label = 'West Mirror Drive 13', coords = vec3(906.37, -489.69, 59.44) },
        { label = 'West Mirror Drive 14', coords = vec3(878.67, -498.27, 58.10) },
        { label = 'West Mirror Drive 15', coords = vec3(861.86, -509.14, 57.52) },
        { label = 'West Mirror Drive 16', coords = vec3(850.31, -532.71, 57.92) },
        { label = 'West Mirror Drive 17', coords = vec3(844.30, -563.34, 57.83) },
        { label = 'West Mirror Drive 18', coords = vec3(861.66, -583.55, 58.16) },
        { label = 'West Mirror Drive 19', coords = vec3(886.77, -608.21, 58.45) },
    },
    route6 = {
        { label = 'West Mirror Drive 20', coords = vec3(902.97, -615.59, 58.45) },
        { label = 'West Mirror Drive 21', coords = vec3(928.89, -639.78, 58.24) },
        { label = 'West Mirror Drive 22', coords = vec3(943.65, -653.62, 58.43) },
        { label = 'West Mirror Drive 23', coords = vec3(960.43, -669.66, 58.45) },
        { label = 'West Mirror Drive 24', coords = vec3(970.92, -700.51, 58.48) },
        { label = 'West Mirror Drive 25', coords = vec3(979.34, -716.14, 58.22) },
        { label = 'West Mirror Drive 26', coords = vec3(997.10, -729.37, 57.82) },
    },
    route7 = {
        { label = 'Bridge St 1', coords = vec3(1100.71, -411.34, 67.56) },
        { label = 'Bridge St 2', coords = vec3(1099.57, -438.43, 67.79) },
        { label = 'Bridge St 3', coords = vec3(1098.68, -464.57, 67.32) },
        { label = 'Bridge St 4', coords = vec3(1090.41, -484.43, 65.66) },
        { label = 'Bridge St 5', coords = vec3(1046.37, -498.00, 64.08) },
        { label = 'Bridge St 6', coords = vec3(1051.57, -470.53, 63.90) },
        { label = 'Bridge St 7', coords = vec3(1056.18, -448.91, 66.26) },
        { label = 'Bridge St 8', coords = vec3(1061.02, -378.75, 68.23) },
    },
    route8 = {
        { label = 'Wild Oats Dr 1', coords = vec3(223.48, 514.19, 140.77) },
        { label = 'Wild Oats Dr 2', coords = vec3(149.16, 474.69, 142.51) },
        { label = 'Wild Oats Dr 3', coords = vec3(107.17, 467.23, 147.37) },
        { label = 'Wild Oats Dr 4', coords = vec3(57.98, 450.17, 147.03) },
        { label = 'Wild Oats Dr 5', coords = vec3(-7.57, 468.17, 145.87) },
        { label = 'Wild Oats Dr 6', coords = vec3(-66.52, 490.63, 144.69) },
        { label = 'Wild Oats Dr 7', coords = vec3(-109.90, 502.31, 143.48) },
        { label = 'Wild Oats Dr 8', coords = vec3(-175.49, 502.46, 137.42) },
        { label = 'Wild Oats Dr 9', coords = vec3(-230.23, 487.93, 128.77) },
        { label = 'Wild Oats Dr 10', coords = vec3(-284.97, 474.67, 120.82) },
    },
    route9 = {
        { label = 'Didion Dr 1', coords = vec3(-312.14, 474.67, 111.82) },
        { label = 'Whispymound Dr 1', coords = vec3(8.63, 540.41, 176.03) },
        { label = 'Whispymound Dr 2', coords = vec3(45.97, 555.89, 180.08) },
        { label = 'Whispymound Dr 3', coords = vec3(84.99, 561.71, 182.77) },
        { label = 'Whispymound Dr 4', coords = vec3(119.37, 564.46, 183.96) },
        { label = 'Whispymound Dr 5', coords = vec3(150.84, 555.85, 183.74) },
        { label = 'Whispymound Dr 6', coords = vec3(216.34, 620.42, 187.76) },
        { label = 'Whispymound Dr 7', coords = vec3(232.14, 672.09, 189.98) },
        { label = 'Lake Vinewood Dr 1', coords = vec3(228.73, 765.82, 204.98) },
    },
    route10 = {
        { label = 'Great Ocean Hwy 1', coords = vec3(-1058.82, 4915.37, 211.82) },
        { label = 'Great Ocean Hwy 2', coords = vec3(-1075.74, 4897.41, 214.27) },
        { label = 'Great Ocean Hwy 3', coords = vec3(-1098.53, 4893.42, 216.07) },
        { label = 'Great Ocean Hwy 4', coords = vec3(-1113.49, 4903.58, 218.60) },
        { label = 'Great Ocean Hwy 5', coords = vec3(-1144.14, 4908.46, 220.97) },
        { label = 'Great Ocean Hwy 6', coords = vec3(-1146.44, 4940.85, 222.27) },
    },
    route11 = {
        { label = 'Procopio Promenade 1', coords = vec3(-681.93, 5770.75, 17.51) },
        { label = 'Procopio Promenade 2', coords = vec3(-683.91, 5766.50, 17.51) },
        { label = 'Procopio Promenade 3', coords = vec3(-685.93, 5763.11, 17.51) },
        { label = 'Procopio Promenade 4', coords = vec3(-687.39, 5759.04, 17.51) },
        { label = 'Procopio Promenade 5', coords = vec3(-690.18, 5759.49, 17.51) },
        { label = 'Procopio Promenade 6', coords = vec3(-694.07, 5761.30, 17.51) },
        { label = 'Procopio Promenade 7', coords = vec3(-698.20, 5763.21, 17.51) },
        { label = 'Procopio Promenade 8', coords = vec3(-701.78, 5764.89, 17.51) },
        { label = 'Procopio Promenade 9', coords = vec3(-706.02, 5766.78, 17.51) },
        { label = 'Procopio Promenade 10', coords = vec3(-709.87, 5768.67, 17.51) },
    },
    route12 = {
        { label = 'Paleto Blvd 1', coords = vec3(-374.56, 6190.98, 31.73) },
        { label = 'Paleto Blvd 2', coords = vec3(-356.99, 6207.47, 31.85) },
        { label = 'Paleto Blvd 3', coords = vec3(-347.29, 6225.23, 31.88) },
        { label = 'Paleto Blvd 4', coords = vec3(-15.18, 6557.69, 33.24) },
        { label = 'Paleto Blvd 5', coords = vec3(11.60, 6578.39, 33.07) },
        { label = 'Paleto Blvd 6', coords = vec3(31.61, 6596.41, 32.82) },
        { label = 'Paleto Blvd 7', coords = vec3(-280.75, 6351.04, 32.60) },
        { label = 'Paleto Blvd 8', coords = vec3(-302.08, 6326.99, 32.89) },
    },
    route13 = {
        { label = 'Procopio Dr 1', coords = vec3(56.47, 6646.05, 32.28) },
        { label = 'Procopio Dr 2', coords = vec3(35.63, 6663.06, 32.19) },
        { label = 'Procopio Dr 3', coords = vec3(-9.57, 6654.11, 31.69) },
        { label = 'Procopio Dr 4', coords = vec3(1.40, 6612.76, 32.08) },
        { label = 'Procopio Dr 5', coords = vec3(-41.42, 6637.02, 31.09) },
        { label = 'Procopio Dr 6', coords = vec3(-26.83, 6597.55, 31.86) },
        { label = 'Procopio Dr 7', coords = vec3(-44.70, 6582.37, 32.18) },
        { label = 'Procopio Dr 8', coords = vec3(-130.58, 6551.60, 29.52) },
        { label = 'Procopio Dr 9', coords = vec3(-105.61, 6528.55, 30.17) },
        { label = 'Procopio Dr 10', coords = vec3(-214.89, 6444.24, 31.31) },
    },
    route14 = {
        { label = 'Niland Ave 1', coords = vec3(1932.35, 3804.73, 32.91) },
        { label = 'Algonquin Blvd 1', coords = vec3(1925.10, 3824.74, 32.44) },
        { label = 'Niland Ave 2', coords = vec3(1899.00, 3781.69, 32.88) },
        { label = 'Algonquin Blvd 2', coords = vec3(1880.65, 3810.55, 32.78) },
        { label = 'Zancudo Ave 1', coords = vec3(1827.13, 3729.30, 33.96) },
        { label = 'Zancudo Ave 2', coords = vec3(1779.36, 3640.83, 34.50) },
        { label = 'Armadillo Ave 1', coords = vec3(1843.67, 3777.73, 33.59) },
        { label = 'Mountain View Dr 1', coords = vec3(1748.93, 3783.25, 34.83) },
        { label = 'Cholla Springs Ave 1', coords = vec3(1763.70, 3823.57, 34.77) },
        { label = 'Marina Dr 1', coords = vec3(1915.98, 3909.50, 33.44) },
        { label = 'Panorama Dr 1', coords = vec3(1540.78, 3721.10, 34.88) },
        { label = 'Calafia Rd 1', coords = vec3(98.02, 3682.01, 39.74) },
        { label = 'Lesbos Ln 1', coords = vec3(1430.70, 3671.38, 34.83) },
    },
    route15 = {
        { label = 'Grove St 1', coords = vec3(76.20, -1948.22, 21.17) },
        { label = 'Grove St 2', coords = vec3(85.96, -1959.71, 21.12) },
        { label = 'Grove St 3', coords = vec3(114.31, -1961.08, 21.33) },
        { label = 'Grove St 4', coords = vec3(126.88, -1929.94, 21.38) },
        { label = 'Grove St 5', coords = vec3(118.42, -1920.99, 21.32) },
        { label = 'Grove St 6', coords = vec3(100.99, -1912.16, 21.41) },
        { label = 'Grove St 7', coords = vec3(72.24, -1939.14, 21.37) },
        { label = 'Grove St 8', coords = vec3(56.66, -1922.79, 21.91) },
        { label = 'Grove St 9', coords = vec3(38.96, -1911.64, 21.95) },
        { label = 'Grove St 10', coords = vec3(23.56, -1896.17, 22.96) },
    },
    route16 = {
        -- Covenant, Brouge, Roy Lowenstein, Jamestown, Carson, Forum, Strawberry
        { label = 'Covenant Ave 1', coords = vec3(104.17, -1885.29, 24.32) },
        { label = 'Brouge Ave 1', coords = vec3(152.21, -1823.37, 27.86) },
        { label = 'Roy Lowenstein Blvd 1', coords = vec3(208.63, -1895.23, 24.81) },
        { label = 'Jamestown St 1', coords = vec3(291.40, -1980.02, 21.60) },
        { label = 'Carson Ave 1', coords = vec3(282.80, -1899.10, 27.27) },
        { label = 'Forum Dr 1', coords = vec3(-158.09, -1680.06, 33.83) },
        { label = 'Strawberry Ave 1', coords = vec3(-83.64, -1622.97, 31.48) },
    },
}
