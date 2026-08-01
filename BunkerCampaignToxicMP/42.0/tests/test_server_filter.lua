Events.OnInitGlobalModData.handlers[1](true)
Events.OnTick.handlers[1]()
ToxicFilterAdvance(2000)
Events.OnTick.handlers[1]()

assert(ToxicFilterMaskData().percent < 1, "server must drain the filter while protected in a toxic zone")
assert(ToxicFilterSyncCount() >= 1, "server must transmit changed filter modData to the client")
assert(ToxicFilterFieldSyncCount() >= 1, "server must synchronize the visible item condition")
assert(ToxicFilterCondition() < 10, "visible item condition must reflect remaining filter charge")

local firstRemaining = ToxicFilterMaskData().percent
ToxicFilterMaskData().percent = 1 -- simulate a stale owning-client inventory packet
ToxicFilterAdvance(2000)
Events.OnTick.handlers[1]()
assert(ToxicFilterMaskData().percent < firstRemaining,
    "stale client item modData must not refill the server-authoritative filter")

local inZoneRemaining = ToxicFilterMaskData().percent
ToxicFilterMoveOutside()
ToxicFilterAdvance(2000)
Events.OnTick.handlers[1]()
assert(ToxicFilterMaskData().percent < inZoneRemaining,
    "a worn gas-mask filter must continue draining outside toxic zones")

ToxicFilterEnableContactTarget()
local source = BunkerCampaignToxicMP.Server.getPlayerRecord(ToxicFilterPlayer())
local target = BunkerCampaignToxicMP.Server.getPlayerRecord(ToxicFilterContactTarget())
source.surfaceContamination = 80
source.gearContamination = 80
target.surfaceContamination = 0
target.gearContamination = 0
ToxicFilterAdvance(2000)
Events.OnTick.handlers[1]()
assert(target.surfaceContamination > 0,
    "a highly contaminated nearby player must transfer surface contamination")

local zoneNotifications = 0
BunkerCampaignToxicMP.Server.addZoneListener(function() zoneNotifications = zoneNotifications + 1 end)
assert(BunkerCampaignToxicMP.Server.ensureZone("z-level-test", {
    startX=0,startY=0,endX=5,endY=5,startZ=-4,endZ=-4,
}), "server must accept a bounded single-level zone")
assert(zoneNotifications == 1, "zone changes must notify the ventilation integration immediately")
local foundLevel = false
for _, zone in ipairs(BunkerCampaignToxicMP.Server.zones) do
    if zone.name == "z-level-test" and zone.z1 == -4 and zone.z2 == -4 then foundLevel = true end
end
assert(foundLevel, "zone sanitization must preserve vertical bounds")

print("BunkerCampaignToxicMP server filter tests passed")
