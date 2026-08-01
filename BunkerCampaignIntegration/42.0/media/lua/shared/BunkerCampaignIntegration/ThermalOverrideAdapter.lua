BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local ThermalOverrideAdapter = {}

local function available()
    return type(bcThermalBegin) == "function"
        and type(bcThermalAddRegion) == "function"
        and type(bcThermalCommit) == "function"
end

function ThermalOverrideAdapter.isAvailable()
    return available()
end

function ThermalOverrideAdapter.clear()
    if type(bcThermalClear) ~= "function" then return false, "java_override_unavailable" end
    local ok, reason = pcall(bcThermalClear)
    return ok, ok and nil or tostring(reason)
end

function ThermalOverrideAdapter.apply(heating)
    if type(heating) ~= "table" then return false, "missing_heating" end
    if not available() then return false, "java_override_unavailable" end

    local ok, result = pcall(function()
        bcThermalBegin()
        local count = 0
        for roomId, room in pairs(type(heating.rooms) == "table" and heating.rooms or {}) do
            local temperature = tonumber(room.temperature)
                or tonumber(heating.averageTemperature) or 0
            local regions = type(room.regions) == "table" and room.regions or {}
            if #regions == 0 and type(room.bounds) == "table" then regions = { room.bounds } end
            for _, region in ipairs(regions) do
                if bcThermalAddRegion(tostring(roomId),
                    tonumber(region.x1) or 0, tonumber(region.y1) or 0,
                    tonumber(region.x2) or 0, tonumber(region.y2) or 0,
                    tonumber(region.z) or 0, temperature) then
                    count = count + 1
                end
            end
        end
        local committed = bcThermalCommit()
        if tonumber(committed) ~= count then
            error("thermal region commit mismatch")
        end
        return count
    end)
    if not ok then
        if type(bcThermalClear) == "function" then pcall(bcThermalClear) end
        return false, tostring(result)
    end
    return true, result
end

BunkerCampaignIntegration.ThermalOverrideAdapter = ThermalOverrideAdapter
return ThermalOverrideAdapter
