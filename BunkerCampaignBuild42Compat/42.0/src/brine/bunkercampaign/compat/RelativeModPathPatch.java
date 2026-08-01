package brine.bunkercampaign.compat;

import java.io.File;
import java.net.URI;

import me.zed_0xff.zombie_buddy.annotations.Patch;

/**
 * Build 42.20 lowercases the candidate file URI before URI.relativize().
 * URI paths are case-sensitive, so a normally cased Windows mod root no longer
 * matches and the engine returns an absolute path. That path cannot be looked
 * up in ZomboidFileSystem's relative-path map and breaks checksums/AnimSets.
 */
public final class RelativeModPathPatch {
    private RelativeModPathPatch() {
    }

    public static String fixResult(URI root, String path, String result) {
        if (root == null || path == null || result == null
                || !"file".equalsIgnoreCase(root.getScheme())
                || !result.equals(path)) {
            return result;
        }

        try {
            String rootPath = new File(root).getCanonicalPath();
            String filePath = new File(path).getCanonicalPath();
            if (filePath.equalsIgnoreCase(rootPath)) {
                return "";
            }

            String prefix = rootPath.endsWith(File.separator)
                    ? rootPath
                    : rootPath + File.separator;
            if (filePath.length() > prefix.length()
                    && filePath.regionMatches(true, 0, prefix, 0, prefix.length())) {
                return filePath.substring(prefix.length())
                        .replace(File.separatorChar, '/');
            }
        } catch (Exception ignored) {
            // Preserve the engine result when canonicalization is unavailable.
        }
        return result;
    }

    @Patch(className = "zombie.ZomboidFileSystem",
            methodName = "getRelativeFile", warmUp = true)
    public static final class Advice {
        private Advice() {
        }

        @Patch.OnExit
        public static void exit(@Patch.Argument(0) URI root,
                @Patch.Argument(1) String path,
                @Patch.Return(readOnly = false) String result) {
            result = fixResult(root, path, result);
        }
    }
}
