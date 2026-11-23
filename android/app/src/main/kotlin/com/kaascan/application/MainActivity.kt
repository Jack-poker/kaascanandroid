package com.kaascan.application

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.util.Log
import com.kaascan.application.PosExtensionBridge
import com.google.appinventor.components.runtime.Form

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.kaascan/pos_extensions"
    private val WIDGET_CHANNEL = "com.kaascan.application/widget"
    private val REMINDER_CHANNEL = "com.kaascan.application/reminders"
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

                MethodChannel(messenger, WIDGET_CHANNEL).setMethodCallHandler { call, result ->
                    when (call.method) {
                        "pinWidget" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val manager = getSystemService(AppWidgetManager::class.java)
                                val provider = ComponentName(this, SomaBalanceWidget::class.java)
                                if (manager?.isRequestPinAppWidgetSupported == true) {
                                    manager.requestPinAppWidget(provider, null, null)
                                    result.success(true)
                                } else {
                                    result.success(false)
                                }
                            } else {
                                result.success(false)
                            }
                        }
                        else -> result.notImplemented()
                    }
                }

                MethodChannel(messenger, REMINDER_CHANNEL).setMethodCallHandler { call, result ->
                    when (call.method) {
                        "startChargeReminder" -> {
                            val baseUrl = call.argument<String>("baseUrl")
                            val threshold = call.argument<Number>("thresholdRwf")?.toDouble()
                            if (baseUrl.isNullOrBlank() || threshold == null) {
                                result.error("BAD_ARGS", "baseUrl and thresholdRwf are required", null)
                            } else {
                                ChargeReminderWorker.start(applicationContext, baseUrl, threshold)
                                result.success(true)
                            }
                        }
                        else -> result.notImplemented()
                    }
                }
    }
}
