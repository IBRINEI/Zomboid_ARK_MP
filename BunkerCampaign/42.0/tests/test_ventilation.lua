local root = (... and ... ~= "" and ...) or "media/lua/shared/?.lua"
package.path = root .. ";" .. package.path

require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"
require "BunkerCampaign/StateSchema"
require "BunkerCampaign/VentilationSimulation"

local function assertNear(actual, expected, tolerance, message)
    assert(math.abs(actual - expected) <= tolerance, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

local state = BunkerCampaign.StateSchema.createDefault()
local ventilation = state.bunker.modules.ventilation

local migrated = {
    bunker = {
        modules = {
            ventilation = {
                enabled = false,
                condition = 2,
                filterRemaining = -1,
                co2 = 0 / 0,
            },
        },
    },
}
local changed, messages = BunkerCampaign.StateSchema.prepare(migrated, false)
assert(changed, "version 0 state must be migrated")
assert(migrated.version == 6, "migration must set state version")
assert(migrated.bunker.modules.water.status == "offline", "migration must add water defaults")
assert(migrated.bunker.modules.power.generators.main.fuel == 0.87, "migration must add power defaults")
assert(migrated.bunker.modules.ventilation.enabled == false, "migration must preserve valid existing values")
assert(migrated.bunker.modules.ventilation.condition == 1, "migration must clamp condition")
assert(migrated.bunker.modules.ventilation.filterRemaining == 0, "migration must clamp filter")
assert(migrated.bunker.modules.ventilation.co2 == 420, "migration must replace NaN")
assert(type(migrated.bunker.modules.ventilation.rooms) == "table", "migration must add room state")
assert(type(migrated.bunker.modules.water.storage) == "table", "migration must add quality-aware water state")
assert(#messages > 0, "migration must report its action")

local legacyPriority = BunkerCampaign.StateSchema.createDefault()
legacyPriority.version = 4
legacyPriority.bunker.modules.power.consumers.decontamination.priority = 75
BunkerCampaign.StateSchema.prepare(legacyPriority, false)
assert(legacyPriority.bunker.modules.power.consumers.decontamination.priority == 85,
    "version 4 saves must migrate decontamination above the water-pump priority")

local futureState = BunkerCampaign.StateSchema.createDefault()
futureState.version = 999
local acceptedFutureVersion = pcall(function()
    BunkerCampaign.StateSchema.prepare(futureState, false)
end)
assert(not acceptedFutureVersion, "newer state versions must fail closed")

ventilation.enabled = false
ventilation.requestedMode = "off"
BunkerCampaign.VentilationSimulation.update(ventilation, 10)
assert(ventilation.co2 >= 420, "CO2 must remain at or above the outside baseline")

ventilation.enabled = true
ventilation.requestedMode = "external_filtration"
ventilation.powerAllocated = true
ventilation.externalContamination = 1
local before = ventilation.filterRemaining
BunkerCampaign.VentilationSimulation.update(ventilation, 10)
assert(ventilation.filterRemaining < before, "filter must be consumed while ventilation is active")

ventilation.filterRemaining = 0
ventilation.filterBank.remaining = 0
ventilation.internalContamination = 0
BunkerCampaign.VentilationSimulation.update(ventilation, 10)
assert(ventilation.internalContamination > 0, "external contamination must enter after filter exhaustion")

ventilation.co2 = 420
ventilation.enabled = true
ventilation.externalContamination = 0
ventilation.filterRemaining = 1
BunkerCampaign.VentilationSimulation.update(ventilation, 10)
assertNear(ventilation.co2, 420, 0.001, "CO2 must not fall below baseline")

print("BunkerCampaign ventilation tests passed")
