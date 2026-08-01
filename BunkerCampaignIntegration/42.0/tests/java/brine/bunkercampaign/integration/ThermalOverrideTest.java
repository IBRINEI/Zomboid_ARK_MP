package brine.bunkercampaign.integration;

public final class ThermalOverrideTest {
    private ThermalOverrideTest() {
    }

    public static void main(String[] args) {
        ThermalOverride.clear();
        assertNear(ThermalOverride.resolve(10, 20, -4, 22), 22);

        ThermalOverride.begin();
        check(ThermalOverride.addRegion("corridor", 0, 0, 20, 20, -4, -30));
        check(ThermalOverride.addRegion("lab", 10, 10, 12, 12, -4, -12.5));
        check(ThermalOverride.commit() == 2);

        assertNear(ThermalOverride.resolve(1, 1, -4, 22), -30);
        assertNear(ThermalOverride.resolve(11, 11, -4, 22), -12.5f);
        assertNear(ThermalOverride.resolve(11, 11, -3, 22), 22);

        ThermalOverride.begin();
        check(ThermalOverride.addRegion("cold", 1, 1, 1, 1, -4, -500));
        check(ThermalOverride.commit() == 1);
        assertNear(ThermalOverride.resolve(1, 1, -4, 22), -100);

        ThermalOverride.clear();
        check(ThermalOverride.regionCount() == 0);
        System.out.println("BunkerCampaignIntegration thermal override tests passed");
    }

    private static void check(boolean value) {
        if (!value) {
            throw new AssertionError("check failed");
        }
    }

    private static void assertNear(float actual, float expected) {
        if (Math.abs(actual - expected) > 0.0001f) {
            throw new AssertionError(actual + " != " + expected);
        }
    }
}
