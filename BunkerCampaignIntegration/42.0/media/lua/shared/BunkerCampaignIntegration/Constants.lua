BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local Constants = {}

Constants.MOD_ID = "BunkerCampaignIntegration"
Constants.NETWORK_MODULE = "BunkerCampaignIntegration"
Constants.DECON_NETWORK_MODULE = "BunkerCampaignDecontamination"
Constants.STATE_KEY = "BunkerCampaign.IntegrationState"
Constants.STATE_VERSION = 4
Constants.THE_ARK_STATE_KEY = "BanditWeekOneTheArk"
Constants.TOXIC_ZONES_STATE_KEY = "ToxicZone"
Constants.WATERPIPES_STATE_KEY = "WaterPipes"
Constants.MAX_IMPORTED_ZONES = 256
Constants.BUNKER_BOUNDS = {
    x1 = 9918,
    x2 = 9981,
    y1 = 12595,
    y2 = 12652,
    levels = { [-4] = true, [-5] = true, [-7] = true },
}
Constants.BUNKER_WATER_PUMP = { x = 9950, y = 12616, z = -4 }
Constants.BUNKER_WATER_FLOWMETER = { x = 9954, y = 12615, z = -4 }
Constants.BUNKER_WATER_PIPES = {
    { x = 9950, y = 12615, z = -4, shape = "ns" },
    { x = 9951, y = 12616, z = -4, shape = "we" },
    { x = 9952, y = 12616, z = -4, shape = "nw" },
    { x = 9952, y = 12615, z = -4, shape = "se" },
    { x = 9953, y = 12615, z = -4, shape = "we" },
    { x = 9954, y = 12615, z = -4, shape = "we" },
    { x = 9955, y = 12615, z = -4, shape = "we" },
    { x = 9956, y = 12615, z = -4, shape = "we" },
}
Constants.BUNKER_WATER_BUILDING_CONNECTION = { x = 9956, y = 12615, z = -4 }
Constants.BUNKER_PUMP_POWER_DEMAND_KW = 1.5

Constants.DECONTAMINATION = {
    ROOM = { x1=9944, x2=9949, y1=12622, y2=12628, z=-4 },
    INTERACTION = { x1=9942, x2=9951, y1=12620, y2=12630, z=-4 },
    DIRTY_ENTRY = { x=9942.5, y=12625.5, z=-4 },
    CHAMBER = { x=9948.5, y=12623.5, z=-4 },
    CLEAN_EXIT = { x=9951.5, y=12625.5, z=-4 },
    REAGENT_STORAGE = { x=9950.5, y=12621.5, z=-5 },
    EXTERIOR_TEST = { x=9928.5, y=12625.5, z=0 },
    TEST_ZONE_NAME = "BunkerCampaignExteriorQA",
    TEST_ZONE = { startX=9918, startY=12618, endX=9943, endY=12632 },
    MAX_REAGENT_UNITS = 100,
    TABLET_UNITS = 50,
    MANUAL_WASH = {
        baseWaterLiters=4,
        contaminationPerAdditionalLiter=10,
        contaminationPerAgentUse=25,
        minimumDuration=100,
    },
    MODES = {
        emergency = {
            durationSeconds=10,
            waterLiters=5,
            mixerUnits=2,
            bodyRemoval=0.80,
            gearRemoval=0.50,
            onlyMostContaminated=false,
            requiresPower=false,
        },
        automatic = {
            durationSeconds=20,
            waterLiters=20,
            mixerUnits=5,
            bodyRemoval=1.00,
            gearRemoval=1.00,
            onlyMostContaminated=false,
            requiresPower=true,
        },
    },
}

BunkerCampaignIntegration.Constants = Constants
return Constants
