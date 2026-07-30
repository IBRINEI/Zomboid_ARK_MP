require "BunkerCampaign/Util"
require "BunkerCampaignIntegration/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local Util = BunkerCampaign.Util
local Constants = BunkerCampaignIntegration.Constants
local ZoneSampler = {}

local function normalizeCoordinate(value)
    if not Util.isFiniteNumber(value) then return nil end
    return Util.clamp(value, -1000000, 1000000)
end

function ZoneSampler.sanitize(source)
    local result = {}
    local sourceCount = 0
    local rejectedCount = 0

    if type(source) ~= "table" then return result, sourceCount, rejectedCount end

    for name, raw in pairs(source) do
        sourceCount = sourceCount + 1
        if #result >= Constants.MAX_IMPORTED_ZONES then
            rejectedCount = rejectedCount + 1
        elseif type(raw) == "table" then
            local x1 = normalizeCoordinate(raw.startX)
            local x2 = normalizeCoordinate(raw.endX)
            local y1 = normalizeCoordinate(raw.startY)
            local y2 = normalizeCoordinate(raw.endY)
            local z1 = normalizeCoordinate(raw.startZ)
            local z2 = normalizeCoordinate(raw.endZ)
            if z1 == nil then z1 = 0 end
            if z2 == nil then z2 = z1 end

            if x1 and x2 and y1 and y2 then
                if x1 > x2 then x1, x2 = x2, x1 end
                if y1 > y2 then y1, y2 = y2, y1 end
                result[#result + 1] = {
                    id = tostring(name),
                    startX = x1,
                    startY = y1,
                    endX = x2,
                    endY = y2,
                    startZ = math.floor(math.min(z1, z2)),
                    endZ = math.floor(math.max(z1, z2)),
                }
            else
                rejectedCount = rejectedCount + 1
            end
        else
            rejectedCount = rejectedCount + 1
        end
    end

    return result, sourceCount, rejectedCount
end

function ZoneSampler.isPointToxic(zones, x, y, z)
    if type(zones) ~= "table" or not Util.isFiniteNumber(x) or not Util.isFiniteNumber(y) then return false end
    z = math.floor(tonumber(z) or 0)
    for _, zone in ipairs(zones) do
        if x >= zone.startX and x <= zone.endX and y >= zone.startY and y <= zone.endY
            and z >= (zone.startZ or 0) and z <= (zone.endZ or 0) then
            return true
        end
    end
    return false
end

function ZoneSampler.sampleAirIntakes(zones, airIntakes)
    if type(airIntakes) ~= "table" then return 0, 0, 0 end

    local activeCount = 0
    local toxicCount = 0
    for _, intake in pairs(airIntakes) do
        if type(intake) == "table" and intake.broken ~= true and Util.isFiniteNumber(intake.x) and Util.isFiniteNumber(intake.y) then
            activeCount = activeCount + 1
            if ZoneSampler.isPointToxic(zones, intake.x, intake.y, intake.z) then
                toxicCount = toxicCount + 1
            end
        end
    end

    if activeCount == 0 then return 0, activeCount, toxicCount end
    return toxicCount / activeCount, activeCount, toxicCount
end

function ZoneSampler.sampleAirIntakesDetailed(zones, airIntakes)
    local result, activeCount, toxicCount = {}, 0, 0
    if type(airIntakes) ~= "table" then return result, activeCount, toxicCount end
    local ordered = {}
    for _, intake in pairs(airIntakes) do
        if type(intake) == "table" and Util.isFiniteNumber(intake.x) and Util.isFiniteNumber(intake.y) then
            ordered[#ordered + 1] = intake
        end
    end
    table.sort(ordered, function(left, right)
        if left.x ~= right.x then return left.x < right.x end
        if left.y ~= right.y then return left.y < right.y end
        return (left.z or 0) < (right.z or 0)
    end)
    for index, intake in ipairs(ordered) do
        local id = "intake_" .. tostring(index)
        if intake.broken ~= true then
            activeCount = activeCount + 1
            local value = ZoneSampler.isPointToxic(zones, intake.x, intake.y, intake.z) and 1 or 0
            result[id] = value
            if value > 0 then toxicCount = toxicCount + 1 end
        else
            result[id] = 0
        end
    end
    return result, activeCount, toxicCount
end

BunkerCampaignIntegration.ZoneSampler = ZoneSampler
return ZoneSampler
