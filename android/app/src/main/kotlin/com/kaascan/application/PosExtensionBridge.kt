package com.kaascan.application

import android.app.Activity
import com.baztibiza.bizanfcrfid.BizaNFCRFID
import com.akg.InvoicePrinter.InvoicePrinter
import com.google.appinventor.components.runtime.Form
import com.google.appinventor.components.runtime.BluetoothClient
import com.google.appinventor.components.runtime.EventDispatcher
import com.google.appinventor.components.runtime.Component
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import android.util.Log

import com.google.appinventor.components.runtime.util.YailList

class PosExtensionBridge(private val activity: Activity, private val form: Form, private val messenger: BinaryMessenger) {
    private var nfcExtension: BizaNFCRFID? = null
    private var printerExtension: InvoicePrinter? = null
    private var bluetoothClient: BluetoothClient? = null
    private val logChannel = MethodChannel(messenger, "com.kaascan/pos_logs")

    init {
        try {
            Log.d("PosExtensionBridge", "Initializing extensions...")
            nfcExtension = BizaNFCRFID(form)
            printerExtension = InvoicePrinter(form)
            bluetoothClient = BluetoothClient(form)
            Log.d("PosExtensionBridge", "Extensions initialized successfully")
        } catch (e: Throwable) {
            Log.e("PosExtensionBridge", "CRITICAL: Failed to initialize extensions", e)
            logToFlutter("💀 INIT CRASH: ${e.message}", true)
        }

        // Intercept events from extensions to send back to Flutter
        EventDispatcher.setEventListener(object : EventDispatcher.EventListener {
            override fun onEvent(component: Component, eventName: String, args: Array<out Any>) {
                val data = mutableMapOf<String, Any>()
                data["event"] = eventName
                data["component"] = component.javaClass.simpleName
                data["args"] = args.toList().map { it.toString() }
                
                activity.runOnUiThread {
                    logChannel.invokeMethod("onExtensionEvent", data)
                    
                    // Detailed logging for errors
                    if (eventName.contains("Error", ignoreCase = true) || eventName == "WriteFailed") {
                        val msg = args.firstOrNull()?.toString() ?: "Unknown error"
                        logToFlutter("❌ ${component.javaClass.simpleName} Error ($eventName): $msg", true)
                    } else if (eventName == "TagDetected" && args.isNotEmpty()) {
                        val tagId = args[0].toString()
                        val ndefData = if (args.size > 1) args[1].toString() else ""
                        sendNfcToFlutter(tagId, ndefData)
                    } else {
                        logToFlutter("ℹ️ Extension Event: $eventName from ${component.javaClass.simpleName}")
                    }
                }
            }
        })
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "startNfcReading" -> {
                    nfcExtension?.StartReading()
                    logToFlutter("ℹ️ NFC Reading Started")
                    result.success(true)
                }
                "stopNfcReading" -> {
                    nfcExtension?.StopReading()
                    logToFlutter("🛑 NFC Reading Stopped")
                    result.success(true)
                }
                "setPrinterMac" -> {
                    val mac = call.argument<String>("mac") ?: ""
                    Thread {
                        val success = bluetoothClient?.Connect(mac) ?: false
                        activity.runOnUiThread {
                            if (success) {
                                logToFlutter("🔗 Printer connected: $mac")
                                result.success(true)
                            } else {
                                logToFlutter("❌ Failed to connect to Printer: $mac", true)
                                result.error("CONN_ERROR", "Could not connect to printer", null)
                            }
                        }
                    }.start()
                }
                "setPrinterSecure" -> {
                    val secure = call.argument<Boolean>("secure") ?: true
                    bluetoothClient?.setSecure(secure)
                    logToFlutter("🔒 Printer Secure Connection: $secure")
                    result.success(true)
                }
                "printInvoice" -> {
                    // Legacy: delegates to InvoicePrinter extension
                    val header   = call.argument<String>("header") ?: ""
                    val invoiceId = call.argument<String>("invoiceId") ?: ""
                    val date     = call.argument<String>("date") ?: ""
                    val employee = call.argument<String>("employee") ?: ""
                    val customer = call.argument<String>("customer") ?: ""
                    val products = call.argument<List<String>>("products") ?: emptyList()
                    val discount = call.argument<String>("discount") ?: ""
                    val total    = call.argument<String>("total") ?: ""
                    val remark   = call.argument<String>("remark") ?: ""
                    val footer   = call.argument<String>("footer") ?: ""
                    val client   = bluetoothClient
                    if (client != null && printerExtension != null) {
                        Thread {
                            try {
                                printerExtension?.PrintInvoice(
                                    client, header, invoiceId, date, employee, customer,
                                    YailList.makeList(products), discount, total, remark, footer
                                )
                                logToFlutter("🖨️ Invoice Printing Initiated: $invoiceId ($total)")
                                activity.runOnUiThread { result.success(true) }
                            } catch (e: Throwable) {
                                logToFlutter("💀 Fatal Print Error: ${e.message}", true)
                                activity.runOnUiThread { result.error("PRINT_FATAL", e.message, null) }
                            }
                        }.start()
                    } else {
                        logToFlutter("❌ Printer not initialized", true)
                        result.error("INIT_ERROR", "Printer not initialized", null)
                    }
                }

                "printRawInvoice" -> {
                    // 🆕 Fully customizable raw ESC/POS — all labels come from Dart
                    val client = bluetoothClient
                    if (client == null) {
                        logToFlutter("❌ Printer not connected", true)
                        result.error("INIT_ERROR", "Printer not connected", null)
                    } else {
                        // --- Read all params from Dart ---
                        val header       = call.argument<String>("header") ?: "SMART POS"
                        val subHeader    = call.argument<String>("subHeader") ?: ""
                        val invoiceId    = call.argument<String>("invoiceId") ?: ""
                        val invoiceLabel = call.argument<String>("invoiceLabel") ?: "Invoice #"
                        val dateLabel    = call.argument<String>("dateLabel") ?: "Date"
                        val date         = call.argument<String>("date") ?: ""
                        val employeeLabel = call.argument<String>("employeeLabel") ?: "Cashier"
                        val employee     = call.argument<String>("employee") ?: ""
                        val customerLabel = call.argument<String>("customerLabel") ?: "Customer"
                        val customer     = call.argument<String>("customer") ?: ""
                        val products     = call.argument<List<String>>("products") ?: emptyList()
                        val discountLabel = call.argument<String>("discountLabel") ?: "Discount"
                        val discount     = call.argument<String>("discount") ?: "0"
                        val totalLabel   = call.argument<String>("totalLabel") ?: "TOTAL"
                        val currency     = call.argument<String>("currency") ?: "RWF"
                        val total        = call.argument<String>("total") ?: ""
                        val remarkLabel  = call.argument<String>("remarkLabel") ?: "Payment"
                        val remark       = call.argument<String>("remark") ?: ""
                        val footer       = call.argument<String>("footer") ?: "Thank you!"
                        val paperWidth   = call.argument<Int>("paperWidth") ?: 32

                        Thread {
                            try {
                                val sb = StringBuilder()
                                val ESC = "\u001B"
                                val GS  = "\u001D"

                                fun line(text: String) { sb.append(text).append("\n") }
                                fun divider() { line("-".repeat(paperWidth)) }
                                fun doubleDivider() { line("=".repeat(paperWidth)) }
                                fun bold(on: Boolean) { sb.append(if (on) "${ESC}E\u0001" else "${ESC}E\u0000") }
                                fun center() { sb.append("${ESC}a\u0001") }
                                fun left() { sb.append("${ESC}a\u0000") }
                                fun big() { sb.append("${ESC}!\u0030") }   // double height+width
                                fun normal() { sb.append("${ESC}!\u0000") }
                                fun padded(label: String, value: String): String {
                                    val space = (paperWidth - label.length - value.length).coerceAtLeast(1)
                                    return label + " ".repeat(space) + value
                                }

                                // Init
                                sb.append("${ESC}@")   // reset printer

                                // Header
                                center(); bold(true); big()
                                line(header.uppercase())
                                normal(); bold(false)
                                if (subHeader.isNotEmpty()) { center(); line(subHeader) }
                                doubleDivider()

                                // Meta info
                                left()
                                if (invoiceId.isNotEmpty()) line(padded("$invoiceLabel:", invoiceId))
                                if (date.isNotEmpty())      line(padded("$dateLabel:", date))
                                if (employee.isNotEmpty())  line(padded("$employeeLabel:", employee))
                                if (customer.isNotEmpty())  line(padded("$customerLabel:", customer))
                                divider()

                                // Products
                                if (products.isNotEmpty()) {
                                    for (p in products) { line(p) }
                                    divider()
                                }

                                // Discount
                                if (discount.isNotEmpty() && discount != "0") {
                                    line(padded("$discountLabel:", "$discount $currency"))
                                }

                                // Total
                                bold(true)
                                line(padded("$totalLabel:", "$total $currency"))
                                bold(false)

                                // Remark
                                if (remark.isNotEmpty()) {
                                    line(padded("$remarkLabel:", remark))
                                }

                                doubleDivider()

                                // Footer
                                center(); bold(true)
                                line(footer)
                                bold(false); left()

                                // Feed & cut
                                sb.append("\n\n\n\n")
                                sb.append("${GS}V\u0041\u0003")  // partial cut

                                client.SendText(sb.toString())
                                logToFlutter("🖨️ Raw Invoice Printed: $invoiceId ($total $currency)")
                                activity.runOnUiThread { result.success(true) }
                            } catch (e: Throwable) {
                                logToFlutter("💀 Print Error: ${e.message}", true)
                                activity.runOnUiThread { result.error("PRINT_FATAL", e.message, null) }
                            }
                        }.start()
                    }
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            logToFlutter("❌ Extension Error: ${e.message}", true)
            result.error("EXTENSION_ERROR", e.message, null)
        }
    }

    private fun logToFlutter(message: String, isError: Boolean = false) {
        activity.runOnUiThread {
            logChannel.invokeMethod("log", mapOf("message" to message, "isError" to isError))
        }
    }

    private fun sendNfcToFlutter(tagId: String, ndefData: String) {
        logChannel.invokeMethod("onNfcDetected", mapOf("tagId" to tagId, "ndefData" to ndefData))
    }
}
