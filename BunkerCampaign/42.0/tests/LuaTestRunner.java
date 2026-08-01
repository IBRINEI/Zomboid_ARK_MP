import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;
import se.krka.kahlua.vm.KahluaThread;
import se.krka.kahlua.vm.LuaClosure;

public final class LuaTestRunner {
    public static void main(String[] args) throws Exception {
        StringBuilder source = new StringBuilder();
        for (String argument : args) {
            for (String line : Files.readAllLines(Path.of(argument), StandardCharsets.UTF_8)) {
                if (line.startsWith("require ")) continue;
                if (line.startsWith("local root =")) continue;
                if (line.startsWith("package.path =")) continue;
                if (line.matches("return (Constants|Util|Model|StateSchema|PowerSimulation|WaterSimulation|VentilationSimulation|HeatingSimulation|HeatingComponents|RoomRegistry|CampaignState|ClientState|ServerCommands|ZoneSampler|WaterpipesAdapter|WaterService|DecontaminationModel|ManualWashShared|ClimateAdapter|HeatingAdapter|ThermalOverrideAdapter|ThermalClient|ThermalServer|IntegrationState|TheArkClientBridge|MapRegistration|RepairIntakeAction|Client|Server|PowerGrid|BunkerCampaignArkMP|BunkerCampaignToxicMP)")) continue;
                source.append(line).append('\n');
            }
        }

        J2SEPlatform platform = J2SEPlatform.getInstance();
        KahluaTable environment = platform.newEnvironment();
        LuaClosure closure = LuaCompiler.loadstring(source.toString(), "BunkerCampaignTests", environment);
        KahluaThread thread = new KahluaThread(System.out, platform, environment);
        thread.debugOwnerThread = Thread.currentThread();
        Object[] result = thread.pcall(closure, new Object[0]);
        if (result.length == 0 || !Boolean.TRUE.equals(result[0])) {
            for (Object value : result) System.err.println(String.valueOf(value));
            System.exit(1);
        }
    }
}
