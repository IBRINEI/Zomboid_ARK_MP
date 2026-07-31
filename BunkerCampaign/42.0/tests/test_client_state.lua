local state = BunkerCampaign.ClientState
state.onServerCommand("BunkerCampaign", "stateSnapshot", {
    revision=10, ventilation={}, power={},
})
state.onServerCommand("BunkerCampaign", "stateSnapshot", {
    revision=9, ventilation={}, power={},
})
assert(state.snapshot.revision == 10,
    "an out-of-order state snapshot must not replace newer client state")
state.onServerCommand("BunkerCampaign", "stateSnapshot", {
    revision=11, ventilation={}, power={},
})
assert(state.snapshot.revision == 11,
    "a newer state snapshot must replace current client state")
print("BunkerCampaign client-state tests passed")
