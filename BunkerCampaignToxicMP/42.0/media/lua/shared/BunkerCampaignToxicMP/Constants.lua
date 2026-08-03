BunkerCampaignToxicMP = BunkerCampaignToxicMP or {}

local Constants = {
    STATE_KEY = "BunkerCampaign.ToxicMP",
    ZONES_KEY = "ToxicZone",
    NETWORK_MODULE = "BunkerCampaignToxicMP",
    STATE_VERSION = 4,
    MAX_ZONES = 256,
    MAX_ZONE_SPAN = 20000,
    FILTER_DRAIN_PER_SECOND = 0.0006,
    EXPOSURE_PER_SECOND = 100 / 60,
    EXPOSURE_DECAY_PER_SECOND = 1,
    STATUS_INTERVAL_SECONDS = 2,
    CONTAMINATION_MODDATA_KEY = "BunkerCampaignSurfaceContamination",
    SURFACE_MAX = 100,
    SURFACE_TRACE = 0.5,
    SURFACE_DIRTY = 15,
    SURFACE_DANGEROUS = 60,
    SURFACE_BODY_DEPOSIT_PER_SECOND = 0.55,
    SURFACE_GEAR_DEPOSIT_PER_SECOND = 1.10,
    SURFACE_PACKED_ITEM_DEPOSIT_PER_SECOND = 0.20,
    SURFACE_CONTACT_FRACTION_PER_SECOND = 0.015,
    PLAYER_CONTACT_RADIUS = 2.0,
    PLAYER_CONTACT_FRACTION_PER_SECOND = 0.001,
    SURFACE_ITEM_SYNC_DELTA = 1.0,
    MAX_CARRIED_ITEMS_PER_SCAN = 80,
    MAX_WORLD_ITEMS_PER_CYCLE = 500,
    WORLD_CONTACT_RADIUS = 2,
    WORLD_CONTACT_FRACTION_PER_SECOND = 0.01,
}

Constants.PROTECTIVE_MASKS = {
    Exohelm=true, ExohelmBandit=true, ExohelmCS=true, ExohelmDuty=true,
    ExohelmEcologists=true, ExohelmFreedom=true, ExohelmLoner=true,
    ExohelmMercs=true, ExohelmMilitary=true, ExohelmMonolith=true,
    GP5GasMask=true, M40GasMask=true, PPM88=true, GP10Z=true,
    SEVAHelm=true, SEVAHelmBandit=true, SEVAHelmCS=true, SEVAHelmDuty=true,
    SEVAHelmEcologist=true, SEVAHelmFreedom=true, SEVAHelmMercs=true,
    SEVAHelmMonolith=true, SEVAHelmMonolithGreen=true, SovietPMG=true,
    Sphere08HelmetMilitary=true, Sphere08HelmetCS=true, Sphere08HelmetDuty=true,
    Sphere08HelmetFreedom=true, Sphere08HelmetMercs=true, Sphere08HelmetMonolith=true,
    SphereM12Helmet=true, SphereM12HelmetCS=true, SphereM12HelmetDuty=true,
    SphereM12HelmetFreedom=true, SphereM12HelmetMercs=true, SphereM12HelmetMonolith=true,
    SteelHelmMask=true, CS2aGasMask=true, PBF1=true, PBF1CS=true,
    PBF1Duty=true, PBF1Freedom=true, PBF2=true, PBF2CS=true,
    PBF2Duty=true, PBF2Freedom=true, RespiratorGold=true, RespiratorSilver=true,
    RespiratorCS=true, RespiratorFreedom=true, RespiratorDuty=true,
    RespiratorMonolith=true,
}

Constants.GAS_MASK_PATTERNS = {
    "gasmask", "gas_mask", "respirator", "hazmat", "nbcmask", "nbc_mask",
    "rebreather", "filtermask", "filter_mask", "protectivemask", "protective_mask",
}

Constants.CLOTH_MASK_PATTERNS = {
    "bandana", "balaclava", "scarf", "facemask", "face_mask", "dustmask",
    "dust_mask", "shemagh", "gaiter", "necktube", "neck_tube", "facewrap",
    "tapabocas", "clothmask", "surgicalmask", "surgical_mask",
}

-- Compatibility global used by the original tooltip code and other mods.
ProtectiveMasks = {}
for name, _ in pairs(Constants.PROTECTIVE_MASKS) do ProtectiveMasks[#ProtectiveMasks + 1] = name end

BunkerCampaignToxicMP.Constants = Constants
return Constants
