local ark = ModData.getOrCreate("BanditWeekOneTheArk")
ark.ventilation = {
    active = false,
    co2 = 900,
    filter = 80,
}
ark.airintakes = {
    { x = 100, y = 100, broken = false },
    { x = 101, y = 100, broken = false },
    { x = 102, y = 100, broken = true },
}

local toxic = ModData.getOrCreate("ToxicZone")
toxic.arkIntakes = { startX = 99, startY = 99, endX = 101, endY = 101 }

local waterpipes = ModData.getOrCreate("WaterPipes")
waterpipes.Pumps = {
    ["9950-12616--4"] = { x = 9950, y = 12616, z = -4, efficiency = 90, filter = 75, active = true, burn = false },
}
waterpipes.Pipes = {}
waterpipes.Valves = {}
waterpipes.Flowmeters = {
    ["9954-12615--4"] = { x = 9954, y = 12615, z = -4, f = 500 },
}
waterpipes.Barrels = {
    bunker = { x = 9952, y = 12603, z = -5, w = 400, wmax = 1000, m = "Water" },
}
waterpipes.Sprinklers = {}
waterpipes.Buildings = {}

BunkerCampaign.CampaignState.initialize(true)
BunkerCampaignIntegration.IntegrationState.initialize(true)

local campaign = BunkerCampaign.CampaignState.get()
assert(#BunkerCampaignIntegration.Constants.ENTRY_DOORS == 4,
    "entry-path telemetry must track the surface gate and all three bunker gates")
assert(BunkerCampaign.RoomRegistry.get("laboratory"), "Ark laboratory must be discovered declaratively")
assert(BunkerCampaign.RoomRegistry.get("garage"), "future Ark garage must be discovered without simulation edits")
assert(BunkerCampaign.RoomRegistry.get("corridor"),
    "The Ark corridor without legacy rectangular bounds must use declarative composite geometry")
assert(BunkerCampaign.RoomRegistry.find(9957, 12630, -4).id == "corridor"
    and BunkerCampaign.RoomRegistry.find(9965, 12641, -4).id == "corridor",
    "both corridor stem and loop must resolve to the corridor ventilation room")
assert(campaign.bunker.modules.ventilation.rooms.laboratory
    and campaign.bunker.modules.ventilation.rooms.garage,
    "discovered rooms must receive ventilation state")
assert(BunkerCampaign.RoomRegistry.get("laboratory").connections[1] == "garage",
    "touching Ark rooms must receive inferred adjacency")
assert(campaign.bunker.modules.ventilation.enabled == false, "initial The Ark enabled state must be imported")
assert(campaign.bunker.modules.ventilation.co2 == 900, "initial The Ark CO2 must be imported")
assert(campaign.bunker.modules.ventilation.filterRemaining == 0.8, "initial The Ark filter must be imported")
assert(campaign.bunker.modules.ventilation.externalContamination == 1, "Toxic Zones must drive intake contamination")
assert(campaign.bunker.modules.water.status == "operational", "Waterpipes pump must feed authoritative water state")
assert(campaign.bunker.modules.water.stored == 4, "bunker water storage must be imported in liters")
assert(campaign.bunker.modules.water.flowPerMinute == 5, "bunker throughput must be imported in liters per minute")
assert(waterpipes.Pumps["9950-12616--4"].source == "TaintedWater", "adapter must bind the bunker pump to its underground well")
assert(ark.waterpump.x == 9950 and ark.waterpump.y == 12616, "correct pump coordinates must mirror to Ark state")

campaign.bunker.modules.ventilation.co2 = 1200
campaign.bunker.modules.ventilation.filterRemaining = 0.5
BunkerCampaign.CampaignState.touch()
BunkerCampaignIntegration.IntegrationState.updateOneMinute()
assert(ark.ventilation.co2 == 1200, "authoritative CO2 must mirror to The Ark")
assert(ark.ventilation.filter == 50, "authoritative filter must mirror to The Ark percent")

local function testPlayer(name, admin, x, y, z)
    return {
        getUsername = function(self) return name end,
        isAccessLevel = function(self, level) return admin and level == "admin" end,
        getX = function(self) return x or 0 end,
        getY = function(self) return y or 0 end,
        getZ = function(self) return z or 0 end,
    }
end

local pumpPlayer = testPlayer("pump_operator", false, 9950, 12616, -4)
BunkerCampaignIntegration.IntegrationState.onClientCommand(
    "Commands", "PumpMod", pumpPlayer,
    { x=9950, y=12616, z=-4, active=false }
)
assert(campaign.bunker.modules.power.consumers.water.requested == false,
    "Waterpipes pump OFF must update the authoritative water consumer")
BunkerCampaignIntegration.IntegrationState.onClientCommand(
    "Commands", "PumpMod", pumpPlayer,
    { x=9950, y=12616, z=-4, active=true }
)
assert(campaign.bunker.modules.power.consumers.water.requested == true,
    "Waterpipes pump ON must update the authoritative water consumer")
BunkerCampaignIntegration.IntegrationState.onClientCommand(
    "Commands", "PumpMod", pumpPlayer,
    { x=9950, y=12616, z=-4, efficiency=80 }
)
assert(waterpipes.Pumps["9950-12616--4"].efficiency == 80
    and campaign.bunker.modules.water.pumpCondition == 0.8,
    "Waterpipes repair must reach both the server pump and bunker systems snapshot")
BunkerCampaignIntegration.IntegrationState.onClientCommand(
    "Commands", "PumpMod", pumpPlayer,
    { x=9950, y=12616, z=-4, filter=0 }
)
assert(waterpipes.Pumps["9950-12616--4"].filter == 0
    and campaign.bunker.modules.water.filterRemaining == 0,
    "removing the physical treatment filter must update the bunker systems snapshot")

toxic.arkIntakes = { startX = 500, startY = 500, endX = 510, endY = 510 }
BunkerCampaignIntegration.IntegrationState.onClientCommand(
    "BunkerCampaignIntegration",
    "refreshToxicZones",
    testPlayer("survivor", false),
    {}
)
assert(campaign.bunker.modules.ventilation.externalContamination == 1, "ordinary player must not refresh cached zones")

BunkerCampaignIntegration.IntegrationState.onClientCommand(
    "BunkerCampaignIntegration",
    "refreshToxicZones",
    testPlayer("administrator", true),
    {}
)
assert(campaign.bunker.modules.ventilation.externalContamination == 0, "administrator refresh must import changed zones")

local status = BunkerCampaignIntegration.IntegrationState.snapshot()
assert(status.theArk.initialized, "integration status must report The Ark binding")
assert(status.toxicZones.acceptedCount == 1, "integration status must report imported zones")
assert(status.waterpipes.initialized and status.waterpipes.pumpFound, "integration status must report Waterpipes binding")

print("BunkerCampaign integration server tests passed")
