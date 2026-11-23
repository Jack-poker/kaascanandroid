package com.kaascan.application

import java.util.Locale
import kotlin.math.roundToLong

internal data class ChildBalance(val name: String, val balance: Double)

/** What the charging reminder remembers between runs. Times are epoch millis. */
internal data class ReminderState(
    val lastRunAt: Long = 0L,
    val lastLevel: Int = -1,
    val chargeHandled: Boolean = false,
    val day: String = "",
    val remindersToday: Int = 0,
    val lastRemindedAt: Long = 0L,
)

internal data class ReminderText(val title: String, val body: String)

/** Rules for the low-balance reminder sent while the parent's phone charges. */
internal object ChargeReminderPolicy {
    const val MAX_PER_DAY = 2

    // The job runs about every 15 minutes while charging, so a longer silence
    // means the phone was unplugged in between.
    const val NEW_CHARGE_GAP_MS = 45 * 60_000L

    // Keeps the two daily reminders from landing back to back.
    const val MIN_SPACING_MS = 3 * 60 * 60_000L

    // A charge that starts at night is handled in the morning instead.
    const val QUIET_FROM_HOUR = 22
    const val QUIET_UNTIL_HOUR = 6

    fun isNewCharge(prev: ReminderState, now: Long, level: Int): Boolean {
        if (prev.lastRunAt == 0L) return true
        val gap = now - prev.lastRunAt
        if (gap < 0) return true
        if (gap <= NEW_CHARGE_GAP_MS) return false
        // Some phones pause charging once full; a battery that stayed full was
        // plugged in all along.
        return !(level >= 100 && prev.lastLevel >= 100)
    }

    fun isQuietHour(hour: Int) = hour >= QUIET_FROM_HOUR || hour < QUIET_UNTIL_HOUR

    /** Records this run and says whether to check the balances now. */
    fun onRun(
        prev: ReminderState,
        now: Long,
        level: Int,
        hour: Int,
        today: String,
    ): Pair<ReminderState, Boolean> {
        var state = prev.copy(
            lastRunAt = now,
            lastLevel = level,
            chargeHandled = if (isNewCharge(prev, now, level)) false else prev.chargeHandled,
        )
        if (state.day != today) state = state.copy(day = today, remindersToday = 0)
        val sinceLast = now - state.lastRemindedAt
        val check = !state.chargeHandled &&
            state.remindersToday < MAX_PER_DAY &&
            !isQuietHour(hour) &&
            (sinceLast < 0 || sinceLast >= MIN_SPACING_MS)
        return state to check
    }

    /** One check per charge; only a reminder actually shown counts toward the cap. */
    fun afterCheck(state: ReminderState, now: Long, reminded: Boolean): ReminderState =
        if (reminded) {
            state.copy(
                chargeHandled = true,
                remindersToday = state.remindersToday + 1,
                lastRemindedAt = now,
            )
        } else {
            state.copy(chargeHandled = true)
        }

    fun lowChildren(children: List<ChildBalance>, thresholdRwf: Double): List<ChildBalance> =
        children.filter { it.balance < thresholdRwf }.sortedBy { it.balance }

    fun text(low: List<ChildBalance>, language: String): ReminderText {
        val first = low.first()
        val many = low.size > 1
        val list = low.joinToString(" · ") { "${it.name}: ${rwf(it.balance)}" }
        return when (language) {
            "rw" -> when {
                many -> ReminderText(
                    "Abana ${low.size} bafite amafaranga make",
                    "$list. Kanda hano ubongerere amafaranga.",
                )
                first.balance <= 0 -> ReminderText(
                    "Amafaranga ya ${first.name} yashize",
                    "Nta mafaranga asigaye ku ikarita ye. Kanda hano umwongerere.",
                )
                else -> ReminderText(
                    "Amafaranga ya ${first.name} agiye gushira",
                    "Asigaranye ${rwf(first.balance)} gusa. Kanda hano umwongerere.",
                )
            }
            "fr" -> when {
                many -> ReminderText(
                    "${low.size} enfants ont un solde bas",
                    "$list. Touchez pour recharger.",
                )
                first.balance <= 0 -> ReminderText(
                    "La carte de ${first.name} est vide",
                    "Il ne reste plus rien sur sa carte. Touchez pour la recharger.",
                )
                else -> ReminderText(
                    "Le solde de ${first.name} est bas",
                    "Il ne reste que ${rwf(first.balance)}. Touchez pour recharger.",
                )
            }
            else -> when {
                many -> ReminderText(
                    "${low.size} children are low on money",
                    "$list. Tap to top up.",
                )
                first.balance <= 0 -> ReminderText(
                    "${first.name}'s card is empty",
                    "There's no money left on the card. Tap to top up.",
                )
                else -> ReminderText(
                    "${first.name}'s balance is low",
                    "Only ${rwf(first.balance)} left on the card. Tap to top up.",
                )
            }
        }
    }

    fun channelName(language: String) = when (language) {
        "rw" -> "Kwibutsa amafaranga make"
        "fr" -> "Rappels de solde bas"
        else -> "Low balance reminders"
    }

    private fun rwf(amount: Double) = String.format(Locale.US, "%,d RWF", amount.roundToLong())
}
