if isClient() then return end

require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"
require "BunkerCampaign/StateSchema"
require "BunkerCampaign/PowerSimulation"
require "BunkerCampaign/VentilationSimulation"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local StateSchema = BunkerCampaign.StateSchema
local PowerSimulation = BunkerCampaign.PowerSimulation
local VentilationSimulation = BunkerCampaign.VentilationSimulation
local CampaignState = {
    data = nil,
    minutesSinceSync = 0,
    powerListeners = {},
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
    ventilation.operating = ventilation.enabled and ventilation.powerAllocated
    water.pumpRequested = consumers.water.requested
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
            powerAllocated = ventilation.powerAllocated,
            operating = ventilation.operating,
            condition = ventilation.condition,
            status = ventilation.status,
            filterRemaining = ventilation.filterRemaining,
            co2 = ventilation.co2,
            externalContamination = ventilation.externalContamination,
            internalContamination = ventilation.internalContamination,
            recirculationUnlocked = ventilation.recirculationUnlocked,
        },
        water = {
            adapterOnline = water.adapterOnline,
            pumpActive = water.pumpActive,
            pumpRequested = water.pumpRequested,
            powerAllocated = water.powerAllocated,
            pumpCondition = water.pumpCondition,
            status = water.status,
            filterRemaining = water.filterRemaining,
            stored = water.stored,
            capacity = water.capacity,
            contamination = water.contamination,
            flowPerMinute = water.flowPerMinute,
            powerDemandKw = water.powerDemandKw,
            source = water.source,
        },
        auditLog = copyAuditTail(state.auditLog),
    }
end

local function applyPowerOutputs()
    local modules = CampaignState.data.bunker.modules
    local consumers = modules.power.consumers
    modules.ventilation.powerAllocated = consumers.ventilation.allocated
    modules.ventilation.operating = modules.ventilation.enabled and modules.ventilation.powerAllocated
    modules.water.pumpRequested = consumers.water.requested
    modules.water.powerAllocated = consumers.water.allocated
end

function CampaignState.recalculatePower(deltaMinutes, actor)
    if not CampaignState.data then return nil end
    local power = CampaignState.data.bunker.modules.power
    local events = PowerSimulation.update(power, deltaMinutes or 0)
    applyPowerOutputs()
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

function CampaignState.setConsumerRequested(consumerId, requested, actor)
    if type(requested) ~= "boolean" then return false, "requested must be boolean" end
    local power = CampaignState.data and CampaignState.data.bunker.modules.power
    local consumer = power and power.consumers[consumerId]
    if not consumer then return false, "unknown_consumer" end
    if consumer.requested == requested then return true, "unchanged" end

    consumer.requested = requested
    if consumerId == "ventilation" then CampaignState.data.bunker.modules.ventilation.enabled = requested end
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
    local normalized = {
        adapterOnline = Util.booleanOr(values.adapterOnline, false),
        pumpActive = Util.booleanOr(values.pumpActive, false),
        pumpCondition = Util.numberOr(values.pumpCondition, 0, 0, 1),
        filterRemaining = Util.numberOr(values.filterRemaining, 0, 0, 1),
        stored = Util.numberOr(values.stored, 0, 0, Constants.WATER.MAX_STORAGE),
        capacity = Util.numberOr(values.capacity, 0, 0, Constants.WATER.MAX_STORAGE),
        contamination = Util.numberOr(values.contamination, 0, 0, 1),
        flowPerMinute = Util.numberOr(values.flowPerMinute, 0, 0, Constants.WATER.MAX_FLOW_PER_MINUTE),
        powerDemandKw = Util.numberOr(values.powerDemandKw, 0, 0, Constants.WATER.MAX_POWER_DEMAND_KW),
        status = Constants.VALID_WATER_STATUS[values.status] and values.status or "offline",
        source = type(values.source) == "string" and values.source or "none",
    }
    if normalized.stored > normalized.capacity and normalized.capacity > 0 then
        normalized.stored = normalized.capacity
    end

    local previousStatus = water.status
    local previousOnline = water.adapterOnline
    local changed = false
    for key, value in pairs(normalized) do
        if waterValueChanged(water[key], value) then
            water[key] = value
            changed = true
        end
    end
    if not changed then return true, "unchanged" end

    CampaignState.touch()
    if previousOnline ~= water.adapterOnline then
        CampaignState.appendLog("water", water.adapterOnline and "Waterpipes adapter online" or "Waterpipes adapter offline", source or "server adapter")
    end
    if previousStatus ~= water.status then
        CampaignState.appendLog("water", "status changed " .. tostring(previousStatus) .. " -> " .. tostring(water.status), source or "server adapter")
        CampaignState.broadcast()
    end
    return true
end

function CampaignState.sendToPlayer(player)
    if not CampaignState.data or not isServer() or not player then return end
    sendServerCommand(player, Constants.NETWORK_MODULE, "stateSnapshot", CampaignState.snapshot())
end

function CampaignState.broadcast()
    if not CampaignState.data or not isServer() then return end
    sendServerCommand(Constants.NETWORK_MODULE, "stateSnapshot", CampaignState.snapshot())
end

function CampaignState.setVentilationEnabled(enabled, actor)
    if type(enabled) ~= "boolean" then return false, "enabled must be boolean" end

    local ventilation = CampaignState.data.bunker.modules.ventilation
    local consumer = CampaignState.data.bunker.modules.power.consumers.ventilation
    if ventilation.enabled == enabled and consumer.requested == enabled then return true, "unchanged" end

    return CampaignState.setConsumerRequested("ventilation", enabled, actor)
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

function CampaignState.updateOneMinute()
    if not CampaignState.data then return end

    local powerEvents = CampaignState.recalculatePower(1, "server")
    local ventilation = CampaignState.data.bunker.modules.ventilation
    local events = VentilationSimulation.update(ventilation, 1)
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
    if CampaignState.minutesSinceSync >= Constants.SYNC_INTERVAL_MINUTES then
        CampaignState.minutesSinceSync = 0
        CampaignState.broadcast()
    end
end

Events.OnInitGlobalModData.Add(CampaignState.initialize)
Events.EveryOneMinute.Add(CampaignState.updateOneMinute)

BunkerCampaign.CampaignState = CampaignState
return CampaignState
