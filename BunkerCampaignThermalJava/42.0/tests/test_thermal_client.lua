local Client = BunkerCampaignThermalJava.ThermalClient

assert(#Events.OnServerCommand.callbacks == 1, "client must register one snapshot callback")
assert(#Events.OnDisconnect.callbacks == 1, "client must clear overrides on disconnect")

Client.onServerCommand("OtherModule", "stateSnapshot", { heating={} })
assert(Client.snapshot == nil, "unrelated snapshots must be ignored")

Client.onServerCommand("BunkerCampaign", "stateSnapshot", {
    heating={ rooms={ corridor={
        temperature=-22,
        bounds={ x1=1, y1=2, x2=3, y2=4, z=-4 },
    } } },
})
assert(Client.snapshot ~= nil and Client.regionCount == 1,
    "authoritative heating snapshots must publish the region registry")
assert(Client.lastStatus == "active", "successful publication must be observable")

Client.clear()
assert(Client.snapshot == nil and Client.regionCount == 0,
    "disconnect cleanup must remove the optional module state")

print("BunkerCampaignThermalJava client tests passed")
