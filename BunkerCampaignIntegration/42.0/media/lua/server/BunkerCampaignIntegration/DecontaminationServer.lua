require "BunkerCampaignIntegration/ManualWashActions"

if isClient() then return end

require "BunkerCampaign/CampaignState"
require "BunkerCampaign/Util"
require "BunkerCampaignIntegration/Constants"
require "BunkerCampaignIntegration/DecontaminationModel"
require "BunkerCampaignIntegration/WaterService"
require "BunkerCampaignIntegration/WaterTakeActionServerPatch"
require "BunkerCampaignToxicMP/Server"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local CampaignState = BunkerCampaign.CampaignState
local Util = BunkerCampaign.Util
local Constants = BunkerCampaignIntegration.Constants
local Model = BunkerCampaignIntegration.DecontaminationModel
local WaterService = BunkerCampaignIntegration.WaterService
local ToxicServer = BunkerCampaignToxicMP.Server
local ManualWashShared = BunkerCampaignIntegration.ManualWashShared
local Rules = Constants.DECONTAMINATION

local Server = {
    data = nil,
    lastTickMs = 0,
    lastStatusMs = 0,
    startingCycle = false,
}

local function actor(player)
    return player and player:getUsername() or "unknown"
end

ManualWashShared.getBodyContamination = function(player)
    local record = ToxicServer.getPlayerRecord(player)
    return tonumber(record and record.surfaceContamination) or 0
end

ManualWashShared.onVanillaComplete = function(player, target, item)
    if not player or player:isDead() then return false end
    if target == "body" then
        ToxicServer.cleanPlayer(player, 1, 0, false)
    elseif target == "item" and item then
        ToxicServer.cleanItem(player, item, 1)
    else
        return false
    end
    CampaignState.appendLog("decontamination",
        "vanilla manual wash target=" .. tostring(target), actor(player))
    return true
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

local function collectChamberParticipants()
    local participants = {}
    local seen = {}
    local players = getOnlinePlayers and getOnlinePlayers() or nil
    if not players then return participants end
    for index = 0, players:size() - 1 do
        local player = players:get(index)
        local username = player and player:getUsername() or nil
        if username and inside(Rules.ROOM, player) and not player:isDead() and not seen[username] then
            participants[#participants + 1] = username
            seen[username] = true
        end
    end
    return participants
end

local function includeCurrentParticipants(cycle)
    if type(cycle) ~= "table" then return end
    if type(cycle.participants) ~= "table" then cycle.participants = { cycle.username } end
    local seen = {}
    for _, username in ipairs(cycle.participants) do seen[username] = true end
    for _, username in ipairs(collectChamberParticipants()) do
        if not seen[username] then
            cycle.participants[#cycle.participants + 1] = username
            seen[username] = true
        end
    end
end

local function deconState()
    if Server.data then return Server.data end
    local integration = ModData.getOrCreate(Constants.STATE_KEY)
    if type(integration.decontamination) ~= "table" then integration.decontamination = Model.createDefault() end
    Server.data = Model.normalize(integration.decontamination)
    return Server.data
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

local function consumeWholeInventoryItem(item)
    local container = item and item:getContainer() or nil
    if not container then return false end
    container:Remove(item)
    if type(sendRemoveItemFromContainer) == "function" then
        sendRemoveItemFromContainer(container, item)
    end
    return true
end

local function collectInventoryItems(player, limit)
    local result = {}
    local containers = {}
    local root = player and player:getInventory() or nil
    if not root then return result end
    containers[1] = root
    local containerIndex = 1
    local maximum = math.max(1, tonumber(limit) or 100)
    while containerIndex <= #containers and #result < maximum do
        local container = containers[containerIndex]
        containerIndex = containerIndex + 1
        local items = container:getItems()
        for index = 0, items:size() - 1 do
            if #result >= maximum then break end
            local item = items:get(index)
            if item then
                result[#result + 1] = item
                if instanceof(item, "InventoryContainer")
                    and item:getModData().BunkerCampaignSealed ~= true then
                    containers[#containers + 1] = item:getInventory()
                end
            end
        end
    end
    return result
end

local function cleaningFluidPerUse()
    return math.max(0.001, tonumber(ZomboidGlobals and ZomboidGlobals.CleanStainCleaningFluidAmount) or 0.1)
end

local function manualAgentCapacity(item)
    if not item then return 0 end
    local fullType = item:getFullType()
    if fullType == "Base.Soap2" and instanceof(item, "DrainableComboItem") then
        return math.max(0, math.floor(tonumber(item:getCurrentUses()) or 0))
    end
    if fullType == "Base.CleaningLiquid2" or fullType == "Base.Bleach" then
        local fluid = item:getFluidContainer()
        return fluid and math.max(0, math.floor(fluid:getAmount() / cleaningFluidPerUse() + 0.0001)) or 0
    end
    return 0
end

local function manualAgents(player)
    local agents = {}
    local total = 0
    for _, item in ipairs(collectInventoryItems(player, 100)) do
        local capacity = manualAgentCapacity(item)
        if capacity > 0 then
            agents[#agents + 1] = { item=item, capacity=capacity }
            total = total + capacity
        end
    end
    return agents, total
end

local function consumeManualAgentUses(agents, required)
    local remaining = math.max(0, math.floor(tonumber(required) or 0))
    for _, entry in ipairs(agents) do
        if remaining <= 0 then break end
        local take = math.min(remaining, manualAgentCapacity(entry.item))
        if take > 0 then
            if entry.item:getFullType() == "Base.Soap2" then
                for _ = 1, take do entry.item:UseAndSync() end
            else
                local fluid = entry.item:getFluidContainer()
                local nextAmount = math.max(0, fluid:getAmount() - take * cleaningFluidPerUse())
                if nextAmount <= 0.001 then fluid:Empty() else fluid:adjustAmount(nextAmount) end
                if type(sendItemStats) == "function" then sendItemStats(entry.item) end
            end
            remaining = remaining - take
        end
    end
    return remaining <= 0
end

local function refreshWaterSnapshot(source)
    CampaignState.setWaterSnapshot(WaterService.sample(), source or "decontamination controller")
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
        cleanWaterLiters = WaterService.available("clean"),
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

local function broadcastStatus()
    if not isServer() or not getOnlinePlayers then return end
    local players = getOnlinePlayers()
    for index = 0, players:size() - 1 do
        sendStatus(players:get(index))
    end
end

local function sendResult(player, ok, action, code)
    if player and isServer() then
        sendServerCommand(player, Constants.DECON_NETWORK_MODULE, "deconResult", {
            ok=ok == true,
            action=tostring(action or "unknown"),
            code=code,
        })
        broadcastStatus()
    end
end

local function startCycle(player, modeId)
    if not inInteractionRange(player) then return false, "decon_access_required" end
    if Server.startingCycle then return false, "cycle_active" end
    local state = deconState()
    if state.activeCycle then return false, "cycle_active" end
    local mode = Rules.MODES[modeId]
    if not mode then return false, "unknown_mode" end

    local participants = collectChamberParticipants()
    if #participants == 0 then return false, "chamber_occupant_required" end
    Server.startingCycle = true

    local function completeStart(ok, code)
        Server.startingCycle = false
        return ok, code
    end

    local inventoryReagent = firstReagent(player, mode)
    local cleanWater = WaterService.available("clean")
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
        return completeStart(false, code)
    end

    local consumed = WaterService.consume(mode.waterLiters, "clean", "decontamination")
    if not consumed then
        if mode.requiresPower then setPowerRequested(false, actor(player)) end
        return completeStart(false, "clean_water_changed")
    end

    if inventoryReagent then
        if not consumeInventoryItem(player, inventoryReagent) then
            if mode.requiresPower then setPowerRequested(false, actor(player)) end
            return completeStart(false, "reagent_transaction_failed")
        end
    elseif mode.mixerUnits then
        state.reagentUnits = state.reagentUnits - mode.mixerUnits
    end

    local cycle = Model.start(state, modeId, actor(player), Util.worldAgeHours())
    if not cycle then
        if mode.requiresPower then setPowerRequested(false, actor(player)) end
        return completeStart(false, "cycle_start_failed")
    end
    cycle.participants = participants
    cycle.resources = {
        waterLiters=mode.waterLiters,
        mixerUnits=mode.mixerUnits or 0,
        inventoryReagent=inventoryReagent and inventoryReagent:getFullType() or nil,
        power=mode.requiresPower == true,
    }
    refreshWaterSnapshot("decontamination cycle")
    CampaignState.appendLog("decontamination", modeId .. " cycle started id=" .. tostring(cycle.id), actor(player))
    return completeStart(true)
end

local function finishCycle(cycle)
    local state = deconState()
    local mode = Rules.MODES[cycle.mode]
    if not mode then return false end

    local cleaned = 0
    local online = 0
    for _, username in ipairs(type(cycle.participants) == "table" and cycle.participants or {cycle.username}) do
        local player = findOnlinePlayer(username)
        if player then
            online = online + 1
            if not player:isDead() then
                local ok = ToxicServer.cleanPlayer(player, mode.bodyRemoval, mode.gearRemoval, mode.onlyMostContaminated)
                if ok then cleaned = cleaned + 1 end
            end
        end
    end
    if online == 0 then return false, "participants_offline" end
    if cleaned == 0 then return false, "participants_dead" end

    state.roomContamination = math.max(0, state.roomContamination * (1 - mode.bodyRemoval))
    state.areas.chamber = math.max(0, state.areas.chamber * (1 - mode.bodyRemoval))
    local worldItems, corpses = 0, 0
    local worldRemoval = tonumber(mode.gearRemoval) or 0
    if worldRemoval > 0 then
        local worldOk, cleanedWorldItems, cleanedCorpses = ToxicServer.cleanWorldInBounds(
            Rules.ROOM, worldRemoval
        )
        if worldOk then
            worldItems = cleanedWorldItems or 0
            corpses = cleanedCorpses or 0
        end
    end
    if mode.requiresPower then setPowerRequested(false, cycle.username) end
    Model.finish(state, cycle.mode .. "_complete")
    CampaignState.appendLog("decontamination", cycle.mode .. " cycle completed id=" .. tostring(cycle.id)
        .. " players=" .. tostring(cleaned) .. " worldItems=" .. tostring(worldItems)
        .. " corpses=" .. tostring(corpses), cycle.username)
    for _, username in ipairs(type(cycle.participants) == "table" and cycle.participants or {cycle.username}) do
        local player = findOnlinePlayer(username)
        if player then
            sendServerCommand(player, Constants.DECON_NETWORK_MODULE, "deconResult", {
                ok=true, action="cycleComplete",
            })
        end
    end
    broadcastStatus()
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
    if not consumeWholeInventoryItem(item) then return false, "reagent_transaction_failed" end
    state.reagentUnits = math.min(Rules.MAX_REAGENT_UNITS, state.reagentUnits + Rules.TABLET_UNITS)
    CampaignState.appendLog("decontamination", "NBC mixer loaded to " .. tostring(state.reagentUnits), actor(player))
    return true
end

local function manualWashBunker(player, args)
    if not inInteractionRange(player) then return false, "decon_access_required" end
    local target = type(args) == "table" and args.target or nil
    local contamination = 0
    local item = nil
    if target == "body" then
        local record = ToxicServer.getPlayerRecord(player)
        contamination = tonumber(record and record.surfaceContamination) or 0
    elseif target == "item" then
        item = ToxicServer.findCarriedItem(player, args.itemId)
        if not item then return false, "item_unavailable" end
        contamination = ToxicServer.getItemContamination(item)
    else
        return false, "unknown_manual_target"
    end
    if contamination <= BunkerCampaignToxicMP.Constants.SURFACE_TRACE then return false, "already_clean" end

    local manual = Rules.MANUAL_WASH
    local waterLiters = manual.baseWaterLiters
        + math.ceil(contamination / manual.contaminationPerAdditionalLiter)
    local agentUses = math.max(1, math.ceil(contamination / manual.contaminationPerAgentUse))
    if WaterService.available("clean") + 0.0001 < waterLiters then
        return false, "clean_water_required"
    end
    local agents, availableUses = manualAgents(player)
    if availableUses < agentUses then return false, "cleaning_agent_required" end
    if not WaterService.consume(waterLiters, "clean", "manual_wash") then
        return false, "clean_water_changed"
    end
    if not consumeManualAgentUses(agents, agentUses) then return false, "reagent_transaction_failed" end

    if target == "body" then
        ToxicServer.cleanPlayer(player, 1, 0, false)
    else
        ToxicServer.cleanItem(player, item, 1)
    end
    refreshWaterSnapshot("manual radioactive wash")
    CampaignState.appendLog("decontamination", "manual wash target=" .. target
        .. " contamination=" .. tostring(contamination) .. " water=" .. tostring(waterLiters)
        .. " agentUses=" .. tostring(agentUses), actor(player))
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

    local function add(itemType)
        local item = inventory:AddItem(itemType)
        if not item then return false end
        if type(sendAddItemToContainer) == "function" then
            sendAddItemToContainer(inventory, item)
        end
        return true
    end

    for _ = 1, 3 do if not add("Bandits.NBCTablets") then return false end end
    if not add("Base.CleaningLiquid2") then return false end
    if not add("Base.Bleach") then return false end
    if not add("Base.Soap2") then return false end
    for _ = 1, 4 do if not add("Base.GasmaskFilter") then return false end end
    return true
end

local function qaZoneAt(args, player)
    local x = tonumber(args and args.x) or (player and player:getX())
    local y = tonumber(args and args.y) or (player and player:getY())
    local z = tonumber(args and args.z) or (player and player:getZ())
    local radius = math.max(1, math.min(20, math.floor(tonumber(args and args.radius) or 5)))
    if not x or not y or not z then return nil end
    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    return {
        startX=x - radius, startY=y - radius, endX=x + radius, endY=y + radius,
        startZ=z, endZ=z,
    }
end

local function qaSetRoomAir(player, args)
    local definition = BunkerCampaign.RoomRegistry.find(player:getX(), player:getY(), player:getZ())
    local campaign = CampaignState.get()
    local ventilation = campaign and campaign.bunker.modules.ventilation
    local room = definition and ventilation and ventilation.rooms[definition.id]
    if not room then return false, "player_not_in_registered_room" end
    if args and args.co2 ~= nil then
        room.co2 = Util.clamp(tonumber(args.co2) or BunkerCampaign.Constants.VENTILATION.MIN_CO2,
            BunkerCampaign.Constants.VENTILATION.MIN_CO2, BunkerCampaign.Constants.VENTILATION.MAX_CO2)
    end
    if args and args.contamination ~= nil then
        room.contamination = Util.clamp(tonumber(args.contamination) or 0, 0, 1)
    end
    CampaignState.touch()
    CampaignState.broadcast()
    return true
end

local function sendQaReport(player, kind)
    local campaign = CampaignState.get()
    local ventilation = campaign and campaign.bunker.modules.ventilation or {}
    local definition = BunkerCampaign.RoomRegistry.find(player:getX(), player:getY(), player:getZ())
    local room = definition and ventilation.rooms and ventilation.rooms[definition.id] or nil
    local water = WaterService.sample()
    local campaignWater = campaign and campaign.bunker.modules.water or {}
    water.pumpRequested = campaignWater.requested == true
    water.powerAllocated = campaignWater.powerAllocated == true
    water.reason = campaignWater.reason or "none"
    water.source = campaignWater.selectedSource or water.source
    water.filterUsePerMinute = campaignWater.telemetry
        and campaignWater.telemetry.treatmentFilterUsePerMinute or 0
    sendServerCommand(player, Constants.DECON_NETWORK_MODULE, "qaReport", {
        kind=kind,
        roomId=definition and definition.id or "outside",
        roomCo2=room and room.co2 or 0,
        roomContamination=room and room.contamination or 0,
        roomOccupants=room and room.occupants or 0,
        entryPath=ventilation.entryPath,
        filterRemaining=ventilation.filterBank and ventilation.filterBank.remaining or 0,
        filterUsePerMinute=ventilation.telemetry and ventilation.telemetry.filterUsePerMinute or 0,
        filterActivity=ventilation.telemetry and ventilation.telemetry.filterActivity or "unknown",
        recirculationRemovedM3PerMinute=ventilation.telemetry
            and ventilation.telemetry.recirculationRemovedM3PerMinute or 0,
        intakes=ventilation.intakes,
        airlock=ventilation.airlock,
        water=water,
    })
end

local function setIntakeState(player, args)
    local x, y, z = tonumber(args and args.x), tonumber(args and args.y), tonumber(args and args.z)
    if not x or not y or not z or type(args.broken) ~= "boolean" then return false, "invalid_intake" end
    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    local ark = ModData.getOrCreate(Constants.THE_ARK_STATE_KEY)
    local found = false
    for _, intake in pairs(type(ark.airintakes) == "table" and ark.airintakes or {}) do
        if math.floor(tonumber(intake.x) or 0) == x and math.floor(tonumber(intake.y) or 0) == y
            and math.floor(tonumber(intake.z) or 0) == z then
            intake.broken = args.broken
            if not args.broken and (tonumber(intake.condition) or 0) <= 0 then intake.condition = 1 end
            found = true
        end
    end
    if not found then return false, "air_intake_not_found_on_selected_tile" end
    if type(ModData.transmit) == "function" then ModData.transmit(Constants.THE_ARK_STATE_KEY) end
    local campaign = CampaignState.get()
    local ventilation = campaign and campaign.bunker.modules.ventilation
    for _, intake in pairs(ventilation and ventilation.intakes or {}) do
        if math.floor(tonumber(intake.x) or 0) == x and math.floor(tonumber(intake.y) or 0) == y
            and math.floor(tonumber(intake.z) or 0) == z then
            intake.broken = args.broken
            intake.condition = args.broken and 0 or math.max(tonumber(intake.condition) or 0, 1)
            intake.status = args.broken and "failed" or "operational"
        end
    end
    CampaignState.touch()
    CampaignState.broadcast()
    CampaignState.appendLog("ventilation", (args.broken and "air intake broken at " or "air intake repaired at ")
        .. tostring(x) .. "," .. tostring(y) .. "," .. tostring(z), actor(player))
    return true
end

local function repairIntake(player, args)
    if not player or player:isDead() then return false, "invalid_player" end
    local x, y, z = tonumber(args and args.x), tonumber(args and args.y), tonumber(args and args.z)
    if not x or not y or not z then return false, "invalid_intake" end
    x, y, z = math.floor(x), math.floor(y), math.floor(z)
    if math.floor(player:getZ()) ~= z
        or math.abs(player:getX() - x) > 2 or math.abs(player:getY() - y) > 2 then
        return false, "too_far_from_intake"
    end
    local ark = ModData.getOrCreate(Constants.THE_ARK_STATE_KEY)
    local found, broken = false, false
    for _, intake in pairs(type(ark.airintakes) == "table" and ark.airintakes or {}) do
        if math.floor(tonumber(intake.x) or 0) == x and math.floor(tonumber(intake.y) or 0) == y
            and math.floor(tonumber(intake.z) or 0) == z then
            found = true
            broken = intake.broken == true or (tonumber(intake.condition) or 0) <= 0
            break
        end
    end
    if not found then return false, "air_intake_not_found_on_selected_tile" end
    if not broken then return false, "air_intake_already_operational" end
    local inventory = player:getInventory()
    local scrap = inventory and inventory:getFirstTypeRecurse("Base.ScrapMetal") or nil
    if not scrap then return false, "scrap_metal_required" end
    if not consumeWholeInventoryItem(scrap) then return false, "scrap_metal_unavailable" end
    return setIntakeState(player, {x=x, y=y, z=z, broken=false})
end

local function refreshLifeSupportZones(player)
    local integrationState = BunkerCampaignIntegration.IntegrationState
    if integrationState and not integrationState.toxicZoneListenerRegistered
        and type(integrationState.refreshToxicZones) == "function" then
        integrationState.refreshToxicZones(actor(player))
    end
end

local function runQa(player, command, args)
    if not isAdmin(player) then return false, "admin_required" end
    if command == "qaTeleport" then
        local targetId = type(args) == "table" and args.target or nil
        local targets = {
            exterior=Rules.EXTERIOR_TEST,
            intakes={x=9940.5,y=12633.5,z=0},
            dirty=Rules.DIRTY_ENTRY,
            chamber=Rules.CHAMBER,
            clean=Rules.CLEAN_EXIT,
            reagent=Rules.REAGENT_STORAGE,
            spawn={x=9966.5,y=12622.5,z=-4},
            heating_controller={x=9963.5,y=12627.5,z=-4},
            heat_exchanger={x=9968.5,y=12633.5,z=-4},
            circulation_blower={x=9967.5,y=12635.5,z=-4},
            supply_valve={x=9966.5,y=12637.5,z=-4},
            return_valve={x=9966.5,y=12639.5,z=-4},
            pipe_manifold={x=9966.5,y=12640.5,z=-4},
        }
        local target = targets[targetId]
        if not target then return false, "unknown_target" end
        if targetId == "exterior" then
            ToxicServer.ensureZone(Rules.TEST_ZONE_NAME, Rules.TEST_ZONE)
            refreshLifeSupportZones(player)
        end
        nativeTeleport(player, target)
        return true
    elseif command == "qaContaminate" then
        ToxicServer.setPlayerSurfaceContamination(player, 80, true)
        return true
    elseif command == "qaClean" then
        ToxicServer.cleanPlayer(player, 1, 1, false)
        local state = deconState()
        state.roomContamination = 0
        state.areas.dirty = 0
        state.areas.chamber = 0
        state.areas.clean = 0
        return true
    elseif command == "qaGiveSupplies" then
        return qaGiveSupplies(player), "inventory_unavailable"
    elseif command == "qaFillWater" then
        local changed = WaterService.fillForQa()
        return changed or WaterService.available("clean") > 0, "no_bunker_storage"
    elseif command == "qaRefuelGenerator" then
        local generatorId = type(args) == "table" and args.generator or nil
        if generatorId ~= "main" and generatorId ~= "backup" then return false, "unknown_generator" end
        return CampaignState.refuelGenerator(generatorId, actor(player))
    elseif command == "qaFinishCycle" then
        local cycle = deconState().activeCycle
        if not cycle then return false, "no_active_cycle" end
        cycle.remainingSeconds = 0
        return true
    elseif command == "qaCreateZone" then
        local bounds = qaZoneAt(args, player)
        if not bounds then return false, "invalid_zone" end
        local ok, code = ToxicServer.ensureZone(Rules.TEST_ZONE_NAME, bounds)
        if ok then refreshLifeSupportZones(player) end
        return ok, code
    elseif command == "qaCreateIntakeZone" then
        local ok, code = ToxicServer.ensureZone(Rules.INTAKE_TEST_ZONE_NAME, Rules.INTAKE_TEST_ZONE)
        if ok then refreshLifeSupportZones(player) end
        return ok, code
    elseif command == "qaRemoveZone" then
        ToxicServer.removeZone(Rules.TEST_ZONE_NAME)
        ToxicServer.removeZone(Rules.INTAKE_TEST_ZONE_NAME)
        ToxicServer.removeZone("MPForkTest")
        refreshLifeSupportZones(player)
        return true
    elseif command == "qaSetRoomAir" then
        return qaSetRoomAir(player, args)
    elseif command == "qaSetIntake" then
        return setIntakeState(player, args)
    elseif command == "qaSetVentFilter" then
        local ventilation = CampaignState.get().bunker.modules.ventilation
        local remaining = Util.clamp(tonumber(args and args.remaining) or 1, 0, 1)
        ventilation.filterBank.remaining = remaining
        ventilation.filterRemaining = remaining
        CampaignState.touch()
        CampaignState.broadcast()
        return true
    elseif command == "qaFinishPurge" then
        local airlock = CampaignState.get().bunker.modules.ventilation.airlock
        if not airlock.active then return false, "no_active_purge" end
        airlock.remainingMinutes = 0
        airlock.active = false
        airlock.status = "complete"
        CampaignState.touch()
        CampaignState.broadcast()
        return true
    elseif command == "qaWaterStorage" then
        local medium = args and args.medium or nil
        local fraction = tonumber(args and args.fillFraction) or 0
        if args and args.stopPump == true then
            CampaignState.setConsumerRequested("water", false, actor(player))
        end
        local found = WaterService.setStorageForQa(medium, fraction)
        return found, "no_bunker_storage"
    elseif command == "qaWaterPump" then
        local found = WaterService.setPumpForQa(args and args.condition,
            args and args.filterRemaining, args and args.burn)
        return found, "bunker_pump_missing"
    elseif command == "qaExternalWater" then
        CampaignState.addWaterSource("external_tank", 100, 0.55, actor(player))
        return CampaignState.setWaterSource("external_tank", actor(player))
    elseif command == "qaReport" then
        sendQaReport(player, args and args.kind or "all")
        return true
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
        -- Area transfer belongs to the decontamination suite, not the entire
        -- bunker level east or west of it.
        if side ~= "remote" and inInteractionRange(player) then
            local record = ToxicServer.getPlayerRecord(player)
            local carried = math.max(record and record.surfaceContamination or 0, record and record.gearContamination or 0)
            state.areas[side] = math.max(state.areas[side] or 0, carried * 0.15)
            ToxicServer.applySurfaceContact(player, state.areas[side], math.min(0.10, elapsed * 0.01))
            if side == "chamber" then state.roomContamination = state.areas.chamber end
        end
    end


    if now - Server.lastStatusMs >= 2000 then
        broadcastStatus()
        Server.lastStatusMs = now
    end

    local cycle = state.activeCycle
    if not cycle then return end
    includeCurrentParticipants(cycle)
    local mode = Rules.MODES[cycle.mode]
    local canRun = not mode.requiresPower or (powerConsumer() and powerConsumer().allocated == true)
    local complete = Model.advance(state, elapsed, canRun)
    if complete then
        local ok, code = finishCycle(cycle)
        if not ok and code == "participants_offline" then
            state.status = "paused"
            return
        end
        if not ok and code == "participants_dead" then
            if mode.requiresPower then setPowerRequested(false, cycle.username) end
            Model.finish(state, "player_dead")
            broadcastStatus()
            return
        end
    end
end

function Server.onClientCommand(module, command, player, args)
    if module ~= Constants.DECON_NETWORK_MODULE then return end
    if command == "requestStatus" then sendStatus(player); return end
    if command == "manualWashBunker" then
        local ok, code = manualWashBunker(player, args)
        sendResult(player, ok, command, code)
        return
    end
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
    if command == "repairIntake" then
        local ok, code = repairIntake(player, args)
        sendResult(player, ok, command, ok and nil or code)
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

BunkerCampaignIntegration.Runtime = BunkerCampaignIntegration.Runtime or {}
local runtime = BunkerCampaignIntegration.Runtime.decontaminationServer or {}
if runtime.initialize and type(Events.OnInitGlobalModData.Remove) == "function" then
    Events.OnInitGlobalModData.Remove(runtime.initialize)
end
if runtime.update and Events.OnTick and type(Events.OnTick.Remove) == "function" then
    Events.OnTick.Remove(runtime.update)
end
if runtime.onClientCommand and type(Events.OnClientCommand.Remove) == "function" then
    Events.OnClientCommand.Remove(runtime.onClientCommand)
end
runtime.initialize = Server.initialize
runtime.update = Server.update
runtime.onClientCommand = Server.onClientCommand
BunkerCampaignIntegration.Runtime.decontaminationServer = runtime
Events.OnInitGlobalModData.Add(runtime.initialize)
if Events.OnTick then Events.OnTick.Add(runtime.update) end
Events.OnClientCommand.Add(runtime.onClientCommand)

BunkerCampaignIntegration.DecontaminationServer = Server
return Server
