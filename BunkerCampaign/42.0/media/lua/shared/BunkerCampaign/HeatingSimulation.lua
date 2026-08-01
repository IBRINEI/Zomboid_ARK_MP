require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"
require "BunkerCampaign/RoomRegistry"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local RoomRegistry = BunkerCampaign.RoomRegistry
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
    }
end

function HeatingSimulation.createDefault()
    return {
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
        heatExchanger = {
            condition = 0.82,
            fault = "none",
            outputKw = 0,
        },
        pipes = {
            condition = 0.86,
            integrity = 0.90,
            fault = "none",
        },
        rooms = {},
        telemetry = defaultTelemetry(),
    }
end

local function copyMissing(target, defaults)
    local changed = false
    for key, value in pairs(defaults) do
        if target[key] == nil then target[key] = value; changed = true end
    end
    return changed
end

local function normalizeFault(value)
    return type(value) == "string" and value ~= "" and value or "none"
end

function HeatingSimulation.normalize(heating)
    local defaults = HeatingSimulation.createDefault()
    local changed = copyMissing(heating, defaults)
    if type(heating.heatExchanger) ~= "table" then heating.heatExchanger = {}; changed = true end
    if type(heating.pipes) ~= "table" then heating.pipes = {}; changed = true end
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
    }
    values.status = Constants.VALID_HEATING_STATUS[heating.status]
        and heating.status or defaults.status
    values.reason = type(heating.reason) == "string" and heating.reason or defaults.reason
    for key, value in pairs(values) do
        if heating[key] ~= value then heating[key] = value; changed = true end
    end

    local exchanger = heating.heatExchanger
    local exchangerValues = {
        condition = Util.numberOr(exchanger.condition, defaults.heatExchanger.condition, 0, 1),
        outputKw = Util.numberOr(exchanger.outputKw, 0, 0, Constants.HEATING.MAX_THERMAL_OUTPUT_KW),
        fault = normalizeFault(exchanger.fault),
    }
    for key, value in pairs(exchangerValues) do
        if exchanger[key] ~= value then exchanger[key] = value; changed = true end
    end

    local pipes = heating.pipes
    local pipeValues = {
        condition = Util.numberOr(pipes.condition, defaults.pipes.condition, 0, 1),
        integrity = Util.numberOr(pipes.integrity, defaults.pipes.integrity, 0, 1),
        fault = normalizeFault(pipes.fault),
    }
    for key, value in pairs(pipeValues) do
        if pipes[key] ~= value then pipes[key] = value; changed = true end
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

local function operationalReason(heating)
    if not heating.enabled or not heating.requested then return false, "disabled" end
    if not heating.powerAllocated then return false, "power_shed" end
    if heating.heatExchanger.condition <= Constants.HEATING.FAILED_CONDITION
        or heating.heatExchanger.fault ~= "none" then return false, "heat_exchanger_failed" end
    if heating.pipes.condition <= Constants.HEATING.FAILED_CONDITION
        or heating.pipes.integrity <= Constants.HEATING.FAILED_CONDITION
        or heating.pipes.fault ~= "none" then return false, "pipe_circuit_failed" end
    local hasHeatedRoom = false
    for _, room in pairs(heating.rooms) do
        if roomWeight(room) > 0 then hasHeatedRoom = true; break end
    end
    if not hasHeatedRoom then return false, "no_heated_rooms" end
    if heating.averageTemperature >= heating.targetTemperature - Constants.HEATING.TARGET_DEADBAND then
        return true, "target_reached"
    end
    return true, "heating"
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
    local operating, reason = operationalReason(heating)
    heating.operating = operating
    heating.reason = reason
    heating.fuelAvailable = context.fuelAvailable == true

    local efficiency = heating.heatExchanger.condition
        * heating.pipes.condition * heating.pipes.integrity
    local thermalOutput = operating and heating.powerDemandKw
        * Constants.HEATING.THERMAL_OUTPUT_PER_POWER_KW * efficiency or 0
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
    }
    return {
        statusChanged = previousStatus ~= heating.status,
        previousStatus = previousStatus,
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

BunkerCampaign.HeatingSimulation = HeatingSimulation
return HeatingSimulation
