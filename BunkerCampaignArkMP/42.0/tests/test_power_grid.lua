BunkerCampaignArkMP.PowerGrid.sync()
local mainLight, emergencyLight = ArkMPPowerGridLights()
assert(mainLight.active == true and emergencyLight.active == false,
    "main grid must enable main lights and keep emergency lights dark")
assert(emergencyLight.useBattery == true and emergencyLight.hasBattery == true
    and emergencyLight.canBeModified == false and emergencyLight.power == 1000,
    "streamed emergency fixtures must recover their non-persistent battery identity")

local commands = ArkMPPowerGridCommands()
assert(#commands == 0,
    "startup initialization must not broadcast before the server transport exists")
BunkerCampaignArkMP.PowerGrid.setNetworkReady(true)
BunkerCampaignArkMP.PowerGrid.sync(false)
assert(#commands == 1 and commands[1].command == "powerLighting",
    "initial lighting state must be broadcast to connected clients")
assert(commands[1].args.mainActive == true and commands[1].args.emergencyActive == false,
    "initial lighting broadcast must match physical lights")

-- CampaignState invokes power listeners every game minute.  With no actual
-- transition this must not scan and rewrite hundreds of fixtures.
mainLight.active = false
BunkerCampaignArkMP.PowerGrid.sync()
assert(mainLight.active == false and #commands == 1,
    "unchanged listener updates must neither rescan lights nor rebroadcast")
BunkerCampaignArkMP.PowerGrid.sync(true)
assert(mainLight.active == true and #commands == 1,
    "an explicit startup/arrival reconciliation must repair streamed fixtures once")

local power = ArkMPPowerGridState()
power.gridOnline = false
power.emergencyMode = true
power.consumers.main_lighting.allocated = false
power.consumers.emergency_lighting.allocated = true
BunkerCampaignArkMP.PowerGrid.sync()

assert(mainLight.active == false and emergencyLight.active == true,
    "battery mode must disable main lights and enable red emergency lights")
assert(#commands == 2 and commands[2].args.mainActive == false and commands[2].args.emergencyActive == true,
    "lighting transition must be broadcast to every client")
local lighting = BunkerCampaignArkMP.PowerGrid.getLightingState()
assert(lighting.mainActive == false and lighting.emergencyActive == true,
    "late join manifest must expose current lighting state")

print("BunkerCampaignArkMP power-grid lighting tests passed")
