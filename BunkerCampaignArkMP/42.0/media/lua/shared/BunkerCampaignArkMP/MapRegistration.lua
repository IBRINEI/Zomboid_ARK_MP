require "BunkerCampaignArkMP/Constants"

BunkerCampaignArkMP = BunkerCampaignArkMP or {}

local Constants = BunkerCampaignArkMP.Constants
local MapRegistration = { registered = false }

local basementDefinitions = {
    ark_underground_all = {
        width = 28,
        height = 50,
        stairx = 0,
        stairy = 0,
        stairDir = "N",
    },
    ark_twinrooms = {
        width = 12,
        height = 3,
        stairx = 0,
        stairy = 0,
        stairDir = "",
    },
}

local spawnLocations = {
    {
        x = 9948,
        y = 12600,
        z = -4,
        stairDir = "N",
        choices = { "ark_underground_all" },
    },
    {
        x = 9962,
        y = 12643,
        z = -3,
        stairDir = "",
        choices = { "ark_twinrooms" },
    },
}

function MapRegistration.register()
    if MapRegistration.registered then return true end
    if type(Basements) ~= "table" or type(Basements.getAPIv1) ~= "function" then
        print("[BunkerCampaignArkMP] Basements API is unavailable")
        return false
    end

    local api = Basements.getAPIv1()
    if not api then
        print("[BunkerCampaignArkMP] Basements API v1 returned nil")
        return false
    end

    api:addBasementDefinitions(Constants.MAP_ID, basementDefinitions)
    api:addSpawnLocations(Constants.MAP_ID, spawnLocations)
    MapRegistration.registered = true
    print("[BunkerCampaignArkMP] registered Ark basement prefabs for " .. Constants.MAP_ID)
    return true
end

Events.OnLoadMapZones.Add(MapRegistration.register)

BunkerCampaignArkMP.MapRegistration = MapRegistration
return MapRegistration
