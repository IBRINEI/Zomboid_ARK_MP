local power = BunkerCampaign.PowerSimulation.createDefault()

local initial = BunkerCampaign.PowerSimulation.update(power, 0)
assert(power.status == "operational", "main generator must satisfy the bootstrap load")
assert(power.gridOnline == true, "running generator must expose the main grid")
assert(power.consumers.ventilation.allocated == true, "ventilation must be allocated before lower-priority loads")
assert(power.consumers.water.allocated == true, "water must receive power with the main generator online")
assert(power.consumers.emergency_lighting.allocated == false, "emergency fixtures must remain dark on the main grid")
assert(#initial.allocationChanges > 0, "initial allocation must report changes")

local fuelBefore = power.generators.main.fuel
BunkerCampaign.PowerSimulation.update(power, 1)
assert(power.generators.main.fuel < fuelBefore, "logical generator fuel must be consumed on the server")

power.generators.main.requested = false
BunkerCampaign.PowerSimulation.update(power, 0)
assert(power.gridOnline == false, "stopped generators must de-energize the main grid")
assert(power.emergencyMode == true, "battery must enter emergency mode")
assert(power.consumers.control.source == "battery", "control bus must be battery-backed")
assert(power.consumers.emergency_lighting.source == "battery", "red emergency lights must be battery-backed")
assert(power.consumers.ventilation.allocated == false, "battery must not power ventilation")
assert(power.consumers.water.allocated == false, "battery must not power the water pump")

local chargeBefore = power.battery.charge
BunkerCampaign.PowerSimulation.update(power, 10)
assert(power.battery.charge < chargeBefore, "emergency loads must drain the battery")

power.generators.backup.requested = true
BunkerCampaign.PowerSimulation.update(power, 0)
assert(power.gridOnline == true, "backup generator must restore the grid")
assert(power.consumers.water.allocated == true, "water must resume after backup power is available")
assert(power.consumers.emergency_lighting.allocated == false, "emergency lights must turn off after grid restoration")

print("BunkerCampaign power tests passed")
