BunkerCampaignToxicMP = {}

local function event()
    local result = { handlers = {} }
    result.Add = function(handler) result.handlers[#result.handlers + 1] = handler end
    return result
end

Events = {
    OnInitGlobalModData = event(),
    OnTick = event(),
    OnClientCommand = event(),
}

local maskData = { percent = 1 }
local maskCondition = 10
local calls = { fields=0, commands={} }
local mask = {
    getType = function() return "PPM88" end,
    getModData = function() return maskData end,
    getID = function() return 77 end,
    getConditionMax = function() return 10 end,
    getCondition = function() return maskCondition end,
    setCondition = function(self, value) maskCondition = value end,
    syncItemFields = function() calls.fields = calls.fields + 1 end,
}
local worn = {
    size = function() return 1 end,
    getItemByIndex = function(self, index) return mask end,
}
local player = {
    isGodMod = function() return false end,
    getWornItems = function() return worn end,
    isDead = function() return false end,
    getUsername = function() return "filter-tester" end,
    getX = function() return 10 end,
    getY = function() return 10 end,
    setHealth = function() end,
}
local players = {
    size = function() return 1 end,
    get = function(self, index) return player end,
}
local persisted = {
    ToxicZone = {
        test = { startX=0, startY=0, endX=20, endY=20 },
    },
}
local now = 1000
local synced = 0

isClient = function() return false end
isServer = function() return true end
getTimestampMs = function() return now end
getOnlinePlayers = function() return players end
ModData = {
    getOrCreate = function(key)
        persisted[key] = persisted[key] or {}
        return persisted[key]
    end,
    transmit = function(key) end,
}
sendServerCommand = function(player, module, command, args)
    calls.commands[#calls.commands + 1] = { module=module, command=command, args=args }
end
syncItemModData = function(owner, item)
    assert(owner == player and item == mask, "filter sync must target the owning player and worn mask")
    synced = synced + 1
end

function ToxicFilterAdvance(ms) now = now + ms end
function ToxicFilterMaskData() return maskData end
function ToxicFilterSyncCount() return synced end
function ToxicFilterFieldSyncCount() return calls.fields end
function ToxicFilterCondition() return maskCondition end
function ToxicFilterPlayer() return player end
function ToxicFilterCommands() return calls.commands end
