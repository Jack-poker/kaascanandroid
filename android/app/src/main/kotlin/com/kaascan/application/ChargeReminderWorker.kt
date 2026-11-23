package com.kaascan.application

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.BatteryManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.Constraints
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

/**
 * Wakes about every 15 minutes, but only while the phone is plugged in. On a
 * new charge it fetches the children's balances and, when any card is empty or
 * low, reminds the parent; [ChargeReminderPolicy] decides when.
 */
class ChargeReminderWorker(context: Context, params: WorkerParameters) :
    CoroutineWorker(context, params) {

    private class SessionExpired : IOException()

    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        val ctx = applicationContext
        val flutterPrefs = ctx.getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        val token = flutterPrefs.getString("flutter.login_token", null)
        if (token.isNullOrBlank()) {
            // Signed out: stop waking up until the app starts the reminder again.
            WorkManager.getInstance(ctx).cancelUniqueWork(UNIQUE_NAME)
            return@withContext Result.success()
        }

        val battery = ctx.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        if (battery == null || battery.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0) == 0) {
            return@withContext Result.success()
        }
        val scale = battery.getIntExtra(BatteryManager.EXTRA_SCALE, 100).coerceAtLeast(1)
        val level = battery.getIntExtra(BatteryManager.EXTRA_LEVEL, 0) * 100 / scale

        val prefs = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        val calendar = Calendar.getInstance()
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(calendar.time)
        val (state, check) = ChargeReminderPolicy.onRun(
            load(prefs), now, level, calendar.get(Calendar.HOUR_OF_DAY), today,
        )
        save(prefs, state)
        if (!check) return@withContext Result.success()

        val baseUrl = prefs.getString(KEY_BASE_URL, null) ?: return@withContext Result.success()
        val threshold = prefs.getFloat(KEY_THRESHOLD, DEFAULT_THRESHOLD_RWF).toDouble()
        val children = try {
            fetchChildren(baseUrl, token)
        } catch (e: SessionExpired) {
            save(prefs, ChargeReminderPolicy.afterCheck(state, now, reminded = false))
            return@withContext Result.success()
        } catch (e: Exception) {
            // The charge stays unhandled, so the next run tries again.
            Log.w(TAG, "Balance check failed: ${e.javaClass.simpleName}")
            return@withContext Result.success()
        }

        val low = ChargeReminderPolicy.lowChildren(children, threshold)
        val language = flutterPrefs.getString("flutter.current_language", null) ?: "en"
        val reminded = low.isNotEmpty() && showReminder(ctx, low, language)
        save(prefs, ChargeReminderPolicy.afterCheck(state, now, reminded))
        Log.i(TAG, "Checked ${children.size} children: ${low.size} low, reminded=$reminded")
        Result.success()
    }

    private fun fetchChildren(baseUrl: String, token: String): List<ChildBalance> {
        val connection = URL("${baseUrl.trimEnd('/')}/students/linked").openConnection()
            as HttpURLConnection
        try {
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            connection.setRequestProperty("authorization", "Bearer $token")
            connection.setRequestProperty("Accept", "application/json")
            val code = connection.responseCode
            if (code == 401 || code == 403) throw SessionExpired()
            if (code !in 200..299) throw IOException("HTTP $code")
            val body = connection.inputStream.bufferedReader().use { it.readText() }
            val students = JSONObject(body).optJSONArray("students") ?: return emptyList()
            return (0 until students.length()).mapNotNull { i ->
                val student = students.optJSONObject(i) ?: return@mapNotNull null
                val balance = student.optDouble("account_balance", Double.NaN)
                if (balance.isNaN()) return@mapNotNull null
                ChildBalance(student.optString("student_name").trim(), balance)
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun showReminder(ctx: Context, low: List<ChildBalance>, language: String): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(ctx, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return false
        }
        val manager = NotificationManagerCompat.from(ctx)
        if (!manager.areNotificationsEnabled()) return false

        if (Build.VERSION.SDK_INT >= 26) {
            val system = ctx.getSystemService(NotificationManager::class.java)
            system.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    ChargeReminderPolicy.channelName(language),
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
            // The parent may have switched off just this kind of notification.
            if (system.getNotificationChannel(CHANNEL_ID)?.importance ==
                NotificationManager.IMPORTANCE_NONE
            ) {
                return false
            }
        }

        val copy = ChargeReminderPolicy.text(low, language)
        // Reuses home_widget's launch intent, which the app already routes:
        // somakadi://topup opens the Students tab.
        val openStudents = HomeWidgetLaunchIntent.getActivity(
            ctx, MainActivity::class.java, Uri.parse(TOP_UP_URI),
        )
        val notification = NotificationCompat.Builder(ctx, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_soma)
            .setColor(SOMA_ORANGE)
            .setLargeIcon(robotBitmap(ctx))
            .setContentTitle(copy.title)
            .setContentText(copy.body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(copy.body))
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(openStudents)
            .setAutoCancel(true)
            .build()
        manager.notify(NOTIFICATION_ID, notification)
        return true
    }

    private fun robotBitmap(ctx: Context): Bitmap? {
        val robot = ContextCompat.getDrawable(ctx, R.drawable.soma_robot_face) ?: return null
        val size = (64 * ctx.resources.displayMetrics.density).toInt()
        val scale = minOf(
            size.toFloat() / robot.intrinsicWidth,
            size.toFloat() / robot.intrinsicHeight,
        )
        val width = (robot.intrinsicWidth * scale).toInt()
        val height = (robot.intrinsicHeight * scale).toInt()
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        robot.setBounds((size - width) / 2, (size - height) / 2, (size + width) / 2, (size + height) / 2)
        robot.draw(Canvas(bitmap))
        return bitmap
    }

    private fun load(prefs: SharedPreferences) = ReminderState(
        lastRunAt = prefs.getLong("last_run_at", 0L),
        lastLevel = prefs.getInt("last_level", -1),
        chargeHandled = prefs.getBoolean("charge_handled", false),
        day = prefs.getString("day", null) ?: "",
        remindersToday = prefs.getInt("reminders_today", 0),
        lastRemindedAt = prefs.getLong("last_reminded_at", 0L),
    )

    private fun save(prefs: SharedPreferences, state: ReminderState) {
        prefs.edit()
            .putLong("last_run_at", state.lastRunAt)
            .putInt("last_level", state.lastLevel)
            .putBoolean("charge_handled", state.chargeHandled)
            .putString("day", state.day)
            .putInt("reminders_today", state.remindersToday)
            .putLong("last_reminded_at", state.lastRemindedAt)
            .commit()
    }

    companion object {
        private const val TAG = "SomaChargeReminder"
        private const val UNIQUE_NAME = "soma_charge_reminder"
        private const val PREFS = "soma_charge_reminder"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val KEY_BASE_URL = "base_url"
        private const val KEY_THRESHOLD = "threshold_rwf"
        private const val DEFAULT_THRESHOLD_RWF = 1000f
        private const val CHANNEL_ID = "soma_low_balance"
        private const val NOTIFICATION_ID = 7301
        private const val TOP_UP_URI = "somakadi://topup"
        private const val SOMA_ORANGE = 0xFFFF3C00.toInt()

        /** Safe to call on every launch: an existing schedule keeps its timing. */
        fun start(context: Context, baseUrl: String, thresholdRwf: Double) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(KEY_BASE_URL, baseUrl)
                .putFloat(KEY_THRESHOLD, thresholdRwf.toFloat())
                .apply()
            val request = PeriodicWorkRequestBuilder<ChargeReminderWorker>(15, TimeUnit.MINUTES)
                .setConstraints(Constraints.Builder().setRequiresCharging(true).build())
                .build()
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                UNIQUE_NAME, ExistingPeriodicWorkPolicy.UPDATE, request,
            )
        }
    }
}
