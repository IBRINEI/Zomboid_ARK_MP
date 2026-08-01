if isClient() then return end

require "BunkerCampaign/Constants"
require "BunkerCampaign/CampaignState"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local CampaignState = BunkerCampaign.CampaignState
local ServerCommands = {
    lastStateRequest = {},
}

local function isAdministrator(player)
    return player ~= nil and player:isAccessLevel("admin")
end

local function canOperateBunkerSystems(player)
    if not player or type(player.getX) ~= "function" or type(player.getY) ~= "function" or type(player.getZ) ~= "function" then return false end
    local bounds = Constants.BUNKER_CONTROL_BOUNDS
    local x, y, z = player:getX(), player:getY(), math.floor(player:getZ())
    return x >= bounds.x1 and x <= bounds.x2
        and y >= bounds.y1 and y <= bounds.y2
        and bounds.levels[z] == true
end

local function replyError(player, code)
    if isServer() and player then
        sendServerCommand(player, Constants.NETWORK_MODULE, "commandError", { code = code })
    end
end

local function requestState(player)
    if not player then return end
    local username = player:getUsername()
    local now = getGametimeTimestamp()
    local previous = ServerCommands.lastStateRequest[username] or 0
    if now - previous < 500 then return end
    ServerCommands.lastStateRequest[username] = now
    CampaignState.sendToPlayer(player)
end

local function setVentilation(player, args)
    if not canOperateBunkerSystems(player) then
        CampaignState.appendLog("security", "rejected ventilation mutation", player and player:getUsername() or "unknown")
        replyError(player, "bunker_access_required")
        return
    end
    if type(args) ~= "table" or type(args.enabled) ~= "boolean" then
        CampaignState.appendLog("security", "rejected malformed ventilation command", player:getUsername())
        replyError(player, "invalid_payload")
        return
    end

    local ok, reason = CampaignState.setVentilationEnabled(args.enabled, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setVentilationMode(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    if type(args) ~= "table" or type(args.mode) ~= "string" then replyError(player, "invalid_payload"); return end
    local ok, reason = CampaignState.setVentilationMode(args.mode, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function startAirlockPurge(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    local roomId = type(args) == "table" and args.roomId or "decontamination_chamber"
    if type(roomId) ~= "string" then replyError(player, "invalid_payload"); return end
    local ok, reason = CampaignState.startAirlockPurge(roomId, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function filterCharge(item)
    if item and type(item.getUsedDelta) == "function" then
        local ok, remaining = pcall(item.getUsedDelta, item)
        if ok and tonumber(remaining) then return math.max(0, math.min(1, tonumber(remaining))) end
    end
    local md = item and item:getModData() or nil
    local charge = md and tonumber(md.BunkerCampaignVentFilterRemaining or md.percent) or nil
    if charge then return math.max(0, math.min(1, charge)) end
    return 1
end

local function applyVentilationFilterCharge(item, charge)
    if not item then return end
    charge = math.max(0, math.min(1, tonumber(charge) or 0))
    if type(item.setUsedDelta) == "function" then item:setUsedDelta(charge) end
    local md = item:getModData()
    md.BunkerCampaignVentFilterRemaining = nil
    md.percent = nil
    if type(item.syncItemFields) == "function" then item:syncItemFields() end
end

local function replaceVentilationFilter(player)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    local inventory = player and player:getInventory()
    local item = inventory and inventory:getFirstTypeRecurse("Base.GasmaskFilter") or nil
    if not item then replyError(player, "ventilation_filter_required"); return end
    local charge = filterCharge(item)
    local container = item:getContainer()
    if not container then replyError(player, "filter_transaction_failed"); return end
    container:Remove(item)
    if type(sendRemoveItemFromContainer) == "function" then sendRemoveItemFromContainer(container, item) end
    local ok, previous = CampaignState.replaceVentilationFilter(charge, player:getUsername())
    if not ok then replyError(player, previous or "filter_transaction_failed"); return end
    if previous > 0.001 then
        local used = inventory:AddItem("Base.GasmaskFilter")
        if used then
            applyVentilationFilterCharge(used, previous)
            if type(sendAddItemToContainer) == "function" then sendAddItemToContainer(inventory, used) end
        end
    end
end

local function setWaterSource(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    if type(args) ~= "table" or type(args.id) ~= "string" then replyError(player, "invalid_payload"); return end
    local ok, reason = CampaignState.setWaterSource(args.id, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setWaterBypass(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    if type(args) ~= "table" or type(args.enabled) ~= "boolean" then replyError(player, "invalid_payload"); return end
    local ok, reason = CampaignState.setWaterBypass(args.enabled, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setHeating(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    if type(args) ~= "table" or type(args.enabled) ~= "boolean" then
        replyError(player, "invalid_payload"); return
    end
    local ok, reason = CampaignState.setHeatingEnabled(args.enabled, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setHeatingTarget(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    if type(args) ~= "table" or type(args.temperature) ~= "number" then
        replyError(player, "invalid_payload"); return
    end
    local ok, reason = CampaignState.setHeatingTarget(args.temperature, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setHeatingRoom(player, args)
    if not canOperateBunkerSystems(player) then replyError(player, "bunker_access_required"); return end
    if type(args) ~= "table" or type(args.roomId) ~= "string"
        or type(args.enabled) ~= "boolean" then
        replyError(player, "invalid_payload"); return
    end
    local ok, reason = CampaignState.setHeatingRoomEnabled(
        args.roomId, args.enabled, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setGenerator(player, args)
    if not canOperateBunkerSystems(player) then
        CampaignState.appendLog("security", "rejected generator mutation", player and player:getUsername() or "unknown")
        replyError(player, "bunker_access_required")
        return
    end
    if type(args) ~= "table" or type(args.id) ~= "string" or type(args.requested) ~= "boolean" then
        replyError(player, "invalid_payload")
        return
    end
    local ok, reason = CampaignState.setGeneratorRequested(args.id, args.requested, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

local function setConsumer(player, args)
    if not canOperateBunkerSystems(player) then
        CampaignState.appendLog("security", "rejected consumer mutation", player and player:getUsername() or "unknown")
        replyError(player, "bunker_access_required")
        return
    end
    if type(args) ~= "table" or type(args.id) ~= "string" or type(args.requested) ~= "boolean" then
        replyError(player, "invalid_payload")
        return
    end
    local allowed = { ventilation=true, water=true, heating=true, main_lighting=true }
    if not allowed[args.id] then replyError(player, "unknown_consumer"); return end
    local ok, reason = CampaignState.setConsumerRequested(args.id, args.requested, player:getUsername())
    if not ok then replyError(player, reason or "invalid_payload") end
end

function ServerCommands.onClientCommand(module, command, player, args)
    if module ~= Constants.NETWORK_MODULE then return end

    if command == "requestState" then
        requestState(player)
    elseif command == "setVentilation" then
        setVentilation(player, args)
    elseif command == "setVentilationMode" then
        setVentilationMode(player, args)
    elseif command == "startAirlockPurge" then
        startAirlockPurge(player, args)
    elseif command == "replaceVentilationFilter" then
        replaceVentilationFilter(player)
    elseif command == "setWaterSource" then
        setWaterSource(player, args)
    elseif command == "setWaterBypass" then
        setWaterBypass(player, args)
    elseif command == "setHeating" then
        setHeating(player, args)
    elseif command == "setHeatingTarget" then
        setHeatingTarget(player, args)
    elseif command == "setHeatingRoom" then
        setHeatingRoom(player, args)
    elseif command == "setGenerator" then
        setGenerator(player, args)
    elseif command == "setConsumer" then
        setConsumer(player, args)
    else
        CampaignState.appendLog("security", "rejected unknown command " .. tostring(command), player and player:getUsername() or "unknown")
        replyError(player, "unknown_command")
    end
end

Events.OnClientCommand.Add(ServerCommands.onClientCommand)

BunkerCampaign.ServerCommands = ServerCommands
return ServerCommands
