local clientMode = false
isClient = function() return clientMode end
isServer = function() return not clientMode end

local function event()
    return { Add=function(handler) end, Remove=function(handler) end }
end

Events = {
    OnInitGlobalModData=event(),
    OnReceiveGlobalModData=event(),
    OnServerStarted=event(),
}

local persisted = {}
ModData = {
    getOrCreate=function(key)
        if type(persisted[key]) ~= "table" then persisted[key] = {} end
        return persisted[key]
    end,
    request=function(key) end,
    transmit=function(key) end,
}

function ArkMPTestSetClient(value) clientMode = value end
function ArkMPTestPersisted() return persisted end
