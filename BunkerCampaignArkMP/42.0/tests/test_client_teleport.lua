local player = ArkMPClientPlayer()
local commands = ArkMPClientCommands()

Events.OnCreatePlayer.handlers[1](0, player)
for index = 1, 30 do Events.OnPlayerUpdate.handlers[1](player) end
assert(#commands == 1 and commands[1].command == "joinReady", "entry request must be delayed until the player has a square")

Events.OnServerCommand.handlers[1]("BunkerCampaignArkMP", "teleportToBunker", {
    x=9966.5, y=12622.5, z=-4, nativeTeleport=true,
})
assert(player.teleported ~= true, "client must not duplicate the native server teleport")

-- Simulate the native GameServer.sendTeleport packet being applied by the
-- engine before the next player update.
player.x, player.y, player.z = 9966.5, 12622.5, -4

Events.OnPlayerUpdate.handlers[1](player)
assert(#commands == 2 and commands[2].command == "arrived", "client must confirm arrival after teleport")
assert(commands[2].args.z == -4, "arrival confirmation must contain actual coordinates")

player.x, player.y, player.z, player.teleported = 10944, 9374, 0, false
Events.OnServerCommand.handlers[1]("BunkerCampaignArkMP", "teleportToBunker", {
    x=9966.5, y=12622.5, z=-4, nativeTeleport=false,
})
assert(player.teleported == true, "client must apply the server-authorized fallback when GameServer is unavailable")
Events.OnPlayerUpdate.handlers[1](player)
assert(#commands == 3 and commands[3].command == "arrived", "fallback teleport must use the same arrival confirmation")

Events.OnServerCommand.handlers[1]("BunkerCampaignArkMP", "teleportToBunker", {
    x=9969.5, y=12638.5, z=-5, confirmArrival=false, nativeTeleport=true,
})
Events.OnPlayerUpdate.handlers[1](player)
assert(#commands == 3, "inspection teleport must not trigger the bunker-entry confirmation loop")

local redLight, lightSquare = ArkMPInstallLightFixture(false)
Events.OnServerCommand.handlers[1]("BunkerCampaignArkMP", "lightManifest", {
    lights={ {
        x=9960, y=12622, z=-4, sprite="test-red-light", occurrence=1,
        role="emergency", active=false, useBattery=true,
    } },
    phantoms={},
    lighting={ mainActive=false, emergencyActive=true },
})
for _ = 1, 5 do Events.OnPlayerUpdate.handlers[1](player) end
assert(redLight.active == true, "second client must apply current emergency-light state from its manifest")
assert(redLight.visualActive == true, "manifest reconciliation must enable the local light source")

Events.OnServerCommand.handlers[1]("BunkerCampaignArkMP", "powerLighting", {
    mainActive=true, emergencyActive=false,
})
for _ = 1, 5 do Events.OnPlayerUpdate.handlers[1](player) end
assert(redLight.active == false, "all clients must apply later power-lighting transitions")
assert(redLight.visualActive == false, "power transition must disable the local light source")

redLight.active = true
Events.LoadGridsquare.handlers[1](lightSquare)
for _ = 1, 5 do Events.OnPlayerUpdate.handlers[1](player) end
assert(redLight.active == false,
    "a light restored from a saved chunk must be reconciled without another bunker entry")

print("BunkerCampaignArkMP client teleport tests passed")
