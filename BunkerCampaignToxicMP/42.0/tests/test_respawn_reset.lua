Events.OnInitGlobalModData.handlers[1](true)

local state = BunkerCampaignToxicMP.Server.state
state.players["filter-tester"] = { exposure=100, awaitingRespawn=true }
Events.OnClientCommand.handlers[1]("BunkerCampaignToxicMP", "requestStatus", ToxicFilterPlayer(), {})

assert(state.players["filter-tester"].exposure == 0, "a replacement character must not inherit lethal exposure")
assert(state.players["filter-tester"].awaitingRespawn == nil, "respawn marker must be cleared")
local commands = ToxicFilterCommands()
assert(commands[#commands].command == "exposureStatus" and commands[#commands].args.exposure == 0,
    "the first status for a replacement character must already report zero exposure")

print("BunkerCampaignToxicMP respawn reset tests passed")
