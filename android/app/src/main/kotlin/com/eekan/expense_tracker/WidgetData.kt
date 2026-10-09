package com.eekan.expense_tracker

import android.content.SharedPreferences
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * Data the home-screen widgets share with the Flutter app. The keys and the
 * pending-expense format must match lib/data/home_widget.dart.
 */
object WidgetData {
    private const val PENDING = "pending_expenses"

    fun monthKey(time: Long = System.currentTimeMillis()): String =
        SimpleDateFormat("yyyy-MM", Locale.US).format(Date(time))

    fun currencySymbol(prefs: SharedPreferences): String =
        prefs.getString("currency_symbol", null) ?: ""

    /** Same shape as formatMoney in lib/format.dart: symbol, grouping, two decimals. */
    fun formatMoney(minor: Long, symbol: String): String =
        symbol + String.format(Locale.US, "%,.2f", minor / 100.0)

    private fun pending(prefs: SharedPreferences): JSONArray =
        try {
            JSONArray(prefs.getString(PENDING, null) ?: "[]")
        } catch (e: JSONException) {
            JSONArray()
        }

    /** Queues an expense for the app to import the next time it is opened. */
    fun addPending(prefs: SharedPreferences, amountMinor: Long, category: String) {
        val entry = JSONObject()
            .put("amount", amountMinor)
            .put("category", category)
            .put("time", System.currentTimeMillis())
        prefs.edit().putString(PENDING, pending(prefs).put(entry).toString()).commit()
    }

    /**
     * This month's spending: the total the app last saved, plus anything added
     * from a widget that the app hasn't imported yet.
     */
    fun monthTotalMinor(prefs: SharedPreferences): Long {
        val thisMonth = monthKey()
        // The saved total belongs to the month the app last ran in.
        var total =
            if (prefs.getString("month_key", null) == thisMonth) {
                // Dart ints arrive as Int or Long depending on their size.
                (prefs.all["month_total_minor"] as? Number)?.toLong() ?: 0L
            } else {
                0L
            }
        val queued = pending(prefs)
        for (i in 0 until queued.length()) {
            val entry = queued.optJSONObject(i) ?: continue
            if (monthKey(entry.optLong("time")) == thisMonth) total += entry.optLong("amount")
        }
        return total
    }
}
