package com.google.appinventor.components.runtime;

import java.util.HashMap;
import java.util.Map;

public class EventDispatcher {
    public interface EventListener {
        void onEvent(Component component, String eventName, Object... args);
    }

    private static EventListener listener;

    public static void setEventListener(EventListener l) {
        listener = l;
    }

    public static boolean dispatchEvent(Component component, String eventName, Object... args) {
        if (listener != null) {
            listener.onEvent(component, eventName, args);
            return true;
        }
        return false;
    }

    public static void registerEventForDelegation(Component component, String containerName, String eventName) {
        // No-op for mock
    }
}
