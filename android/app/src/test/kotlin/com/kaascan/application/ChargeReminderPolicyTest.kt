package com.kaascan.application

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class ChargeReminderPolicyTest {
    private val minute = 60_000L
    private val hour = 60 * minute
    private val day = "2026-11-21"

    /** A day of runs, each [run] call is one 15-minute job while charging. */
    private class Phone {
        var state = ReminderState()
        var reminders = 0

        fun run(at: Long, level: Int = 50, hourOfDay: Int = 12, today: String = "2026-11-21", low: Boolean = true) {
            val (next, check) = ChargeReminderPolicy.onRun(state, at, level, hourOfDay, today)
            state = next
            if (check) {
                state = ChargeReminderPolicy.afterCheck(state, at, reminded = low)
                if (low) reminders++
            }
        }
    }

    @Test
    fun remindsOnceForOneLongCharge() {
        val phone = Phone()
        var t = 10 * hour
        repeat(12) { // three hours plugged in
            phone.run(t, hourOfDay = (t / hour).toInt())
            t += 15 * minute
        }
        assertEquals(1, phone.reminders)
    }

    @Test
    fun aNewChargeAfterUnpluggingRemindsAgain() {
        val phone = Phone()
        phone.run(8 * hour, hourOfDay = 8)
        phone.run(13 * hour, level = 40, hourOfDay = 13) // unplugged for hours
        assertEquals(2, phone.reminders)
    }

    @Test
    fun neverMoreThanTwoADay() {
        val phone = Phone()
        listOf(7, 11, 15, 19).forEach { h -> phone.run(h * hour, level = 30, hourOfDay = h) }
        assertEquals(2, phone.reminders)
    }

    @Test
    fun theCapResetsTheNextDay() {
        val phone = Phone()
        listOf(7, 11, 15).forEach { h -> phone.run(h * hour, level = 30, hourOfDay = h) }
        phone.run(31 * hour, level = 20, hourOfDay = 7, today = "2026-11-22")
        assertEquals(3, phone.reminders)
    }

    @Test
    fun aNightChargeWaitsForTheMorning() {
        val phone = Phone()
        var t = 23 * hour
        while (t < 30 * hour) { // 23:00 to 05:45, all quiet
            phone.run(t, hourOfDay = ((t / hour) % 24).toInt(), today = if (t < 24 * hour) day else "2026-11-22")
            t += 15 * minute
        }
        assertEquals(0, phone.reminders)
        phone.run(30 * hour, hourOfDay = 6, today = "2026-11-22")
        assertEquals(1, phone.reminders)
    }

    @Test
    fun twoChargesCloseTogetherAreSpacedOut() {
        val phone = Phone()
        phone.run(12 * hour, hourOfDay = 12)
        var t = 13 * hour // plugged in again an hour later and left charging
        while (t < 15 * hour) {
            phone.run(t, level = 45, hourOfDay = (t / hour).toInt())
            t += 15 * minute
        }
        assertEquals(1, phone.reminders)
        phone.run(15 * hour, level = 60, hourOfDay = 15) // 3h after the first
        assertEquals(2, phone.reminders)
    }

    @Test
    fun aFullBatteryThatStaysFullIsTheSameCharge() {
        val phone = Phone()
        phone.run(9 * hour, level = 100, hourOfDay = 9)
        phone.run(14 * hour, level = 100, hourOfDay = 14) // charger paused while full
        assertEquals(1, phone.reminders)
    }

    @Test
    fun aCheckWithEnoughMoneyStillUsesUpTheCharge() {
        val phone = Phone()
        phone.run(9 * hour, hourOfDay = 9, low = false)
        phone.run(9 * hour + 15 * minute, hourOfDay = 9, low = true)
        assertEquals(0, phone.reminders)
        assertEquals(0, phone.state.remindersToday)
    }

    @Test
    fun aFailedCheckIsRetriedOnTheNextRun() {
        val (state, check) = ChargeReminderPolicy.onRun(ReminderState(), 9 * hour, 50, 9, day)
        assertTrue(check)
        // No afterCheck: the request failed. The next run in the same charge checks again.
        val (_, retry) = ChargeReminderPolicy.onRun(state, 9 * hour + 15 * minute, 52, 9, day)
        assertTrue(retry)
    }

    @Test
    fun lowChildrenAreBelowTheThresholdLowestFirst() {
        val kids = listOf(
            ChildBalance("Mugisha", 450.0),
            ChildBalance("Uwase", 1000.0),
            ChildBalance("Kalisa", 0.0),
        )
        val low = ChargeReminderPolicy.lowChildren(kids, 1000.0)
        assertEquals(listOf("Kalisa", "Mugisha"), low.map { it.name })
    }

    @Test
    fun textNamesTheChildAndAmount() {
        val one = ChargeReminderPolicy.text(listOf(ChildBalance("Mugisha", 1450.0)), "en")
        assertEquals("Mugisha's balance is low", one.title)
        assertTrue(one.body.contains("1,450 RWF"))

        val empty = ChargeReminderPolicy.text(listOf(ChildBalance("Kalisa", 0.0)), "rw")
        assertEquals("Amafaranga ya Kalisa yashize", empty.title)

        val many = ChargeReminderPolicy.text(
            listOf(ChildBalance("Kalisa", 0.0), ChildBalance("Mugisha", 450.0)), "fr",
        )
        assertEquals("2 enfants ont un solde bas", many.title)
        assertTrue(many.body.startsWith("Kalisa: 0 RWF · Mugisha: 450 RWF"))
    }

    @Test
    fun unknownLanguageFallsBackToEnglish() {
        val text = ChargeReminderPolicy.text(listOf(ChildBalance("Kalisa", 0.0)), "sw")
        assertEquals("Kalisa's card is empty", text.title)
    }
}
