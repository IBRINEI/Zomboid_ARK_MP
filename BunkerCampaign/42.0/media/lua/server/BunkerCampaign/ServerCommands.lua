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
    local allowed = { ventilation=true, water=true, main_lighting=true }
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
