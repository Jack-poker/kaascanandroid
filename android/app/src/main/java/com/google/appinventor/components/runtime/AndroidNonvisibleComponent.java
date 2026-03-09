package com.google.appinventor.components.runtime;
public abstract class AndroidNonvisibleComponent implements Component {
    protected final Form form;
    public AndroidNonvisibleComponent(Form form) {
        this.form = form;
    }
    public AndroidNonvisibleComponent(ComponentContainer container) {
        this.form = container.$form();
    }
}
