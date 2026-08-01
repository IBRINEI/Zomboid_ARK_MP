if isClient() then return end

require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"
require "BunkerCampaign/StateSchema"
require "BunkerCampaign/PowerSimulation"
require "BunkerCampaign/VentilationSimulation"
require "BunkerCampaign/WaterSimulation"
require "BunkerCampaign/RoomRegistry"
require "BunkerCampaign/HeatingSimulation"
require "BunkerCampaign/HeatingComponents"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local StateSchema = BunkerCampaign.StateSchema
local PowerSimulation = BunkerCampaign.PowerSimulation
local VentilationSimulation = BunkerCampaign.VentilationSimulation
local WaterSimulation = BunkerCampaign.WaterSimulation
local RoomRegistry = BunkerCampaign.RoomRegistry
local HeatingSimulation = BunkerCampaign.HeatingSimulation
local HeatingComponents = BunkerCampaign.HeatingComponents
local CampaignState = BunkerCampaign.CampaignState or {}
CampaignState.minutesSinceSync = tonumber(CampaignState.minutesSinceSync) or 0
CampaignState.deferBroadcast = CampaignState.deferBroadcast == true
CampaignState.broadcastPending = CampaignState.broadcastPending == true
CampaignState.powerListeners = type(CampaignState.powerListeners) == "table"
    and CampaignState.powerListeners or {}
CampaignState.lifeSupportListeners = type(CampaignState.lifeSupportListeners) == "table"
    and CampaignState.lifeSupportListeners or {}
CampaignState.lifeSupportListeners.sample = type(CampaignState.lifeSupportListeners.sample) == "table"
    and CampaignState.lifeSupportListeners.sample or {}
CampaignState.lifeSupportListeners.postPower = type(CampaignState.lifeSupportListeners.postPower) == "table"
    and CampaignState.lifeSupportListeners.postPower or {}
CampaignState.lifeSupportListeners.postSimulation = type(CampaignState.lifeSupportListeners.postSimulation) == "table"
    and CampaignState.lifeSupportListeners.postSimulation or {}

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
    local heating = state.bunker.modules.heating
    ventilation.powerAllocated = consumers.ventilation.allocated
    VentilationSimulation.update(ventilation, 0)
    water.requested = consumers.water.requested
    water.pumpRequested = water.requested
    water.powerAllocated = consumers.water.allocated
    heating.powerAllocated = consumers.heating.allocated
    HeatingSimulation.update(heating, 0, { ventilation=ventilation })
    state.bunker.temperature = heating.averageTemperature

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
    local heating = state.bunker.modules.heating

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
    local heatingRoomSnapshot = {}
    for id, room in pairs(heating.rooms or {}) do
        heatingRoomSnapshot[id] = {
            id=id, label=room.label, kind=room.kind, volumeM3=room.volumeM3,
            bounds=room.bounds, regions=room.regions, footprintArea=room.footprintArea,
            connections=room.connections, vents=room.vents, ventWeight=room.ventWeight,
            sealed=room.sealed, heatingEnabled=room.heatingEnabled,
            temperature=room.temperature, targetTemperature=room.targetTemperature,
            heatInputKw=room.heatInputKw, heatLossKw=room.heatLossKw,
            status=room.status,
        }
    end
    local heatingComponentSnapshot = {}
    for id, component in pairs(heating.components or {}) do
        local severity = BunkerCampaign.HeatingComponents
            and BunkerCampaign.HeatingComponents.faultSeverity(id, component.fault) or "none"
        heatingComponentSnapshot[id] = {
            id=id,
            condition=component.condition,
            integrity=component.integrity,
            fault=component.diagnosed and component.fault
                or (component.fault ~= "none" and "undiagnosed" or "none"),
            faultSeverity=severity,
            diagnosed=component.diagnosed,
            temporaryRepair=component.temporaryRepair,
            open=component.open,
            outputKw=component.outputKw,
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
        heating = {
            enabled = heating.enabled,
            requested = heating.requested,
            operating = heating.operating,
            powerAllocated = heating.powerAllocated,
            status = heating.status,
            reason = heating.reason,
            targetTemperature = heating.targetTemperature,
            averageTemperature = heating.averageTemperature,
            externalTemperature = heating.externalTemperature,
            baseExternalTemperature = heating.baseExternalTemperature,
            coldOffset = heating.coldOffset,
            powerDemandKw = heating.powerDemandKw,
            fuelAvailable = heating.fuelAvailable,
            heatExchanger = heatingComponentSnapshot.heat_exchanger,
            pipes = heatingComponentSnapshot.pipe_manifold,
            components = heatingComponentSnapshot,
            manualBypass = heating.manualBypass,
            accidents = heating.accidents,
            rooms = heatingRoomSnapshot,
            telemetry = heating.telemetry,
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
    modules.heating.powerAllocated = consumers.heating.allocated
end

function CampaignState.recalculatePower(deltaMinutes, actor)
    if not CampaignState.data then return nil end
    local power = CampaignState.data.bunker.modules.power
    local events = PowerSimulation.update(power, deltaMinutes or 0)
    applyPowerOutputs()
    VentilationSimulation.update(CampaignState.data.bunker.modules.ventilation, 0)
    HeatingSimulation.update(CampaignState.data.bunker.modules.heating, 0, {
        ventilation=CampaignState.data.bunker.modules.ventilation,
    })
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
    elseif consumerId == "heating" then
        local heating = CampaignState.data.bunker.modules.heating
        heating.enabled = requested
        heating.requested = requested
        consumer.demandKw = HeatingSimulation.prepareDemand(heating, {
            ventilation=CampaignState.data.bunker.modules.ventilation,
        })
    end
    CampaignState.recalculatePower(0, actor)
    VentilationSimulation.update(CampaignState.data.bunker.modules.ventilation, 0)
    CampaignState.touch()
    CampaignState.appendLog("power", tostring(consumerId) .. (requested and " power requested" or " power released"), actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.setHeatingEnabled(enabled, actor)
    if type(enabled) ~= "boolean" then return false, "enabled must be boolean" end
    local heating = CampaignState.data and CampaignState.data.bunker.modules.heating
    if not heating then return false, "state_unavailable" end
    if heating.enabled == enabled and heating.requested == enabled then return true, "unchanged" end
    return CampaignState.setConsumerRequested("heating", enabled, actor)
end

function CampaignState.setHeatingTarget(value, actor)
    local heating = CampaignState.data and CampaignState.data.bunker.modules.heating
    if not heating then return false, "state_unavailable" end
    local previous = heating.targetTemperature
    local ok, reason = HeatingSimulation.setTarget(heating, value)
    if not ok then return false, reason end
    if previous == heating.targetTemperature then return true, "unchanged" end
    local consumer = CampaignState.data.bunker.modules.power.consumers.heating
    consumer.demandKw = HeatingSimulation.prepareDemand(heating, {
        ventilation=CampaignState.data.bunker.modules.ventilation,
    })
    CampaignState.recalculatePower(0, actor)
    CampaignState.touch()
    CampaignState.appendLog("heating", "target changed to "
        .. tostring(Util.round(heating.targetTemperature, 1)) .. " C", actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.setHeatingRoomEnabled(roomId, enabled, actor)
    local heating = CampaignState.data and CampaignState.data.bunker.modules.heating
    if not heating then return false, "state_unavailable" end
    local ok, reason = HeatingSimulation.setRoomEnabled(heating, roomId, enabled)
    if not ok then return false, reason end
    CampaignState.touch()
    CampaignState.appendLog("heating", "room " .. roomId
        .. (enabled and " circuit enabled" or " circuit isolated"), actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.setHeatingValve(componentId, open, actor)
    local heating = CampaignState.data and CampaignState.data.bunker.modules.heating
    if not heating then return false, "state_unavailable" end
    local ok, reason = HeatingSimulation.setValve(heating, componentId, open)
    if not ok then return false, reason end
    CampaignState.recalculatePower(0, actor)
    CampaignState.touch()
    CampaignState.appendLog("heating", tostring(componentId)
        .. (open and " opened" or " closed"), actor)
    CampaignState.broadcast()
    return true, reason
end

function CampaignState.setHeatingManualBypass(enabled, actor)
    local heating = CampaignState.data and CampaignState.data.bunker.modules.heating
    if not heating then return false, "state_unavailable" end
    local ok, reason = HeatingSimulation.setManualBypass(heating, enabled)
    if not ok then return false, reason end
    CampaignState.recalculatePower(0, actor)
    CampaignState.touch()
    CampaignState.appendLog("heating", "manual circulation bypass "
        .. (enabled and "enabled" or "disabled"), actor)
    CampaignState.broadcast()
    return true, reason
end

function CampaignState.diagnoseHeatingComponent(componentId, actor)
    local heating = CampaignState.data and CampaignState.data.bunker.modules.heating
    if not heating then return false, "state_unavailable" end
    local ok, fault = HeatingSimulation.diagnoseComponent(heating, componentId)
    if not ok then return false, fault end
    CampaignState.touch()
    CampaignState.appendLog("heating", tostring(componentId)
        .. " diagnosed: " .. tostring(fault), actor)
    CampaignState.broadcast()
    return true, fault
end

function CampaignState.repairHeatingComponent(componentId, mode, improvement, actor)
    local heating = CampaignState.data and CampaignState.data.bunker.modules.heating
    if not heating then return false, "state_unavailable" end
    local ok, reason = HeatingSimulation.repairComponent(
        heating, componentId, mode, improvement)
    if not ok then return false, reason end
    CampaignState.recalculatePower(0, actor)
    CampaignState.touch()
    CampaignState.appendLog("heating", tostring(componentId) .. " "
        .. tostring(mode) .. " repair completed", actor)
    CampaignState.broadcast()
    return true
end

function CampaignState.triggerHeatingFault(componentId, severityOrFault, actor)
    local heating = CampaignState.data and CampaignState.data.bunker.modules.heating
    if not heating then return false, "state_unavailable" end
    local ok, fault = HeatingSimulation.triggerFault(heating,
        componentId, severityOrFault, Util.worldAgeHours())
    if not ok then return false, fault end
    CampaignState.recalculatePower(0, actor)
    CampaignState.touch()
    CampaignState.appendLog("heating", "forced failure " .. tostring(componentId)
        .. ": " .. tostring(fault), actor)
    CampaignState.broadcast()
    return true, fault
end

local function recountHeatingFailures(heating)
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
end

local function restoreHeatingComponent(heating, componentId)
    local component = heating.components[componentId]
    if not component then return false end
    component.condition = 0.90
    if component.integrity ~= nil then component.integrity = 0.90 end
    component.fault = "none"
    component.diagnosed = false
    component.temporaryRepair = false
    if component.open ~= nil then component.open = true end
    if componentId == "heat_exchanger" then component.outputKw = 0 end
    return true
end

local function restoreAllHeatingComponents(heating)
    for _, id in ipairs(HeatingComponents.orderedIds()) do
        restoreHeatingComponent(heating, id)
    end
    heating.manualBypass = false
    heating.accidents.lastFailureHour = -1000
    heating.accidents.activeFailures = 0
    heating.accidents.activeMajorFailures = 0
end

function CampaignState.applyHeatingQa(action, args, actor)
    if not CampaignState.data then return false, "state_unavailable" end
    action = type(action) == "string" and action or ""
    args = type(args) == "table" and args or {}
    local modules = CampaignState.data.bunker.modules
    local heating, ventilation, power = modules.heating, modules.ventilation, modules.power
    HeatingSimulation.normalize(heating)
    local description = action

    if action == "restore_all" then
        restoreAllHeatingComponents(heating)
        description = "all heating components restored to 90%"
    elseif action == "component" then
        local componentId = args.componentId
        local state = args.state
        if not HeatingComponents.get(componentId) then
            return false, "unknown_heating_component"
        end
        if state == "healthy" then
            restoreHeatingComponent(heating, componentId)
            recountHeatingFailures(heating)
        elseif state == "minor" or state == "major" then
            local component = heating.components[componentId]
            local definition = HeatingComponents.get(componentId)
            component.fault = definition.faults[state]
            component.diagnosed = true
            component.temporaryRepair = false
            if component.fault == "valve_stuck_closed" then component.open = false end
            if component.fault == "valve_stuck_open" then component.open = true end
            heating.accidents.lastFailureHour = Util.worldAgeHours()
            heating.accidents.totalFailures = heating.accidents.totalFailures + 1
        else
            return false, "invalid_component_state"
        end
        description = tostring(componentId) .. " set to " .. tostring(state)
    elseif action == "rooms" then
        if not Util.isFiniteNumber(args.temperature) then
            return false, "invalid_temperature"
        end
        local temperature = Util.clamp(args.temperature,
            Constants.HEATING.MIN_TEMPERATURE, Constants.HEATING.MAX_TEMPERATURE)
        for _, room in pairs(heating.rooms) do room.temperature = temperature end
        description = "all room temperatures set to "
            .. tostring(Util.round(temperature, 1)) .. " C"
    elseif action == "ready" then
        restoreAllHeatingComponents(heating)
        heating.enabled, heating.requested = true, true
        heating.targetTemperature = 21
        for _, room in pairs(heating.rooms) do
            room.temperature = 5
            room.heatingEnabled = true
        end
        local main = power.generators.main
        main.requested, main.fuel = true, 1
        main.condition, main.coolant, main.lubricant = 1, 1, 1
        power.generators.backup.requested = false
        VentilationSimulation.setMode(ventilation, "internal_recirculation")
        power.consumers.ventilation.requested = true
        modules.water.requested = false
        modules.water.pumpRequested = false
        power.consumers.water.requested = false
        power.consumers.main_lighting.requested = false
        power.consumers.heating.requested = true
        description = "cold powered heating test state applied"
    elseif action == "power_shed" then
        power.generators.main.requested = false
        power.generators.backup.requested = false
        heating.enabled, heating.requested = true, true
        power.consumers.heating.requested = true
        description = "both generators stopped with heating requested"
    elseif action == "ventilation_off" then
        VentilationSimulation.setMode(ventilation, "off")
        power.consumers.ventilation.requested = false
        heating.enabled, heating.requested = true, true
        power.consumers.heating.requested = true
        description = "ventilation off with heating requested"
    elseif action == "circulation_on" then
        VentilationSimulation.setMode(ventilation, "internal_recirculation")
        power.consumers.ventilation.requested = true
        heating.enabled, heating.requested = true, true
        power.consumers.heating.requested = true
        description = "internal recirculation and heating requested"
    elseif action == "manual_bypass" then
        if type(args.enabled) ~= "boolean" then return false, "invalid_payload" end
        heating.manualBypass = args.enabled
        description = "manual heating bypass " .. (args.enabled and "enabled" or "disabled")
    elseif action == "valves" then
        if type(args.supplyOpen) == "boolean" then
            heating.components.supply_valve.open = args.supplyOpen
        end
        if type(args.returnOpen) == "boolean" then
            heating.components.return_valve.open = args.returnOpen
        end
        description = "heating valves set supply="
            .. tostring(heating.components.supply_valve.open)
            .. " return=" .. tostring(heating.components.return_valve.open)
    else
        return false, "unknown_heating_qa_action"
    end

    recountHeatingFailures(heating)
    local heatingConsumer = power.consumers.heating
    heatingConsumer.demandKw = HeatingSimulation.prepareDemand(heating, {
        ventilation=ventilation,
    })
    local ventilationConsumer = power.consumers.ventilation
    ventilationConsumer.demandKw = VentilationSimulation.powerDemand(ventilation.requestedMode)
    CampaignState.recalculatePower(0, actor)
    CampaignState.touch()
    CampaignState.appendLog("qa", description, actor)
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
        local heating = CampaignState.data.bunker.modules.heating
        heating.rooms = RoomRegistry.ensureThermalState(
            heating.rooms, heating.averageTemperature, heating.targetTemperature)
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
    local heating = modules.heating
    local context = {
        occupancyByRoom=collectRoomOccupancy(),
        intakeContamination={},
        externalContamination=ventilation.externalContamination,
        waterPhysical={},
        externalTemperature=heating.externalTemperature,
        baseExternalTemperature=heating.baseExternalTemperature,
        coldOffset=heating.coldOffset,
        allowHeatingFailures=true,
        worldAgeHours=Util.worldAgeHours(),
    }
    notifyLifeSupportListeners("sample", context)

    local ventilationConsumer = modules.power.consumers.ventilation
    ventilationConsumer.demandKw = VentilationSimulation.powerDemand(ventilation.requestedMode)
    ventilationConsumer.requested = ventilationConsumer.demandKw > 0
    local waterConsumer = modules.power.consumers.water
    waterConsumer.demandKw = WaterSimulation.prepareDemand(water)
    waterConsumer.requested = water.requested and waterConsumer.demandKw > 0
    context.ventilation = ventilation
    local heatingConsumer = modules.power.consumers.heating
    heatingConsumer.demandKw = HeatingSimulation.prepareDemand(heating, context)
    heatingConsumer.requested = heating.requested and heating.enabled
    local powerEvents = CampaignState.recalculatePower(1, "server")
    notifyLifeSupportListeners("postPower", context)
    WaterSimulation.update(water, 1, context.waterPhysical)
    local events = VentilationSimulation.update(ventilation, 1, context)
    context.ventilation = ventilation
    context.fuelAvailable = false
    for _, generator in pairs(modules.power.generators or {}) do
        if generator.running and generator.fuel > 0 then context.fuelAvailable = true; break end
    end
    local heatingEvents = HeatingSimulation.update(heating, 1, context)
    CampaignState.data.bunker.temperature = heating.averageTemperature
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
    if heatingEvents.statusChanged then
        CampaignState.appendLog("heating", "status changed "
            .. tostring(heatingEvents.previousStatus) .. " -> " .. tostring(heating.status), "server")
    end
    if heatingEvents.failure then
        CampaignState.appendLog("heating", "failure "
            .. tostring(heatingEvents.failure.componentId) .. ": "
            .. tostring(heatingEvents.failure.fault), "server")
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

BunkerCampaign.Runtime = BunkerCampaign.Runtime or {}
if BunkerCampaign.Runtime.onInitCampaignState
    and type(Events.OnInitGlobalModData.Remove) == "function" then
    Events.OnInitGlobalModData.Remove(BunkerCampaign.Runtime.onInitCampaignState)
end
if BunkerCampaign.Runtime.onCampaignMinute
    and type(Events.EveryOneMinute.Remove) == "function" then
    Events.EveryOneMinute.Remove(BunkerCampaign.Runtime.onCampaignMinute)
end
BunkerCampaign.Runtime.onInitCampaignState = CampaignState.initialize
BunkerCampaign.Runtime.onCampaignMinute = CampaignState.updateOneMinute
Events.OnInitGlobalModData.Add(BunkerCampaign.Runtime.onInitCampaignState)
Events.EveryOneMinute.Add(BunkerCampaign.Runtime.onCampaignMinute)

BunkerCampaign.CampaignState = CampaignState
return CampaignState
