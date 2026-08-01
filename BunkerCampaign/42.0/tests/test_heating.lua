local RoomRegistry = BunkerCampaign.RoomRegistry
local HeatingSimulation = BunkerCampaign.HeatingSimulation
local HeatingRules = BunkerCampaign.Constants.HEATING

assert(RoomRegistry.register({
    id="thermal_laboratory", label="Thermal laboratory", kind="habitable",
    bounds={x1=100,x2=104,y1=100,y2=104,z=-4},
    vents={{x=102,y=100,z=-4}}, connections={"thermal_corridor"},
}), "thermal laboratory must register")
assert(RoomRegistry.register({
    id="thermal_corridor", label="Thermal corridor", kind="circulation",
    bounds={x1=105,x2=110,y1=100,y2=102,z=-4},
    vents={{x=105,y=101,z=-4}}, connections={"thermal_laboratory","thermal_airlock"},
}), "thermal corridor must register")
assert(RoomRegistry.register({
    id="thermal_airlock", label="Thermal airlock", kind="airlock",
    bounds={x1=111,x2=113,y1=100,y2=102,z=-4},
    vents={}, connections={"thermal_corridor"},
}), "thermal airlock must register")

local heating = HeatingSimulation.createDefault()
HeatingSimulation.normalize(heating)
assert(heating.rooms.thermal_laboratory and heating.rooms.thermal_corridor
    and heating.rooms.thermal_airlock, "all registered rooms must receive thermal state")
assert(heating.rooms.thermal_laboratory.vents[1].x == 102,
    "thermal state must preserve The Ark vent coordinates")
assert(heating.rooms.thermal_airlock.heatingEnabled == false,
    "a room without a physical vent must not receive direct heat")

local demand = HeatingSimulation.prepareDemand(heating, {
    externalTemperature=-40,
    baseExternalTemperature=8,
    coldOffset=-48,
    ventilation={activeMode="sealed",telemetry={outsideExchangeM3PerMinute=0}},
})
assert(demand > HeatingRules.STANDBY_POWER_KW and demand <= HeatingRules.MAX_POWER_KW,
    "cold weather must produce a bounded quadratic heating demand")

heating.powerAllocated = true
local beforeWarm = heating.rooms.thermal_laboratory.temperature
HeatingSimulation.update(heating, 1, {
    externalTemperature=-40,
    baseExternalTemperature=8,
    coldOffset=-48,
    fuelAvailable=true,
    ventilation={operating=true,activeMode="internal_recirculation",
        telemetry={outsideExchangeM3PerMinute=0}},
})
assert(heating.operating and heating.heatExchanger.outputKw > 0,
    "an allocated healthy exchanger must produce heat")
assert(heating.rooms.thermal_laboratory.temperature > beforeWarm,
    "a powered vented room must warm gradually")
assert(heating.rooms.thermal_laboratory.temperature - beforeWarm
    <= HeatingRules.MAX_TEMPERATURE_CHANGE_PER_MINUTE,
    "heating must respect thermal inertia")

local normalOutput = heating.heatExchanger.outputKw
HeatingSimulation.update(heating, 0, {
    externalTemperature=-40,
    ventilation={operating=false,activeMode="off",
        telemetry={outsideExchangeM3PerMinute=0}},
})
assert(not heating.operating and heating.reason == "air_circuit_unavailable",
    "normal heating distribution must require operating ventilation and circulation")
assert(HeatingSimulation.setManualBypass(heating, true))
HeatingSimulation.update(heating, 0, {
    externalTemperature=-40,
    ventilation={operating=false,activeMode="off",
        telemetry={outsideExchangeM3PerMinute=0}},
})
assert(heating.operating and heating.reason == "manual_bypass"
    and heating.heatExchanger.outputKw > 0 and heating.heatExchanger.outputKw < normalOutput,
    "manual bypass must provide only reduced emergency heat without ventilation")
assert(HeatingSimulation.setManualBypass(heating, false))
assert(HeatingSimulation.setValve(heating, "supply_valve", false))
HeatingSimulation.update(heating, 0, {
    externalTemperature=-40,
    ventilation={operating=true,activeMode="internal_recirculation",
        telemetry={outsideExchangeM3PerMinute=0}},
})
assert(not heating.operating and heating.reason == "air_circuit_unavailable",
    "a closed physical heating valve must stop normal distribution")
assert(HeatingSimulation.setValve(heating, "supply_valve", true))

heating.powerAllocated = false
local beforeCool = heating.rooms.thermal_laboratory.temperature
HeatingSimulation.update(heating, 1, {
    externalTemperature=-40,
    ventilation={operating=true,activeMode="internal_recirculation",
        telemetry={outsideExchangeM3PerMinute=0}},
})
assert(not heating.operating and heating.reason == "power_shed",
    "load shedding must stop the heat exchanger")
assert(heating.rooms.thermal_laboratory.temperature < beforeCool,
    "an unpowered bunker must cool gradually rather than switch instantly")

heating.powerAllocated = true
local sealedDemand = HeatingSimulation.prepareDemand(heating, {
    externalTemperature=-40,
    ventilation={activeMode="sealed",telemetry={outsideExchangeM3PerMinute=0}},
})
local openDemand = HeatingSimulation.prepareDemand(heating, {
    externalTemperature=-40,
    entryPath={breached=true},
    ventilation={activeMode="external_filtration",telemetry={outsideExchangeM3PerMinute=700}},
})
assert(openDemand > sealedDemand,
    "outside airflow and an open entry path must increase heating demand")

local ok = HeatingSimulation.setRoomEnabled(heating, "thermal_laboratory", false)
assert(ok and heating.rooms.thermal_laboratory.heatingEnabled == false,
    "operators must be able to isolate a vented heating zone")
local noVentOk, noVentReason = HeatingSimulation.setRoomEnabled(
    heating, "thermal_airlock", true)
assert(not noVentOk and noVentReason == "room_has_no_heating_vents",
    "a room without a vent must reject impossible direct heating")

assert(HeatingSimulation.setTarget(heating, 100))
assert(heating.targetTemperature == HeatingRules.MAX_TARGET_TEMPERATURE,
    "heating target must be server bounded")

heating.heatExchanger.fault = "test_fault"
HeatingSimulation.update(heating, 1, {
    externalTemperature=-40,
    ventilation={operating=true,activeMode="internal_recirculation",
        telemetry={outsideExchangeM3PerMinute=0}},
})
assert(not heating.operating and heating.reason == "heat_exchanger_failed",
    "an exchanger fault must stop heat production without erasing room temperatures")

heating.heatExchanger.fault = "none"
local faultOk, faultName = HeatingSimulation.triggerFault(
    heating, "circulation_blower", "minor", 100)
assert(faultOk and faultName == "worn_bearing"
    and heating.accidents.activeFailures == 1,
    "server incidents must create a bounded component fault")
assert(HeatingSimulation.diagnoseComponent(heating, "circulation_blower"))
assert(heating.components.circulation_blower.diagnosed,
    "diagnosis must persist on the authoritative component")
assert(HeatingSimulation.repairComponent(
    heating, "circulation_blower", "temporary", 0.2))
assert(heating.components.circulation_blower.fault == "none"
    and heating.components.circulation_blower.temporaryRepair,
    "temporary repair must restore operation but retain accelerated wear")

heating.accidents.lastFailureHour = 0
local natural = HeatingSimulation.update(heating, 1, {
    externalTemperature=-60,
    worldAgeHours=20,
    allowHeatingFailures=true,
    failureRoll=0,
    ventilation={operating=true,activeMode="internal_recirculation",
        airflowM3PerMinute=450,telemetry={outsideExchangeM3PerMinute=0}},
})
assert(natural.failure ~= nil and heating.accidents.activeFailures <= 2
    and heating.accidents.activeMajorFailures <= 1,
    "stressed equipment must generate bounded natural failures")
local cooldown = HeatingSimulation.update(heating, 1, {
    externalTemperature=-60,
    worldAgeHours=20.1,
    allowHeatingFailures=true,
    failureRoll=0,
    ventilation={operating=true,activeMode="internal_recirculation",
        airflowM3PerMinute=450,telemetry={outsideExchangeM3PerMinute=0}},
})
assert(cooldown.failure == nil,
    "failure cooldown must prevent cascading tick-by-tick accidents")

print("BunkerCampaign heating tests passed")
