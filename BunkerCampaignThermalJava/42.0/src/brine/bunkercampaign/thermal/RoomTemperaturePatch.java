package brine.bunkercampaign.thermal;

import me.zed_0xff.zombie_buddy.annotations.Patch;
import zombie.iso.IsoGridSquare;

@Patch(className = "zombie.iso.weather.ClimateManager",
        methodName = "getAirTemperatureForSquare", warmUp = true)
public final class RoomTemperaturePatch {
    private RoomTemperaturePatch() {
    }

    @Patch.OnExit
    public static void exit(@Patch.Argument(0) IsoGridSquare square,
            @Patch.Return(readOnly = false) float result) {
        if (square != null) {
            result = ThermalOverride.resolve(square.getX(), square.getY(),
                    square.getZ(), result);
        }
    }
}
