BunkerCampaignIntegration = BunkerCampaignIntegration or {}

local Constants = {}

Constants.MOD_ID = "BunkerCampaignIntegration"
Constants.NETWORK_MODULE = "BunkerCampaignIntegration"
Constants.STATE_KEY = "BunkerCampaign.IntegrationState"
Constants.STATE_VERSION = 2
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

BunkerCampaignIntegration.Constants = Constants
return Constants
