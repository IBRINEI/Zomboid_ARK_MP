require "BunkerCampaignIntegration/ClimateAdapter"
require "BunkerCampaignIntegration/HeatingAdapter"
require "BunkerCampaignIntegration/ThermalOverrideAdapter"

BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local previous = BunkerCampaignIntegration.HeatingClient
if type(previous) == "table" then
    if previous.onServerCommand and Events.OnServerCommand then
        Events.OnServerCommand.Remove(previous.onServerCommand)
    end
    if previous.onClimateTick and Events.OnClimateTick then
        Events.OnClimateTick.Remove(previous.onClimateTick)
    end
end

local ClimateAdapter = BunkerCampaignIntegration.ClimateAdapter
local HeatingAdapter = BunkerCampaignIntegration.HeatingAdapter
local ThermalOverrideAdapter = BunkerCampaignIntegration.ThermalOverrideAdapter
local HeatingClient = { snapshot = previous and previous.snapshot or nil }

function HeatingClient.apply()
    local heating = HeatingClient.snapshot
    if type(heating) ~= "table" then return end
    ClimateAdapter.apply(heating)
    HeatingAdapter.apply(heating)
    ThermalOverrideAdapter.apply(heating)
end

function HeatingClient.onServerCommand(module, command, args)
    if module ~= "BunkerCampaign" or command ~= "stateSnapshot"
        or type(args) ~= "table" or type(args.heating) ~= "table" then return end
    HeatingClient.snapshot = args.heating
    HeatingClient.apply()
end

function HeatingClient.onClimateTick()
    local heating = HeatingClient.snapshot
    if type(heating) == "table" then ClimateAdapter.apply(heating) end
end

Events.OnServerCommand.Add(HeatingClient.onServerCommand)
Events.OnClimateTick.Add(HeatingClient.onClimateTick)

BunkerCampaignIntegration.HeatingClient = HeatingClient
return HeatingClient
