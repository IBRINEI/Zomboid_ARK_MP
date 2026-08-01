BunkerCampaign = BunkerCampaign or {}
isClient = function() return true end
getPlayer = function() return nil end
sendClientCommand = function() end

local function event()
    return { Add=function() end }
end

Events = {
    OnServerCommand=event(),
    OnCreatePlayer=event(),
}
