isClient = function() return false end
isServer = function() return true end

local function event()
    local value = { handlers={} }
    value.Add = function(handler) value.handlers[#value.handlers + 1] = handler end
    return value
end
Events = { OnInitGlobalModData=event() }

local persisted = {
    ["BunkerCampaign.IntegrationState"]={},
    WaterPipes={
        Pumps={}, Pipes={}, Valves={}, Flowmeters={}, Sprinklers={}, Buildings={},
        Barrels={ clean={x=9952,y=12603,z=-5,w=1000,wmax=2000,m="Water"} },
    },
}
ModData = {
    getOrCreate=function(key) persisted[key] = persisted[key] or {}; return persisted[key] end,
}
TransmitWPModData = function() end

local waterState = { telemetry={consumedLiters=0,lastTransactionId=""} }
BunkerCampaign.CampaignState = {
    get=function() return {bunker={modules={water=waterState}}} end,
    setWaterSnapshot=function() end,
}
