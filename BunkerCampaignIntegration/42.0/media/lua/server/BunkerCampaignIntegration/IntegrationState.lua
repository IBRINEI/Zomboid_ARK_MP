if isClient() then return end

require "BunkerCampaign/CampaignState"
require "BunkerCampaign/Util"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignIntegration/ZoneSampler"
require "BunkerCampaignIntegration/WaterpipesAdapter"
require "BunkerCampaignIntegration/DecontaminationModel"
require "BunkerCampaignArkMP/Constants"
require "BunkerCampaignToxicMP/Server"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local CampaignState = BunkerCampaign.CampaignState
local Util = BunkerCampaign.Util
local Constants = BunkerCampaignIntegration.Constants
local ZoneSampler = BunkerCampaignIntegration.ZoneSampler
local WaterpipesAdapter = BunkerCampaignIntegration.WaterpipesAdapter
local DecontaminationModel = BunkerCampaignIntegration.DecontaminationModel
local ToxicServer = BunkerCampaignToxicMP.Server
local IntegrationState = {
    data = nil,
    powerListenerRegistered = false,
    lifeSupportRegistered = false,
    toxicProviderRegistered = false,
    toxicZoneListenerRegistered = false,
}
local getArkState

local function bunkerAirContamination(player)
    if not player then return 0 end
    local definition = BunkerCampaign.RoomRegistry.find(player:getX(), player:getY(), player:getZ())
    local campaign = CampaignState.get()
    local ventilation = campaign and campaign.bunker.modules.ventilation
    local room = definition and ventilation and ventilation.rooms[definition.id]
    local contamination = room and room.contamination or 0
    local coreConstants = BunkerCampaign.Constants
    local cutoff = coreConstants and coreConstants.VENTILATION
        and coreConstants.VENTILATION.AIRBORNE_TRACE_CUTOFF or 0
    return contamination < cutoff and 0 or contamination
end

local function roomId(name)
    local id = tostring(name or "room"):gsub("(%l)(%u)", "%1_%2"):gsub("[^%w]+", "_")
    return string.lower(id)
end

local function roomKind(name)
    if name == "Entrance" or name == "DecontaminationChamber" then return "airlock" end
    if name == "Generator" or name == "AirVentRoom" or name == "ServiceTunnels" then return "technical" end
    if name == "Corridor" then return "circulation" end
    return "habitable"
end

local function boundsAdjacent(left, right)
    if left.z ~= right.z then return false end
    local xOverlap = left.x1 <= right.x2 + 1 and right.x1 <= left.x2 + 1
    local yOverlap = left.y1 <= right.y2 + 1 and right.y1 <= left.y2 + 1
    return xOverlap and yOverlap
end

local function roomFootprints(definition)
    return type(definition.regions) == "table" and #definition.regions > 0
        and definition.regions or {definition.bounds}
end

local function footprintsAdjacent(left, right)
    for _, leftRegion in ipairs(roomFootprints(left)) do
        for _, rightRegion in ipairs(roomFootprints(right)) do
            if boundsAdjacent(leftRegion, rightRegion) then return true end
        end
    end
    return false
end

local function geometryBounds(regions)
    if type(regions) ~= "table" or #regions == 0 then return nil end
    local result = {
        x1=regions[1].x1, x2=regions[1].x2,
        y1=regions[1].y1, y2=regions[1].y2, z=regions[1].z,
    }
    for _, region in ipairs(regions) do
        result.x1, result.x2 = math.min(result.x1, region.x1), math.max(result.x2, region.x2)
        result.y1, result.y2 = math.min(result.y1, region.y1), math.max(result.y2, region.y2)
    end
    return result
end

local function registerArkRooms()
    if type(BWOARooms) ~= "table" then return 0 end
    local definitions = {}
    for name, room in pairs(BWOARooms) do
        if name ~= "Exterior" and type(room) == "table" then
            if type(room.Init) == "function" then pcall(room.Init) end
            local geometry = Constants.ROOM_GEOMETRY[name]
            local regions = geometry and geometry.regions or nil
            local bounds = Util.isFiniteNumber(room.x1) and Util.isFiniteNumber(room.x2)
                and Util.isFiniteNumber(room.y1) and Util.isFiniteNumber(room.y2)
                and Util.isFiniteNumber(room.z)
                and {x1=room.x1, x2=room.x2, y1=room.y1, y2=room.y2, z=room.z}
                or geometryBounds(regions)
            if bounds and bounds.z < 0 then
                definitions[#definitions + 1] = {
                    id=roomId(name),
                    label=type(room.name) == "string" and room.name or name,
                    kind=roomKind(name),
                    bounds=bounds,
                    regions=regions,
                    vents=type(room.vents) == "table" and room.vents or {},
                    ventWeight=math.max(0.25, #(type(room.vents) == "table" and room.vents or {})),
                    leakRate=roomKind(name) == "airlock" and 0.008 or 0.002,
                    connections={},
                }
            end
        end
    end
    table.sort(definitions, function(left, right) return left.id < right.id end)
    for leftIndex, left in ipairs(definitions) do
        for rightIndex = leftIndex + 1, #definitions do
            local right = definitions[rightIndex]
            if footprintsAdjacent(left, right) then
                left.connections[#left.connections + 1] = right.id
                right.connections[#right.connections + 1] = left.id
            end
        end
    end
    local accepted = 0
    for _, definition in ipairs(definitions) do
        if CampaignState.registerRoom(definition) then accepted = accepted + 1 end
    end
    return accepted
end

local function prepare(data)
    if tonumber(data.version) and tonumber(data.version) > Constants.STATE_VERSION then
        error("Bunker Campaign integration state is newer than this adapter")
    end

    if type(data.theArk) ~= "table" then data.theArk = {} end
    if type(data.toxicZones) ~= "table" then data.toxicZones = {} end
    if type(data.toxicZones.zones) ~= "table" then data.toxicZones.zones = {} end
    if type(data.waterpipes) ~= "table" then data.waterpipes = {} end
    if type(data.decontamination) ~= "table" then data.decontamination = DecontaminationModel.createDefault() end
    DecontaminationModel.normalize(data.decontamination)

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
    target.requestedMode = target.enabled and "external_filtration" or "off"
    target.co2 = Util.numberOr(source.co2, target.co2, BunkerCampaign.Constants.VENTILATION.MIN_CO2, BunkerCampaign.Constants.VENTILATION.MAX_CO2)
    for _, room in pairs(target.rooms or {}) do room.co2 = target.co2 end
    if Util.isFiniteNumber(source.filter) then
        target.filterRemaining = Util.clamp(source.filter / 100, 0, 1)
        target.filterBank.remaining = target.filterRemaining
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
    local detailed, activeCount, toxicCount = ZoneSampler.sampleAirIntakesDetailed(zones, ark.airintakes)
    local value = activeCount > 0 and toxicCount / activeCount or 0
    IntegrationState.data.toxicZones.lastActiveIntakes = activeCount
    IntegrationState.data.toxicZones.lastToxicIntakes = toxicCount
    local campaign = CampaignState.get()
    local ventilation = campaign and campaign.bunker.modules.ventilation
    if ventilation then
        for id, contamination in pairs(detailed) do
            if ventilation.intakes[id] then ventilation.intakes[id].externalContamination = contamination end
        end
    end
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

local function doorStateAt(definition)
    local cell = getCell and getCell() or nil
    local square = cell and cell:getGridSquare(definition.x, definition.y, definition.z) or nil
    if not square or not square:getChunk() or not square.getObjects then
        return { id=definition.id, label=definition.label, x=definition.x, y=definition.y,
            z=definition.z, loaded=false, open=false }
    end
    local objects = square:getObjects()
    for index = 0, objects:size() - 1 do
        local object = objects:get(index)
        local isDoor = false
        if type(instanceof) == "function" then
            isDoor = instanceof(object, "IsoDoor")
                or (instanceof(object, "IsoThumpable") and object.isDoor and object:isDoor())
        elseif object and object.IsOpen then
            isDoor = true
        end
        if isDoor and object.IsOpen then
            return {
                id=definition.id, label=definition.label, x=definition.x, y=definition.y, z=definition.z,
                loaded=true, open=object:IsOpen() == true,
            }
        end
    end
    return { id=definition.id, label=definition.label, x=definition.x, y=definition.y,
        z=definition.z, loaded=true, open=false, missing=true }
end

local function sampleEntryPath(zones)
    local definitions = Constants.ENTRY_DOORS
    local result = {
        sampled=#definitions > 0,
        breached=false,
        allOpen=false,
        openCount=0,
        loadedCount=0,
        total=#definitions,
        externalContamination=0,
        doors={},
    }
    for _, definition in ipairs(definitions) do
        local state = doorStateAt(definition)
        result.doors[#result.doors + 1] = state
        if state.loaded then
            result.loadedCount = result.loadedCount + 1
            if state.open then result.openCount = result.openCount + 1 end
        end
    end
    result.allOpen = result.total > 0 and result.loadedCount == result.total
        and result.openCount == result.total
    result.breached = result.allOpen
    local exterior = Constants.DECONTAMINATION.EXTERIOR_TEST
    result.externalContamination = ZoneSampler.isPointToxic(zones, exterior.x, exterior.y, exterior.z) and 1 or 0
    return result
end

local function syncWaterpipes()
    local gmd = ModData.getOrCreate(Constants.WATERPIPES_STATE_KEY)
    local ark = getArkState()
    local campaign = CampaignState.get()
    local power = campaign and campaign.bunker.modules.power or nil
    local water = campaign and campaign.bunker.modules.water or nil
    local waterConsumer = power and power.consumers.water or nil
    local activeDefault = water and water.requested and waterConsumer and waterConsumer.allocated
    if not waterConsumer then activeDefault = type(ark.waterpump) ~= "table" or ark.waterpump.active ~= false end
    local pump, changed = WaterpipesAdapter.ensureBunkerPump(
        gmd,
        WaterpipesAdapter.isPhysicalPumpLoaded(),
        activeDefault
    )
    if WaterpipesAdapter.ensureBunkerInfrastructure(gmd) then changed = true end
    if pump and water then
        local selected = water.sources and water.sources[water.selectedSource]
        local sourceAvailable = selected and selected.enabled
            and (selected.renewable or (tonumber(selected.availableLiters) or 0) > 0)
        local shouldOperate = water.requested and water.powerAllocated and sourceAvailable
            and (tonumber(pump.efficiency) or 0) > 5 and pump.burn ~= true
        if WaterpipesAdapter.setBunkerPumpOperating(
            gmd, shouldOperate, water.selectedSource, water.treatment and water.treatment.bypass
        ) then changed = true end
    end

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

local function sampleLifeSupport(state, context)
    if not IntegrationState.data then return end
    local ark = getArkState()
    local zones = IntegrationState.data.toxicZones.zones
    local detailed, activeCount, toxicCount = ZoneSampler.sampleAirIntakesDetailed(zones, ark.airintakes)
    context.intakeContamination = detailed
    context.externalContamination = activeCount > 0 and toxicCount / activeCount or 0
    context.entryPath = sampleEntryPath(zones)
    IntegrationState.data.toxicZones.lastActiveIntakes = activeCount
    IntegrationState.data.toxicZones.lastToxicIntakes = toxicCount

    local ventilation = state.bunker.modules.ventilation
    local ordered = {}
    for _, intake in pairs(type(ark.airintakes) == "table" and ark.airintakes or {}) do
        if type(intake) == "table" then ordered[#ordered + 1] = intake end
    end
    table.sort(ordered, function(left, right)
        if left.x ~= right.x then return left.x < right.x end
        if left.y ~= right.y then return left.y < right.y end
        return (left.z or 0) < (right.z or 0)
    end)
    for index, intake in ipairs(ordered) do
        local target = ventilation.intakes["intake_" .. tostring(index)]
        if target then
            target.x, target.y, target.z = intake.x, intake.y, intake.z
            target.broken = intake.broken == true
            target.condition = target.broken and 0 or Util.numberOr(intake.condition, target.condition, 0, 1)
        end
    end

    local gmd = ModData.getOrCreate(Constants.WATERPIPES_STATE_KEY)
    local water = state.bunker.modules.water
    local pump, changed = WaterpipesAdapter.ensureBunkerPump(
        gmd, WaterpipesAdapter.isPhysicalPumpLoaded(), water.requested and water.powerAllocated
    )
    if WaterpipesAdapter.ensureBunkerInfrastructure(gmd) then changed = true end
    if changed and type(TransmitWPModData) == "function" then TransmitWPModData() end
    context.waterPhysical = WaterpipesAdapter.sample(gmd)
    local filterChanged, filterUse = WaterpipesAdapter.consumeTreatmentFilter(
        gmd, context.waterPhysical.flowPerMinute)
    if filterChanged then
        if type(TransmitWPModData) == "function" then TransmitWPModData() end
        context.waterPhysical = WaterpipesAdapter.sample(gmd)
    end
    context.waterPhysical.filterUsePerMinute = filterUse
    IntegrationState.data.waterpipes.initialized = pump ~= nil
    IntegrationState.data.waterpipes.lastPumpFound = pump ~= nil
    IntegrationState.data.waterpipes.lastFlowPerMinute = context.waterPhysical.flowPerMinute
end

local function actuateLifeSupport(state, context)
    local gmd = ModData.getOrCreate(Constants.WATERPIPES_STATE_KEY)
    local water = state.bunker.modules.water
    local selected = water.sources and water.sources[water.selectedSource]
    local sourceAvailable = selected and selected.enabled
        and (selected.renewable or (tonumber(selected.availableLiters) or 0) > 0)
    local shouldOperate = water.requested and water.powerAllocated and sourceAvailable
        and water.pump.condition > 0.05
    local changed = WaterpipesAdapter.setBunkerPumpOperating(
        gmd, shouldOperate, water.selectedSource, water.treatment.bypass
    )
    if changed and type(TransmitWPModData) == "function" then TransmitWPModData() end
    context.waterPhysical = WaterpipesAdapter.sample(gmd)
end

local function raiseStat(stats, stat, target, step)
    if not stats or not stat then return end
    local current = stats:get(stat)
    if current < target then stats:set(stat, math.min(target, current + step)) end
end

local function lowerStat(stats, stat, target, step)
    if not stats or not stat then return end
    local current = stats:get(stat)
    if current > target then stats:set(stat, math.max(target, current - step)) end
end

local function applyCo2Effects()
    if not getOnlinePlayers or type(CharacterStat) ~= "table" then return end
    local campaign = CampaignState.get()
    local ventilation = campaign and campaign.bunker.modules.ventilation
    if not ventilation then return end
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        local definition = player and BunkerCampaign.RoomRegistry.find(player:getX(), player:getY(), player:getZ())
        local room = definition and ventilation.rooms[definition.id]
        local co2 = tonumber(room and room.co2) or 0
        if player and not player:isDead() and co2 > 1000 then
            pcall(function()
                local stats = player:getStats()
                if co2 > 1000 then raiseStat(stats, CharacterStat.FATIGUE, 0.40, 0.02) end
                if co2 > 2000 then raiseStat(stats, CharacterStat.PAIN, 50, 1) end
                if co2 > 5000 then
                    raiseStat(stats, CharacterStat.FOOD_SICKNESS, 55, 1)
                    lowerStat(stats, CharacterStat.ENDURANCE, 0.70, 0.03)
                end
                if co2 > 10000 then
                    raiseStat(stats, CharacterStat.INTOXICATION, 80, 3)
                    raiseStat(stats, CharacterStat.PANIC, 50, 5)
                end
                if co2 > 30000 then
                    local bodyDamage = player:getBodyDamage()
                    bodyDamage:setOverallBodyHealth(math.max(0,
                        bodyDamage:getOverallBodyHealth() - math.min(12, (co2 - 30000) / 5000)))
                end
            end)
        end
    end
end

local function finishLifeSupport()
    mirrorToArk()
    applyCo2Effects()
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
        decontamination = {
            status = data.decontamination.status,
            reagentUnits = data.decontamination.reagentUnits,
            roomContamination = data.decontamination.roomContamination,
            areas = data.decontamination.areas,
            activeCycle = data.decontamination.activeCycle,
            lastResult = data.decontamination.lastResult,
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

    local roomCount = registerArkRooms()

    if not IntegrationState.powerListenerRegistered then
        CampaignState.addPowerListener(syncWaterpipes)
        IntegrationState.powerListenerRegistered = true
    end
    if not IntegrationState.lifeSupportRegistered then
        CampaignState.addLifeSupportListener("sample", sampleLifeSupport)
        CampaignState.addLifeSupportListener("postPower", actuateLifeSupport)
        CampaignState.addLifeSupportListener("postSimulation", finishLifeSupport)
        IntegrationState.lifeSupportRegistered = true
    end
    if not IntegrationState.toxicProviderRegistered then
        ToxicServer.addAmbientProvider(bunkerAirContamination)
        IntegrationState.toxicProviderRegistered = true
    end
    if not IntegrationState.toxicZoneListenerRegistered and type(ToxicServer.addZoneListener) == "function" then
        ToxicServer.addZoneListener(function()
            IntegrationState.refreshToxicZones("ToxicMP zone change")
        end)
        IntegrationState.toxicZoneListenerRegistered = true
    end

    importArkVentilationOnce()
    importArkPowerOnce()
    if not data.toxicZones.initialized then importToxicZones("server initialization") end
    updateExternalContamination()
    mirrorToArk()
    syncWaterpipes()

    print("[BunkerCampaignIntegration] ready zones=" .. tostring(#data.toxicZones.zones)
        .. " rooms=" .. tostring(roomCount))
end

-- Kept as a deterministic compatibility hook for tests and admin diagnostics.
-- The live server uses CampaignState's phased life-support tick instead.
function IntegrationState.updateOneMinute()
    if not IntegrationState.data or not CampaignState.get() then return end
    updateExternalContamination()
    syncWaterpipes()
    mirrorToArk()
end

function IntegrationState.refreshToxicZones(actor)
    if not IntegrationState.data then return false end
    importToxicZones(actor or "integration refresh")
    updateExternalContamination()
    mirrorToArk()
    return true
end

function IntegrationState.onClientCommand(module, command, player, args)
    if module == "Commands" and command == "PumpMod" and type(args) == "table" then
        local pump = Constants.BUNKER_WATER_PUMP
        local isBunkerPump = math.floor(tonumber(args.x) or 0) == pump.x
            and math.floor(tonumber(args.y) or 0) == pump.y
            and math.floor(tonumber(args.z) or 0) == pump.z
        local nearby = player and math.abs(player:getX() - pump.x) <= 4
            and math.abs(player:getY() - pump.y) <= 4
            and math.floor(player:getZ()) == pump.z
        if isBunkerPump and (nearby or (player and player:isAccessLevel("admin"))) then
            local gmd = ModData.getOrCreate(Constants.WATERPIPES_STATE_KEY)
            local record = type(gmd.Pumps) == "table"
                and gmd.Pumps[tostring(pump.x) .. "-" .. tostring(pump.y) .. "-" .. tostring(pump.z)] or nil
            if type(record) == "table" then
                if args.efficiency ~= nil then
                    record.efficiency = Util.clamp(tonumber(args.efficiency) or record.efficiency or 0, 0, 100)
                end
                if args.filter ~= nil then
                    record.filter = Util.clamp(tonumber(args.filter) or record.filter or 0, 0, 100)
                    record.BunkerCampaignStoredFilter = nil
                    record.BunkerCampaignBypass = false
                end
                if type(args.burn) == "boolean" then record.burn = args.burn end
            end
            if type(args.active) == "boolean" then
                CampaignState.setConsumerRequested("water", args.active, player:getUsername())
            end
            syncWaterpipes()
        end
        return
    end
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
Events.OnClientCommand.Add(IntegrationState.onClientCommand)

BunkerCampaignIntegration.IntegrationState = IntegrationState
return IntegrationState
