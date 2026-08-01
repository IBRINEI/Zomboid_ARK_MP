package brine.bunkercampaign.thermal.external;

import brine.bunkercampaign.thermal.ThermalOverride;

public final class ExternalAccessProbe {
    private ExternalAccessProbe() {
    }

    public static float resolve(int x, int y, int z, float fallback) {
        return ThermalOverride.resolve(x, y, z, fallback);
    }
}
