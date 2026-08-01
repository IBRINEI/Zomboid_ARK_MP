if isClient() then return end

require "BunkerCampaign/CampaignState"
require "BunkerCampaignThermalJava/ThermalOverrideAdapter"

BunkerCampaignThermalJava = BunkerCampaignThermalJava or {}

local previous = BunkerCampaignThermalJava.ThermalServer
if type(previous) == "table" then
    if previous.onInitGlobalModData then
        Events.OnInitGlobalModData.Remove(previous.onInitGlobalModData)
    end
    if previous.onServerStarted then Events.OnServerStarted.Remove(previous.onServerStarted) end
    if previous.onMinute then Events.EveryOneMinute.Remove(previous.onMinute) end
end

local Adapter = BunkerCampaignThermalJava.ThermalOverrideAdapter
local ThermalServer = {
    lastStatus = previous and previous.lastStatus or nil,
    regionCount = previous and previous.regionCount or 0,
    refreshCount = previous and previous.refreshCount or 0,
}

local function report(status)
    if ThermalServer.lastStatus == status then return end
    ThermalServer.lastStatus = status
    print("[BunkerCampaignThermalJava][server] status=" .. tostring(status))
end

function ThermalServer.refresh()
    local state = BunkerCampaign and BunkerCampaign.CampaignState
        and BunkerCampaign.CampaignState.get() or nil
    local heating = state and state.bunker and state.bunker.modules
        and state.bunker.modules.heating or nil
    if type(heating) ~= "table" then
        ThermalServer.regionCount = 0
        report("waiting_for_heating")
        return false, "missing_heating"
    end

    local ok, detail = Adapter.apply(heating)
    ThermalServer.regionCount = ok and tonumber(detail) or 0
    ThermalServer.refreshCount = ThermalServer.refreshCount + 1
    report(ok and "active" or detail)
    return ok, detail
end

function ThermalServer.onInitGlobalModData()
    ThermalServer.refresh()
end

function ThermalServer.onServerStarted()
    ThermalServer.refresh()
end

function ThermalServer.onMinute()
    ThermalServer.refresh()
end

Events.OnInitGlobalModData.Add(ThermalServer.onInitGlobalModData)
Events.OnServerStarted.Add(ThermalServer.onServerStarted)
Events.EveryOneMinute.Add(ThermalServer.onMinute)

BunkerCampaignThermalJava.ThermalServer = ThermalServer
return ThermalServer
