import java.io.Reader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import se.krka.kahlua.luaj.compiler.LuaCompiler;

public final class LuaSyntaxCheck {
    public static void main(String[] args) throws Exception {
        int failures = 0;
        for (String argument : args) {
            Path path = Path.of(argument);
            try (Reader reader = Files.newBufferedReader(path, StandardCharsets.UTF_8)) {
                LuaCompiler.loadis(reader, path.toString(), null);
                System.out.println("OK\t" + path);
            } catch (Throwable error) {
                failures++;
                System.err.println("FAIL\t" + path + "\t" + error.getMessage());
            }
        }
        if (failures > 0) System.exit(1);
    }
}
