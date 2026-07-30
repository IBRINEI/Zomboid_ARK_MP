require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local WaterSimulation = {}

local function ensureTable(parent, key)
    if type(parent[key]) ~= "table" then parent[key] = {} end
    return parent[key]
end

local function sourceDefaults(id, kind, contamination, availableLiters, enabled)
    return {
        id=id,
        kind=kind,
        enabled=enabled == true,
        availableLiters=availableLiters,
        renewable=availableLiters < 0,
        contamination=contamination,
        maximumFlowLpm=Constants.WATER.NOMINAL_FLOW_LPM,
        status=enabled and "available" or "disabled",
    }
end

function WaterSimulation.createDefault()
    return {
        adapterOnline=false,
        requested=true,
        pumpRequested=true,
        powerAllocated=false,
        physicallyAvailable=false,
        operating=false,
        pumpActive=false,
        status="offline",
        reason="adapter_offline",
        source="underground_well",
        selectedSource="underground_well",
        sources={
            underground_well=sourceDefaults("underground_well", "well", 1, -1, true),
            external_tank=sourceDefaults("external_tank", "stored", 0.35, 0, false),
            collected_water=sourceDefaults("collected_water", "weather", 0.55, 0, false),
            portable_supply=sourceDefaults("portable_supply", "portable", 0, 0, false),
        },
        pump={
            condition=0,
            maximumFlowLpm=Constants.WATER.NOMINAL_FLOW_LPM,
            actualFlowLpm=0,
            dryRunMinutes=0,
            fault="none",
        },
        treatment={
            bypass=false,
            filterRemaining=0,
            efficiency=Constants.WATER.FILTER_EFFICIENCY,
            maximumFlowLpm=Constants.WATER.NOMINAL_FLOW_LPM,
            fault="none",
        },
        storage={
            cleanLiters=0,
            taintedLiters=0,
            capacityLiters=0,
            contamination=0,
        },
        telemetry={
            producedLiters=0,
            consumedLiters=0,
            lastFlowLpm=0,
            lastTransactionId="",
        },
        faults={},
        -- Legacy snapshot fields retained for old clients and saves.
        pumpCondition=0,
        filterRemaining=0,
        stored=0,
        capacity=0,
        contamination=0,
        flowPerMinute=0,
        powerDemandKw=Constants.WATER.PUMP_POWER_KW,
    }
end

local function normalizeSource(source, defaults)
    source.id = type(source.id) == "string" and source.id or defaults.id
    source.kind = type(source.kind) == "string" and source.kind or defaults.kind
    source.enabled = Util.booleanOr(source.enabled, defaults.enabled)
    source.availableLiters = Util.numberOr(source.availableLiters, defaults.availableLiters,
        -1, Constants.WATER.MAX_STORAGE)
    source.renewable = source.availableLiters < 0 or Util.booleanOr(source.renewable, defaults.renewable)
    source.contamination = Util.numberOr(source.contamination, defaults.contamination, 0, 1)
    source.maximumFlowLpm = Util.numberOr(source.maximumFlowLpm, defaults.maximumFlowLpm,
        0, Constants.WATER.MAX_FLOW_PER_MINUTE)
    source.status = type(source.status) == "string" and source.status or defaults.status
end

function WaterSimulation.normalize(water)
    local defaults = WaterSimulation.createDefault()
    if type(water) ~= "table" then return defaults end

    water.adapterOnline = Util.booleanOr(water.adapterOnline, defaults.adapterOnline)
    water.requested = Util.booleanOr(water.requested, Util.booleanOr(water.pumpRequested, defaults.requested))
    water.pumpRequested = water.requested
    water.powerAllocated = Util.booleanOr(water.powerAllocated, false)
    water.physicallyAvailable = Util.booleanOr(water.physicallyAvailable, water.adapterOnline)
    water.operating = Util.booleanOr(water.operating, Util.booleanOr(water.pumpActive, false))
    water.pumpActive = water.operating
    water.status = Constants.VALID_WATER_STATUS[water.status] and water.status or defaults.status
    water.reason = type(water.reason) == "string" and water.reason or defaults.reason
    water.selectedSource = type(water.selectedSource) == "string" and water.selectedSource
        or (type(water.source) == "string" and water.source ~= "none" and water.source or defaults.selectedSource)
    water.source = water.selectedSource

    local sources = ensureTable(water, "sources")
    for id, sourceDefault in pairs(defaults.sources) do
        if type(sources[id]) ~= "table" then sources[id] = {} end
        normalizeSource(sources[id], sourceDefault)
    end

    local pump = ensureTable(water, "pump")
    local legacyPumpCondition = Util.numberOr(water.pumpCondition, defaults.pump.condition, 0, 1)
    pump.condition = Util.numberOr(pump.condition, legacyPumpCondition, 0, 1)
    pump.maximumFlowLpm = Util.numberOr(pump.maximumFlowLpm, defaults.pump.maximumFlowLpm,
        0, Constants.WATER.MAX_FLOW_PER_MINUTE)
    pump.actualFlowLpm = Util.numberOr(pump.actualFlowLpm, water.flowPerMinute or 0,
        0, Constants.WATER.MAX_FLOW_PER_MINUTE)
    pump.dryRunMinutes = Util.numberOr(pump.dryRunMinutes, 0, 0, 1000000000)
    pump.fault = type(pump.fault) == "string" and pump.fault or "none"

    local treatment = ensureTable(water, "treatment")
    treatment.bypass = Util.booleanOr(treatment.bypass, false)
    local legacyFilter = Util.numberOr(water.filterRemaining, defaults.treatment.filterRemaining, 0, 1)
    treatment.filterRemaining = Util.numberOr(treatment.filterRemaining, legacyFilter, 0, 1)
    treatment.efficiency = Util.numberOr(treatment.efficiency, defaults.treatment.efficiency, 0, 1)
    treatment.maximumFlowLpm = Util.numberOr(treatment.maximumFlowLpm, defaults.treatment.maximumFlowLpm,
        0, Constants.WATER.MAX_FLOW_PER_MINUTE)
    treatment.fault = type(treatment.fault) == "string" and treatment.fault or "none"

    local storage = ensureTable(water, "storage")
    local legacyStored = Util.numberOr(water.stored, 0, 0, Constants.WATER.MAX_STORAGE)
    local legacyContamination = Util.numberOr(water.contamination, 0, 0, 1)
    storage.cleanLiters = Util.numberOr(storage.cleanLiters, legacyStored * (1 - legacyContamination),
        0, Constants.WATER.MAX_STORAGE)
    storage.taintedLiters = Util.numberOr(storage.taintedLiters, legacyStored * legacyContamination,
        0, Constants.WATER.MAX_STORAGE)
    storage.capacityLiters = Util.numberOr(storage.capacityLiters, water.capacity or 0,
        0, Constants.WATER.MAX_STORAGE)
    local total = storage.cleanLiters + storage.taintedLiters
    storage.contamination = total > 0 and storage.taintedLiters / total or 0

    local telemetry = ensureTable(water, "telemetry")
    telemetry.producedLiters = Util.numberOr(telemetry.producedLiters, 0, 0, Constants.WATER.MAX_STORAGE)
    telemetry.consumedLiters = Util.numberOr(telemetry.consumedLiters, 0, 0, Constants.WATER.MAX_STORAGE)
    telemetry.lastFlowLpm = Util.numberOr(telemetry.lastFlowLpm, pump.actualFlowLpm,
        0, Constants.WATER.MAX_FLOW_PER_MINUTE)
    telemetry.lastTransactionId = type(telemetry.lastTransactionId) == "string" and telemetry.lastTransactionId or ""
    ensureTable(water, "faults")

    water.pumpCondition = pump.condition
    water.filterRemaining = treatment.filterRemaining
    water.stored = total
    water.capacity = storage.capacityLiters
    water.contamination = storage.contamination
    water.flowPerMinute = pump.actualFlowLpm
    water.powerDemandKw = Util.numberOr(water.powerDemandKw, Constants.WATER.PUMP_POWER_KW,
        0, Constants.WATER.MAX_POWER_DEMAND_KW)
    return water
end

function WaterSimulation.prepareDemand(water)
    WaterSimulation.normalize(water)
    if not water.requested then return 0 end
    return Constants.WATER.PUMP_POWER_KW
end

function WaterSimulation.update(water, deltaMinutes, physical)
    WaterSimulation.normalize(water)
    deltaMinutes = Util.numberOr(deltaMinutes, 1, 0, 60)
    physical = type(physical) == "table" and physical or {}

    water.adapterOnline = Util.booleanOr(physical.adapterOnline, water.adapterOnline)
    local physicalFallback = Util.booleanOr(physical.pumpPresent,
        Util.booleanOr(physical.pumpActive, water.physicallyAvailable))
    water.physicallyAvailable = Util.booleanOr(physical.physicallyAvailable, physicalFallback)
    water.pump.condition = Util.numberOr(physical.pumpCondition, water.pump.condition, 0, 1)
    water.treatment.filterRemaining = Util.numberOr(physical.filterRemaining,
        water.treatment.filterRemaining, 0, 1)
    water.storage.cleanLiters = Util.numberOr(physical.cleanStored, water.storage.cleanLiters,
        0, Constants.WATER.MAX_STORAGE)
    water.storage.taintedLiters = Util.numberOr(physical.taintedStored, water.storage.taintedLiters,
        0, Constants.WATER.MAX_STORAGE)
    water.storage.capacityLiters = Util.numberOr(physical.capacity, water.storage.capacityLiters,
        0, Constants.WATER.MAX_STORAGE)
    local total = water.storage.cleanLiters + water.storage.taintedLiters
    water.storage.contamination = total > 0 and water.storage.taintedLiters / total or 0

    local selected = water.sources[water.selectedSource]
    local sourceAvailable = selected and selected.enabled
        and (selected.renewable or selected.availableLiters > 0)
    local canOperate = water.requested and water.powerAllocated and water.adapterOnline
        and water.physicallyAvailable and water.pump.condition > 0.05 and sourceAvailable
    water.operating = canOperate and Util.booleanOr(physical.pumpActive, canOperate)
    water.pumpActive = water.operating
    water.pump.actualFlowLpm = water.operating
        and Util.numberOr(physical.flowPerMinute, 0, 0, Constants.WATER.MAX_FLOW_PER_MINUTE) or 0
    if water.operating and selected and not selected.renewable and selected.availableLiters >= 0
        and deltaMinutes > 0 then
        water.pump.actualFlowLpm = math.min(water.pump.actualFlowLpm,
            selected.availableLiters / deltaMinutes)
    end
    water.telemetry.lastFlowLpm = water.pump.actualFlowLpm
    local producedLiters = water.pump.actualFlowLpm * deltaMinutes
    water.telemetry.producedLiters = water.telemetry.producedLiters + producedLiters
    if water.operating and selected and not selected.renewable and selected.availableLiters >= 0 then
        selected.availableLiters = math.max(0, selected.availableLiters - producedLiters)
        if selected.availableLiters <= 0 then
            selected.status = "empty"
            sourceAvailable = false
            water.operating = false
            water.pumpActive = false
        end
    end

    if not water.requested then water.reason = "operator_off"
    elseif not water.adapterOnline then water.reason = "adapter_offline"
    elseif not water.physicallyAvailable then water.reason = "pump_missing"
    elseif not water.powerAllocated then water.reason = "power_shed"
    elseif water.pump.condition <= 0.05 then water.reason = "pump_failed"
    elseif not sourceAvailable then water.reason = "source_empty"
    elseif physical.storageFull == true then water.reason = "storage_full"
    elseif water.treatment.filterRemaining <= 0 and selected and selected.contamination > 0 then water.reason = "filter_exhausted"
    else water.reason = "none" end

    if water.reason == "adapter_offline" or water.reason == "pump_missing" or water.reason == "operator_off" then water.status = "offline"
    elseif water.pump.condition <= 0.05 or physical.burn == true then water.status = "failed"
    elseif water.storage.contamination > Constants.WATER.DRINKABLE_CONTAMINATION then water.status = "contaminated"
    elseif water.reason ~= "none" and water.reason ~= "storage_full" then water.status = "degraded"
    elseif water.pump.condition < 0.50 or water.treatment.filterRemaining < 0.20 then water.status = "degraded"
    else water.status = "operational" end

    water.pumpCondition = water.pump.condition
    water.filterRemaining = water.treatment.filterRemaining
    water.stored = total
    water.capacity = water.storage.capacityLiters
    water.contamination = water.storage.contamination
    water.flowPerMinute = water.pump.actualFlowLpm
    water.source = water.selectedSource
    return water
end

BunkerCampaign.WaterSimulation = WaterSimulation
return WaterSimulation
