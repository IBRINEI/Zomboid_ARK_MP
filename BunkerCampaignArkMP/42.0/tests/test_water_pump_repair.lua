BunkerCampaignArkMP.Server.state = { status = "ready" }

BunkerCampaignArkMP.Server.tryBuild()
assert(ArkMPWaterPumpRepairCalls() == 1, "ready bunker must repair one missing physical pump")
assert(ArkMPWaterPumpRepairSquare().pump ~= nil, "repair must leave a physical pump on the target square")

BunkerCampaignArkMP.Server.tryBuild()
assert(ArkMPWaterPumpRepairCalls() == 1, "repair must be idempotent when the pump already exists")

print("BunkerCampaignArkMP water pump repair tests passed")
