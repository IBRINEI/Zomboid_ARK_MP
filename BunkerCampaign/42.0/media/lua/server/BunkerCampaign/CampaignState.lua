if isClient() then return end

require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"
require "BunkerCampaign/StateSchema"
require "BunkerCampaign/PowerSimulation"
require "BunkerCampaign/VentilationSimulation"
require "BunkerCampaign/WaterSimulation"
require "BunkerCampaign/RoomRegistry"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local StateSchema = BunkerCampaign.StateSchema
local PowerSimulation = BunkerCampaign.PowerSimulation
local VentilationSimulation = BunkerCampaign.VentilationSimulation
local WaterSimulation = BunkerCampaign.WaterSimulation
local RoomRegistry = BunkerCampaign.RoomRegistry
local CampaignState = {
    data = nil,
    minutesSinceSync = 0,
    deferBroadcast = false,
    broadcastPending = false,
    powerListeners = {},
    lifeSupportListeners = {
        sample = {},
        postPower = {},
        postSimulation = {},
    },
}

local function trimAuditLog(log)
    while #log > Constants.MAX_AUDIT_LOG_ENTRIES do
        table.remove(log, 1)
    end
end

function CampaignState.appendLog(category, message, actor)
    if not CampaignState.data then return end

    local state = CampaignState.data
    local entry = {
        id = state.nextAuditLogId,
        worldAgeHours = Util.worldAgeHours(),
        category = tostring(category or "system"),
        message = tostring(message or ""),
        actor = tostring(actor or "system"),
    }
    state.nextAuditLogId = state.nextAuditLogId + 1
    table.insert(state.auditLog, entry)
    trimAuditLog(state.auditLog)
    print("[BunkerCampaign][" .. entry.category .. "] " .. entry.message .. " actor=" .. entry.actor)
end

function CampaignState.touch()
    local state = CampaignState.data
    state.revision = state.revision + 1
    state.lastUpdatedWorldAgeHours = Util.worldAgeHours()
end

function CampaignState.initialize(isNewGame)
    local state = ModData.getOrCreate(Constants.STATE_KEY)
    local changed, changes = StateSchema.prepare(state, isNewGame)
    CampaignState.data = state

    PowerSimulation.update(state.bunker.modules.power, 0)
    local consumers = state.bunker.modules.power.consumers
    local ventilation = state.bunker.modules.ventilation
    local water = state.bunker.modules.water
    ventilation.powerAllocated = consumers.ventilation.allocated
    VentilationSimulation.update(ventilation, 0)
    water.requested = consumers.water.requested
    water.pumpRequested = water.requested
    water.powerAllocated = consumers.water.allocated

    for _, message in ipairs(changes) do
        CampaignState.appendLog("migration", message, "server")
    end
    if changed then CampaignState.touch() end

    print("[BunkerCampaign] state ready version=" .. tostring(state.version) .. " revision=" .. tostring(state.revision))
end

function CampaignState.get()
    return CampaignState.data
end

function CampaignState.addPowerListener(listener)
    if type(listener) ~= "function" then return end
    for _, current in ipairs(CampaignState.powerListeners) do
        if current == listener then return end
    end
    CampaignState.powerListeners[#CampaignState.powerListeners + 1] = listener
end

function CampaignState.addLifeSupportListener(phase, listener)
    local listeners = CampaignState.lifeSupportListeners[phase]
    if type(listeners) ~= "table" or type(listener) ~= "function" then return false end
    for _, current in ipairs(listeners) do if current == listener then return true end end
    listeners[#listeners + 1] = listener
    return true
end

local function notifyLifeSupportListeners(phase, context)
    for _, listener in ipairs(CampaignState.lifeSupportListeners[phase] or {}) do
        local ok, message = pcall(listener, CampaignState.data, context)
        if not ok then
            print("[BunkerCampaign][life-support] " .. tostring(phase) .. " listener failed: " .. tostring(message))
        end
    end
end

local function notifyPowerListeners()
    for _, listener in ipairs(CampaignState.powerListeners) do
        local ok, message = pcall(listener, CampaignState.data.bunker.modules.power)
        if not ok then print("[BunkerCampaign][power] adapter listener failed: " .. tostring(message)) end
    end
end

local function copyAuditTail(log)
    local result = {}
    local first = math.max(1, #log - Constants.CLIENT_AUDIT_LOG_ENTRIES + 1)
    for index = first, #log do
        local entry = log[index]
        result[#result + 1] = {
            id = entry.id,
            worldAgeHours = entry.worldAgeHours,
            category = entry.category,
            message = entry.message,
            actor = entry.actor,
        }
    end
    return result
end

function CampaignState.snapshot()
    local state = CampaignState.data
    if not state then return nil end
    local ventilation = state.bunker.modules.ventilation
    local water = state.bunker.modules.water
    local power = state.bunker.modules.power

    local generatorSnapshot = {}
    for id, generator in pairs(power.generators) do
        generatorSnapshot[id] = {
            requested = generator.requested,
            running = generator.running,
            status = generator.status,
            fuel = generator.fuel,
            condition = generator.condition,
            coolant = generator.coolant,
            lubricant = generator.lubricant,
            maxOutputKw = generator.maxOutputKw,
            availableKw = generator.availableKw,
            loadKw = generator.loadKw,
        }
    end
    local consumerSnapshot = {}
    for id, consumer in pairs(power.consumers) do
        consumerSnapshot[id] = {
            requested = consumer.requested,
            demandKw = consumer.demandKw,
            priority = consumer.priority,
            batteryEligible = consumer.batteryEligible,
            allocated = consumer.allocated,
            source = consumer.source,
        }
    end
    local roomSnapshot = {}
    for id, room in pairs(ventilation.rooms or {}) do
        roomSnapshot[id] = {
            id=id, label=room.label, kind=room.kind, volumeM3=room.volumeM3,
            bounds=room.bounds, regions=room.regions, footprintArea=room.footprintArea,
            connections=room.connections,
            occupants=room.occupants, sealed=room.sealed, co2=room.co2,
            contamination=room.contamination, airflowM3PerMinute=room.airflowM3PerMinute,
            status=room.status,
        }
    end
    local intakeSnapshot = {}
    for id, intake in pairs(ventilation.intakes or {}) do
        intakeSnapshot[id] = {
            id=id, x=intake.x, y=intake.y, z=intake.z, open=intake.open,
            broken=intake.broken, condition=intake.condition,
            externalContamination=intake.externalContamination,
            maximumFlowM3PerMinute=intake.maximumFlowM3PerMinute,
            status=intake.status,
        }
    end
    local sourceSnapshot = {}
    for id, source in pairs(water.sources or {}) do
        sourceSnapshot[id] = {
            id=id, kind=source.kind, enabled=source.enabled,
            availableLiters=source.availableLiters, renewable=source.renewable,
            contamination=source.contamination, maximumFlowLpm=source.maximumFlowLpm,
            status=source.status,
        }
    end

    return {
        version = state.version,
        campaignId = state.campaignId,
        revision = state.revision,
        lastUpdatedWorldAgeHours = state.lastUpdatedWorldAgeHours,
        power = {
            status = power.status,
            gridOnline = power.gridOnline,
            emergencyMode = power.emergencyMode,
            availableCapacityKw = power.availableCapacityKw,
            demandKw = power.demandKw,
            allocatedKw = power.allocatedKw,
            shedKw = power.shedKw,
            battery = {
                charge = power.battery.charge,
                capacityKwh = power.battery.capacityKwh,
                outputKw = power.battery.outputKw,
                chargingKw = power.battery.chargingKw,
            },
            generators = generatorSnapshot,
            consumers = consumerSnapshot,
        },
        ventilation = {
            enabled = ventilation.enabled,
            requestedMode = ventilation.requestedMode,
            activeMode = ventilation.activeMode,
            reason = ventilation.reason,
            powerAllocated = ventilation.powerAllocated,
            operating = ventilation.operating,
            condition = ventilation.condition,
            fanCondition = ventilation.fanCondition,
            status = ventilation.status,
            powerDemandKw = ventilation.powerDemandKw,
            airflowM3PerMinute = ventilation.airflowM3PerMinute,
            filterRemaining = ventilation.filterRemaining,
            filterBank = {
                remaining=ventilation.filterBank.remaining,
                efficiency=ventilation.filterBank.efficiency,
                condition=ventilation.filterBank.condition,
                bypass=ventilation.filterBank.bypass,
                fault=ventilation.filterBank.fault,
            },
            co2 = ventilation.co2,
            externalContamination = ventilation.externalContamination,
            internalContamination = ventilation.internalContamination,
            recirculationUnlocked = ventilation.recirculationUnlocked,
            intakes = intakeSnapshot,
            rooms = roomSnapshot,
            airlock = {
                active=ventilation.airlock.active,
                roomId=ventilation.airlock.roomId,
                remainingMinutes=ventilation.airlock.remainingMinutes,
                durationMinutes=ventilation.airlock.durationMinutes,
                status=ventilation.airlock.status,
                doorsInterlocked=ventilation.airlock.doorsInterlocked,
            },
            entryPath = ventilation.entryPath,
            telemetry = ventilation.telemetry,
        },
        water = {
            adapterOnline = water.adapterOnline,
            pumpActive = water.pumpActive,
            pumpRequested = water.pumpRequested,
            requested = water.requested,
            powerAllocated = water.powerAllocated,
            physicallyAvailable = water.physicallyAvailable,
            operating = water.operating,
            pumpCondition = water.pumpCondition,
            status = water.status,
            reason = water.reason,
            filterRemaining = water.filterRemaining,
            stored = water.stored,
            capacity = water.capacity,
            contamination = water.contamination,
            flowPerMinute = water.flowPerMinute,
            powerDemandKw = water.powerDemandKw,
            source = water.source,
            selectedSource = water.selectedSource,
            sources = sourceSnapshot,
            pump = water.pump,
            treatment = water.treatment,
            storage = water.storage,
            telemetry = water.telemetry,
        },
        auditLog = copyAuditTail(state.auditLog),
    }
end

local function applyPowerOutputs()
    local modules = CampaignState.data.bunker.modules
    local consumers = modules.power.consumers
    modules.ventilation.powerAllocated = consumers.ventilation.allocated
    modules.water.requested = consumers.water.requested
    modules.water.pumpRequested = modules.water.requested
    modules.water.powerAllocated = consumers.water.allocated
end

function CampaignState.recalculatePower(deltaMinutes, actor)
    if not CampaignState.data then return nil end
    local power = CampaignState.data.bunker.modules.power
    local events = PowerSimulation.update(power, deltaMinutes or 0)
    applyPowerOutputs()
    VentilationSimulation.update(CampaignState.data.bunker.modules.ventilation, 0)
    notifyPowerListeners()
    if events.statusChanged then
        CampaignState.appendLog("power", "status changed " .. tostring(events.previousStatus) .. " -> " .. tostring(power.status), actor or "server")
    end
    return events
end

function CampaignState.setGeneratorRequested(generatorId, requested, actor)
    if type(requested) ~= "boolean" then return false, "requested must be boolean" end
    local power = CampaignState.data and CampaignState.data.bunker.modules.power
    local generator = power and power.generators[generatorId]
    if not generator then return false, "unknown_generator" end
    if generator.requested == requested then return true, "unchanged" end

    generator.requested = requested
    CampaignState.recalculatePower(0, actor)
    CampaignState.touch()
    CampaignState.appendLog("power", tostring(generatorId) .. (requested and " generator start requested" or " generator stop requested"), actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.refuelGenerator(generatorId, actor)
    local power = CampaignState.data and CampaignState.data.bunker.modules.power
    local generator = power and power.generators[generatorId]
    if not generator then return false, "unknown_generator" end
    if generator.fuel >= 1 then return true, "unchanged" end

    generator.fuel = 1
    CampaignState.recalculatePower(0, actor)
    CampaignState.touch()
    CampaignState.appendLog("power", tostring(generatorId) .. " generator refueled", actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.setConsumerRequested(consumerId, requested, actor)
    if type(requested) ~= "boolean" then return false, "requested must be boolean" end
    local power = CampaignState.data and CampaignState.data.bunker.modules.power
    local consumer = power and power.consumers[consumerId]
    if not consumer then return false, "unknown_consumer" end
    if consumer.requested == requested then return true, "unchanged" end

    consumer.requested = requested
    if consumerId == "ventilation" then
        local ventilation = CampaignState.data.bunker.modules.ventilation
        VentilationSimulation.setMode(ventilation, requested and "external_filtration" or "off")
        consumer.demandKw = VentilationSimulation.powerDemand(ventilation.requestedMode)
    elseif consumerId == "water" then
        local water = CampaignState.data.bunker.modules.water
        water.requested = requested
        water.pumpRequested = requested
        consumer.demandKw = WaterSimulation.prepareDemand(water)
    end
    CampaignState.recalculatePower(0, actor)
    VentilationSimulation.update(CampaignState.data.bunker.modules.ventilation, 0)
    CampaignState.touch()
    CampaignState.appendLog("power", tostring(consumerId) .. (requested and " power requested" or " power released"), actor)
    CampaignState.broadcast()
    return true
end

local function waterValueChanged(previous, current)
    if type(previous) == "number" and type(current) == "number" then
        return math.abs(previous - current) >= 0.0001
    end
    return previous ~= current
end

function CampaignState.setWaterSnapshot(values, source)
    if type(values) ~= "table" or not CampaignState.data then
        return false, "water snapshot must be a table"
    end

    local water = CampaignState.data.bunker.modules.water
    local previousStatus, previousOnline = water.status, water.adapterOnline
    local previousStored, previousFlow = water.stored, water.flowPerMinute
    local previousPumpCondition, previousFilter = water.pumpCondition, water.filterRemaining
    local previousContamination, previousPumpActive = water.contamination, water.pumpActive
    local physical = values
    if values.cleanStored == nil and values.taintedStored == nil and values.stored ~= nil then
        local capacity = Util.numberOr(values.capacity, 0, 0, Constants.WATER.MAX_STORAGE)
        local stored = math.min(Util.numberOr(values.stored, 0, 0, Constants.WATER.MAX_STORAGE), capacity)
        local contamination = Util.numberOr(values.contamination, 0, 0, 1)
        physical = {}
        for key, value in pairs(values) do physical[key] = value end
        physical.cleanStored = stored * (1 - contamination)
        physical.taintedStored = stored * contamination
    end
    WaterSimulation.update(water, 0, physical)
    local changed = previousStatus ~= water.status or previousOnline ~= water.adapterOnline
        or waterValueChanged(previousStored, water.stored)
        or waterValueChanged(previousFlow, water.flowPerMinute)
        or waterValueChanged(previousPumpCondition, water.pumpCondition)
        or waterValueChanged(previousFilter, water.filterRemaining)
        or waterValueChanged(previousContamination, water.contamination)
        or previousPumpActive ~= water.pumpActive
    if not changed then return true, "unchanged" end

    CampaignState.touch()
    if previousOnline ~= water.adapterOnline then
        CampaignState.appendLog("water", water.adapterOnline and "Waterpipes adapter online" or "Waterpipes adapter offline", source or "server adapter")
    end
    if previousStatus ~= water.status then
        CampaignState.appendLog("water", "status changed " .. tostring(previousStatus) .. " -> " .. tostring(water.status), source or "server adapter")
    end
    CampaignState.broadcast()
    return true
end

function CampaignState.sendToPlayer(player)
    if not CampaignState.data or not isServer() or not player then return end
    sendServerCommand(player, Constants.NETWORK_MODULE, "stateSnapshot", CampaignState.snapshot())
end

function CampaignState.broadcast()
    if not CampaignState.data or not isServer() then return end
    if CampaignState.deferBroadcast then
        CampaignState.broadcastPending = true
        return
    end
    if type(getOnlinePlayers) == "function" then
        local players = getOnlinePlayers()
        if not players or players:size() == 0 then return end
    end
    sendServerCommand(Constants.NETWORK_MODULE, "stateSnapshot", CampaignState.snapshot())
end

function CampaignState.setVentilationEnabled(enabled, actor)
    if type(enabled) ~= "boolean" then return false, "enabled must be boolean" end

    local ventilation = CampaignState.data.bunker.modules.ventilation
    local consumer = CampaignState.data.bunker.modules.power.consumers.ventilation
    if ventilation.enabled == enabled and consumer.requested == enabled then return true, "unchanged" end

    return CampaignState.setConsumerRequested("ventilation", enabled, actor)
end

function CampaignState.setVentilationMode(mode, actor)
    local ventilation = CampaignState.data and CampaignState.data.bunker.modules.ventilation
    if not ventilation then return false, "state_unavailable" end
    local ok, reason = VentilationSimulation.setMode(ventilation, mode)
    if not ok then return false, reason end
    local consumer = CampaignState.data.bunker.modules.power.consumers.ventilation
    consumer.requested = ventilation.powerDemandKw > 0
    consumer.demandKw = ventilation.powerDemandKw
    CampaignState.recalculatePower(0, actor)
    VentilationSimulation.update(ventilation, 0)
    CampaignState.touch()
    CampaignState.appendLog("ventilation", "mode requested " .. mode, actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.startAirlockPurge(roomId, actor)
    local ventilation = CampaignState.data and CampaignState.data.bunker.modules.ventilation
    if not ventilation then return false, "state_unavailable" end
    local ok, reason = VentilationSimulation.startAirlockPurge(ventilation, roomId)
    if not ok then return false, reason end
    CampaignState.touch()
    CampaignState.appendLog("ventilation", "airlock purge started room=" .. roomId, actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.replaceVentilationFilter(remaining, actor)
    local ventilation = CampaignState.data and CampaignState.data.bunker.modules.ventilation
    if not ventilation then return false, "state_unavailable" end
    remaining = Util.numberOr(remaining, 1, 0, 1)
    local previous = ventilation.filterBank.remaining
    ventilation.filterBank.remaining = remaining
    ventilation.filterRemaining = remaining
    ventilation.filterBank.fault = "none"
    CampaignState.touch()
    CampaignState.appendLog("ventilation", "filter replaced previous="
        .. tostring(Util.round(previous * 100, 1)) .. "%", actor)
    CampaignState.broadcast()
    return true, previous
end

function CampaignState.setWaterSource(sourceId, actor)
    local water = CampaignState.data and CampaignState.data.bunker.modules.water
    if not water or type(water.sources[sourceId]) ~= "table" then return false, "unknown_water_source" end
    if not water.sources[sourceId].enabled then return false, "water_source_unavailable" end
    water.selectedSource = sourceId
    water.source = sourceId
    CampaignState.touch()
    CampaignState.appendLog("water", "source selected " .. sourceId, actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.addWaterSource(sourceId, liters, contamination, actor)
    local water = CampaignState.data and CampaignState.data.bunker.modules.water
    local source = water and water.sources[sourceId]
    if not source then return false, "unknown_water_source" end
    liters = Util.numberOr(liters, 0, 0, Constants.WATER.MAX_STORAGE)
    if liters <= 0 or source.renewable then return false, "invalid_water_amount" end
    source.availableLiters = math.min(Constants.WATER.MAX_STORAGE, source.availableLiters + liters)
    source.contamination = Util.numberOr(contamination, source.contamination, 0, 1)
    source.enabled = true
    source.status = "available"
    CampaignState.touch()
    CampaignState.appendLog("water", "source replenished " .. sourceId .. " liters="
        .. tostring(Util.round(liters, 1)), actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.setWaterBypass(enabled, actor)
    if type(enabled) ~= "boolean" then return false, "invalid_payload" end
    local water = CampaignState.data and CampaignState.data.bunker.modules.water
    if not water then return false, "state_unavailable" end
    water.treatment.bypass = enabled
    CampaignState.touch()
    CampaignState.appendLog("water", enabled and "treatment bypass opened" or "treatment bypass closed", actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.registerRoom(definition)
    local ok, reason = RoomRegistry.register(definition)
    if not ok then return false, reason end
    if CampaignState.data then
        local ventilation = CampaignState.data.bunker.modules.ventilation
        if definition.id ~= "legacy_habitat" then ventilation.rooms.legacy_habitat = nil end
        ventilation.rooms = RoomRegistry.ensureState(ventilation.rooms, Constants.VENTILATION.MIN_CO2)
    end
    return true
end

function CampaignState.setExternalContamination(value, source)
    if not Util.isFiniteNumber(value) then return false, "value must be a finite number" end

    value = Util.clamp(value, 0, 1)
    local ventilation = CampaignState.data.bunker.modules.ventilation
    if math.abs(ventilation.externalContamination - value) < 0.0001 then
        return true, "unchanged"
    end

    local previous = ventilation.externalContamination
    ventilation.externalContamination = value
    CampaignState.touch()
    CampaignState.appendLog(
        "environment",
        "external contamination changed " .. tostring(Util.round(previous, 3)) .. " -> " .. tostring(Util.round(value, 3)),
        source or "server adapter"
    )
    CampaignState.broadcast()
    return true
end

local function collectRoomOccupancy()
    local result = {}
    if not getOnlinePlayers then return result end
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and not player:isDead() then
            local definition = RoomRegistry.find(player:getX(), player:getY(), player:getZ())
            if definition then result[definition.id] = (result[definition.id] or 0) + 1 end
        end
    end
    return result
end

function CampaignState.updateOneMinute()
    if not CampaignState.data then return end

    CampaignState.deferBroadcast = true
    CampaignState.broadcastPending = false

    local modules = CampaignState.data.bunker.modules
    local ventilation = modules.ventilation
    local water = modules.water
    local context = {
        occupancyByRoom=collectRoomOccupancy(),
        intakeContamination={},
        externalContamination=ventilation.externalContamination,
        waterPhysical={},
    }
    notifyLifeSupportListeners("sample", context)

    local ventilationConsumer = modules.power.consumers.ventilation
    ventilationConsumer.demandKw = VentilationSimulation.powerDemand(ventilation.requestedMode)
    ventilationConsumer.requested = ventilationConsumer.demandKw > 0
    local waterConsumer = modules.power.consumers.water
    waterConsumer.demandKw = WaterSimulation.prepareDemand(water)
    waterConsumer.requested = water.requested and waterConsumer.demandKw > 0
    local powerEvents = CampaignState.recalculatePower(1, "server")
    notifyLifeSupportListeners("postPower", context)
    WaterSimulation.update(water, 1, context.waterPhysical)
    local events = VentilationSimulation.update(ventilation, 1, context)
    notifyLifeSupportListeners("postSimulation", context)
    CampaignState.touch()

    if powerEvents and #powerEvents.allocationChanges > 0 then
        CampaignState.appendLog("power", "allocation changed: " .. table.concat(powerEvents.allocationChanges, ","), "server")
    end

    if events.statusChanged then
        CampaignState.appendLog("ventilation", "status changed " .. tostring(events.previousStatus) .. " -> " .. tostring(ventilation.status), "server")
    end
    if events.filterExhausted then
        CampaignState.appendLog("ventilation", "filter exhausted", "server")
    end

    CampaignState.minutesSinceSync = CampaignState.minutesSinceSync + 1
    local periodicSync = CampaignState.minutesSinceSync >= Constants.SYNC_INTERVAL_MINUTES
    if periodicSync then
        CampaignState.minutesSinceSync = 0
    end
    local publish = CampaignState.broadcastPending or periodicSync
    CampaignState.deferBroadcast = false
    CampaignState.broadcastPending = false
    if publish then CampaignState.broadcast() end
end

Events.OnInitGlobalModData.Add(CampaignState.initialize)
Events.EveryOneMinute.Add(CampaignState.updateOneMinute)

BunkerCampaign.CampaignState = CampaignState
return CampaignState
