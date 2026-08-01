package brine.bunkercampaign.compat;

import java.io.File;
import java.net.URI;

public final class RelativeModPathPatchTest {
    private RelativeModPathPatchTest() {
    }

    public static void main(String[] args) throws Exception {
        File root = new File("C:/Users/BRINE/Zomboid/mods/Bandits/common");
        String actual = new File(root,
                "media/AnimSets/player/HitReaction/HitReaction.xml").getPath();
        URI lowerRoot = URI.create(root.toURI().toString().toLowerCase());

        assertEquals("media/AnimSets/player/hitreaction/HitReaction.xml",
                RelativeModPathPatch.fixResult(lowerRoot, actual, actual));
        assertEquals("already/relative.xml",
                RelativeModPathPatch.fixResult(lowerRoot, actual,
                        "already/relative.xml"));
        assertEquals(actual,
                RelativeModPathPatch.fixResult(null, actual, actual));

        System.out.println("RelativeModPathPatchTest: PASS");
    }

    private static void assertEquals(String expected, String actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected <" + expected + "> but was <"
                    + actual + ">");
        }
    }
}
