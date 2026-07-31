local RoomRegistry = BunkerCampaign.RoomRegistry
local VentilationSimulation = BunkerCampaign.VentilationSimulation
local WaterSimulation = BunkerCampaign.WaterSimulation

assert(RoomRegistry.register({
    id="laboratory", label="Laboratory", kind="habitable",
    bounds={x1=10, x2=14, y1=20, y2=24, z=-4},
    vents={{x=12, y=20, z=-4}}, connections={"garage"},
}), "laboratory must register")
assert(RoomRegistry.register({
    id="garage", label="Garage", kind="technical",
    bounds={x1=15, x2=20, y1=20, y2=25, z=-4},
    vents={{x=15, y=22, z=-4}}, connections={"laboratory"},
}), "garage must register")
assert(RoomRegistry.find(12, 22, -4).id == "laboratory", "coordinates must resolve to a room")
assert(RoomRegistry.find(17, 23, -4).id == "garage", "new rooms must need no simulation changes")
assert(RoomRegistry.register({
    id="corridor", label="Corridor", kind="circulation",
    regions={
        {x1=21,x2=22,y1=20,y2=30,z=-4},
        {x1=21,x2=30,y1=29,y2=30,z=-4},
    },
    vents={{x=21,y=25,z=-4}}, connections={"garage"},
}), "non-rectangular corridor geometry must register")
assert(RoomRegistry.find(22, 27, -4).id == "corridor"
    and RoomRegistry.find(27, 30, -4).id == "corridor",
    "every composite corridor segment must resolve to one ventilation room")

local ventilation = VentilationSimulation.createDefault()
ventilation.powerAllocated = true
ventilation.recirculationUnlocked = true
VentilationSimulation.normalize(ventilation)
assert(ventilation.rooms.laboratory and ventilation.rooms.garage, "registered rooms must receive state")

for _, intake in pairs(ventilation.intakes) do intake.externalContamination = 1 end
local filterBefore = ventilation.filterBank.remaining
VentilationSimulation.update(ventilation, 1, {
    occupancyByRoom={laboratory=2, garage=1},
    externalContamination=1,
})
assert(ventilation.activeMode == "external_filtration", "powered external mode must operate")
assert(ventilation.telemetry.totalOccupants == 3, "room occupants must be counted")
assert(ventilation.rooms.laboratory.co2 > BunkerCampaign.Constants.VENTILATION.MIN_CO2,
    "occupied room must generate CO2")
assert(ventilation.filterBank.remaining < filterBefore, "outside contamination must load the filter")
assert(ventilation.rooms.laboratory.contamination == 0,
    "a healthy full-efficiency filter must not leak trace contamination into a clean room")
ventilation.filterBank.condition = 0.5
VentilationSimulation.update(ventilation, 1, {
    occupancyByRoom={}, externalContamination=1,
})
assert(ventilation.rooms.laboratory.contamination == 0,
    "a serviceable damaged filter must remain a barrier until it actually fails or is exhausted")
ventilation.filterBank.condition = 1

ventilation.rooms.laboratory.contamination = 0.5
assert(VentilationSimulation.setMode(ventilation, "internal_recirculation"))
local recirculationFilter = ventilation.filterBank.remaining
VentilationSimulation.update(ventilation, 1, {occupancyByRoom={laboratory=1},externalContamination=1})
assert(ventilation.rooms.laboratory.contamination < 0.5
    and ventilation.filterBank.remaining < recirculationFilter,
    "internal recirculation must clean existing airborne contamination and load the filter")
assert(ventilation.telemetry.filterActivity == "cleaning_internal_air"
    and ventilation.telemetry.recirculationRemovalPerMinute > 0
    and ventilation.telemetry.recirculationRemovedM3PerMinute > 0,
    "recirculation effectiveness must be exposed in telemetry")

ventilation.intakes.intake_1.broken = true
ventilation.intakes.intake_1.condition = 1
VentilationSimulation.normalize(ventilation)
assert(ventilation.intakes.intake_1.condition == 0
    and ventilation.intakes.intake_1.status == "failed",
    "a broken intake must expose zero condition even when an old save retained 100 percent")

VentilationSimulation.update(ventilation, 1, {occupancyByRoom={}})
assert(ventilation.telemetry.totalOccupants == 0
    and ventilation.rooms.laboratory.occupants == 0 and ventilation.rooms.garage.occupants == 0,
    "leaving a room must reset its occupant count instead of accumulating visits")

assert(VentilationSimulation.setMode(ventilation, "sealed"))
ventilation.rooms.laboratory.contamination = 0
VentilationSimulation.update(ventilation, 1, {occupancyByRoom={laboratory=2}})
assert(ventilation.activeMode == "sealed" and ventilation.airflowM3PerMinute == 0,
    "sealed mode must stop mechanical airflow")
assert(ventilation.rooms.laboratory.contamination == 0,
    "sealed mode must block intentional outside contamination exchange")
assert(VentilationSimulation.setMode(ventilation, "off"))
VentilationSimulation.update(ventilation, 1, {occupancyByRoom={laboratory=2},externalContamination=1})
assert(ventilation.rooms.laboratory.contamination > 0,
    "OFF must remain distinct from sealed by allowing passive room leakage")

ventilation.rooms.laboratory.contamination = 0.8
assert(VentilationSimulation.setMode(ventilation, "emergency_ventilation"))
assert(VentilationSimulation.startAirlockPurge(ventilation, "laboratory"))
VentilationSimulation.update(ventilation, 1, {
    externalContamination=0,
    entryPath={sampled=true,breached=true,allOpen=true,openCount=3,loadedCount=3,total=3,doors={}},
})
assert(ventilation.airlock.active and ventilation.airlock.status == "waiting_for_doors"
    and ventilation.airlock.remainingMinutes == BunkerCampaign.Constants.VENTILATION.AIRLOCK_PURGE_MINUTES,
    "purge must pause while the complete entry door path is open")
VentilationSimulation.update(ventilation, 2, {
    externalContamination=0,
    entryPath={sampled=true,breached=false,allOpen=false,openCount=1,loadedCount=3,total=3,doors={}},
})
assert(not ventilation.airlock.active and ventilation.airlock.status == "complete",
    "powered purge must complete")
assert(ventilation.rooms.laboratory.contamination < 0.8, "purge must clean its target room")

local water = WaterSimulation.createDefault()
water.adapterOnline = true
water.physicallyAvailable = true
water.powerAllocated = true
WaterSimulation.update(water, 1, {
    adapterOnline=true, physicallyAvailable=true, pumpPresent=true, pumpActive=true,
    pumpCondition=0.9, filterRemaining=0.8, cleanStored=50, taintedStored=10,
    capacity=100, flowPerMinute=6, filterUsePerMinute=0.012,
})
assert(water.operating, "powered physical pump must operate")
assert(water.storage.cleanLiters == 50 and water.storage.taintedLiters == 10,
    "water qualities must remain separate")
assert(water.telemetry.producedLiters == 6, "actual flow must drive production telemetry")
assert(water.telemetry.treatmentFilterUsePerMinute == 0.012,
    "physical water-filter consumption must be visible in campaign telemetry")

water.powerAllocated = false
WaterSimulation.update(water, 1, {adapterOnline=true, physicallyAvailable=true, pumpActive=false})
assert(not water.operating and water.reason == "power_shed", "pump must stop after load shedding")

water.selectedSource = "external_tank"
water.sources.external_tank.enabled = true
water.sources.external_tank.availableLiters = 5
water.powerAllocated = true
WaterSimulation.update(water, 1, {
    adapterOnline=true, physicallyAvailable=true, pumpPresent=true, pumpActive=true,
    flowPerMinute=2,
})
assert(water.sources.external_tank.availableLiters == 3,
    "a finite source must debit only physically pumped volume")
WaterSimulation.update(water, 2, {
    adapterOnline=true, physicallyAvailable=true, pumpPresent=true, pumpActive=true,
    flowPerMinute=2,
})
assert(water.sources.external_tank.availableLiters == 0
    and water.sources.external_tank.status == "empty",
    "a finite source must become empty without a negative balance")
WaterSimulation.update(water, 1, {
    adapterOnline=true, physicallyAvailable=true, pumpPresent=true, pumpActive=true,
    flowPerMinute=2,
})
assert(not water.operating and water.reason == "source_empty",
    "an exhausted source must stop the physical water request")

print("BunkerCampaign life-support tests passed")
