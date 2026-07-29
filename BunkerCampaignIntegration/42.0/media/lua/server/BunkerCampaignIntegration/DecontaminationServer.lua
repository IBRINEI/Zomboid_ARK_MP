if isClient() then return end

require "BunkerCampaign/CampaignState"
require "BunkerCampaign/Util"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignIntegration/DecontaminationModel"
require "BunkerCampaignIntegration/WaterpipesAdapter"
require "BunkerCampaignToxicMP/Server"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local CampaignState = BunkerCampaign.CampaignState
local Util = BunkerCampaign.Util
local Constants = BunkerCampaignIntegration.Constants
local Model = BunkerCampaignIntegration.DecontaminationModel
local WaterpipesAdapter = BunkerCampaignIntegration.WaterpipesAdapter
local ToxicServer = BunkerCampaignToxicMP.Server
local Rules = Constants.DECONTAMINATION

local Server = {
    data = nil,
    lastTickMs = 0,
    lastStatusMs = 0,
}

local function actor(player)
    return player and player:getUsername() or "unknown"
end

local function isAdmin(player)
    return player and player:isAccessLevel("admin")
end

local function inside(bounds, player)
    if not player then return false end
    local z = math.floor(player:getZ())
    return z == bounds.z
        and player:getX() >= bounds.x1 and player:getX() <= bounds.x2
        and player:getY() >= bounds.y1 and player:getY() <= bounds.y2
end

local function inInteractionRange(player)
    return inside(Rules.INTERACTION, player)
end

local function zoneSide(player)
    if not player or math.floor(player:getZ()) ~= Rules.ROOM.z then return "remote" end
    if inside(Rules.ROOM, player) then return "chamber" end
    if player:getX() < Rules.ROOM.x1 then return "dirty" end
    if player:getX() > Rules.ROOM.x2 then return "clean" end
    return "remote"
end

local function findOnlinePlayer(username)
    if type(username) ~= "string" or not getOnlinePlayers then return nil end
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        if player and player:getUsername() == username then return player end
    end
    return nil
end

local function deconState()
    if Server.data then return Server.data end
    local integration = ModData.getOrCreate(Constants.STATE_KEY)
    if type(integration.decontamination) ~= "table" then integration.decontamination = Model.createDefault() end
    Server.data = Model.normalize(integration.decontamination)
    return Server.data
end

local function waterState()
    return ModData.getOrCreate(Constants.WATERPIPES_STATE_KEY)
end

local function powerConsumer()
    local campaign = CampaignState.get()
    local power = campaign and campaign.bunker and campaign.bunker.modules and campaign.bunker.modules.power
    return power and power.consumers and power.consumers.decontamination or nil
end

local function setPowerRequested(requested, username)
    local consumer = powerConsumer()
    if not consumer then return false end
    local ok = CampaignState.setConsumerRequested("decontamination", requested, username or "decontamination controller")
    return ok == true and powerConsumer() and powerConsumer().allocated == requested
end

local function firstReagent(player, mode)
    if not mode.inventoryReagent then return nil end
    local inventory = player and player:getInventory()
    if not inventory then return nil end
    for _, itemType in ipairs(mode.reagentTypes or {}) do
        local item = inventory:getFirstTypeRecurse(itemType)
        if item then return item end
    end
    return nil
end

local function consumeInventoryItem(player, item)
    if not player or not item then return false end
    if item.UseAndSync then
        item:UseAndSync()
        return true
    end
    if item.Use then
        item:Use()
        return true
    end
    local container = item:getContainer()
    if container then container:Remove(item); return true end
    return false
end

local function refreshWaterSnapshot(source)
    local gmd = waterState()
    if type(TransmitWPModData) == "function" then TransmitWPModData() end
    CampaignState.setWaterSnapshot(WaterpipesAdapter.sample(gmd), source or "decontamination controller")
end

local function snapshotFor(player)
    local state = deconState()
    local record = player and ToxicServer.getPlayerRecord(player) or nil
    local consumer = powerConsumer()
    return {
        status = state.status,
        reagentUnits = state.reagentUnits,
        roomContamination = state.roomContamination,
        areas = state.areas,
        activeCycle = state.activeCycle,
        lastResult = state.lastResult,
        cleanWaterLiters = WaterpipesAdapter.availableBunkerWater(waterState(), true),
        powerRequested = consumer and consumer.requested == true or false,
        powerAllocated = consumer and consumer.allocated == true or false,
        surfaceContamination = record and record.surfaceContamination or 0,
        gearContamination = record and record.gearContamination or 0,
        side = zoneSide(player),
        unsafeForCleanSide = record and (record.surfaceContamination or 0) >= BunkerCampaignToxicMP.Constants.SURFACE_DIRTY or false,
    }
end

local function sendStatus(player)
    if player and isServer() then
        sendServerCommand(player, Constants.DECON_NETWORK_MODULE, "deconStatus", snapshotFor(player))
    end
end

local function sendResult(player, ok, action, code)
    if player and isServer() then
        sendServerCommand(player, Constants.DECON_NETWORK_MODULE, "deconResult", {
            ok=ok == true,
            action=tostring(action or "unknown"),
            code=code,
        })
        sendStatus(player)
    end
end

local function startCycle(player, modeId)
    if not inInteractionRange(player) then return false, "decon_access_required" end
    local state = deconState()
    if state.activeCycle then return false, "cycle_active" end
    local mode = Rules.MODES[modeId]
    if not mode then return false, "unknown_mode" end

    local inventoryReagent = firstReagent(player, mode)
    local cleanWater = WaterpipesAdapter.availableBunkerWater(waterState(), true)
    local powerReady = true
    if mode.requiresPower then powerReady = setPowerRequested(true, actor(player)) end

    local ok, code = Model.precheck(modeId, {
        cleanWaterLiters=cleanWater,
        powerAllocated=powerReady,
        inventoryReagent=inventoryReagent ~= nil,
        mixerUnits=state.reagentUnits,
    })
    if not ok then
        if mode.requiresPower then setPowerRequested(false, actor(player)) end
        return false, code
    end

    local consumed = WaterpipesAdapter.consumeBunkerWater(waterState(), mode.waterLiters, true)
    if not consumed then
        if mode.requiresPower then setPowerRequested(false, actor(player)) end
        return false, "clean_water_changed"
    end

    if inventoryReagent then
        if not consumeInventoryItem(player, inventoryReagent) then
            if mode.requiresPower then setPowerRequested(false, actor(player)) end
            return false, "reagent_transaction_failed"
        end
    elseif mode.mixerUnits then
        state.reagentUnits = state.reagentUnits - mode.mixerUnits
    end

    local cycle = Model.start(state, modeId, actor(player), Util.worldAgeHours())
    if not cycle then
        if mode.requiresPower then setPowerRequested(false, actor(player)) end
        return false, "cycle_start_failed"
    end
    cycle.resources = {
        waterLiters=mode.waterLiters,
        mixerUnits=mode.mixerUnits or 0,
        inventoryReagent=inventoryReagent and inventoryReagent:getFullType() or nil,
        power=mode.requiresPower == true,
    }
    refreshWaterSnapshot("decontamination cycle")
    CampaignState.appendLog("decontamination", modeId .. " cycle started id=" .. tostring(cycle.id), actor(player))
    return true
end

local function finishCycle(player, cycle)
    local state = deconState()
    local mode = Rules.MODES[cycle.mode]
    if not player or not mode then return false end
    local ok = ToxicServer.cleanPlayer(player, mode.bodyRemoval, mode.gearRemoval, mode.onlyMostContaminated)
    if not ok then return false end
    state.roomContamination = math.max(0, state.roomContamination * (1 - mode.bodyRemoval))
    state.areas.chamber = math.max(0, state.areas.chamber * (1 - mode.bodyRemoval))
    if mode.requiresPower then setPowerRequested(false, cycle.username) end
    Model.finish(state, cycle.mode .. "_complete")
    CampaignState.appendLog("decontamination", cycle.mode .. " cycle completed id=" .. tostring(cycle.id), cycle.username)
    sendResult(player, true, "cycleComplete", nil)
    return true
end

local function loadReagent(player)
    if not inInteractionRange(player) then return false, "decon_access_required" end
    local state = deconState()
    if state.activeCycle then return false, "cycle_active" end
    if state.reagentUnits >= Rules.MAX_REAGENT_UNITS then return false, "mixer_full" end
    local inventory = player:getInventory()
    local item = inventory and inventory:getFirstTypeRecurse("Bandits.NBCTablets") or nil
    if not item then return false, "nbc_tablet_required" end
    if not consumeInventoryItem(player, item) then return false, "reagent_transaction_failed" end
    state.reagentUnits = math.min(Rules.MAX_REAGENT_UNITS, state.reagentUnits + Rules.TABLET_UNITS)
    CampaignState.appendLog("decontamination", "NBC mixer loaded to " .. tostring(state.reagentUnits), actor(player))
    return true
end

local function nativeTeleport(player, target)
    local native = false
    if GameServer and GameServer.sendTeleport then
        local ok = pcall(GameServer.sendTeleport, player, target.x, target.y, target.z)
        native = ok == true
    end
    if not native and player.teleportTo then pcall(player.teleportTo, player, target.x, target.y, target.z) end
    sendServerCommand(player, Constants.DECON_NETWORK_MODULE, "qaTeleport", {
        x=target.x, y=target.y, z=target.z, nativeTeleport=native,
    })
end

local function qaGiveSupplies(player)
    local inventory = player:getInventory()
    if not inventory then return false end
    for _ = 1, 3 do inventory:AddItem("Bandits.NBCTablets") end
    inventory:AddItem("Base.CleaningLiquid2")
    inventory:AddItem("Base.Bleach")
    return true
end

local function runQa(player, command, args)
    if not isAdmin(player) then return false, "admin_required" end
    if command == "qaTeleport" then
        local targetId = type(args) == "table" and args.target or nil
        local targets = {
            exterior=Rules.EXTERIOR_TEST,
            dirty=Rules.DIRTY_ENTRY,
            chamber=Rules.CHAMBER,
            clean=Rules.CLEAN_EXIT,
            reagent=Rules.REAGENT_STORAGE,
        }
        local target = targets[targetId]
        if not target then return false, "unknown_target" end
        if targetId == "exterior" then ToxicServer.ensureZone(Rules.TEST_ZONE_NAME, Rules.TEST_ZONE) end
        nativeTeleport(player, target)
        return true
    elseif command == "qaContaminate" then
        ToxicServer.setPlayerSurfaceContamination(player, 80, true)
        return true
    elseif command == "qaClean" then
        ToxicServer.setPlayerSurfaceContamination(player, 0, true)
        local state = deconState()
        state.roomContamination = 0
        state.areas.dirty = 0
        state.areas.chamber = 0
        state.areas.clean = 0
        return true
    elseif command == "qaGiveSupplies" then
        return qaGiveSupplies(player), "inventory_unavailable"
    elseif command == "qaFillWater" then
        local changed = WaterpipesAdapter.fillBunkerWater(waterState())
        refreshWaterSnapshot("QA water fill")
        return changed or WaterpipesAdapter.availableBunkerWater(waterState(), true) > 0, "no_bunker_storage"
    elseif command == "qaFinishCycle" then
        local cycle = deconState().activeCycle
        if not cycle then return false, "no_active_cycle" end
        cycle.remainingSeconds = 0
        return true
    elseif command == "qaCreateZone" then
        return ToxicServer.ensureZone(Rules.TEST_ZONE_NAME, Rules.TEST_ZONE)
    elseif command == "qaRemoveZone" then
        return ToxicServer.removeZone(Rules.TEST_ZONE_NAME)
    end
    return false, "unknown_qa_command"
end

function Server.initialize()
    local integration = ModData.getOrCreate(Constants.STATE_KEY)
    if type(integration.decontamination) ~= "table" then integration.decontamination = Model.createDefault() end
    Server.data = Model.normalize(integration.decontamination)
    local cycle = Server.data.activeCycle
    if cycle and Rules.MODES[cycle.mode] and Rules.MODES[cycle.mode].requiresPower then
        setPowerRequested(true, cycle.username)
    elseif powerConsumer() and powerConsumer().requested then
        setPowerRequested(false, "decontamination startup")
    end
    print("[BunkerCampaignDecontamination] server ready status=" .. tostring(Server.data.status))
end

function Server.update()
    local state = Server.data
    if not state then return end
    local now = getTimestampMs()
    if Server.lastTickMs == 0 then Server.lastTickMs = now; return end
    local elapsed = math.min(5, math.max(0, (now - Server.lastTickMs) / 1000))
    if elapsed < 0.25 then return end
    Server.lastTickMs = now

    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        local side = zoneSide(player)
        if side ~= "remote" then
            local record = ToxicServer.getPlayerRecord(player)
            local carried = math.max(record and record.surfaceContamination or 0, record and record.gearContamination or 0)
            state.areas[side] = math.max(state.areas[side] or 0, carried * 0.15)
            ToxicServer.applySurfaceContact(player, state.areas[side], math.min(0.10, elapsed * 0.01))
            if side == "chamber" then state.roomContamination = state.areas.chamber end
        end
    end

    local cycle = state.activeCycle
    if not cycle then return end
    local mode = Rules.MODES[cycle.mode]
    local canRun = not mode.requiresPower or (powerConsumer() and powerConsumer().allocated == true)
    local complete = Model.advance(state, elapsed, canRun)
    if now - Server.lastStatusMs >= 2000 then
        local owner = findOnlinePlayer(cycle.username)
        if owner then sendStatus(owner) end
        Server.lastStatusMs = now
    end
    if complete then
        local player = findOnlinePlayer(cycle.username)
        if not player then
            state.status = "paused"
            return
        end
        if player:isDead() then
            if mode.requiresPower then setPowerRequested(false, cycle.username) end
            Model.finish(state, "player_dead")
            sendResult(player, false, "cycleComplete", "player_dead")
            return
        end
        finishCycle(player, cycle)
    end
end

function Server.onClientCommand(module, command, player, args)
    if module ~= Constants.DECON_NETWORK_MODULE then return end
    if command == "requestStatus" then sendStatus(player); return end
    if command == "startCycle" then
        local mode = type(args) == "table" and args.mode or nil
        local ok, code = startCycle(player, mode)
        sendResult(player, ok, "startCycle", code)
        return
    end
    if command == "loadReagent" then
        local ok, code = loadReagent(player)
        sendResult(player, ok, command, code)
        return
    end
    if string.sub(tostring(command), 1, 2) == "qa" then
        local ok, code = runQa(player, command, args)
        sendResult(player, ok, command, ok and nil or code)
        return
    end
    CampaignState.appendLog("security", "rejected decontamination command " .. tostring(command), actor(player))
    sendResult(player, false, command, "unknown_command")
end

Events.OnInitGlobalModData.Add(Server.initialize)
if Events.OnTick then Events.OnTick.Add(Server.update) end
Events.OnClientCommand.Add(Server.onClientCommand)

BunkerCampaignIntegration.DecontaminationServer = Server
return Server
