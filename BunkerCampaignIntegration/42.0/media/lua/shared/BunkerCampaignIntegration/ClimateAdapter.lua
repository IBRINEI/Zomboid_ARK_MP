require "BunkerCampaign/Util"
require "BunkerCampaignIntegration/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local Util = BunkerCampaign.Util
local Constants = BunkerCampaignIntegration.Constants
local ClimateAdapter = {}

local function optionValue(values, selected, fallback)
    local index = math.floor(tonumber(selected) or 0)
    return values[index] or fallback
end

function ClimateAdapter.resolveOptions(sandbox)
    local bwoa = type(sandbox) == "table" and type(sandbox.BWOA) == "table"
        and sandbox.BWOA or {}
    local climate = Constants.ARK_CLIMATE
    return {
        falloutStart = optionValue(climate.FALLOUT_START_OPTIONS,
            bwoa.FalloutStarted, climate.DEFAULT_FALLOUT_START),
        falloutEnd = optionValue(climate.FALLOUT_END_OPTIONS,
            bwoa.FalloutEnds, climate.DEFAULT_FALLOUT_END),
        peakPoint = optionValue(climate.FALLOUT_CURVE_OPTIONS,
            bwoa.FalloutCurve, climate.DEFAULT_PEAK_POINT),
        temperatureDrop = optionValue(climate.TEMPERATURE_DROP_OPTIONS,
            bwoa.TemperatureDrop, climate.DEFAULT_TEMPERATURE_DROP),
    }
end

-- This is The Ark's two-sided sine fallout curve.  It is kept pure so the
-- server can own the result and clients only apply the replicated snapshot.
function ClimateAdapter.temperatureOffset(worldAgeHours, options)
    options = type(options) == "table" and options or ClimateAdapter.resolveOptions(nil)
    local age = (tonumber(worldAgeHours) or 0) - Constants.ARK_CLIMATE.WORLD_AGE_OFFSET_HOURS
    local startAt = tonumber(options.falloutStart) or Constants.ARK_CLIMATE.DEFAULT_FALLOUT_START
    local endAt = tonumber(options.falloutEnd) or Constants.ARK_CLIMATE.DEFAULT_FALLOUT_END
    local peak = Util.clamp(tonumber(options.peakPoint)
        or Constants.ARK_CLIMATE.DEFAULT_PEAK_POINT, 0.01, 0.99)
    if age < startAt or age > endAt or endAt <= startAt then return 0, 0 end

    local progress = (age - startAt) / (endAt - startAt)
    local strength
    if progress <= peak then
        strength = math.sin((progress / peak) * (math.pi / 2))
    else
        strength = math.sin((math.pi / 2)
            + ((progress - peak) / (1 - peak)) * (math.pi / 2))
    end
    strength = Util.clamp(strength, 0, 1)
    return strength * (tonumber(options.temperatureDrop)
        or Constants.ARK_CLIMATE.DEFAULT_TEMPERATURE_DROP), strength
end

local function climateManager()
    local world = type(getWorld) == "function" and getWorld() or nil
    return world and world.getClimateManager and world:getClimateManager() or nil
end

function ClimateAdapter.sample(manager, worldAgeHours, sandbox)
    manager = manager or climateManager()
    local temperature = manager and manager.getClimateFloat and manager:getClimateFloat(4) or nil
    local base = temperature and temperature.getInternalValue
        and tonumber(temperature:getInternalValue()) or 0
    local options = ClimateAdapter.resolveOptions(sandbox or SandboxVars)
    local offset, strength = ClimateAdapter.temperatureOffset(worldAgeHours, options)
    return {
        worldAgeHours = tonumber(worldAgeHours) or 0,
        baseExternalTemperature = base,
        coldOffset = offset,
        externalTemperature = base + offset,
        falloutStrength = strength,
        windIntensity = manager and manager.getWindIntensity
            and tonumber(manager:getWindIntensity()) or 0,
        precipitationIntensity = manager and manager.getPrecipitationIntensity
            and tonumber(manager:getPrecipitationIntensity()) or 0,
    }
end

function ClimateAdapter.apply(snapshot, manager)
    if type(snapshot) ~= "table" then return false, "missing_snapshot" end
    manager = manager or climateManager()
    local temperature = manager and manager.getClimateFloat and manager:getClimateFloat(4) or nil
    if not temperature or not temperature.setEnableOverride then
        return false, "climate_manager_unavailable"
    end
    local offset = tonumber(snapshot.coldOffset) or 0
    if math.abs(offset) < 0.0001 then
        temperature:setEnableOverride(false)
    else
        temperature:setEnableOverride(true)
        temperature:setOverride(tonumber(snapshot.externalTemperature) or 0, 1)
    end
    return true
end

BunkerCampaignIntegration.ClimateAdapter = ClimateAdapter
return ClimateAdapter
