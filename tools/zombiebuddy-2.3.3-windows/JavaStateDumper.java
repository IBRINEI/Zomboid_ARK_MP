package me.zed_0xff.zombie_buddy.patches.experimental;

import org.lwjgl.glfw.GLFW;
import org.lwjgl.glfw.GLFWKeyCallbackI;

import sun.misc.Signal;

import me.zed_0xff.zombie_buddy.Callbacks;
import me.zed_0xff.zombie_buddy.Logger;

/**
 * Project-local compatibility replacement for ZombieBuddy 2.3.3.
 *
 * Windows/JDK 25 does not provide the Unix INFO signal. Upstream calls
 * new Signal("INFO") before starting the experimental HTTP server, so the
 * resulting IllegalArgumentException aborts the rest of experimental PreMain.
 */
public class JavaStateDumper {
    private static GLFWKeyCallbackI originalKeyCallback = null;
    private static boolean initialized = false;
    private static long window = 0;

    static void init() {
        if (initialized) {
            return;
        }

        initialized = true;
        Callbacks.onDisplayCreate.register(JavaStateDumper::installKeyCallback);

        try {
            Signal.handle(new Signal("INFO"), JavaStateDumper::handleSignal);
        } catch (IllegalArgumentException | UnsupportedOperationException error) {
            Logger.warn("INFO signal is unavailable; Ctrl+T thread dumps remain enabled: " + error);
        }
    }

    public static void handleSignal(Signal signal) {
        if ("INFO".equals(signal.getName())) {
            dumpThreadStacks();
        } else {
            Logger.warn("Received unexpected signal: " + signal);
        }
    }

    public static void installKeyCallback() {
        try {
            if (!org.lwjglx.opengl.Display.isCreated()) {
                return;
            }

            long currentWindow = org.lwjglx.opengl.Display.getWindow();
            if (currentWindow == window) {
                return;
            }

            window = currentWindow;
            originalKeyCallback = GLFW.glfwSetKeyCallback(window, JavaStateDumper::handleKey);
            Logger.info("Installed GLFW key callback for Ctrl+T thread dump");
        } catch (Throwable error) {
            Logger.warn("Failed to install GLFW key callback: " + error);
        }
    }

    private static void handleKey(long currentWindow, int key, int scancode, int action, int mods) {
        if (key == GLFW.GLFW_KEY_T
                && action == GLFW.GLFW_PRESS
                && (mods & GLFW.GLFW_MOD_CONTROL) != 0) {
            dumpThreadStacks();
        }

        if (originalKeyCallback != null) {
            originalKeyCallback.invoke(currentWindow, key, scancode, action, mods);
        }
    }

    public static void dumpThreadStacks() {
        Logger.info("=== Thread Dump ===");
        for (var entry : Thread.getAllStackTraces().entrySet()) {
            Thread thread = entry.getKey();
            Logger.info(String.format("Thread: %s (state=%s)", thread.getName(), thread.getState()));
            for (StackTraceElement element : entry.getValue()) {
                Logger.info("    at " + element);
            }
        }
        Logger.info("=== End Thread Dump ===");
    }
}
