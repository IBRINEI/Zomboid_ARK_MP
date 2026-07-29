local attempts = 0
BWOARooms.AirVentRoom = {
    Build = function()
        attempts = attempts + 1
        error("deliberate build failure")
    end,
}

Events.OnInitGlobalModData.handlers[2](true)
assert(BunkerCampaignArkMP.Server.state.status == "build_error", "failed build must latch an error state")
assert(attempts == 1, "initial build must run once")

for _ = 1, 20 do Events.LoadGridsquare.handlers[1]({}) end
Events.EveryOneMinute.handlers[1]()
assert(attempts == 1, "grid and minute events must not retry a latched build error")

local admin = ArkMPServerEntryPlayer()
admin.admin = true
Events.OnClientCommand.handlers[1]("BunkerCampaignArkMP", "retryBuild", admin, {})
assert(attempts == 2, "an explicit admin retry must run exactly one new attempt")
assert(BunkerCampaignArkMP.Server.state.status == "build_error", "a repeated failure must latch again")

print("BunkerCampaignArkMP build error latch tests passed")
