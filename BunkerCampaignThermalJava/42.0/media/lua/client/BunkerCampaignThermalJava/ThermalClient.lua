require "BunkerCampaignThermalJava/ThermalOverrideAdapter"

BunkerCampaignThermalJava = BunkerCampaignThermalJava or {}

local previous = BunkerCampaignThermalJava.ThermalClient
if type(previous) == "table" then
    if previous.onServerCommand then Events.OnServerCommand.Remove(previous.onServerCommand) end
    if previous.onCreatePlayer then Events.OnCreatePlayer.Remove(previous.onCreatePlayer) end
    if previous.clear then
        Events.OnDisconnect.Remove(previous.clear)
        Events.OnMainMenuEnter.Remove(previous.clear)
    end
end

local Adapter = BunkerCampaignThermalJava.ThermalOverrideAdapter
local ThermalClient = {
    snapshot = previous and previous.snapshot or nil,
    lastStatus = previous and previous.lastStatus or nil,
    regionCount = previous and previous.regionCount or 0,
}

local function report(status)
    if ThermalClient.lastStatus == status then return end
    ThermalClient.lastStatus = status
    print("[BunkerCampaignThermalJava] status=" .. tostring(status))
end

function ThermalClient.apply(heating)
    if type(heating) ~= "table" then return false, "missing_heating" end
    ThermalClient.snapshot = heating
    local ok, detail = Adapter.apply(heating)
    ThermalClient.regionCount = ok and tonumber(detail) or 0
    report(ok and "active" or detail)
    return ok, detail
end

function ThermalClient.onServerCommand(module, command, args)
    if module == "BunkerCampaign" and command == "stateSnapshot"
        and type(args) == "table" and type(args.heating) == "table" then
        ThermalClient.apply(args.heating)
    end
end

function ThermalClient.onCreatePlayer()
    local snapshot = BunkerCampaign and BunkerCampaign.ClientState
        and BunkerCampaign.ClientState.snapshot or nil
    if type(snapshot) == "table" and type(snapshot.heating) == "table" then
        ThermalClient.apply(snapshot.heating)
    end
end

function ThermalClient.clear()
    Adapter.clear()
    ThermalClient.snapshot = nil
    ThermalClient.regionCount = 0
    ThermalClient.lastStatus = nil
end

Events.OnServerCommand.Add(ThermalClient.onServerCommand)
Events.OnCreatePlayer.Add(ThermalClient.onCreatePlayer)
Events.OnDisconnect.Add(ThermalClient.clear)
Events.OnMainMenuEnter.Add(ThermalClient.clear)

BunkerCampaignThermalJava.ThermalClient = ThermalClient
return ThermalClient
