require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"
require "BunkerCampaign/RoomRegistry"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local RoomRegistry = BunkerCampaign.RoomRegistry
local VentilationSimulation = {}

local function ensureTable(parent, key)
    if type(parent[key]) ~= "table" then parent[key] = {} end
    return parent[key]
end

local function defaultIntake(id, x, y, z)
    return {
        id=id, x=x, y=y, z=z,
        open=true,
        broken=false,
        condition=1,
        externalContamination=0,
        maximumFlowM3PerMinute=300,
        status="operational",
    }
end

function VentilationSimulation.createDefault()
    return {
        enabled=true,
        requestedMode="external_filtration",
        activeMode="off",
        reason="power_shed",
        powerAllocated=false,
        operating=false,
        condition=1,
        fanCondition=1,
        status="operational",
        powerDemandKw=Constants.VENTILATION.FAN_POWER_EXTERNAL_KW,
        airflowM3PerMinute=0,
        filterRemaining=1,
        filterBank={
            remaining=1,
            efficiency=Constants.VENTILATION.FILTER_EFFICIENCY,
            condition=1,
            bypass=false,
            fault="none",
        },
        co2=Constants.VENTILATION.MIN_CO2,
        externalContamination=0,
        internalContamination=0,
        recirculationUnlocked=true,
        intakes={
            intake_1=defaultIntake("intake_1", 9940, 12633, 0),
            intake_2=defaultIntake("intake_2", 9940, 12634, 0),
            intake_3=defaultIntake("intake_3", 9941, 12633, 0),
            intake_4=defaultIntake("intake_4", 9941, 12634, 0),
        },
        rooms={},
        airlock={
            active=false,
            roomId="decontamination_chamber",
            remainingMinutes=0,
            status="idle",
            doorsInterlocked=true,
        },
        faults={},
        telemetry={
            activeIntakes=0,
            occupiedRooms=0,
            totalOccupants=0,
            worstRoomId="",
            co2TrendPpmPerMinute=0,
        },
    }
end

local function normalizeIntake(intake, defaults)
    intake.id = type(intake.id) == "string" and intake.id or defaults.id
    intake.x = Util.numberOr(intake.x, defaults.x, -1000000, 1000000)
    intake.y = Util.numberOr(intake.y, defaults.y, -1000000, 1000000)
    intake.z = math.floor(Util.numberOr(intake.z, defaults.z, -32, 32))
    intake.open = Util.booleanOr(intake.open, defaults.open)
    intake.broken = Util.booleanOr(intake.broken, defaults.broken)
    intake.condition = Util.numberOr(intake.condition, intake.broken and 0 or defaults.condition, 0, 1)
    intake.externalContamination = Util.numberOr(intake.externalContamination, 0, 0, 1)
    intake.maximumFlowM3PerMinute = Util.numberOr(intake.maximumFlowM3PerMinute,
        defaults.maximumFlowM3PerMinute, 0, 100000)
    if intake.broken or intake.condition <= 0.05 then intake.status = "failed"
    elseif not intake.open then intake.status = "closed"
    elseif intake.condition < 0.50 then intake.status = "degraded"
    else intake.status = "operational" end
end

function VentilationSimulation.normalize(ventilation)
    local defaults = VentilationSimulation.createDefault()
    if type(ventilation) ~= "table" then return defaults end

    ventilation.enabled = Util.booleanOr(ventilation.enabled, defaults.enabled)
    local legacyMode = ventilation.enabled and "external_filtration" or "off"
    ventilation.requestedMode = Constants.VENTILATION_MODES[ventilation.requestedMode]
        and ventilation.requestedMode or legacyMode
    ventilation.activeMode = Constants.VENTILATION_MODES[ventilation.activeMode]
        and ventilation.activeMode or "off"
    ventilation.reason = type(ventilation.reason) == "string" and ventilation.reason or defaults.reason
    ventilation.powerAllocated = Util.booleanOr(ventilation.powerAllocated, false)
    ventilation.operating = Util.booleanOr(ventilation.operating, false)
    ventilation.condition = Util.numberOr(ventilation.condition, defaults.condition, 0, 1)
    ventilation.fanCondition = Util.numberOr(ventilation.fanCondition, ventilation.condition, 0, 1)
    ventilation.status = Constants.VALID_VENTILATION_STATUS[ventilation.status]
        and ventilation.status or defaults.status
    ventilation.airflowM3PerMinute = Util.numberOr(ventilation.airflowM3PerMinute, 0, 0, 100000)
    ventilation.co2 = Util.numberOr(ventilation.co2, defaults.co2,
        Constants.VENTILATION.MIN_CO2, Constants.VENTILATION.MAX_CO2)
    ventilation.externalContamination = Util.numberOr(ventilation.externalContamination, 0, 0, 1)
    ventilation.internalContamination = Util.numberOr(ventilation.internalContamination, 0, 0, 1)
    ventilation.recirculationUnlocked = Util.booleanOr(ventilation.recirculationUnlocked, defaults.recirculationUnlocked)

    local filter = ensureTable(ventilation, "filterBank")
    local legacyFilter = Util.numberOr(ventilation.filterRemaining, 1, 0, 1)
    filter.remaining = Util.numberOr(filter.remaining, legacyFilter, 0, 1)
    filter.efficiency = Util.numberOr(filter.efficiency, defaults.filterBank.efficiency, 0, 1)
    filter.condition = Util.numberOr(filter.condition, defaults.filterBank.condition, 0, 1)
    filter.bypass = Util.booleanOr(filter.bypass, false)
    filter.fault = type(filter.fault) == "string" and filter.fault or "none"
    ventilation.filterRemaining = filter.remaining

    local intakes = ensureTable(ventilation, "intakes")
    for id, intakeDefault in pairs(defaults.intakes) do
        if type(intakes[id]) ~= "table" then intakes[id] = {} end
        normalizeIntake(intakes[id], intakeDefault)
    end
    for id, intake in pairs(intakes) do
        if defaults.intakes[id] == nil then
            normalizeIntake(intake, defaultIntake(id, intake.x or 0, intake.y or 0, intake.z or 0))
        end
    end

    ventilation.rooms = RoomRegistry.ensureState(ventilation.rooms, Constants.VENTILATION.MIN_CO2)
    local airlock = ensureTable(ventilation, "airlock")
    airlock.active = Util.booleanOr(airlock.active, false)
    airlock.roomId = type(airlock.roomId) == "string" and airlock.roomId or defaults.airlock.roomId
    airlock.remainingMinutes = Util.numberOr(airlock.remainingMinutes, 0, 0, 60)
    airlock.status = type(airlock.status) == "string" and airlock.status or "idle"
    airlock.doorsInterlocked = Util.booleanOr(airlock.doorsInterlocked, true)
    ensureTable(ventilation, "faults")
    local telemetry = ensureTable(ventilation, "telemetry")
    telemetry.activeIntakes = math.floor(Util.numberOr(telemetry.activeIntakes, 0, 0, 1000))
    telemetry.occupiedRooms = math.floor(Util.numberOr(telemetry.occupiedRooms, 0, 0, 1000))
    telemetry.totalOccupants = math.floor(Util.numberOr(telemetry.totalOccupants, 0, 0, 1000))
    telemetry.worstRoomId = type(telemetry.worstRoomId) == "string" and telemetry.worstRoomId or ""
    telemetry.co2TrendPpmPerMinute = Util.numberOr(telemetry.co2TrendPpmPerMinute, 0, -10000, 10000)
    ventilation.powerDemandKw = VentilationSimulation.powerDemand(ventilation.requestedMode)
    return ventilation
end

function VentilationSimulation.powerDemand(mode)
    local rules = Constants.VENTILATION
    if mode == "external_filtration" then return rules.FAN_POWER_EXTERNAL_KW end
    if mode == "internal_recirculation" then return rules.FAN_POWER_RECIRCULATION_KW end
    if mode == "emergency_ventilation" then return rules.FAN_POWER_EMERGENCY_KW end
    return 0
end

function VentilationSimulation.setMode(ventilation, mode)
    if not Constants.VENTILATION_MODES[mode] then return false, "unknown_ventilation_mode" end
    VentilationSimulation.normalize(ventilation)
    if mode == "internal_recirculation" and not ventilation.recirculationUnlocked then
        return false, "recirculation_locked"
    end
    ventilation.requestedMode = mode
    ventilation.enabled = mode ~= "off" and mode ~= "sealed"
    ventilation.powerDemandKw = VentilationSimulation.powerDemand(mode)
    return true
end

function VentilationSimulation.startAirlockPurge(ventilation, roomId)
    VentilationSimulation.normalize(ventilation)
    if ventilation.airlock.active then return false, "airlock_cycle_active" end
    if type(ventilation.rooms[roomId]) ~= "table" then return false, "unknown_room" end
    ventilation.airlock.active = true
    ventilation.airlock.roomId = roomId
    ventilation.airlock.remainingMinutes = Constants.VENTILATION.AIRLOCK_PURGE_MINUTES
    ventilation.airlock.status = "waiting_for_power"
    ventilation.airlock.doorsInterlocked = true
    return true
end

local function activeIntakeSummary(ventilation)
    local count, capacity, contamination = 0, 0, 0
    for _, intake in pairs(ventilation.intakes) do
        if intake.open and not intake.broken and intake.condition > 0.05 then
            local flow = intake.maximumFlowM3PerMinute * intake.condition
            count = count + 1
            capacity = capacity + flow
            contamination = contamination + flow * intake.externalContamination
        end
    end
    return count, capacity, capacity > 0 and contamination / capacity or 0
end

local function requestedFlow(mode)
    local rules = Constants.VENTILATION
    if mode == "external_filtration" then return rules.EXTERNAL_FLOW_M3_PER_MINUTE end
    if mode == "internal_recirculation" then return rules.RECIRCULATION_FLOW_M3_PER_MINUTE end
    if mode == "emergency_ventilation" then return rules.EMERGENCY_FLOW_M3_PER_MINUTE end
    return 0
end

local function selectActiveMode(ventilation, intakeCapacity)
    local requested = ventilation.requestedMode
    if requested == "off" or requested == "sealed" then return requested, "none" end
    if not ventilation.powerAllocated then return "off", "power_shed" end
    if ventilation.fanCondition <= 0.05 or ventilation.condition <= 0.05 then return "off", "fan_failed" end
    if (requested == "external_filtration" or requested == "emergency_ventilation") and intakeCapacity <= 0 then
        if ventilation.recirculationUnlocked then return "internal_recirculation", "no_air_intake" end
        return "sealed", "no_air_intake"
    end
    return requested, "none"
end

local function fallbackRoom(ventilation)
    for _ in pairs(ventilation.rooms) do return end
    ventilation.rooms.legacy_habitat = {
        id="legacy_habitat", label="Bunker", kind="habitable", volumeM3=5000,
        ventWeight=1, leakRate=0.002, sealed=true, occupants=0,
        co2=ventilation.co2, contamination=ventilation.internalContamination,
        airflowM3PerMinute=0, status="operational",
    }
end

local function applyConnectionMixing(ventilation, deltaMinutes)
    local processed = {}
    for _, definition in ipairs(RoomRegistry.all()) do
        local left = ventilation.rooms[definition.id]
        if left then
            for _, otherId in ipairs(definition.connections or {}) do
                local key = definition.id < otherId and definition.id .. ":" .. otherId or otherId .. ":" .. definition.id
                local right = ventilation.rooms[otherId]
                if right and not processed[key] then
                    processed[key] = true
                    local fraction = math.min(0.25, Constants.VENTILATION.ROOM_MIX_FRACTION_PER_MINUTE * deltaMinutes)
                    local co2Delta = (right.co2 - left.co2) * fraction
                    local contaminationDelta = (right.contamination - left.contamination) * fraction
                    left.co2 = left.co2 + co2Delta
                    right.co2 = right.co2 - co2Delta
                    left.contamination = left.contamination + contaminationDelta
                    right.contamination = right.contamination - contaminationDelta
                end
            end
        end
    end
end

function VentilationSimulation.update(ventilation, deltaMinutes, context)
    VentilationSimulation.normalize(ventilation)
    fallbackRoom(ventilation)
    deltaMinutes = Util.numberOr(deltaMinutes, 1, 0, 60)
    context = type(context) == "table" and context or {}
    local rules = Constants.VENTILATION
    local oldStatus, oldFilter = ventilation.status, ventilation.filterBank.remaining
    local oldCo2 = ventilation.co2
    local storedOutside = ventilation.externalContamination

    local occupancy = type(context.occupancyByRoom) == "table" and context.occupancyByRoom or {}
    for id, room in pairs(ventilation.rooms) do
        room.occupants = math.max(0, math.floor(Util.numberOr(occupancy[id], room.occupants or 0, 0, 1000)))
    end
    if type(context.intakeContamination) == "table" then
        for id, value in pairs(context.intakeContamination) do
            if ventilation.intakes[id] then
                ventilation.intakes[id].externalContamination = Util.numberOr(value, 0, 0, 1)
            end
        end
    end

    local intakeCount, intakeCapacity, outside = activeIntakeSummary(ventilation)
    if context.externalContamination ~= nil then outside = Util.numberOr(context.externalContamination, outside, 0, 1) end
    if context.externalContamination == nil and type(context.intakeContamination) ~= "table" then outside = storedOutside end
    ventilation.externalContamination = outside
    ventilation.activeMode, ventilation.reason = selectActiveMode(ventilation, intakeCapacity)
    ventilation.operating = ventilation.activeMode ~= "off" and ventilation.activeMode ~= "sealed"

    local flow = requestedFlow(ventilation.activeMode) * ventilation.fanCondition * ventilation.condition
    if ventilation.activeMode == "external_filtration" or ventilation.activeMode == "emergency_ventilation" then
        flow = math.min(flow, intakeCapacity)
    end
    ventilation.airflowM3PerMinute = math.max(0, flow)

    local totalWeight = 0
    for _, room in pairs(ventilation.rooms) do totalWeight = totalWeight + math.max(0, room.ventWeight or 0) end
    if totalWeight <= 0 then totalWeight = 1 end

    local filter = ventilation.filterBank
    local filterEffective = filter.remaining > 0 and not filter.bypass and filter.condition > 0.05
    local efficiency = filterEffective and filter.efficiency * filter.condition or 0
    local capturedLoad = 0
    local totalVolume, weightedCo2, weightedContamination = 0, 0, 0
    local totalOccupants, occupiedRooms, worstRoomId, worstScore = 0, 0, "", -1

    for id, room in pairs(ventilation.rooms) do
        local volume = math.max(1, room.volumeM3)
        local roomFlow = ventilation.airflowM3PerMinute * math.max(0, room.ventWeight or 0) / totalWeight
        room.airflowM3PerMinute = roomFlow
        local beforeContamination = room.contamination
        local generatedCo2 = room.occupants * rules.CO2_GENERATION_PPM_M3_PER_PERSON_MINUTE
            / volume * deltaMinutes

        if ventilation.activeMode == "external_filtration" or ventilation.activeMode == "emergency_ventilation" then
            local exchange = math.min(1, roomFlow * deltaMinutes / volume)
            room.co2 = room.co2 + (rules.EXTERNAL_CO2_PPM - room.co2) * exchange
            room.co2 = room.co2 + generatedCo2 * (1 - exchange * 0.5)
            local supplied = outside * (1 - efficiency)
            room.contamination = room.contamination + (supplied - room.contamination) * exchange
            capturedLoad = capturedLoad + outside * efficiency * roomFlow * deltaMinutes
        elseif ventilation.activeMode == "internal_recirculation" then
            room.co2 = room.co2 + generatedCo2
            local passes = math.min(1, roomFlow * deltaMinutes / volume)
            room.contamination = room.contamination * (1 - efficiency * passes)
            capturedLoad = capturedLoad + math.max(0, beforeContamination - room.contamination) * volume
        else
            room.co2 = room.co2 + generatedCo2
            local leak = ventilation.activeMode == "sealed" and rules.SEALED_LEAK_FRACTION_PER_MINUTE
                or math.max(rules.SEALED_LEAK_FRACTION_PER_MINUTE, room.leakRate or 0)
            local exchange = math.min(0.25, leak * deltaMinutes * (room.sealed and 1 or 8))
            room.co2 = room.co2 + (rules.EXTERNAL_CO2_PPM - room.co2) * exchange
            room.contamination = room.contamination + (outside - room.contamination) * exchange
        end

        if ventilation.airlock.active and ventilation.airlock.roomId == id and ventilation.operating then
            local purge = math.min(1, 0.65 * deltaMinutes)
            room.contamination = room.contamination * (1 - purge)
            room.co2 = room.co2 + (rules.EXTERNAL_CO2_PPM - room.co2) * purge
        end

        room.co2 = Util.clamp(room.co2, rules.MIN_CO2, rules.MAX_CO2)
        room.contamination = Util.clamp(room.contamination, 0, 1)
        if room.co2 >= 5000 or room.contamination >= 0.60 then room.status = "uninhabitable"
        elseif room.co2 >= 2500 or room.contamination >= 0.25 then room.status = "emergency"
        elseif room.co2 >= 1200 or room.contamination >= 0.05 then room.status = "degraded"
        else room.status = "operational" end

        totalVolume = totalVolume + volume
        weightedCo2 = weightedCo2 + room.co2 * volume
        weightedContamination = weightedContamination + room.contamination * volume
        totalOccupants = totalOccupants + room.occupants
        if room.occupants > 0 then occupiedRooms = occupiedRooms + 1 end
        local score = room.co2 / 2500 + room.contamination * 4
        if score > worstScore then worstScore, worstRoomId = score, id end
    end

    applyConnectionMixing(ventilation, deltaMinutes)
    if filterEffective and capturedLoad > 0 then
        filter.remaining = math.max(0, filter.remaining - capturedLoad / rules.FILTER_LOAD_CAPACITY)
    end
    ventilation.filterRemaining = filter.remaining
    ventilation.co2 = totalVolume > 0 and weightedCo2 / totalVolume or rules.MIN_CO2
    ventilation.internalContamination = totalVolume > 0 and weightedContamination / totalVolume or 0

    if ventilation.airlock.active then
        if ventilation.operating then
            ventilation.airlock.status = "purging"
            ventilation.airlock.remainingMinutes = math.max(0, ventilation.airlock.remainingMinutes - deltaMinutes)
            if ventilation.airlock.remainingMinutes <= 0 then
                ventilation.airlock.active = false
                ventilation.airlock.status = "complete"
            end
        else
            ventilation.airlock.status = "waiting_for_power"
        end
    end

    if ventilation.condition <= 0.05 or ventilation.fanCondition <= 0.05 then ventilation.status = "failed"
    elseif ventilation.co2 >= 2500 or ventilation.internalContamination >= 0.25 then ventilation.status = "emergency"
    elseif ventilation.reason ~= "none" or filter.remaining < 0.25
        or ventilation.co2 >= 1200 or ventilation.internalContamination >= 0.05 then ventilation.status = "degraded"
    else ventilation.status = "operational" end

    ventilation.telemetry.activeIntakes = intakeCount
    ventilation.telemetry.occupiedRooms = occupiedRooms
    ventilation.telemetry.totalOccupants = totalOccupants
    ventilation.telemetry.worstRoomId = worstRoomId
    ventilation.telemetry.co2TrendPpmPerMinute = deltaMinutes > 0 and (ventilation.co2 - oldCo2) / deltaMinutes or 0
    ventilation.enabled = ventilation.requestedMode ~= "off" and ventilation.requestedMode ~= "sealed"
    ventilation.powerDemandKw = VentilationSimulation.powerDemand(ventilation.requestedMode)

    return {
        statusChanged=oldStatus ~= ventilation.status,
        previousStatus=oldStatus,
        filterExhausted=oldFilter > 0 and filter.remaining <= 0,
        airlockCompleted=not ventilation.airlock.active and ventilation.airlock.status == "complete",
    }
end

BunkerCampaign.VentilationSimulation = VentilationSimulation
return VentilationSimulation
