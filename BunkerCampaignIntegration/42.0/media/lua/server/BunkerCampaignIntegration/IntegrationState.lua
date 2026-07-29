if isClient() then return end

require "BunkerCampaign/CampaignState"
require "BunkerCampaign/Util"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignIntegration/ZoneSampler"
require "BunkerCampaignIntegration/WaterpipesAdapter"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local CampaignState = BunkerCampaign.CampaignState
local Util = BunkerCampaign.Util
local Constants = BunkerCampaignIntegration.Constants
local ZoneSampler = BunkerCampaignIntegration.ZoneSampler
local WaterpipesAdapter = BunkerCampaignIntegration.WaterpipesAdapter
local IntegrationState = {
    data = nil,
    powerListenerRegistered = false,
}
local getArkState

local function prepare(data)
    if tonumber(data.version) and tonumber(data.version) > Constants.STATE_VERSION then
        error("Bunker Campaign integration state is newer than this adapter")
    end

    if type(data.theArk) ~= "table" then data.theArk = {} end
    if type(data.toxicZones) ~= "table" then data.toxicZones = {} end
    if type(data.toxicZones.zones) ~= "table" then data.toxicZones.zones = {} end
    if type(data.waterpipes) ~= "table" then data.waterpipes = {} end

    data.theArk.initialized = data.theArk.initialized == true
    data.theArk.powerInitialized = data.theArk.powerInitialized == true
    data.theArk.lastMirroredRevision = math.floor(Util.numberOr(data.theArk.lastMirroredRevision, -1, -1, 2147483647))
    data.toxicZones.initialized = data.toxicZones.initialized == true
    data.toxicZones.sourceCount = math.floor(Util.numberOr(data.toxicZones.sourceCount, 0, 0, Constants.MAX_IMPORTED_ZONES * 100))
    data.toxicZones.rejectedCount = math.floor(Util.numberOr(data.toxicZones.rejectedCount, 0, 0, Constants.MAX_IMPORTED_ZONES * 100))
    data.waterpipes.initialized = data.waterpipes.initialized == true
    data.version = Constants.STATE_VERSION
end

local function arkPercent(value, fallback)
    if not Util.isFiniteNumber(value) then return fallback end
    return Util.clamp(value / 100, 0, 1)
end

local function importArkPowerOnce()
    local integration = IntegrationState.data
    local campaign = CampaignState.get()
    local ark = getArkState()
    if integration.theArk.powerInitialized or not campaign then return end

    local power = campaign.bunker.modules.power
    local arkGenerators = type(ark.generators) == "table" and ark.generators or {}
    for _, id in ipairs({ "main", "backup" }) do
        local source = arkGenerators[id]
        local target = power.generators[id]
        if type(source) == "table" and target then
            target.requested = Util.booleanOr(source.active, target.requested)
            target.fuel = arkPercent(source.fuel, target.fuel)
            target.condition = arkPercent(source.condition, target.condition)
            target.coolant = arkPercent(source.coolant, target.coolant)
            target.lubricant = arkPercent(source.lubricant, target.lubricant)
        end
    end
    if type(ark.ventilation) == "table" then
        power.consumers.ventilation.requested = Util.booleanOr(ark.ventilation.active, power.consumers.ventilation.requested)
    end
    if type(ark.waterpump) == "table" then
        power.consumers.water.requested = Util.booleanOr(ark.waterpump.active, power.consumers.water.requested)
    end

    integration.theArk.powerInitialized = true
    CampaignState.recalculatePower(0, "TheArk adapter")
    CampaignState.touch()
    CampaignState.appendLog("integration", "imported initial generators and power requests from The Ark", "TheArk adapter")
end

getArkState = function()
    return ModData.getOrCreate(Constants.THE_ARK_STATE_KEY)
end

local function importArkVentilationOnce()
    local integration = IntegrationState.data
    local campaign = CampaignState.get()
    local ark = getArkState()
    if integration.theArk.initialized or not campaign or type(ark.ventilation) ~= "table" then return end

    local source = ark.ventilation
    local target = campaign.bunker.modules.ventilation
    target.enabled = Util.booleanOr(source.active, target.enabled)
    target.co2 = Util.numberOr(source.co2, target.co2, BunkerCampaign.Constants.VENTILATION.MIN_CO2, BunkerCampaign.Constants.VENTILATION.MAX_CO2)
    if Util.isFiniteNumber(source.filter) then
        target.filterRemaining = Util.clamp(source.filter / 100, 0, 1)
    end

    integration.theArk.initialized = true
    CampaignState.touch()
    CampaignState.appendLog("integration", "imported initial ventilation from The Ark", "TheArk adapter")
end

local function importToxicZones(actor)
    local raw = ModData.getOrCreate(Constants.TOXIC_ZONES_STATE_KEY)
    local zones, sourceCount, rejectedCount = ZoneSampler.sanitize(raw)
    local target = IntegrationState.data.toxicZones
    target.zones = zones
    target.sourceCount = sourceCount
    target.rejectedCount = rejectedCount
    target.initialized = true
    target.lastImportedWorldAgeHours = Util.worldAgeHours()

    CampaignState.appendLog(
        "integration",
        "imported Toxic Zones: accepted=" .. tostring(#zones) .. " rejected=" .. tostring(rejectedCount),
        actor or "ToxicZones adapter"
    )
end

local function updateExternalContamination()
    local ark = getArkState()
    local zones = IntegrationState.data.toxicZones.zones
    local value, activeCount, toxicCount = ZoneSampler.sampleAirIntakes(zones, ark.airintakes)
    IntegrationState.data.toxicZones.lastActiveIntakes = activeCount
    IntegrationState.data.toxicZones.lastToxicIntakes = toxicCount
    CampaignState.setExternalContamination(value, "ToxicZones adapter")
end

local function mirrorToArk()
    local campaign = CampaignState.get()
    local ark = getArkState()
    if not campaign or type(ark.ventilation) ~= "table" then return end

    local source = campaign.bunker.modules.ventilation
    local target = ark.ventilation
    target.active = source.enabled
    target.co2 = source.co2
    target.filter = source.filterRemaining * 100
    local power = campaign.bunker.modules.power
    if type(ark.generators) ~= "table" then ark.generators = {} end
    for _, id in ipairs({ "main", "backup" }) do
        local generator = power.generators[id]
        if generator then
            if type(ark.generators[id]) ~= "table" then ark.generators[id] = {} end
            local legacy = ark.generators[id]
            legacy.active = generator.requested
            legacy.fuel = generator.fuel * 100
            legacy.condition = generator.condition * 100
            legacy.coolant = generator.coolant * 100
            legacy.lubricant = generator.lubricant * 100
            legacy.powerUsing = generator.loadKw
        end
    end
    IntegrationState.data.theArk.lastMirroredRevision = campaign.revision
end

local function syncWaterpipes()
    local gmd = ModData.getOrCreate(Constants.WATERPIPES_STATE_KEY)
    local ark = getArkState()
    local campaign = CampaignState.get()
    local power = campaign and campaign.bunker.modules.power or nil
    local waterConsumer = power and power.consumers.water or nil
    local activeDefault = waterConsumer and waterConsumer.requested and waterConsumer.allocated
    if not waterConsumer then activeDefault = type(ark.waterpump) ~= "table" or ark.waterpump.active ~= false end
    local pump, changed = WaterpipesAdapter.ensureBunkerPump(
        gmd,
        WaterpipesAdapter.isPhysicalPumpLoaded(),
        activeDefault
    )
    if WaterpipesAdapter.ensureBunkerInfrastructure(gmd) then changed = true end

    if changed and type(TransmitWPModData) == "function" then TransmitWPModData() end

    local snapshot = WaterpipesAdapter.sample(gmd)
    CampaignState.setWaterSnapshot(snapshot, "Waterpipes adapter")
    IntegrationState.data.waterpipes.initialized = pump ~= nil
    IntegrationState.data.waterpipes.lastPumpFound = pump ~= nil
    IntegrationState.data.waterpipes.lastFlowPerMinute = snapshot.flowPerMinute

    if pump then
        if type(ark.waterpump) ~= "table" then ark.waterpump = {} end
        ark.waterpump.x = Constants.BUNKER_WATER_PUMP.x
        ark.waterpump.y = Constants.BUNKER_WATER_PUMP.y
        ark.waterpump.z = Constants.BUNKER_WATER_PUMP.z
        ark.waterpump.active = waterConsumer and waterConsumer.requested or pump.active == true
        ark.waterpump.condition = snapshot.pumpCondition * 100
        ark.waterpump.filter = snapshot.filterRemaining * 100
        ark.waterpump.source = snapshot.source
    end
end

function IntegrationState.snapshot()
    local data = IntegrationState.data
    if not data then return nil end
    return {
        version = data.version,
        theArk = {
            initialized = data.theArk.initialized,
            powerInitialized = data.theArk.powerInitialized,
            lastMirroredRevision = data.theArk.lastMirroredRevision,
        },
        toxicZones = {
            initialized = data.toxicZones.initialized,
            acceptedCount = #data.toxicZones.zones,
            sourceCount = data.toxicZones.sourceCount,
            rejectedCount = data.toxicZones.rejectedCount,
            activeIntakes = data.toxicZones.lastActiveIntakes or 0,
            toxicIntakes = data.toxicZones.lastToxicIntakes or 0,
        },
        waterpipes = {
            initialized = data.waterpipes.initialized,
            pumpFound = data.waterpipes.lastPumpFound == true,
            flowPerMinute = data.waterpipes.lastFlowPerMinute or 0,
        },
    }
end

local function sendStatus(player)
    if player and isServer() then
        sendServerCommand(player, Constants.NETWORK_MODULE, "integrationStatus", IntegrationState.snapshot())
    end
end

function IntegrationState.initialize(isNewGame)
    local data = ModData.getOrCreate(Constants.STATE_KEY)
    prepare(data)
    IntegrationState.data = data

    if not IntegrationState.powerListenerRegistered then
        CampaignState.addPowerListener(syncWaterpipes)
        IntegrationState.powerListenerRegistered = true
    end

    importArkVentilationOnce()
    importArkPowerOnce()
    if not data.toxicZones.initialized then importToxicZones("server initialization") end
    updateExternalContamination()
    mirrorToArk()
    syncWaterpipes()

    print("[BunkerCampaignIntegration] ready zones=" .. tostring(#data.toxicZones.zones))
end

function IntegrationState.updateOneMinute()
    if not IntegrationState.data or not CampaignState.get() then return end
    updateExternalContamination()
    mirrorToArk()
    syncWaterpipes()
end

function IntegrationState.onClientCommand(module, command, player, args)
    if module ~= Constants.NETWORK_MODULE then return end

    if command == "requestStatus" then
        sendStatus(player)
        return
    end

    if command == "refreshToxicZones" then
        if not player or not player:isAccessLevel("admin") then
            CampaignState.appendLog("security", "rejected Toxic Zones refresh", player and player:getUsername() or "unknown")
            if player and isServer() then
                sendServerCommand(player, Constants.NETWORK_MODULE, "commandError", { code = "admin_required" })
            end
            return
        end

        importToxicZones(player:getUsername())
        updateExternalContamination()
        mirrorToArk()
        sendStatus(player)
        return
    end

    CampaignState.appendLog("security", "rejected unknown integration command " .. tostring(command), player and player:getUsername() or "unknown")
end

Events.OnInitGlobalModData.Add(IntegrationState.initialize)
Events.EveryOneMinute.Add(IntegrationState.updateOneMinute)
Events.OnClientCommand.Add(IntegrationState.onClientCommand)

BunkerCampaignIntegration.IntegrationState = IntegrationState
return IntegrationState
