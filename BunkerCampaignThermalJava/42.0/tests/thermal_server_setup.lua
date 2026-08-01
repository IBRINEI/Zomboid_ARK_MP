BunkerCampaign = {}
BunkerCampaignThermalJava = {}

isClient = function() return false end

local function event()
    local result = { callbacks={} }
    result.Add = function(callback) result.callbacks[#result.callbacks + 1] = callback end
    result.Remove = function(callback)
        for index=#result.callbacks, 1, -1 do
            if result.callbacks[index] == callback then table.remove(result.callbacks, index) end
        end
    end
    return result
end

Events = {
    OnInitGlobalModData=event(),
    OnServerStarted=event(),
    EveryOneMinute=event(),
}

local heating = {
    averageTemperature=-20,
    rooms={
        corridor={
            temperature=-22,
            bounds={ x1=1, y1=2, x2=3, y2=4, z=-4 },
        },
        infirmary={
            temperature=-18,
            regions={
                { x1=10, y1=20, x2=11, y2=21, z=-4 },
                { x1=12, y1=20, x2=13, y2=21, z=-4 },
            },
        },
    },
}

BunkerCampaign.CampaignState = {
    get=function()
        return { bunker={ modules={ heating=heating } } }
    end,
}

committedThermalRegions = nil
local staged = nil
bcThermalBegin = function() staged = {}; return true end
bcThermalAddRegion = function(roomId, x1, y1, x2, y2, z, temperature)
    staged[#staged + 1] = { roomId=roomId, temperature=temperature }
    return true
end
bcThermalCommit = function()
    committedThermalRegions = staged
    return #staged
end
bcThermalClear = function()
    staged = nil
    committedThermalRegions = nil
end
