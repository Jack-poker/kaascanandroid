package com.kaascan.application

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import com.kaascan.application.PosExtensionBridge
import com.google.appinventor.components.runtime.Form

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.kaascan/pos_extensions"
    private var bridge: PosExtensionBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
                val messenger = flutterEngine.dartExecutor.binaryMessenger
                if (bridge == null) {
                    val form = Form(this)
                    bridge = PosExtensionBridge(this, form, messenger)
                }
                
                MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
                    try {
                        bridge?.handle(call, result)
                    } catch (e: Throwable) {
                        Log.e("MainActivity", "POS Bridge error during call", e)
                        result.error("POS_BRIDGE_ERROR", e.message, null)
                    }
                }
    }
}
