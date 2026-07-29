BunkerCampaignArkMP = {}

local handlers = {}
Events = {
    OnLoadMapZones = {
        Add = function(handler) handlers[#handlers + 1] = handler end,
    },
}

local recorded = {}
Basements = {
    getAPIv1 = function()
        return {
            addBasementDefinitions = function(self, mapID, definitions)
                recorded.mapID = mapID
                recorded.definitions = definitions
            end,
            addSpawnLocations = function(self, mapID, locations)
                recorded.spawnMapID = mapID
                recorded.locations = locations
            end,
        }
    end,
}

function ArkMPMapHandlers() return handlers end
function ArkMPMapRecorded() return recorded end
