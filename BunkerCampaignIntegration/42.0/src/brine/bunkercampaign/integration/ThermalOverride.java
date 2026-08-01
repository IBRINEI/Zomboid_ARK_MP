package brine.bunkercampaign.integration;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

import se.krka.kahlua.integration.annotations.LuaMethod;

/**
 * Atomic room-temperature registry populated by the authoritative Lua state.
 * The active list is immutable so ClimateManager reads never observe a partial
 * stateSnapshot update.
 */
public final class ThermalOverride {
    private static final float MIN_TEMPERATURE = -100.0f;
    private static final float MAX_TEMPERATURE = 60.0f;

    private static volatile List<Region> active = Collections.emptyList();
    private static List<Region> staging;

    private ThermalOverride() {
    }

    @LuaMethod(name = "bcThermalBegin", global = true)
    public static synchronized boolean begin() {
        staging = new ArrayList<>();
        return true;
    }

    @LuaMethod(name = "bcThermalAddRegion", global = true)
    public static synchronized boolean addRegion(String roomId, double x1, double y1,
            double x2, double y2, double z, double temperature) {
        if (staging == null || !Double.isFinite(x1) || !Double.isFinite(y1)
                || !Double.isFinite(x2) || !Double.isFinite(y2)
                || !Double.isFinite(z) || !Double.isFinite(temperature)) {
            return false;
        }

        int left = (int) Math.floor(Math.min(x1, x2));
        int right = (int) Math.floor(Math.max(x1, x2));
        int top = (int) Math.floor(Math.min(y1, y2));
        int bottom = (int) Math.floor(Math.max(y1, y2));
        int level = (int) Math.floor(z);
        float value = (float) Math.max(MIN_TEMPERATURE,
                Math.min(MAX_TEMPERATURE, temperature));
        staging.add(new Region(roomId == null ? "" : roomId,
                left, top, right, bottom, level, value));
        return true;
    }

    @LuaMethod(name = "bcThermalCommit", global = true)
    public static synchronized int commit() {
        if (staging == null) {
            return -1;
        }
        active = Collections.unmodifiableList(new ArrayList<>(staging));
        staging = null;
        return active.size();
    }

    @LuaMethod(name = "bcThermalClear", global = true)
    public static synchronized void clear() {
        staging = null;
        active = Collections.emptyList();
    }

    @LuaMethod(name = "bcThermalRegionCount", global = true)
    public static int regionCount() {
        return active.size();
    }

    @LuaMethod(name = "bcThermalResolve", global = true)
    public static double resolveForLua(double x, double y, double z, double fallback) {
        return resolve((int) Math.floor(x), (int) Math.floor(y),
                (int) Math.floor(z), (float) fallback);
    }

    static float resolve(int x, int y, int z, float fallback) {
        Region best = null;
        long bestArea = Long.MAX_VALUE;
        for (Region region : active) {
            if (region.contains(x, y, z) && region.area < bestArea) {
                best = region;
                bestArea = region.area;
            }
        }
        return best == null ? fallback : best.temperature;
    }

    private static final class Region {
        @SuppressWarnings("unused")
        private final String roomId;
        private final int x1;
        private final int y1;
        private final int x2;
        private final int y2;
        private final int z;
        private final float temperature;
        private final long area;

        private Region(String roomId, int x1, int y1, int x2, int y2,
                int z, float temperature) {
            this.roomId = roomId;
            this.x1 = x1;
            this.y1 = y1;
            this.x2 = x2;
            this.y2 = y2;
            this.z = z;
            this.temperature = temperature;
            this.area = Math.max(1L, (long) (x2 - x1 + 1) * (y2 - y1 + 1));
        }

        private boolean contains(int x, int y, int level) {
            return level == z && x >= x1 && x <= x2 && y >= y1 && y <= y2;
        }
    }
}
