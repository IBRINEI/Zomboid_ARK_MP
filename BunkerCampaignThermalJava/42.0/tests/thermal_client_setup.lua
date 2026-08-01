BunkerCampaign = {}
BunkerCampaignThermalJava = {}

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
    OnServerCommand=event(),
    OnCreatePlayer=event(),
    OnDisconnect=event(),
    OnMainMenuEnter=event(),
}

local staged = nil
bcThermalBegin = function() staged = {}; return true end
bcThermalAddRegion = function(roomId, x1, y1, x2, y2, z, temperature)
    staged[#staged + 1] = { roomId=roomId, temperature=temperature }
    return true
end
bcThermalCommit = function() return #staged end
bcThermalClear = function() staged = nil end
