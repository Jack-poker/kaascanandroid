package io.karsmiths.ntfy

import android.content.Context
import android.content.Intent
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** NtfyPlugin */
class NtfyPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var channel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var context: Context? = null
    private var eventSink: EventChannel.EventSink? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "ntfy")
        channel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "ntfy_events")
        eventChannel.setStreamHandler(this)
        
        NtfyForegroundService.messageListener = { message ->
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                eventSink?.success(message)
            }
        }
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {

            "subscribe" -> {
                val url = call.argument<String>("url") ?: "https://ntfy.sh"
                val topic = call.argument<String>("topic") ?: ""
                val auth = call.argument<String>("auth")
                
                val intent = Intent(context, NtfyForegroundService::class.java).apply {
                    action = NtfyForegroundService.ACTION_START
                    putExtra(NtfyForegroundService.EXTRA_URL, url)
                    putExtra(NtfyForegroundService.EXTRA_TOPIC, topic)
                    if (auth != null) {
                        putExtra(NtfyForegroundService.EXTRA_AUTH, auth)
                    }
                }
                
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION.SDK_INT) {
                    context?.startForegroundService(intent)
                } else {
                    context?.startService(intent)
                }
                result.success(null)
            }
            "unsubscribe" -> {
                val intent = Intent(context, NtfyForegroundService::class.java).apply {
                    action = NtfyForegroundService.ACTION_STOP
                }
                context?.startService(intent)
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        NtfyForegroundService.messageListener = null
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
