package brine.bunkercampaign.thermal;

import brine.bunkercampaign.thermal.external.ExternalAccessProbe;

public final class ThermalOverrideTest {
    private ThermalOverrideTest() {
    }

    public static void main(String[] args) {
        ThermalOverride.clear();
        assertNear(ExternalAccessProbe.resolve(10, 20, -4, 22), 22);

        ThermalOverride.begin();
        check(ThermalOverride.addRegion("corridor", 0, 0, 20, 20, -4, -30));
        check(ThermalOverride.addRegion("lab", 10, 10, 12, 12, -4, -12.5));
        check(ThermalOverride.commit() == 2);

        assertNear(ExternalAccessProbe.resolve(1, 1, -4, 22), -30);
        assertNear(ExternalAccessProbe.resolve(11, 11, -4, 22), -12.5f);
        assertNear(ExternalAccessProbe.resolve(11, 11, -3, 22), 22);

        ThermalOverride.begin();
        check(ThermalOverride.addRegion("cold", 1, 1, 1, 1, -4, -500));
        check(ThermalOverride.commit() == 1);
        assertNear(ExternalAccessProbe.resolve(1, 1, -4, 22), -100);

        ThermalOverride.clear();
        check(ThermalOverride.regionCount() == 0);
        System.out.println("BunkerCampaignThermalJava override tests passed");
    }

    private static void assertNear(float actual, float expected) {
        if (Math.abs(actual - expected) > 0.0001f) {
            throw new AssertionError(actual + " != " + expected);
        }
    }

    private static void check(boolean value) {
        if (!value) throw new AssertionError("check failed");
    }
}
