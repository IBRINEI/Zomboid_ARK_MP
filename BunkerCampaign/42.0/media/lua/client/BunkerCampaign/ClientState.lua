require "BunkerCampaign/Constants"

BunkerCampaign = BunkerCampaign or {}

local Constants = BunkerCampaign.Constants
local ClientState = BunkerCampaign.ClientState or {}
ClientState.listeners = type(ClientState.listeners) == "table" and ClientState.listeners or {}

local function send(player, command, args)
    args = type(args) == "table" and args or {}
    ClientState.lastSentCommand = {
        module=Constants.NETWORK_MODULE,
        command=command,
        correlationId=args.correlationId,
        args=args,
    }
    sendClientCommand(player, Constants.NETWORK_MODULE, command, args)
end

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
        if player then send(player, "requestState", {}) end
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
        if player then send(player, "setVentilation", { enabled = enabled }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setVentilationEnabled(enabled, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setVentilationMode(player, mode)
    if type(mode) ~= "string" then return end
    player = player or getPlayer()
    if isClient() then
        if player then send(player, "setVentilationMode", { mode=mode }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setVentilationMode(mode, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.startAirlockPurge(player, roomId)
    player = player or getPlayer()
    roomId = type(roomId) == "string" and roomId or "decontamination_chamber"
    if isClient() then
        if player then send(player, "startAirlockPurge", { roomId=roomId }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.startAirlockPurge(roomId, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.replaceVentilationFilter(player)
    player = player or getPlayer()
    if isClient() then
        if player then send(player, "replaceVentilationFilter", {}) end
    end
end

function ClientState.setWaterSource(player, sourceId)
    if type(sourceId) ~= "string" then return end
    player = player or getPlayer()
    if isClient() then
        if player then send(player, "setWaterSource", { id=sourceId }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setWaterSource(sourceId, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setWaterBypass(player, enabled)
    if type(enabled) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() then
        if player then send(player, "setWaterBypass", { enabled=enabled }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setWaterBypass(enabled, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setHeatingEnabled(player, enabled)
    if type(enabled) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() then
        if player then send(player, "setHeating", { enabled=enabled }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setHeatingEnabled(enabled, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setHeatingTarget(player, temperature)
    if type(temperature) ~= "number" then return end
    player = player or getPlayer()
    if isClient() then
        if player then send(player, "setHeatingTarget", {
            temperature=temperature,
        }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setHeatingTarget(temperature, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setHeatingRoomEnabled(player, roomId, enabled)
    if type(roomId) ~= "string" or type(enabled) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() then
        if player then send(player, "setHeatingRoom", {
            roomId=roomId, enabled=enabled,
        }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setHeatingRoomEnabled(roomId, enabled, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.diagnoseHeatingComponent(player, componentId)
    if type(componentId) ~= "string" then return end
    player = player or getPlayer()
    if isClient() and player then
        send(player, "diagnoseHeatingComponent", {
            componentId=componentId,
        })
    end
end

function ClientState.repairHeatingComponent(player, componentId, mode)
    if type(componentId) ~= "string" or (mode ~= "temporary" and mode ~= "full") then return end
    player = player or getPlayer()
    if isClient() and player then
        send(player, "repairHeatingComponent", {
            componentId=componentId, mode=mode,
        })
    end
end

function ClientState.setHeatingValve(player, componentId, open)
    if type(componentId) ~= "string" or type(open) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() and player then
        send(player, "setHeatingValve", {
            componentId=componentId, open=open,
        })
    end
end

function ClientState.setHeatingManualBypass(player, enabled)
    if type(enabled) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() and player then
        send(player, "setHeatingManualBypass", {
            enabled=enabled,
        })
    end
end

function ClientState.triggerHeatingFault(player, componentId, severity)
    if type(componentId) ~= "string" or (severity ~= "minor" and severity ~= "major") then return end
    player = player or getPlayer()
    if isClient() and player then
        send(player, "triggerHeatingFault", {
            componentId=componentId, severity=severity,
        })
    end
end

function ClientState.setGeneratorRequested(player, generatorId, requested)
    if type(generatorId) ~= "string" or type(requested) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() then
        if player then send(player, "setGenerator", { id=generatorId, requested=requested }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setGeneratorRequested(generatorId, requested, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.setConsumerRequested(player, consumerId, requested)
    if type(consumerId) ~= "string" or type(requested) ~= "boolean" then return end
    player = player or getPlayer()
    if isClient() then
        if player then send(player, "setConsumer", { id=consumerId, requested=requested }) end
    elseif BunkerCampaign.CampaignState then
        BunkerCampaign.CampaignState.setConsumerRequested(consumerId, requested, "singleplayer")
        ClientState.request(player)
    end
end

function ClientState.onServerCommand(module, command, args)
    if module ~= Constants.NETWORK_MODULE then return end
    ClientState.lastReceivedResponse = {
        module=module,
        command=command,
        correlationId=type(args) == "table" and args.debugCorrelationId or nil,
    }

    if command == "stateSnapshot" and type(args) == "table" and type(args.ventilation) == "table"
        and type(args.power) == "table" and type(args.heating) == "table" then
        local currentRevision = ClientState.snapshot and tonumber(ClientState.snapshot.revision) or nil
        local incomingRevision = tonumber(args.revision)
        if currentRevision and incomingRevision and incomingRevision < currentRevision then return end
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

BunkerCampaign.Runtime = BunkerCampaign.Runtime or {}
if BunkerCampaign.Runtime.onServerCommand
    and type(Events.OnServerCommand.Remove) == "function" then
    Events.OnServerCommand.Remove(BunkerCampaign.Runtime.onServerCommand)
end
if BunkerCampaign.Runtime.onCreatePlayer
    and type(Events.OnCreatePlayer.Remove) == "function" then
    Events.OnCreatePlayer.Remove(BunkerCampaign.Runtime.onCreatePlayer)
end
BunkerCampaign.Runtime.onServerCommand = ClientState.onServerCommand
BunkerCampaign.Runtime.onCreatePlayer = onCreatePlayer
Events.OnServerCommand.Add(BunkerCampaign.Runtime.onServerCommand)
Events.OnCreatePlayer.Add(BunkerCampaign.Runtime.onCreatePlayer)

BunkerCampaign.Debug = BunkerCampaign.Debug or {}
function BunkerCampaign.Debug.getClientState()
    return {
        context="client",
        revision=ClientState.snapshot and ClientState.snapshot.revision or nil,
        lastSentCommand=ClientState.lastSentCommand,
        lastReceivedResponse=ClientState.lastReceivedResponse,
        lastError=ClientState.lastError,
    }
end
function BunkerCampaign.Debug.getLastClientCommand() return ClientState.lastSentCommand end
function BunkerCampaign.Debug.getLastClientError() return ClientState.lastError end
function BunkerCampaign.Debug.runClientScenario(name, args)
    if name ~= "state_round_trip" then return {ok=false, code="unknown_scenario"} end
    local player = getPlayer()
    if not player or not isClient() then return {ok=false, code="client_player_required"} end
    local correlationId = type(args) == "table" and args.correlationId or nil
    if type(correlationId) ~= "string" or correlationId == "" then
        correlationId = "client-round-trip:" .. tostring(getTimestampMs())
    end
    send(player, "requestState", {correlationId=string.sub(correlationId, 1, 128)})
    return {ok=true, correlationId=correlationId}
end
function BunkerCampaign.Debug.resetClientState()
    ClientState.lastSentCommand = nil
    ClientState.lastReceivedResponse = nil
    ClientState.lastError = nil
    return true
end

BunkerCampaign.ClientState = ClientState
return ClientState
