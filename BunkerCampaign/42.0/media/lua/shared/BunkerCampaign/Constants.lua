BunkerCampaign = BunkerCampaign or {}

local Constants = {}

Constants.MOD_ID = "BunkerCampaign"
Constants.NETWORK_MODULE = "BunkerCampaign"
Constants.STATE_KEY = "BunkerCampaign.State"
Constants.CURRENT_STATE_VERSION = 5
Constants.MAX_AUDIT_LOG_ENTRIES = 100
Constants.CLIENT_AUDIT_LOG_ENTRIES = 12
Constants.SYNC_INTERVAL_MINUTES = 5
Constants.BUNKER_CONTROL_BOUNDS = {
    x1 = 9918, x2 = 9981,
    y1 = 12595, y2 = 12652,
    levels = { [-4] = true, [-5] = true, [-7] = true },
}

Constants.VENTILATION = {
    MIN_CO2 = 400,
    MAX_CO2 = 10000,
    CO2_REMOVAL_PER_MINUTE = 30,
    CO2_RISE_PER_MINUTE = 20,
    BASE_FILTER_USE_PER_MINUTE = 0.00025,
    FILTER_CONTAMINATION_MULTIPLIER = 8,
    CONTAMINATION_INGRESS_PER_MINUTE = 0.004,
    CONTAMINATION_CLEAR_PER_MINUTE = 0.002,
}

Constants.VALID_VENTILATION_STATUS = {
    operational = true,
    degraded = true,
    emergency = true,
    failed = true,
}

Constants.WATER = {
    MAX_STORAGE = 1000000000,
    MAX_FLOW_PER_MINUTE = 1000000,
    MAX_POWER_DEMAND_KW = 1000,
}

Constants.VALID_WATER_STATUS = {
    offline = true,
    operational = true,
    degraded = true,
    contaminated = true,
    failed = true,
}

Constants.POWER = {
    MAIN_GENERATOR_MAX_KW = 12,
    BACKUP_GENERATOR_MAX_KW = 8,
    MAX_GENERATOR_OUTPUT_KW = 1000,
    MAX_CONSUMER_DEMAND_KW = 1000,
    MAX_TOTAL_POWER_KW = 10000,
    BATTERY_CAPACITY_KWH = 4,
    BATTERY_INITIAL_CHARGE = 1,
    BATTERY_MAX_OUTPUT_KW = 1,
    BATTERY_MAX_CHARGE_KW = 1,
    BATTERY_CHARGE_EFFICIENCY = 0.90,
    -- The original Ark uses 0.05 fuel-percent per kW and game minute by default.
    FUEL_PERCENT_PER_KW_MINUTE = 0.05,
    COOLANT_PERCENT_PER_MINUTE = 0.002,
    LUBRICANT_PERCENT_PER_MINUTE = 0.004,
    CONDITION_PERCENT_PER_MINUTE = 0.001,
    LOW_FLUID_CONDITION_PENALTY = 0.01,
}

Constants.VALID_POWER_STATUS = {
    offline = true,
    operational = true,
    degraded = true,
    emergency = true,
}

Constants.VALID_GENERATOR_STATUS = {
    offline = true,
    operational = true,
    degraded = true,
    exhausted = true,
    failed = true,
}

Constants.VALID_POWER_SOURCE = {
    off = true,
    generator = true,
    battery = true,
    shed = true,
}

BunkerCampaign.Constants = Constants
return Constants
