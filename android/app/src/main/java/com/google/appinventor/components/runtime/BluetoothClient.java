package com.google.appinventor.components.runtime;
public class BluetoothClient extends AndroidNonvisibleComponent {
    private String macAddress = "";

    public BluetoothClient(ComponentContainer container) {
        super(container);
    }

    private android.bluetooth.BluetoothSocket socket = null;
    private java.io.OutputStream outStream = null;
    private static final java.util.UUID SPP_UUID = java.util.UUID.fromString("00001101-0000-1000-8000-00805F9B34FB");

    public boolean Connect(String address) {
        this.macAddress = address;
        try {
            Disconnect(); // Close previous
            android.bluetooth.BluetoothAdapter adapter = android.bluetooth.BluetoothAdapter.getDefaultAdapter();
            if (adapter == null) return false;
            android.bluetooth.BluetoothDevice device = adapter.getRemoteDevice(address);
            socket = device.createRfcommSocketToServiceRecord(SPP_UUID);
            socket.connect();
            outStream = socket.getOutputStream();
            return true;
        } catch (Exception e) {
            android.util.Log.e("BluetoothClient", "Connection failed", e);
            return false;
        }
    }

    public boolean IsConnected() {
        return socket != null && socket.isConnected();
    }

    public void Disconnect() {
        try { if (outStream != null) outStream.close(); } catch (Exception e) {}
        try { if (socket != null) socket.close(); } catch (Exception e) {}
        outStream = null;
        socket = null;
    }

    public void SendText(String text) {
        try {
            if (outStream != null) outStream.write(text.getBytes());
        } catch (Exception e) {}
    }

    public void SendBytes(com.google.appinventor.components.runtime.util.YailList list) {
        try {
            if (outStream != null) {
                // Skip the *list* header
                for (int i = 0; i < list.size(); i++) {
                   Object o = list.get(i);
                   if (o instanceof Number) {
                       outStream.write(((Number)o).intValue());
                   }
                }
            }
        } catch (Exception e) {}
    }

    public void Send1ByteNumber(String number) {
        try { outStream.write(Integer.parseInt(number)); } catch (Exception e) {}
    }
    
    public void Send2ByteNumber(String number) {
        // Simple 2-byte implementation
        try {
            int n = Integer.parseInt(number);
            outStream.write((n >> 8) & 0xFF);
            outStream.write(n & 0xFF);
        } catch (Exception e) {}
    }

    public void Send4ByteNumber(String number) {
        try {
            int n = Integer.parseInt(number);
            outStream.write((n >> 24) & 0xFF);
            outStream.write((n >> 16) & 0xFF);
            outStream.write((n >> 8) & 0xFF);
            outStream.write(n & 0xFF);
        } catch (Exception e) {}
    }

    public boolean IsEnabled() { return true; }
    public String GetDeviceName(String address) { return "BT_Printer"; }
    public String GetDeviceAddress(String name) { return macAddress; }
    public boolean ConnectDevice(String address) { return Connect(address); }
    public com.google.appinventor.components.runtime.util.YailList AddressesAndNames() {
        return new com.google.appinventor.components.runtime.util.YailList();
    }
    public boolean Available() { return true; }
    public boolean Enabled() { return true; }
    
    public String ReceiveText(int numberOfBytes) { return ""; }
    public com.google.appinventor.components.runtime.util.YailList ReceiveSignedBytes(int numberOfBytes) { 
        return new com.google.appinventor.components.runtime.util.YailList(); 
    }
    public com.google.appinventor.components.runtime.util.YailList ReceiveUnsignedBytes(int numberOfBytes) { 
        return new com.google.appinventor.components.runtime.util.YailList(); 
    }
    public void setDelimiterByte(int number) {}
    public int getDelimiterByte() { return 0; }
    public boolean getSecure() { return true; }
    public void setSecure(boolean secure) {}
}
