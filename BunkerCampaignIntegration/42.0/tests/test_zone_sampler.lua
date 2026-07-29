local zones, sourceCount, rejectedCount = BunkerCampaignIntegration.ZoneSampler.sanitize({
    valid = { startX = 10, startY = 20, endX = 0, endY = 0 },
    invalid = { startX = "bad", startY = 0, endX = 1, endY = 1 },
})

assert(sourceCount == 2, "all source zones must be counted")
assert(#zones == 1, "only valid zones must be imported")
assert(rejectedCount == 1, "invalid zones must be rejected")
assert(BunkerCampaignIntegration.ZoneSampler.isPointToxic(zones, 5, 5), "reversed coordinates must normalize")
assert(not BunkerCampaignIntegration.ZoneSampler.isPointToxic(zones, 50, 50), "outside point must be clean")

local contamination, activeCount, toxicCount = BunkerCampaignIntegration.ZoneSampler.sampleAirIntakes(zones, {
    { x = 5, y = 5, broken = false },
    { x = 50, y = 50, broken = false },
    { x = 5, y = 5, broken = true },
})
assert(activeCount == 2, "broken air intakes must be excluded")
assert(toxicCount == 1, "one active intake must be toxic")
assert(contamination == 0.5, "contamination must equal toxic active-intake fraction")

print("BunkerCampaign integration zone tests passed")
