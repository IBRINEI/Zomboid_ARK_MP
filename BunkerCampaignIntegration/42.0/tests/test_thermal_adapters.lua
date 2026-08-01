local root = "C:/Users/BRINE/Zomboid/mods/"
package.path = root .. "BunkerCampaign/42.0/media/lua/shared/?.lua;" .. root .. "BunkerCampaignIntegration/42.0/media/lua/shared/?.lua;" .. package.path

require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignIntegration/ClimateAdapter"
require "BunkerCampaignIntegration/HeatingAdapter"
require "BunkerCampaignIntegration/ThermalOverrideAdapter"

local ClimateAdapter = BunkerCampaignIntegration.ClimateAdapter
local HeatingAdapter = BunkerCampaignIntegration.HeatingAdapter
local ThermalOverrideAdapter = BunkerCampaignIntegration.ThermalOverrideAdapter

local function assertNear(actual, expected, tolerance, message)
    assert(math.abs(actual - expected) <= tolerance,
        (message or "values differ") .. ": " .. tostring(actual) .. " vs " .. tostring(expected))
end

local options = ClimateAdapter.resolveOptions({ BWOA={
    FalloutStarted=4, FalloutEnds=3, FalloutCurve=4, TemperatureDrop=3,
} })
assert(options.falloutStart == -2208 and options.falloutEnd == 744,
    "The Ark sandbox option indexes must keep their original meaning")
assert(options.peakPoint == 0.65 and options.temperatureDrop == -50,
    "The Ark curve and temperature-drop options must be reused")

local before = ClimateAdapter.temperatureOffset(-3000, options)
local atStart = ClimateAdapter.temperatureOffset(options.falloutStart + 10, options)
local peakAge = options.falloutStart
    + (options.falloutEnd - options.falloutStart) * options.peakPoint + 10
local atPeak, peakStrength = ClimateAdapter.temperatureOffset(peakAge, options)
local atEnd = ClimateAdapter.temperatureOffset(options.falloutEnd + 10, options)
assertNear(before, 0, 0.0001, "fallout cold must be inactive before the curve")
assertNear(atStart, 0, 0.0001, "fallout curve must begin at zero")
assertNear(atPeak, -50, 0.0001, "fallout curve must reach the selected temperature drop")
assertNear(peakStrength, 1, 0.0001, "fallout curve strength must peak at one")
assertNear(atEnd, 0, 0.0001, "fallout curve must return to zero")

local climateFloat = {
    enabled=false, override=nil,
    getInternalValue=function() return 12 end,
    setEnableOverride=function(self, value) self.enabled=value end,
    setOverride=function(self, value) self.override=value end,
}
local manager = {
    getClimateFloat=function() return climateFloat end,
    getWindIntensity=function() return 0.4 end,
    getPrecipitationIntensity=function() return 0.2 end,
}
local climate = ClimateAdapter.sample(manager, peakAge, { BWOA={
    FalloutStarted=4, FalloutEnds=3, FalloutCurve=4, TemperatureDrop=3,
} })
assertNear(climate.baseExternalTemperature, 12, 0.0001)
assertNear(climate.externalTemperature, -38, 0.0001)
assert(ClimateAdapter.apply(climate, manager))
assert(climateFloat.enabled and climateFloat.override == -38,
    "authoritative external temperature must be applied as a climate override")
climate.coldOffset = 0
assert(ClimateAdapter.apply(climate, manager) and climateFloat.enabled == false,
    "climate override must be released when the fallout curve ends")

local added, removed = {}, {}
local cell = {
    getGridSquare=function() return {} end,
    addHeatSource=function(self, source) added[#added + 1] = source end,
    removeHeatSource=function(self, source) removed[#removed + 1] = source end,
}
IsoHeatSource = {
    new=function(x, y, z, radius, temperature)
        return {
            x=x, y=y, z=z, radius=radius, temperature=temperature,
            setRadius=function(self, value) self.radius=value end,
            setTemperature=function(self, value) self.temperature=value end,
        }
    end,
}
local heating = {
    enabled=true, requested=true, powerAllocated=true, operating=true,
    averageTemperature=18,
    rooms={ laboratory={
        id="laboratory", heatingEnabled=true, temperature=18,
        vents={ {x=10,y=20,z=-4}, {x=11,y=20,z=-4} },
    } },
}
HeatingAdapter.clear(cell)
assert(HeatingAdapter.apply(heating, cell))
assert(#added == 2 and HeatingAdapter.sourceCount() == 2,
    "one bounded heat source must be created for each loaded room vent")
assert(added[1].radius == BunkerCampaign.Constants.HEATING.HEAT_SOURCE_RADIUS,
    "The Ark radius 1000 must not be retained")
assertNear(added[1].temperature, 25, 0.0001,
    "The Ark local heat-source correction must be retained")

heating.rooms.laboratory.temperature = 19
HeatingAdapter.apply(heating, cell)
assert(#added == 2 and added[1].temperature == 26,
    "existing sources must update without duplication")
heating.powerAllocated = false
HeatingAdapter.apply(heating, cell)
assert(#removed == 2 and HeatingAdapter.sourceCount() == 0,
    "shed heating power must remove all local heat sources")

local staged, committed = nil, nil
bcThermalBegin = function() staged = {}; return true end
bcThermalAddRegion = function(roomId, x1, y1, x2, y2, z, temperature)
    staged[#staged + 1] = {
        roomId=roomId, x1=x1, y1=y1, x2=x2, y2=y2, z=z,
        temperature=temperature,
    }
    return true
end
bcThermalCommit = function() committed = staged; return #staged end
bcThermalClear = function() staged, committed = nil, nil end

heating.rooms.laboratory.bounds = { x1=10, y1=20, x2=12, y2=22, z=-4 }
heating.rooms.laboratory.regions = {
    { x1=10, y1=20, x2=11, y2=22, z=-4 },
    { x1=12, y1=21, x2=12, y2=22, z=-4 },
}
heating.rooms.laboratory.temperature = -18.5
local thermalOk, regionCount = ThermalOverrideAdapter.apply(heating)
assert(thermalOk and regionCount == 2 and #committed == 2,
    "room-temperature override must atomically publish every room region")
assert(committed[1].roomId == "laboratory" and committed[1].temperature == -18.5,
    "published regions must carry the authoritative room temperature")

bcThermalBegin, bcThermalAddRegion, bcThermalCommit, bcThermalClear = nil, nil, nil, nil
local unavailable, unavailableReason = ThermalOverrideAdapter.apply(heating)
assert(unavailable == false and unavailableReason == "java_override_unavailable",
    "missing ZombieBuddy Java API must fail closed without a Lua error")

print("BunkerCampaign thermal adapter tests passed")
