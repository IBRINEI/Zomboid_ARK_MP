Events.OnInitGlobalModData.handlers[2](true)
assert(ArkMPRoomMetadataInitCalls() == 1,
    "server restart must rebuild room coordinate manifests without rebuilding world objects")

local syncsBeforeGridStreaming = ArkMPPowerSyncCalls()
for _ = 1, 100 do Events.LoadGridsquare.handlers[1]({}) end
assert(ArkMPPowerSyncCalls() == syncsBeforeGridStreaming,
    "ready bunker must not rescan the power grid for every streamed square")

local player = ArkMPServerEntryPlayer()
Events.OnClientCommand.handlers[1]("BunkerCampaignArkMP", "joinReady", player, {})

assert(player.serverTeleported == true, "server must move its authoritative player object")
assert(player.nativeTeleported == true, "server must prefer the native multiplayer teleport packet")
assert(player:getX() == 9966.5 and player:getY() == 12622.5 and player:getZ() == -4,
    "server and client target coordinates must match")

local commands = ArkMPServerEntryCommands()
assert(#commands >= 2, "entry must return both teleport and status commands")
assert(commands[#commands - 1].command == "teleportToBunker", "entry must authorize client teleport")
assert(commands[#commands - 1].args.nativeTeleport == true, "client must be told that the native packet owns movement")
assert(commands[#commands].command == "status", "entry must return current construction status")

local commandCountBeforeArrival = #commands
Events.OnClientCommand.handlers[1]("BunkerCampaignArkMP", "arrived", player, {})
commands = ArkMPServerEntryCommands()
local receivedCurrentLighting = false
for index = commandCountBeforeArrival + 1, #commands do
    if commands[index].command == "powerLighting"
        and commands[index].target == player
        and commands[index].args.mainActive == true
        and commands[index].args.emergencyActive == false then
        receivedCurrentLighting = true
    end
end
assert(receivedCurrentLighting,
    "confirmed arrival must receive the current lighting state even without a global transition")

GameServer = nil
player.x, player.y, player.z = 10944, 9374, 0
player.networkAIRequested = false
Events.OnClientCommand.handlers[1]("BunkerCampaignArkMP", "joinReady", player, {})
assert(player.serverTeleported == true,
    "fallback must preposition the authoritative network player")
assert(player.networkAIRequested == false,
    "fallback must not index opaque B42.19 NetworkPlayerAI userdata")
commands = ArkMPServerEntryCommands()
assert(commands[#commands - 1].args.nativeTeleport == false,
    "fallback movement must be explicitly authorized for the owning client")

for _, probe in ipairs(BunkerCampaignArkMP.Constants.BUILD_PROBES) do
    assert(probe.name ~= "twinrooms", "optional upper twinrooms must not block main-bunker construction")
end

print("BunkerCampaignArkMP server entry tests passed")
