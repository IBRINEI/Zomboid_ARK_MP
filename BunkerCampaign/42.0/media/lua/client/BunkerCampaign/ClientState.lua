require "BunkerCampaign/Constants"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local ClientState = {
    snapshot = nil,
    lastError = nil,
    listeners = {},
}

local function notifyListeners()
    for _, listener in ipairs(ClientState.listeners) do
        listener(ClientState.snapshot, ClientState.lastError)
    end
end

function ClientState.addListener(listener)
    if type(listener) == "function" then
        table.insert(ClientState.listeners, listener)
    end
end

function ClientState.removeListener(listener)
    for index = #ClientState.listeners, 1, -1 do
        if ClientState.listeners[index] == listener then
            table.remove(ClientState.listeners, index)
        end
    end
end

function ClientState.request(player)
    player = player or getPlayer()
    if isClient() then
        if player then sendClientCommand(player, Constants.NETWORK_MODULE, "requestState", {}) end
    elseif BunkerCampaign.CampaignState then
        ClientState.snapshot = BunkerCampaign.CampaignState.snapshot()
        ClientState.lastError = nil
        notifyListeners()
    end
end

function ClientState.setVentilationEnabled(player, enabled)
    if type(enabled) ~= "boolean" then return end
    player = player or getPlayer()

    if isClient() then
        if player then sendClientCommand(player, Constants.NETWORK_MODULE, "setVentilation", { enabled = enabled }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setVentilationEnabled(enabled, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setVentilationMode(player, mode)
    if type(mode) ~= "string" then return end
    player = player or getPlayer()
    if isClient() then
        if player then sendClientCommand(player, Constants.NETWORK_MODULE, "setVentilationMode", { mode=mode }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setVentilationMode(mode, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.startAirlockPurge(player, roomId)
    player = player or getPlayer()
    roomId = type(roomId) == "string" and roomId or "decontamination_chamber"
    if isClient() then
        if player then sendClientCommand(player, Constants.NETWORK_MODULE, "startAirlockPurge", { roomId=roomId }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.startAirlockPurge(roomId, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.replaceVentilationFilter(player)
    player = player or getPlayer()
    if isClient() then
        if player then sendClientCommand(player, Constants.NETWORK_MODULE, "replaceVentilationFilter", {}) end
    end
end

function ClientState.setWaterSource(player, sourceId)
    if type(sourceId) ~= "string" then return end
    player = player or getPlayer()
    if isClient() then
        if player then sendClientCommand(player, Constants.NETWORK_MODULE, "setWaterSource", { id=sourceId }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setWaterSource(sourceId, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setWaterBypass(player, enabled)
    if type(enabled) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() then
        if player then sendClientCommand(player, Constants.NETWORK_MODULE, "setWaterBypass", { enabled=enabled }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setWaterBypass(enabled, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setGeneratorRequested(player, generatorId, requested)
    if type(generatorId) ~= "string" or type(requested) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() then
        if player then sendClientCommand(player, Constants.NETWORK_MODULE, "setGenerator", { id=generatorId, requested=requested }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setGeneratorRequested(generatorId, requested, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setConsumerRequested(player, consumerId, requested)
    if type(consumerId) ~= "string" or type(requested) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() then
        if player then sendClientCommand(player, Constants.NETWORK_MODULE, "setConsumer", { id=consumerId, requested=requested }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setConsumerRequested(consumerId, requested, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.onServerCommand(module, command, args)
    if module ~= Constants.NETWORK_MODULE then return end

    if command == "stateSnapshot" and type(args) == "table" and type(args.ventilation) == "table" and type(args.power) == "table" then
        ClientState.snapshot = args
        ClientState.lastError = nil
        notifyListeners()
    elseif command == "commandError" and type(args) == "table" then
        ClientState.lastError = tostring(args.code or "unknown_error")
        notifyListeners()
    end
end

local function onCreatePlayer(playerIndex, player)
    ClientState.request(player)
end

Events.OnServerCommand.Add(ClientState.onServerCommand)
Events.OnCreatePlayer.Add(onCreatePlayer)

BunkerCampaign.ClientState = ClientState
return ClientState
