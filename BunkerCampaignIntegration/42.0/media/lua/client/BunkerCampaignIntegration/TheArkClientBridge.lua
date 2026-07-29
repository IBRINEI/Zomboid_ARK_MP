require "BWOAGMD"
require "BunkerCampaign/ClientState"
require "BunkerCampaignIntegration/Constants"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local ClientState = BunkerCampaign.ClientState
local Constants = BunkerCampaignIntegration.Constants
local TheArkClientBridge = {
    status = nil,
    lastError = nil,
}

local function mirror(snapshot)
    if type(snapshot) ~= "table" or type(snapshot.ventilation) ~= "table" then return end
    if type(GetBWOAModData) ~= "function" then return end

    local ark = GetBWOAModData()
    if type(ark) ~= "table" or type(ark.ventilation) ~= "table" then return end

    ark.ventilation.active = snapshot.ventilation.enabled
    ark.ventilation.co2 = snapshot.ventilation.co2
    ark.ventilation.filter = snapshot.ventilation.filterRemaining * 100
end

local function onCoreState(snapshot, errorCode)
    mirror(snapshot)
    if type(BWOANoah) == "table" and BWOANoah.shown and type(BWOANoah.LoadScreen) == "function" then
        BWOANoah.LoadScreen()
    end
end

local function everyOneMinute()
    mirror(ClientState.snapshot)
end

local function requestStatus(player)
    if isClient() and player then
        sendClientCommand(player, Constants.NETWORK_MODULE, "requestStatus", {})
    end
end

local function onCreatePlayer(playerIndex, player)
    requestStatus(player)
    mirror(ClientState.snapshot)
end

local function onServerCommand(module, command, args)
    if module ~= Constants.NETWORK_MODULE then return end
    if command == "integrationStatus" and type(args) == "table" then
        TheArkClientBridge.status = args
        TheArkClientBridge.lastError = nil
    elseif command == "commandError" and type(args) == "table" then
        TheArkClientBridge.lastError = tostring(args.code or "unknown_error")
    end
end

local function onKeyPressed(keynum)
    if type(BWOANoah) ~= "table" or not BWOANoah.shown or BWOANoah.screen ~= "Ventilation" then return end
    if keynum ~= Keyboard.KEY_1 then return end

    local player = getSpecificPlayer(0)
    local ark = type(GetBWOAModData) == "function" and GetBWOAModData() or nil
    if not player or type(ark) ~= "table" or type(ark.ventilation) ~= "table" then return end

    -- The Ark handles the key first and mutates its client table. Forward that desired
    -- value to the authoritative server, then immediately restore the last snapshot.
    ClientState.setVentilationEnabled(player, ark.ventilation.active == true)
    mirror(ClientState.snapshot)
    if type(BWOANoah.LoadScreen) == "function" then BWOANoah.LoadScreen() end
end

ClientState.addListener(onCoreState)
Events.EveryOneMinute.Add(everyOneMinute)
Events.OnCreatePlayer.Add(onCreatePlayer)
Events.OnServerCommand.Add(onServerCommand)
Events.OnKeyPressed.Add(onKeyPressed)

BunkerCampaignIntegration.TheArkClientBridge = TheArkClientBridge
return TheArkClientBridge
