require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"
require "BunkerCampaign/RoomRegistry"
require "BunkerCampaign/HeatingComponents"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local RoomRegistry = BunkerCampaign.RoomRegistry
local HeatingComponents = BunkerCampaign.HeatingComponents
local HeatingSimulation = {}

local function defaultTelemetry()
    return {
        totalVolumeM3 = 0,
        heatedRoomCount = 0,
        totalRoomCount = 0,
        heatInputKw = 0,
        heatLossKw = 0,
        outsideExchangeM3PerMinute = 0,
        weatherLossMultiplier = 1,
        coldestRoomId = nil,
        coldestTemperature = Constants.HEATING.DEFAULT_ROOM_TEMPERATURE,
        warmestRoomId = nil,
        warmestTemperature = Constants.HEATING.DEFAULT_ROOM_TEMPERATURE,
        distributionEfficiency = 0,
        controllerOnline = false,
        circulationOnline = false,
        activeFailures = 0,
        activeMajorFailures = 0,
    }
end

function HeatingSimulation.createDefault()
    local components = HeatingComponents.createDefaultState()
    local state = {
        enabled = true,
        requested = true,
        operating = false,
        powerAllocated = false,
        status = "offline",
        reason = "not_initialized",
        targetTemperature = Constants.HEATING.DEFAULT_TARGET_TEMPERATURE,
        averageTemperature = Constants.HEATING.DEFAULT_ROOM_TEMPERATURE,
        externalTemperature = Constants.HEATING.DEFAULT_EXTERNAL_TEMPERATURE,
        baseExternalTemperature = Constants.HEATING.DEFAULT_EXTERNAL_TEMPERATURE,
        coldOffset = 0,
        powerDemandKw = Constants.HEATING.STANDBY_POWER_KW,
        fuelAvailable = false,
        components = components,
        manualBypass = false,
        accidents = {
            lastFailureHour = -1000,
            totalFailures = 0,
            activeFailures = 0,
            activeMajorFailures = 0,
        },
        rooms = {},
        telemetry = defaultTelemetry(),
    }
    state.heatExchanger = components.heat_exchanger
    state.pipes = components.pipe_manifold
    return state
end

local function copyMissing(target, defaults)
    local changed = false
    for key, value in pairs(defaults) do
        if target[key] == nil then target[key] = value; changed = true end
    end
    return changed
end

function HeatingSimulation.normalize(heating)
    local defaults = HeatingSimulation.createDefault()
    local legacyExchanger = type(heating.heatExchanger) == "table"
        and heating.heatExchanger or nil
    local legacyPipes = type(heating.pipes) == "table" and heating.pipes or nil
    local hadComponents = type(heating.components) == "table"
    local changed = copyMissing(heating, defaults)
    if type(heating.components) ~= "table" then
        heating.components = HeatingComponents.createDefaultState()
        changed = true
    end
    for _, id in ipairs(HeatingComponents.orderedIds()) do
        if type(heating.components[id]) ~= "table" then
            heating.components[id] = HeatingComponents.createComponentState(
                HeatingComponents.get(id))
            changed = true
        end
        if HeatingComponents.normalizeComponent(id, heating.components[id]) then changed = true end
    end
    if not hadComponents and legacyExchanger then
        local component = heating.components.heat_exchanger
        component.condition = Util.numberOr(legacyExchanger.condition,
            component.condition, 0, 1)
        component.fault = type(legacyExchanger.fault) == "string"
            and legacyExchanger.fault or "none"
        component.outputKw = Util.numberOr(legacyExchanger.outputKw, 0, 0,
            Constants.HEATING.MAX_THERMAL_OUTPUT_KW)
    end
    if not hadComponents and legacyPipes then
        local component = heating.components.pipe_manifold
        component.condition = Util.numberOr(legacyPipes.condition,
            component.condition, 0, 1)
        component.integrity = Util.numberOr(legacyPipes.integrity,
            component.integrity, 0, 1)
        component.fault = type(legacyPipes.fault) == "string"
            and legacyPipes.fault or "none"
    end
    if heating.heatExchanger ~= heating.components.heat_exchanger then
        heating.heatExchanger = heating.components.heat_exchanger
        changed = true
    end
    if heating.pipes ~= heating.components.pipe_manifold then
        heating.pipes = heating.components.pipe_manifold
        changed = true
    end
    if type(heating.accidents) ~= "table" then heating.accidents = {}; changed = true end
    if type(heating.rooms) ~= "table" then heating.rooms = {}; changed = true end
    if type(heating.telemetry) ~= "table" then heating.telemetry = {}; changed = true end

    local values = {
        enabled = Util.booleanOr(heating.enabled, defaults.enabled),
        requested = Util.booleanOr(heating.requested, defaults.requested),
        operating = Util.booleanOr(heating.operating, false),
        powerAllocated = Util.booleanOr(heating.powerAllocated, false),
        targetTemperature = Util.numberOr(heating.targetTemperature,
            defaults.targetTemperature, Constants.HEATING.MIN_TARGET_TEMPERATURE,
            Constants.HEATING.MAX_TARGET_TEMPERATURE),
        averageTemperature = Util.numberOr(heating.averageTemperature,
            defaults.averageTemperature, Constants.HEATING.MIN_TEMPERATURE,
            Constants.HEATING.MAX_TEMPERATURE),
        externalTemperature = Util.numberOr(heating.externalTemperature,
            defaults.externalTemperature, Constants.HEATING.MIN_TEMPERATURE,
            Constants.HEATING.MAX_TEMPERATURE),
        baseExternalTemperature = Util.numberOr(heating.baseExternalTemperature,
            defaults.baseExternalTemperature, Constants.HEATING.MIN_TEMPERATURE,
            Constants.HEATING.MAX_TEMPERATURE),
        coldOffset = Util.numberOr(heating.coldOffset, 0,
            Constants.HEATING.MIN_COLD_OFFSET, Constants.HEATING.MAX_COLD_OFFSET),
        powerDemandKw = Util.numberOr(heating.powerDemandKw, defaults.powerDemandKw,
            0, Constants.HEATING.MAX_POWER_KW),
        fuelAvailable = Util.booleanOr(heating.fuelAvailable, false),
        manualBypass = Util.booleanOr(heating.manualBypass, false),
    }
    values.status = Constants.VALID_HEATING_STATUS[heating.status]
        and heating.status or defaults.status
    values.reason = type(heating.reason) == "string" and heating.reason or defaults.reason
    for key, value in pairs(values) do
        if heating[key] ~= value then heating[key] = value; changed = true end
    end

    local accidents = heating.accidents
    local accidentValues = {
        lastFailureHour=Util.numberOr(accidents.lastFailureHour, -1000, -1000, 1000000000),
        totalFailures=math.floor(Util.numberOr(accidents.totalFailures, 0, 0, 2147483647)),
        activeFailures=math.floor(Util.numberOr(accidents.activeFailures, 0, 0,
            Constants.HEATING.MAX_ACTIVE_FAILURES)),
        activeMajorFailures=math.floor(Util.numberOr(accidents.activeMajorFailures, 0, 0,
            Constants.HEATING.MAX_ACTIVE_MAJOR_FAILURES)),
    }
    for key, value in pairs(accidentValues) do
        if accidents[key] ~= value then accidents[key] = value; changed = true end
    end

    heating.rooms = RoomRegistry.ensureThermalState(
        heating.rooms, heating.averageTemperature, heating.targetTemperature)
    copyMissing(heating.telemetry, defaultTelemetry())
    return changed
end

local function roomVolume(room)
    return math.max(1, tonumber(room and room.volumeM3) or 1)
end

local function roomWeight(room)
    if not room or room.heatingEnabled == false then return 0 end
    return math.max(0, tonumber(room.ventWeight) or 0)
end

local function aggregateTemperatures(heating)
    local volume, weightedTemperature = 0, 0
    local coldestId, coldest = nil, math.huge
    local warmestId, warmest = nil, -math.huge
    local count, heated = 0, 0
    for id, room in pairs(heating.rooms) do
        local roomVolumeM3 = roomVolume(room)
        local temperature = Util.numberOr(room.temperature, heating.averageTemperature,
            Constants.HEATING.MIN_TEMPERATURE, Constants.HEATING.MAX_TEMPERATURE)
        volume = volume + roomVolumeM3
        weightedTemperature = weightedTemperature + temperature * roomVolumeM3
        count = count + 1
        if roomWeight(room) > 0 then heated = heated + 1 end
        if temperature < coldest then coldestId, coldest = id, temperature end
        if temperature > warmest then warmestId, warmest = id, temperature end
    end
    if volume <= 0 then
        return heating.averageTemperature, 0, nil, heating.averageTemperature,
            nil, heating.averageTemperature, 0, 0
    end
    return weightedTemperature / volume, volume, coldestId, coldest,
        warmestId, warmest, count, heated
end

function HeatingSimulation.prepareDemand(heating, context)
    HeatingSimulation.normalize(heating)
    context = type(context) == "table" and context or {}
    heating.externalTemperature = Util.numberOr(context.externalTemperature,
        heating.externalTemperature, Constants.HEATING.MIN_TEMPERATURE,
        Constants.HEATING.MAX_TEMPERATURE)
    heating.baseExternalTemperature = Util.numberOr(context.baseExternalTemperature,
        heating.baseExternalTemperature, Constants.HEATING.MIN_TEMPERATURE,
        Constants.HEATING.MAX_TEMPERATURE)
    heating.coldOffset = Util.numberOr(context.coldOffset, heating.coldOffset,
        Constants.HEATING.MIN_COLD_OFFSET, Constants.HEATING.MAX_COLD_OFFSET)

    local average = aggregateTemperatures(heating)
    heating.averageTemperature = average
    if not heating.enabled or not heating.requested then
        heating.powerDemandKw = 0
        return 0
    end

    -- Reuse The Ark's quadratic demand curve, but keep it bounded in kW and
    -- owned by the server power allocator.
    local difference = math.max(0, heating.targetTemperature - heating.externalTemperature)
    local normalized = math.min(Constants.HEATING.DEMAND_REFERENCE_DELTA, difference)
        / Constants.HEATING.DEMAND_REFERENCE_DELTA
    local demand = Constants.HEATING.STANDBY_POWER_KW
        + (normalized * normalized)
        * (Constants.HEATING.MAX_POWER_KW - Constants.HEATING.STANDBY_POWER_KW)
    if context.entryPath and context.entryPath.breached then
        demand = demand * Constants.HEATING.BREACH_DEMAND_MULTIPLIER
    end
    local ventilation = context.ventilation
    if ventilation and (ventilation.activeMode == "external_filtration"
        or ventilation.activeMode == "emergency_ventilation") then
        demand = demand * Constants.HEATING.OUTSIDE_AIR_DEMAND_MULTIPLIER
    end
    heating.powerDemandKw = Util.clamp(demand,
        Constants.HEATING.STANDBY_POWER_KW, Constants.HEATING.MAX_POWER_KW)
    return heating.powerDemandKw
end

local function isMajorFailure(id, component)
    return component.condition <= Constants.HEATING.FAILED_CONDITION
        or HeatingComponents.faultSeverity(id, component.fault) == "major"
end

local function faultMultiplier(id, component)
    local severity = HeatingComponents.faultSeverity(id, component.fault)
    if severity == "major" then return 0 end
    if severity == "minor" then
        if component.fault == "valve_stuck_open" then return 1 end
        if component.fault == "sensor_drift" then return 0.80 end
        return Constants.HEATING.DEGRADED_COMPONENT_OUTPUT_MULTIPLIER
    end
    return 1
end

local function effectiveValveOpen(component)
    if component.fault == "valve_stuck_closed" then return false end
    if component.fault == "valve_stuck_open" then return true end
    return component.open == true
end

local function circulationState(heating, context)
    local components = heating.components
    local ventilation = type(context.ventilation) == "table" and context.ventilation or {}
    local controllerOnline = not isMajorFailure("controller", components.controller)
    local blowerOnline = not isMajorFailure("circulation_blower", components.circulation_blower)
    local supplyOpen = effectiveValveOpen(components.supply_valve)
    local returnOpen = effectiveValveOpen(components.return_valve)
    local ventilationMode = ventilation.activeMode
    local airflow = tonumber(ventilation.airflowM3PerMinute)
    local ventilationMovingAir = ventilation.operating == true
        and (airflow == nil or airflow > 0.1)
        and (ventilationMode == "external_filtration"
            or ventilationMode == "internal_recirculation"
            or ventilationMode == "emergency_ventilation")
    local normal = controllerOnline and blowerOnline and supplyOpen and returnOpen
        and ventilationMovingAir
    return {
        controllerOnline=controllerOnline,
        blowerOnline=blowerOnline,
        supplyOpen=supplyOpen,
        returnOpen=returnOpen,
        ventilationMovingAir=ventilationMovingAir,
        normal=normal,
    }
end

local function operationalReason(heating, context)
    if not heating.enabled or not heating.requested then return false, "disabled" end
    if not heating.powerAllocated then return false, "power_shed" end
    if isMajorFailure("heat_exchanger", heating.components.heat_exchanger) then
        return false, "heat_exchanger_failed"
    end
    if isMajorFailure("pipe_manifold", heating.components.pipe_manifold)
        or heating.pipes.integrity <= Constants.HEATING.FAILED_CONDITION then
        return false, "pipe_circuit_failed"
    end
    local hasHeatedRoom = false
    for _, room in pairs(heating.rooms) do
        if roomWeight(room) > 0 then hasHeatedRoom = true; break end
    end
    if not hasHeatedRoom then return false, "no_heated_rooms" end
    local circulation = circulationState(heating, context)
    if heating.manualBypass then return true, "manual_bypass" end
    if not circulation.controllerOnline then return false, "controller_failed" end
    if not circulation.normal then return false, "air_circuit_unavailable" end
    if heating.averageTemperature >= heating.targetTemperature - Constants.HEATING.TARGET_DEADBAND then
        return true, "target_reached"
    end
    return true, "heating"
end

local function updateFailureCounts(heating)
    local active, major = 0, 0
    for _, id in ipairs(HeatingComponents.orderedIds()) do
        local component = heating.components[id]
        if component.fault ~= "none" then
            active = active + 1
            if HeatingComponents.faultSeverity(id, component.fault) == "major" then
                major = major + 1
            end
        end
    end
    heating.accidents.activeFailures = active
    heating.accidents.activeMajorFailures = major
    return active, major
end


local function applyWear(heating, deltaMinutes, operating)
    if not operating or deltaMinutes <= 0 then return end
    local stress = 1 + math.max(0, -heating.externalTemperature - 20) / 160
    for _, id in ipairs(HeatingComponents.orderedIds()) do
        local definition = HeatingComponents.get(id)
        local component = heating.components[id]
        local multiplier = component.temporaryRepair
            and Constants.HEATING.TEMPORARY_REPAIR_WEAR_MULTIPLIER or 1
        component.condition = Util.clamp(component.condition
            - definition.wearPerOperatingMinute * deltaMinutes * stress * multiplier, 0, 1)
        if id == "pipe_manifold" and component.fault == "coolant_leak" then
            component.integrity = Util.clamp(component.integrity
                - definition.wearPerOperatingMinute * deltaMinutes * 3, 0, 1)
        end
    end
end


local function failureRoll(context)
    if type(context.failureRoll) == "number" then
        return Util.clamp(context.failureRoll, 0, 1)
    end
    if type(context.failureRoll) == "function" then
        return Util.clamp(tonumber(context.failureRoll()) or 1, 0, 1)
    end
    if type(ZombRand) == "function" then return ZombRand(1000000) / 1000000 end
    return 1
end


local function tryTriggerFailure(heating, context)
    if context.allowHeatingFailures ~= true then return nil end
    local active, major = updateFailureCounts(heating)
    if active >= Constants.HEATING.MAX_ACTIVE_FAILURES then return nil end
    local now = tonumber(context.worldAgeHours) or Util.worldAgeHours()
    if now - heating.accidents.lastFailureHour < Constants.HEATING.FAILURE_COOLDOWN_HOURS then
        return nil
    end
    local candidateId, candidateCondition = nil, math.huge
    for _, id in ipairs(HeatingComponents.orderedIds()) do
        local component = heating.components[id]
        local eligible = heating.operating
            or (id == "pipe_manifold"
                and heating.averageTemperature <= Constants.HEATING.UNINHABITABLE_TEMPERATURE)
        if eligible and component.fault == "none" and component.condition < candidateCondition then
            candidateId, candidateCondition = id, component.condition
        end
    end
    if not candidateId then return nil end
    local coldStress = math.max(0, -heating.externalTemperature - 30) / 70
    local conditionStress = math.max(0, 0.75 - candidateCondition) * 8
    local loadStress = heating.powerDemandKw / math.max(0.01, Constants.HEATING.MAX_POWER_KW)
    local chance = Constants.HEATING.BASE_FAILURE_CHANCE_PER_MINUTE
        * (1 + coldStress + conditionStress + loadStress)
    chance = math.min(Constants.HEATING.MAX_FAILURE_CHANCE_PER_MINUTE, chance)
    if failureRoll(context) >= chance then return nil end
    local definition = HeatingComponents.get(candidateId)
    local severity = candidateCondition <= 0.25
        and major < Constants.HEATING.MAX_ACTIVE_MAJOR_FAILURES and "major" or "minor"
    local fault = definition.faults[severity]
    local component = heating.components[candidateId]
    component.fault = fault
    component.diagnosed = false
    if fault == "valve_stuck_closed" then component.open = false end
    heating.accidents.lastFailureHour = now
    heating.accidents.totalFailures = heating.accidents.totalFailures + 1
    updateFailureCounts(heating)
    return { componentId=candidateId, fault=fault, severity=severity }
end

local function roomLossMultiplier(room, context)
    local multiplier = 1
    if room.kind == "airlock" then multiplier = multiplier * 2.5
    elseif room.kind == "technical" then multiplier = multiplier * 1.35
    elseif room.kind == "circulation" then multiplier = multiplier * 1.20 end
    if room.sealed == false then multiplier = multiplier * 1.8 end
    if context.entryPath and context.entryPath.breached
        and (room.kind == "airlock" or room.id == "entrance"
            or room.id == "decontamination_chamber") then
        multiplier = multiplier * Constants.HEATING.BREACH_LOSS_MULTIPLIER
    end
    return multiplier
end

local function mixConnectedRooms(rooms, deltas)
    local seen = {}
    for id, room in pairs(rooms) do
        for _, otherId in ipairs(type(room.connections) == "table" and room.connections or {}) do
            local other = rooms[otherId]
            local key = id < tostring(otherId) and id .. ":" .. tostring(otherId)
                or tostring(otherId) .. ":" .. id
            if other and not seen[key] then
                seen[key] = true
                local leftVolume, rightVolume = roomVolume(room), roomVolume(other)
                local difference = (other.temperature or 0) - (room.temperature or 0)
                local exchange = difference * Constants.HEATING.ROOM_MIX_FRACTION_PER_MINUTE
                local total = leftVolume + rightVolume
                deltas[id] = (deltas[id] or 0) + exchange * rightVolume / total
                deltas[otherId] = (deltas[otherId] or 0) - exchange * leftVolume / total
            end
        end
    end
end

function HeatingSimulation.update(heating, deltaMinutes, context)
    HeatingSimulation.normalize(heating)
    deltaMinutes = math.max(0, tonumber(deltaMinutes) or 0)
    context = type(context) == "table" and context or {}
    HeatingSimulation.prepareDemand(heating, context)

    local previousStatus = heating.status
    local operating, reason = operationalReason(heating, context)
    heating.operating = operating
    heating.reason = reason
    heating.fuelAvailable = context.fuelAvailable == true

    local circulation = circulationState(heating, context)
    local distributionEfficiency = circulation.normal and 1
        or (heating.manualBypass and Constants.HEATING.MANUAL_BYPASS_OUTPUT_MULTIPLIER or 0)
    local efficiency = heating.heatExchanger.condition
        * heating.pipes.condition * heating.pipes.integrity
        * (0.5 + 0.5 * heating.components.circulation_blower.condition)
        * faultMultiplier("heat_exchanger", heating.components.heat_exchanger)
        * faultMultiplier("pipe_manifold", heating.components.pipe_manifold)
        * faultMultiplier("circulation_blower", heating.components.circulation_blower)
        * faultMultiplier("controller", heating.components.controller)
    local thermalOutput = operating and heating.powerDemandKw
        * Constants.HEATING.THERMAL_OUTPUT_PER_POWER_KW * efficiency
        * distributionEfficiency or 0
    if reason == "target_reached" then thermalOutput = 0 end
    heating.heatExchanger.outputKw = Util.clamp(thermalOutput, 0,
        Constants.HEATING.MAX_THERMAL_OUTPUT_KW)

    local average, totalVolume, coldestId, coldest, warmestId, warmest,
        roomCount, heatedCount = aggregateTemperatures(heating)
    heating.averageTemperature = average
    local totalWeight = 0
    for _, room in pairs(heating.rooms) do totalWeight = totalWeight + roomWeight(room) end

    local ventilation = context.ventilation or {}
    local outsideExchange = tonumber(ventilation.telemetry
        and ventilation.telemetry.outsideExchangeM3PerMinute) or 0
    local wind = Util.clamp(tonumber(context.windIntensity) or 0, 0, 1)
    local precipitation = Util.clamp(tonumber(context.precipitationIntensity) or 0, 0, 1)
    local weatherMultiplier = 1 + wind * Constants.HEATING.WIND_LOSS_MULTIPLIER
        + precipitation * Constants.HEATING.PRECIPITATION_LOSS_MULTIPLIER
    local outsideExchangeFraction = totalVolume > 0
        and math.min(Constants.HEATING.MAX_OUTSIDE_EXCHANGE_FRACTION_PER_MINUTE,
            outsideExchange / totalVolume) or 0

    local deltas = {}
    local totalLossKw = 0
    local totalInputKw = 0
    for id, room in pairs(heating.rooms) do
        room.targetTemperature = heating.targetTemperature
        local volume = roomVolume(room)
        local lossMultiplier = roomLossMultiplier(room, context) * weatherMultiplier
        local temperatureDifference = heating.externalTemperature - room.temperature
        local lossFraction = Constants.HEATING.BASE_LOSS_FRACTION_PER_MINUTE * lossMultiplier
        if roomWeight(room) > 0 and totalWeight > 0 then
            lossFraction = lossFraction + outsideExchangeFraction
        end
        local lossDelta = temperatureDifference * lossFraction * deltaMinutes
        deltas[id] = (deltas[id] or 0) + lossDelta
        room.heatLossKw = math.abs(lossDelta) * volume
            * Constants.HEATING.THERMAL_MASS_KWH_PER_M3_C * 60
            / math.max(deltaMinutes, 1)
        totalLossKw = totalLossKw + room.heatLossKw

        local weight = roomWeight(room)
        local inputKw = totalWeight > 0 and thermalOutput * weight / totalWeight or 0
        room.heatInputKw = inputKw
        totalInputKw = totalInputKw + inputKw
        if inputKw > 0 and deltaMinutes > 0 then
            local heatDelta = inputKw * (deltaMinutes / 60)
                / (volume * Constants.HEATING.THERMAL_MASS_KWH_PER_M3_C)
            if room.temperature >= room.targetTemperature then heatDelta = 0 end
            deltas[id] = (deltas[id] or 0) + heatDelta
        end
    end

    if deltaMinutes > 0 then mixConnectedRooms(heating.rooms, deltas) end
    for id, room in pairs(heating.rooms) do
        local maximumChange = Constants.HEATING.MAX_TEMPERATURE_CHANGE_PER_MINUTE
            * deltaMinutes
        local change = Util.clamp(deltas[id] or 0, -maximumChange, maximumChange)
        room.temperature = Util.clamp(room.temperature + change,
            Constants.HEATING.MIN_TEMPERATURE, Constants.HEATING.MAX_TEMPERATURE)
        if room.temperature <= Constants.HEATING.UNINHABITABLE_TEMPERATURE then
            room.status = "uninhabitable"
        elseif room.temperature <= Constants.HEATING.EMERGENCY_TEMPERATURE then
            room.status = "emergency"
        elseif room.temperature <= Constants.HEATING.DEGRADED_TEMPERATURE then
            room.status = "degraded"
        else
            room.status = "operational"
        end
    end

    average, totalVolume, coldestId, coldest, warmestId, warmest,
        roomCount, heatedCount = aggregateTemperatures(heating)
    heating.averageTemperature = average
    applyWear(heating, deltaMinutes, operating and thermalOutput > 0)
    local failure = tryTriggerFailure(heating, context)
    local activeFailures, activeMajorFailures = updateFailureCounts(heating)
    if not heating.enabled or not heating.requested then
        heating.status = average <= Constants.HEATING.EMERGENCY_TEMPERATURE
            and "emergency" or "offline"
    elseif not operating then
        heating.status = average <= Constants.HEATING.EMERGENCY_TEMPERATURE
            and "emergency" or "failed"
    elseif average <= Constants.HEATING.EMERGENCY_TEMPERATURE then
        heating.status = "emergency"
    elseif average <= Constants.HEATING.DEGRADED_TEMPERATURE
        or efficiency < Constants.HEATING.DEGRADED_CONDITION then
        heating.status = "degraded"
    else
        heating.status = "operational"
    end

    heating.telemetry = {
        totalVolumeM3 = totalVolume,
        heatedRoomCount = heatedCount,
        totalRoomCount = roomCount,
        heatInputKw = totalInputKw,
        heatLossKw = totalLossKw,
        outsideExchangeM3PerMinute = outsideExchange,
        weatherLossMultiplier = weatherMultiplier,
        coldestRoomId = coldestId,
        coldestTemperature = coldest,
        warmestRoomId = warmestId,
        warmestTemperature = warmest,
        distributionEfficiency = distributionEfficiency,
        controllerOnline = circulation.controllerOnline,
        circulationOnline = circulation.normal,
        activeFailures = activeFailures,
        activeMajorFailures = activeMajorFailures,
    }
    return {
        statusChanged = previousStatus ~= heating.status,
        previousStatus = previousStatus,
        failure = failure,
    }
end

function HeatingSimulation.setTarget(heating, value)
    if not Util.isFiniteNumber(value) then return false, "invalid_temperature" end
    heating.targetTemperature = Util.clamp(value,
        Constants.HEATING.MIN_TARGET_TEMPERATURE,
        Constants.HEATING.MAX_TARGET_TEMPERATURE)
    return true
end

function HeatingSimulation.setRoomEnabled(heating, roomId, enabled)
    if type(roomId) ~= "string" or type(enabled) ~= "boolean" then
        return false, "invalid_payload"
    end
    local room = heating.rooms and heating.rooms[roomId]
    if not room then return false, "unknown_room" end
    if #(type(room.vents) == "table" and room.vents or {}) == 0 then
        return false, "room_has_no_heating_vents"
    end
    room.heatingEnabled = enabled
    return true
end

function HeatingSimulation.controllerOperational(heating)
    HeatingSimulation.normalize(heating)
    return not isMajorFailure("controller", heating.components.controller)
end

function HeatingSimulation.setValve(heating, componentId, open)
    HeatingSimulation.normalize(heating)
    local definition = HeatingComponents.get(componentId)
    local component = heating.components[componentId]
    if not definition or definition.role ~= "valve" or not component then
        return false, "unknown_heating_valve"
    end
    if type(open) ~= "boolean" then return false, "invalid_payload" end
    if component.fault == "valve_stuck_closed" or component.fault == "valve_stuck_open" then
        return false, "heating_valve_stuck"
    end
    if component.open == open then return true, "unchanged" end
    component.open = open
    return true
end

function HeatingSimulation.setManualBypass(heating, enabled)
    HeatingSimulation.normalize(heating)
    if type(enabled) ~= "boolean" then return false, "invalid_payload" end
    if heating.manualBypass == enabled then return true, "unchanged" end
    heating.manualBypass = enabled
    return true
end

function HeatingSimulation.diagnoseComponent(heating, componentId)
    HeatingSimulation.normalize(heating)
    local component = heating.components[componentId]
    if not component or not HeatingComponents.get(componentId) then
        return false, "unknown_heating_component"
    end
    component.diagnosed = true
    return true, component.fault
end

function HeatingSimulation.repairComponent(heating, componentId, mode, improvement)
    HeatingSimulation.normalize(heating)
    local component = heating.components[componentId]
    if not component or not HeatingComponents.get(componentId) then
        return false, "unknown_heating_component"
    end
    mode = mode == "temporary" and "temporary" or mode == "full" and "full" or nil
    if not mode then return false, "invalid_repair_mode" end
    if component.fault == "none" and component.condition >= (mode == "full" and 0.90 or 0.40)
        and (component.integrity == nil or component.integrity >= 0.90) then
        return false, "repair_not_needed"
    end
    if mode == "temporary" then
        component.condition = math.max(component.condition, 0.35)
        if component.integrity ~= nil then component.integrity = math.max(component.integrity, 0.30) end
        component.temporaryRepair = true
    else
        improvement = Util.clamp(tonumber(improvement) or 0.25, 0.15, 0.45)
        component.condition = math.min(0.95, math.max(0.55, component.condition + improvement))
        if component.integrity ~= nil then
            component.integrity = math.min(0.95,
                math.max(0.60, component.integrity + improvement))
        end
        component.temporaryRepair = false
    end
    component.fault = "none"
    component.diagnosed = false
    updateFailureCounts(heating)
    return true
end

function HeatingSimulation.triggerFault(heating, componentId, severityOrFault, worldAgeHours)
    HeatingSimulation.normalize(heating)
    local definition = HeatingComponents.get(componentId)
    local component = heating.components[componentId]
    if not definition or not component then return false, "unknown_heating_component" end
    if component.fault ~= "none" then return false, "component_already_faulted" end
    local fault = severityOrFault == "minor" and definition.faults.minor
        or severityOrFault == "major" and definition.faults.major or severityOrFault
    if fault ~= definition.faults.minor and fault ~= definition.faults.major then
        return false, "invalid_heating_fault"
    end
    local active, major = updateFailureCounts(heating)
    local severity = HeatingComponents.faultSeverity(componentId, fault)
    if active >= Constants.HEATING.MAX_ACTIVE_FAILURES then
        return false, "too_many_active_heating_failures"
    end
    if severity == "major" and major >= Constants.HEATING.MAX_ACTIVE_MAJOR_FAILURES then
        return false, "major_heating_failure_already_active"
    end
    component.fault = fault
    component.diagnosed = false
    if fault == "valve_stuck_closed" then component.open = false end
    heating.accidents.lastFailureHour = tonumber(worldAgeHours) or Util.worldAgeHours()
    heating.accidents.totalFailures = heating.accidents.totalFailures + 1
    updateFailureCounts(heating)
    return true, fault
end

BunkerCampaign.HeatingSimulation = HeatingSimulation
return HeatingSimulation
