package com.kaascan.application

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.os.Bundle
import android.text.format.DateFormat
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Date

/**
 * Home-screen widget: the children's total balance, waiting messages from the
 * children (card taps at school), Soma AI, and top-up.
 * The Flutter app writes everything it shows (see soma_home_widget.dart):
 * "soma_balance", "soma_balance_at", "soma_kids", "soma_kid_name" and the
 * "soma_msg_*" keys. The widget never calls the API. A full card at 4x2 and a
 * compact strip when resized smaller.
 */
class SomaBalanceWidget : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        appWidgetIds.forEach { id -> render(context, appWidgetManager, id, widgetData) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        render(context, appWidgetManager, appWidgetId, HomeWidgetPlugin.getData(context))
    }

    private fun render(context: Context, manager: AppWidgetManager, id: Int, data: SharedPreferences) {
        val minHeight = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 110)
        val compact = minHeight in 1 until COMPACT_BELOW_DP
        val layout = if (compact) R.layout.soma_balance_widget_small else R.layout.soma_balance_widget
        val text = Copy.forLanguage(appLanguage(context))
        val balance = data.getString("soma_balance", null)?.trim().orEmpty()

        val views = RemoteViews(context.packageName, layout).apply {
            if (balance.isEmpty()) {
                setTextViewText(R.id.widget_label, text.signedOut)
                setTextViewText(R.id.widget_balance, "••••")
                setTextViewText(R.id.widget_currency, "")
            } else {
                val parts = balance.split(" ")
                val amount = if (parts.size > 1) parts.dropLast(1).joinToString(" ") else balance
                val currency = if (parts.size > 1) parts.last() else ""
                setTextViewText(R.id.widget_label, balanceLabel(data, text))
                setTextViewText(R.id.widget_balance, amount)
                setTextViewText(R.id.widget_currency, currency)
            }

            val messages = if (balance.isEmpty()) 0 else intOf(data, "soma_msg_count")
            if (messages > 0) {
                setTextViewText(R.id.widget_msg_badge, if (messages > 9) "9+" else messages.toString())
                setViewVisibility(R.id.widget_msg_badge, View.VISIBLE)
            } else {
                setViewVisibility(R.id.widget_msg_badge, View.GONE)
            }

            if (compact) {
                setTextViewText(R.id.widget_ask_button, text.askShort)
            } else {
                setTextViewText(R.id.widget_ask_title, text.ask)
                setTextViewText(R.id.widget_ask_sub, text.askSub)
                if (messages > 0) {
                    setTextViewText(R.id.widget_msg_text, messageLabel(data, messages, text))
                    setViewVisibility(R.id.widget_msg_chip, View.VISIBLE)
                    setViewVisibility(R.id.widget_updated, View.GONE)
                    setOnClickPendingIntent(R.id.widget_msg_chip, launch(context, "somakadi://messages"))
                } else {
                    setTextViewText(R.id.widget_updated, updatedLabel(context, data, text))
                    setViewVisibility(R.id.widget_msg_chip, View.GONE)
                    setViewVisibility(R.id.widget_updated, View.VISIBLE)
                }
            }

            setOnClickPendingIntent(
                R.id.widget_root,
                launch(context, if (messages > 0) "somakadi://messages" else null),
            )
            setOnClickPendingIntent(R.id.widget_ask_button, launch(context, "somakadi://soma"))
            setOnClickPendingIntent(R.id.widget_topup_button, launch(context, "somakadi://topup"))
        }
        manager.updateAppWidget(id, views)
    }

    private fun launch(context: Context, uri: String?) =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, uri?.let(Uri::parse))

    private fun updatedLabel(context: Context, data: SharedPreferences, text: Copy): String {
        val at = when (val raw = data.all["soma_balance_at"]) {
            is Number -> raw.toLong()
            is String -> raw.toLongOrNull()
            else -> null
        } ?: return text.wallet
        return "${text.updated} ${DateFormat.getTimeFormat(context).format(Date(at))}"
    }

    private fun intOf(data: SharedPreferences, key: String): Int = when (val raw = data.all[key]) {
        is Number -> raw.toInt()
        is String -> raw.toIntOrNull() ?: 0
        else -> 0
    }

    private fun balanceLabel(data: SharedPreferences, text: Copy): String {
        if (!data.contains("soma_kids")) return text.balance
        val kids = intOf(data, "soma_kids")
        val name = data.getString("soma_kid_name", null)?.trim().orEmpty()
        return when {
            kids <= 0 -> text.noKids
            kids == 1 && name.isNotEmpty() -> text.oneKid.format(name)
            else -> text.manyKids.format(kids)
        }
    }

    private fun messageLabel(data: SharedPreferences, count: Int, text: Copy): String {
        if (count > 1) return text.manyMessages.format(count)
        val name = data.getString("soma_msg_name", null)?.trim().orEmpty().ifEmpty { text.child }
        val amount = data.getString("soma_msg_amount", null)?.trim().orEmpty()
        return when (data.getString("soma_msg_kind", null)) {
            "money_request" -> if (amount.isNotEmpty()) "$name · $amount RWF" else "$name · ${text.asksMoney}"
            "call_me" -> "$name · ${text.callMe}"
            "pick_me_up" -> "$name · ${text.pickMeUp}"
            "school_note" -> "$name · ${text.schoolNote}"
            else -> "$name · ${text.message}"
        }
    }

    private fun appLanguage(context: Context): String =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.current_language", null) ?: "en"

    private data class Copy(
        val balance: String,
        val signedOut: String,
        val ask: String,
        val askSub: String,
        val askShort: String,
        val updated: String,
        val wallet: String,
        val oneKid: String,
        val manyKids: String,
        val noKids: String,
        val manyMessages: String,
        val child: String,
        val asksMoney: String,
        val callMe: String,
        val pickMeUp: String,
        val message: String,
        val schoolNote: String,
    ) {
        companion object {
            fun forLanguage(lang: String) = when (lang) {
                "rw" -> Copy(
                    balance = "Amafaranga y'abana",
                    signedOut = "Injira urebe amafaranga",
                    ask = "Baza Soma AI",
                    askSub = "ibijyanye n'umwana wawe",
                    askShort = "Baza Soma",
                    updated = "Saa",
                    wallet = "Konti",
                    oneKid = "Amafaranga ya %s",
                    manyKids = "Abana %d bose hamwe",
                    noKids = "Nta mwana urahuzwa",
                    manyMessages = "Ubutumwa %d bushya",
                    child = "Umwana",
                    asksMoney = "arasaba amafaranga",
                    callMe = "hamagara",
                    pickMeUp = "ngwino untware",
                    message = "ubutumwa",
                    schoolNote = "ubutumwa bw'ishuri",
                )
                "fr" -> Copy(
                    balance = "Solde des enfants",
                    signedOut = "Connectez-vous pour voir le solde",
                    ask = "Demander à Soma",
                    askSub = "à propos de votre enfant",
                    askShort = "Soma AI",
                    updated = "À",
                    wallet = "Portefeuille",
                    oneKid = "Solde de %s",
                    manyKids = "Total pour %d enfants",
                    noKids = "Aucun enfant lié",
                    manyMessages = "%d nouveaux messages",
                    child = "Enfant",
                    asksMoney = "demande de l'argent",
                    callMe = "appelle-moi",
                    pickMeUp = "viens me chercher",
                    message = "message",
                    schoolNote = "message de l'école",
                )
                else -> Copy(
                    balance = "Children's balance",
                    signedOut = "Sign in to see your balance",
                    ask = "Ask Soma AI",
                    askSub = "about your child",
                    askShort = "Ask Soma",
                    updated = "Updated",
                    wallet = "Wallet",
                    oneKid = "%s's balance",
                    manyKids = "Total for %d children",
                    noKids = "No child linked yet",
                    manyMessages = "%d new messages",
                    child = "Your child",
                    asksMoney = "asks for money",
                    callMe = "call me",
                    pickMeUp = "pick me up",
                    message = "new message",
                    schoolNote = "note from school",
                )
            }
        }
    }

    private companion object {
        const val COMPACT_BELOW_DP = 100
    }
}
