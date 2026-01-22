-- Cleaning emotes for house robbery furniture interactions
-- Provides StartCleaningEmote/StopCleaningEmote to play named emotes and manage props

local activeProps = {}

local function loadAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

local function requestModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    return hash
end

local function attachProp(ped, def)
    local hash = requestModel(def.Name)
    local obj = CreateObject(hash, 0.0, 0.0, 0.0, true, true, false)
    local boneIndex = GetPedBoneIndex(ped, def.Bone or 28422)
    local pos = def.Placement and def.Placement[1] or vector3(0.0, 0.0, 0.0)
    local rot = def.Placement and def.Placement[2] or vector3(0.0, 0.0, 0.0)
    AttachEntityToEntity(obj, ped, boneIndex, pos.x, pos.y, pos.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    table.insert(activeProps, obj)
    return obj
end

local Emotes = {
    mop = {
        Animation = 'idle',
        Dictionary = 'missfbi4prepp1',
        Options = {
            Flags = { Loop = true, Move = true },
            Props = {
                { Bone = 28422, Name = 'prop_cs_mop_s', Placement = { vector3(-0.02, -0.06, -0.2), vector3(-13.377, 10.3568, 17.9681) } },
            }
        }
    },
    mop2 = {
        Animation = 'idle_scrub_small_player',
        Dictionary = 'move_mop',
        Options = {
            Flags = { Loop = true, Move = true },
            Props = {
                { Bone = 28422, Name = 'prop_cs_mop_s', Placement = { vector3(0.0, 0.0, 0.12), vector3(0.0, 0.0, 0.0) } },
            }
        }
    },
    broom = {
        Animation = 'base',
        Dictionary = 'anim@amb@drug_field_workers@rake@male_a@base',
        Options = {
            Flags = { Loop = true },
            Props = {
                { Bone = 28422, Name = 'prop_tool_broom', Placement = { vector3(-0.01, 0.04, -0.03), vector3(0.0, 0.0, 0.0) } },
            }
        }
    },
    broom2 = {
        Animation = 'idle_b',
        Dictionary = 'anim@amb@drug_field_workers@rake@male_a@idles',
        Options = {
            Flags = { Loop = true },
            Props = {
                { Bone = 28422, Name = 'prop_tool_broom', Placement = { vector3(-0.01, 0.04, -0.03), vector3(0.0, 0.0, 0.0) } },
            }
        }
    },
    broom3 = {
        Animation = 'base',
        Dictionary = 'anim@amb@drug_field_workers@rake@male_b@base',
        Options = {
            Flags = { Loop = true },
            Props = {
                { Bone = 28422, Name = 'prop_tool_broom', Placement = { vector3(-0.01, 0.04, -0.03), vector3(0.0, 0.0, 0.0) } },
            }
        }
    },
    broom4 = {
        Animation = 'idle_d',
        Dictionary = 'anim@amb@drug_field_workers@rake@male_b@idles',
        Options = {
            Flags = { Loop = true },
            Props = {
                { Bone = 28422, Name = 'prop_tool_broom', Placement = { vector3(-0.01, 0.04, -0.03), vector3(0.0, 0.0, 0.0) } },
            }
        }
    },
    clean = {
        Animation = 'base',
        Dictionary = 'timetable@floyd@clean_kitchen@base',
        Options = {
            Flags = { Loop = true, Move = true },
            Props = {
                { Bone = 28422, Name = 'prop_sponge_01', Placement = { vector3(0.0, 0.0, -0.01), vector3(90.0, 0.0, 0.0) } },
            }
        }
    },
    clean2 = {
        Animation = 'base',
        Dictionary = 'amb@world_human_maid_clean@',
        Options = {
            Flags = { Loop = true, Move = true },
            Props = {
                { Bone = 28422, Name = 'prop_sponge_01', Placement = { vector3(0.0, 0.0, -0.01), vector3(90.0, 0.0, 0.0) } },
            }
        }
    },
}

local function computeAnimFlag(opts)
    -- Default to looping upper-body animation allowing movement where applicable
    local flag = 17
    if opts and opts.Flags and opts.Flags.Move then
        flag = 51
    end
    return flag
end

local function startEmote(ped, name)
    local def = Emotes[name]
    if not def then return false end
    local dict, anim = def.Dictionary, def.Animation
    loadAnimDict(dict)
    local flag = computeAnimFlag(def.Options)
    TaskPlayAnim(ped, dict, anim, 8.0, 8.0, -1, flag, 0.0, false, false, false)
    if def.Options and def.Options.Props then
        for i = 1, #def.Options.Props do
            attachProp(ped, def.Options.Props[i])
        end
    end
    return true
end

local function stopEmote(ped)
    ClearPedTasks(ped)
    for i = 1, #activeProps do
        local obj = activeProps[i]
        if obj and DoesEntityExist(obj) then
            DeleteObject(obj)
        end
    end
    activeProps = {}
end

exports('StartCleaningEmote', function(name)
    local ped = PlayerPedId()
    return startEmote(ped, name)
end)
exports('StopCleaningEmote', function(ped)
    stopEmote(ped or PlayerPedId())
end)
exports('HasCleaningEmote', function(name)
    return Emotes[name] ~= nil
end)

HR_Animations = {
    Start = function(name)
        local ped = PlayerPedId()
        return startEmote(ped, name)
    end,
    Stop = function(ped)
        stopEmote(ped or PlayerPedId())
    end,
    Has = function(name)
        return Emotes[name] ~= nil
    end
}