local Server = BunkerCampaignThermalJava.ThermalServer

assert(#Events.OnInitGlobalModData.callbacks == 1,
    "server must register one initialization callback")
assert(#Events.OnServerStarted.callbacks == 1,
    "server must register one post-start callback")
assert(#Events.EveryOneMinute.callbacks == 1,
    "server must register one refresh callback")

local ok, count = Server.refresh()
assert(ok and count == 3 and Server.regionCount == 3,
    "server must publish every authoritative thermal region")
assert(Server.lastStatus == "active" and Server.refreshCount == 1,
    "successful server publication must be observable")
assert(#committedThermalRegions == 3,
    "server must atomically commit the complete registry")

BunkerCampaign.CampaignState.get().bunker.modules.heating.rooms.corridor.temperature = -35
Server.onMinute()
local found = false
for _, region in ipairs(committedThermalRegions) do
    if region.roomId == "corridor" and region.temperature == -35 then found = true end
end
assert(found, "minute refresh must propagate changed authoritative temperatures")

print("BunkerCampaignThermalJava server tests passed")
