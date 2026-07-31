BunkerCampaign = BunkerCampaign or {}

local Constants = {}

Constants.MOD_ID = "BunkerCampaign"
Constants.NETWORK_MODULE = "BunkerCampaign"
Constants.STATE_KEY = "BunkerCampaign.State"
Constants.CURRENT_STATE_VERSION = 6
Constants.MAX_AUDIT_LOG_ENTRIES = 100
Constants.CLIENT_AUDIT_LOG_ENTRIES = 12
Constants.SYNC_INTERVAL_MINUTES = 5
Constants.BUNKER_CONTROL_BOUNDS = {
    x1 = 9918, x2 = 9981,
    y1 = 12595, y2 = 12652,
    levels = { [-4] = true, [-5] = true, [-7] = true },
}

Constants.VENTILATION = {
    MIN_CO2 = 420,
    MAX_CO2 = 100000,
    CO2_GENERATION_PPM_M3_PER_PERSON_MINUTE = 4800,
    EXTERNAL_CO2_PPM = 420,
    EXTERNAL_FLOW_M3_PER_MINUTE = 700,
    RECIRCULATION_FLOW_M3_PER_MINUTE = 450,
    EMERGENCY_FLOW_M3_PER_MINUTE = 1200,
    -- Sealed is an intentional isolation state.  Passive leakage belongs to
    -- OFF; a breached entry path is handled separately and still overrides it.
    SEALED_LEAK_FRACTION_PER_MINUTE = 0,
    ROOM_MIX_FRACTION_PER_MINUTE = 0.025,
    FILTER_EFFICIENCY = 1.0,
    FILTER_LOAD_CAPACITY = 150000,
    AIRBORNE_TRACE_CUTOFF = 0.02,
    ENTRY_BREACH_EXCHANGE_PER_MINUTE = 0.35,
    FAN_POWER_EXTERNAL_KW = 3.5,
    FAN_POWER_RECIRCULATION_KW = 2.2,
    FAN_POWER_EMERGENCY_KW = 4.5,
    AIRLOCK_PURGE_MINUTES = 2,
}

Constants.VENTILATION_MODES = {
    off=true,
    external_filtration=true,
    internal_recirculation=true,
    emergency_ventilation=true,
    sealed=true,
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
    NOMINAL_FLOW_LPM = 12,
    PUMP_POWER_KW = 1.5,
    FILTER_EFFICIENCY = 0.98,
    DRINKABLE_CONTAMINATION = 0.02,
    MAX_TRANSACTION_HISTORY = 64,
}

Constants.VALID_WATER_STATUS = {
    offline = true,
    operational = true,
    degraded = true,
    contaminated = true,
    failed = true,
}

Constants.VALID_ROOM_STATUS = {
    operational=true,
    degraded=true,
    emergency=true,
    uninhabitable=true,
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
