require "BunkerCampaign/Constants"
require "BunkerCampaign/Util"
require "BunkerCampaign/PowerSimulation"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local Util = BunkerCampaign.Util
local PowerSimulation = BunkerCampaign.PowerSimulation
local StateSchema = {}

local function defaultVentilation()
    return {
        enabled = true,
        powerAllocated = false,
        operating = false,
        condition = 1.0,
        status = "operational",
        filterRemaining = 1.0,
        co2 = 400,
        externalContamination = 0.0,
        internalContamination = 0.0,
        recirculationUnlocked = false,
    }
end

local function defaultWater()
    return {
        adapterOnline = false,
        pumpActive = false,
        pumpRequested = true,
        powerAllocated = false,
        pumpCondition = 0.0,
        status = "offline",
        filterRemaining = 0.0,
        stored = 0.0,
        capacity = 0.0,
        contamination = 0.0,
        flowPerMinute = 0.0,
        powerDemandKw = 0.0,
        source = "none",
    }
end

function StateSchema.createDefault()
    local now = Util.worldAgeHours()
    return {
        version = Constants.CURRENT_STATE_VERSION,
        campaignId = "default",
        revision = 0,
        createdAtWorldAgeHours = now,
        lastUpdatedWorldAgeHours = now,
        bunker = {
            contamination = 0.0,
            temperature = 18.0,
            sealed = true,
            modules = {
                power = PowerSimulation.createDefault(),
                ventilation = defaultVentilation(),
                water = defaultWater(),
            },
        },
        auditLog = {},
        nextAuditLogId = 1,
    }
end


local function ensureTable(parent, key)
    if type(parent[key]) ~= "table" then
        parent[key] = {}
        return true
    end
    return false
end

local function copyMissing(target, defaults)
    local changed = false
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
            changed = true
        end
    end
    return changed
end

local function normalizeWater(water)
    local defaults = defaultWater()
    local changed = copyMissing(water, defaults)

    local adapterOnline = Util.booleanOr(water.adapterOnline, defaults.adapterOnline)
    local pumpActive = Util.booleanOr(water.pumpActive, defaults.pumpActive)
    local pumpRequested = Util.booleanOr(water.pumpRequested, defaults.pumpRequested)
    local powerAllocated = Util.booleanOr(water.powerAllocated, defaults.powerAllocated)
    local pumpCondition = Util.numberOr(water.pumpCondition, defaults.pumpCondition, 0, 1)
    local filterRemaining = Util.numberOr(water.filterRemaining, defaults.filterRemaining, 0, 1)
    local stored = Util.numberOr(water.stored, defaults.stored, 0, Constants.WATER.MAX_STORAGE)
    local capacity = Util.numberOr(water.capacity, defaults.capacity, 0, Constants.WATER.MAX_STORAGE)
    local contamination = Util.numberOr(water.contamination, defaults.contamination, 0, 1)
    local flow = Util.numberOr(water.flowPerMinute, defaults.flowPerMinute, 0, Constants.WATER.MAX_FLOW_PER_MINUTE)
    local power = Util.numberOr(water.powerDemandKw, defaults.powerDemandKw, 0, Constants.WATER.MAX_POWER_DEMAND_KW)
    local status = Constants.VALID_WATER_STATUS[water.status] and water.status or defaults.status
    local source = type(water.source) == "string" and water.source or defaults.source

    if stored > capacity and capacity > 0 then stored = capacity end
    if water.adapterOnline ~= adapterOnline then water.adapterOnline = adapterOnline; changed = true end
    if water.pumpActive ~= pumpActive then water.pumpActive = pumpActive; changed = true end
    if water.pumpRequested ~= pumpRequested then water.pumpRequested = pumpRequested; changed = true end
    if water.powerAllocated ~= powerAllocated then water.powerAllocated = powerAllocated; changed = true end
    if water.pumpCondition ~= pumpCondition then water.pumpCondition = pumpCondition; changed = true end
    if water.filterRemaining ~= filterRemaining then water.filterRemaining = filterRemaining; changed = true end
    if water.stored ~= stored then water.stored = stored; changed = true end
    if water.capacity ~= capacity then water.capacity = capacity; changed = true end
    if water.contamination ~= contamination then water.contamination = contamination; changed = true end
    if water.flowPerMinute ~= flow then water.flowPerMinute = flow; changed = true end
    if water.powerDemandKw ~= power then water.powerDemandKw = power; changed = true end
    if water.status ~= status then water.status = status; changed = true end
    if water.source ~= source then water.source = source; changed = true end

    return changed
end

local function normalizeVentilation(ventilation)
    local defaults = defaultVentilation()
    local changed = copyMissing(ventilation, defaults)

    local enabled = Util.booleanOr(ventilation.enabled, defaults.enabled)
    local powerAllocated = Util.booleanOr(ventilation.powerAllocated, defaults.powerAllocated)
    local operating = enabled and powerAllocated
    local condition = Util.numberOr(ventilation.condition, defaults.condition, 0, 1)
    local filterRemaining = Util.numberOr(ventilation.filterRemaining, defaults.filterRemaining, 0, 1)
    local co2 = Util.numberOr(ventilation.co2, defaults.co2, Constants.VENTILATION.MIN_CO2, Constants.VENTILATION.MAX_CO2)
    local external = Util.numberOr(ventilation.externalContamination, defaults.externalContamination, 0, 1)
    local internal = Util.numberOr(ventilation.internalContamination, defaults.internalContamination, 0, 1)
    local recirculation = Util.booleanOr(ventilation.recirculationUnlocked, defaults.recirculationUnlocked)
    local status = Constants.VALID_VENTILATION_STATUS[ventilation.status] and ventilation.status or defaults.status

    if ventilation.enabled ~= enabled then ventilation.enabled = enabled; changed = true end
    if ventilation.powerAllocated ~= powerAllocated then ventilation.powerAllocated = powerAllocated; changed = true end
    if ventilation.operating ~= operating then ventilation.operating = operating; changed = true end
    if ventilation.condition ~= condition then ventilation.condition = condition; changed = true end
    if ventilation.filterRemaining ~= filterRemaining then ventilation.filterRemaining = filterRemaining; changed = true end
    if ventilation.co2 ~= co2 then ventilation.co2 = co2; changed = true end
    if ventilation.externalContamination ~= external then ventilation.externalContamination = external; changed = true end
    if ventilation.internalContamination ~= internal then ventilation.internalContamination = internal; changed = true end
    if ventilation.recirculationUnlocked ~= recirculation then ventilation.recirculationUnlocked = recirculation; changed = true end
    if ventilation.status ~= status then ventilation.status = status; changed = true end

    return changed
end

local function normalizeAuditLog(state)
    local cleaned = {}
    local maxId = 0
    local source = state.auditLog
    local first = math.max(1, #source - Constants.MAX_AUDIT_LOG_ENTRIES + 1)
    local changed = first > 1

    for index = first, #source do
        local entry = source[index]
        if type(entry) == "table" then
            local id = math.max(1, math.floor(Util.numberOr(entry.id, maxId + 1, 1, 2147483647)))
            maxId = math.max(maxId, id)
            cleaned[#cleaned + 1] = {
                id = id,
                worldAgeHours = Util.numberOr(entry.worldAgeHours, 0, 0, 1000000000),
                category = type(entry.category) == "string" and entry.category or "system",
                message = type(entry.message) == "string" and entry.message or "invalid legacy log entry",
                actor = type(entry.actor) == "string" and entry.actor or "system",
            }
        else
            changed = true
        end
    end

    if #cleaned ~= #source then changed = true end
    if changed then state.auditLog = cleaned end
    local nextId = math.max(state.nextAuditLogId, maxId + 1)
    if state.nextAuditLogId ~= nextId then
        state.nextAuditLogId = nextId
        changed = true
    end
    return changed
end

function StateSchema.prepare(state, isNewGame)
    local defaults = StateSchema.createDefault()
    local changes = {}
    local changed = false

    local oldVersion = tonumber(state.version) or 0
    if oldVersion > Constants.CURRENT_STATE_VERSION then
        error("Bunker Campaign state version " .. tostring(oldVersion) .. " is newer than supported version " .. tostring(Constants.CURRENT_STATE_VERSION))
    end

    if oldVersion < 1 then
        table.insert(changes, "state migration 0 -> 1")
        changed = true
    end
    if oldVersion < 2 then
        table.insert(changes, "state migration 1 -> 2: water module")
        changed = true
    end
    if oldVersion < 3 then
        table.insert(changes, "state migration 2 -> 3: server power system")
        changed = true
    end
    if oldVersion < 4 then
        table.insert(changes, "state migration 3 -> 4: decontamination power consumer")
        changed = true
    end
    if oldVersion < 5 then
        table.insert(changes, "state migration 4 -> 5: decontamination backup-power priority")
        changed = true
    end

    if copyMissing(state, {
        campaignId = defaults.campaignId,
        revision = defaults.revision,
        createdAtWorldAgeHours = defaults.createdAtWorldAgeHours,
        lastUpdatedWorldAgeHours = defaults.lastUpdatedWorldAgeHours,
        nextAuditLogId = defaults.nextAuditLogId,
    }) then changed = true end

    if ensureTable(state, "bunker") then changed = true end
    if copyMissing(state.bunker, {
        contamination = defaults.bunker.contamination,
        temperature = defaults.bunker.temperature,
        sealed = defaults.bunker.sealed,
    }) then changed = true end
    if ensureTable(state.bunker, "modules") then changed = true end
    if ensureTable(state.bunker.modules, "power") then changed = true end
    if PowerSimulation.normalize(state.bunker.modules.power) then changed = true end
    if oldVersion < 5 then
        state.bunker.modules.power.consumers.decontamination.priority =
            defaults.bunker.modules.power.consumers.decontamination.priority
    end
    if ensureTable(state.bunker.modules, "ventilation") then changed = true end
    if normalizeVentilation(state.bunker.modules.ventilation) then changed = true end
    if ensureTable(state.bunker.modules, "water") then changed = true end
    if normalizeWater(state.bunker.modules.water) then changed = true end
    if ensureTable(state, "auditLog") then changed = true end

    local campaignId = type(state.campaignId) == "string" and state.campaignId or defaults.campaignId
    local revision = math.max(0, math.floor(Util.numberOr(state.revision, 0, 0, 2147483647)))
    local createdAt = Util.numberOr(state.createdAtWorldAgeHours, defaults.createdAtWorldAgeHours, 0, 1000000000)
    local updatedAt = Util.numberOr(state.lastUpdatedWorldAgeHours, defaults.lastUpdatedWorldAgeHours, 0, 1000000000)
    local nextLogId = math.max(1, math.floor(Util.numberOr(state.nextAuditLogId, 1, 1, 2147483647)))
    local bunkerContamination = Util.numberOr(state.bunker.contamination, defaults.bunker.contamination, 0, 1)
    local bunkerTemperature = Util.numberOr(state.bunker.temperature, defaults.bunker.temperature, -100, 100)
    local bunkerSealed = Util.booleanOr(state.bunker.sealed, defaults.bunker.sealed)

    if state.campaignId ~= campaignId then state.campaignId = campaignId; changed = true end
    if state.revision ~= revision then state.revision = revision; changed = true end
    if state.createdAtWorldAgeHours ~= createdAt then state.createdAtWorldAgeHours = createdAt; changed = true end
    if state.lastUpdatedWorldAgeHours ~= updatedAt then state.lastUpdatedWorldAgeHours = updatedAt; changed = true end
    if state.nextAuditLogId ~= nextLogId then state.nextAuditLogId = nextLogId; changed = true end
    if state.bunker.contamination ~= bunkerContamination then state.bunker.contamination = bunkerContamination; changed = true end
    if state.bunker.temperature ~= bunkerTemperature then state.bunker.temperature = bunkerTemperature; changed = true end
    if state.bunker.sealed ~= bunkerSealed then state.bunker.sealed = bunkerSealed; changed = true end
    if normalizeAuditLog(state) then changed = true end
    state.version = Constants.CURRENT_STATE_VERSION

    if isNewGame then table.insert(changes, "new campaign state initialized") end
    return changed, changes
end

BunkerCampaign.StateSchema = StateSchema
return StateSchema
