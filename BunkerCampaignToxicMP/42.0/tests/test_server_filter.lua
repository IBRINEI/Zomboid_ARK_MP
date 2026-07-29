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

print("BunkerCampaignToxicMP server filter tests passed")
