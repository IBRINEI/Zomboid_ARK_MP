require "BunkerCampaign/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local HeatingAdapter = {}
local sources = BunkerCampaignIntegration.heatingSources or {}
BunkerCampaignIntegration.heatingSources = sources

local function sourceId(roomId, vent)
    return tostring(roomId) .. ":" .. tostring(math.floor(tonumber(vent.x) or 0))
        .. ":" .. tostring(math.floor(tonumber(vent.y) or 0))
        .. ":" .. tostring(math.floor(tonumber(vent.z) or 0))
end

local function removeSource(cell, id)
    local source = sources[id]
    if not source then return end
    if cell and cell.removeHeatSource then pcall(function() cell:removeHeatSource(source) end) end
    sources[id] = nil
end

function HeatingAdapter.clear(cell)
    cell = cell or (type(getCell) == "function" and getCell() or nil)
    for id in pairs(sources) do removeSource(cell, id) end
end

function HeatingAdapter.apply(heating, cell)
    if type(heating) ~= "table" then return false, "missing_heating" end
    cell = cell or (type(getCell) == "function" and getCell() or nil)
    if not cell then return false, "cell_unavailable" end

    local desired = {}
    local active = heating.enabled == true and heating.requested == true
        and heating.powerAllocated == true and heating.operating == true
    for roomId, room in pairs(type(heating.rooms) == "table" and heating.rooms or {}) do
        if active and room.heatingEnabled ~= false then
            for _, vent in ipairs(type(room.vents) == "table" and room.vents or {}) do
                local x = math.floor(tonumber(vent.x) or 0)
                local y = math.floor(tonumber(vent.y) or 0)
                local z = math.floor(tonumber(vent.z) or 0)
                local id = sourceId(roomId, vent)
                desired[id] = true
                local square = cell.getGridSquare and cell:getGridSquare(x, y, z) or nil
                local source = sources[id]
                if square and not source and IsoHeatSource and IsoHeatSource.new then
                    source = IsoHeatSource.new(x, y, z,
                        BunkerCampaign.Constants.HEATING.HEAT_SOURCE_RADIUS,
                        (tonumber(room.temperature) or heating.averageTemperature or 0)
                            + BunkerCampaign.Constants.HEATING.HEAT_SOURCE_CORRECTION)
                    sources[id] = source
                    if cell.addHeatSource then cell:addHeatSource(source) end
                elseif source then
                    if source.setRadius then
                        source:setRadius(BunkerCampaign.Constants.HEATING.HEAT_SOURCE_RADIUS)
                    end
                    if source.setTemperature then
                        source:setTemperature((tonumber(room.temperature)
                            or heating.averageTemperature or 0)
                            + BunkerCampaign.Constants.HEATING.HEAT_SOURCE_CORRECTION)
                    end
                end
            end
        end
    end
    for id in pairs(sources) do
        if not desired[id] then removeSource(cell, id) end
    end
    return true
end

function HeatingAdapter.sourceCount()
    local count = 0
    for _ in pairs(sources) do count = count + 1 end
    return count
end

BunkerCampaignIntegration.HeatingAdapter = HeatingAdapter
return HeatingAdapter
