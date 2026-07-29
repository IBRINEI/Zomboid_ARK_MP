require "BunkerCampaignToxicMP/Constants"

BunkerCampaignToxicMP = BunkerCampaignToxicMP or {}

local Constants = BunkerCampaignToxicMP.Constants
local Model = {}

function Model.clamp(value)
    value = tonumber(value) or 0
    if value ~= value or value == math.huge or value == -math.huge then return 0 end
    return math.max(0, math.min(Constants.SURFACE_MAX, value))
end

function Model.deposit(current, ratePerSecond, elapsedSeconds)
    local currentValue = Model.clamp(current)
    local rate = math.max(0, tonumber(ratePerSecond) or 0)
    local elapsed = math.max(0, tonumber(elapsedSeconds) or 0)
    return Model.clamp(currentValue + rate * elapsed)
end

function Model.contact(target, source, fraction)
    local targetValue = Model.clamp(target)
    local sourceValue = Model.clamp(source)
    local amount = math.max(0, math.min(1, tonumber(fraction) or 0))
    if sourceValue <= targetValue then return targetValue end
    return Model.clamp(targetValue + (sourceValue - targetValue) * amount)
end

function Model.clean(current, removalFraction)
    local currentValue = Model.clamp(current)
    local removal = math.max(0, math.min(1, tonumber(removalFraction) or 0))
    return Model.clamp(currentValue * (1 - removal))
end

function Model.classify(value)
    value = Model.clamp(value)
    if value >= Constants.SURFACE_DANGEROUS then return "dangerous" end
    if value >= Constants.SURFACE_DIRTY then return "dirty" end
    if value > Constants.SURFACE_TRACE then return "trace" end
    return "clean"
end

BunkerCampaignToxicMP.ContaminationModel = Model
return Model
