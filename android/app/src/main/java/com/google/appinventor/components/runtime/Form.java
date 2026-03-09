package com.google.appinventor.components.runtime;
import android.app.Activity;
import android.os.Handler;

public class Form implements ComponentContainer {
    private final Activity activity;
    private final Handler handler;

    public Form(Activity activity) {
        this.activity = activity;
        this.handler = new Handler();
    }

    @Override
    public Activity $context() { return activity; }

    @Override
    public Form $form() { return this; }

    public void dispatchErrorOccurredEvent(Component component, String functionName, int errorNumber, Object... messageArgs) {
        // Handle error if needed
    }

    public void runOnUiThread(Runnable runnable) {
        activity.runOnUiThread(runnable);
    }

    public void registerForOnInitialize(Component component) {}
    public void registerForOnCreate(Component component) {}
    public void registerForOnResume(Component component) {}
    public void registerForOnPause(Component component) {}
    public void registerForOnStop(Component component) {}
    public void registerForOnDestroy(Component component) {}
    public void registerForOnStop(OnStopListener listener) {}
    public void registerForOnResume(OnResumeListener listener) {}
    public void registerForOnPause(OnPauseListener listener) {}

    public boolean canDispatchEvent(Component component, String eventName) {
        return true;
    }
}
