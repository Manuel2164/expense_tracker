package com.eekan.expense_tracker

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Home-screen widget with its own keypad: type an amount, pick a category and
 * add the expense without opening the app. Widgets can't hold a text field, so
 * every key is a button that sends a broadcast back to this class.
 */
class QuickAddWidgetProvider : HomeWidgetProvider() {
    private class Category(val name: String, val viewId: Int, val label: String)

    // Names and labels mirror ExpenseCategory in lib/models/expense.dart.
    private val categories = listOf(
        Category("food", R.id.quick_cat_food, "Food & Dining"),
        Category("transport", R.id.quick_cat_transport, "Transport"),
        Category("bills", R.id.quick_cat_bills, "Bills & Utilities"),
        Category("shopping", R.id.quick_cat_shopping, "Shopping"),
        Category("entertainment", R.id.quick_cat_entertainment, "Entertainment"),
        Category("health", R.id.quick_cat_health, "Health"),
        Category("education", R.id.quick_cat_education, "Education"),
        Category("other", R.id.quick_cat_other, "Other"),
    )

    private val keys = mapOf(
        "0" to R.id.quick_key_0,
        "1" to R.id.quick_key_1,
        "2" to R.id.quick_key_2,
        "3" to R.id.quick_key_3,
        "4" to R.id.quick_key_4,
        "5" to R.id.quick_key_5,
        "6" to R.id.quick_key_6,
        "7" to R.id.quick_key_7,
        "8" to R.id.quick_key_8,
        "9" to R.id.quick_key_9,
        "dot" to R.id.quick_key_dot,
        "back" to R.id.quick_key_back,
    )

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_PRESS) {
            super.onReceive(context, intent)
            return
        }
        val uri = intent.data ?: return
        val state = state(context)
        val widgetData = HomeWidgetPlugin.getData(context)
        val amount = state.getString(AMOUNT, null) ?: ""

        when (uri.host) {
            "key" -> state.edit()
                .putString(AMOUNT, type(amount, uri.lastPathSegment ?: return))
                .remove(STATUS)
                .apply()
            "category" -> state.edit().putString(CATEGORY, uri.lastPathSegment).apply()
            "add" -> {
                val minor = amount.toBigDecimalOrNull()?.movePointRight(2)?.toLong() ?: 0L
                if (minor <= 0) {
                    state.edit().putString(STATUS, "Type an amount first").apply()
                } else {
                    val category = selected(state)
                    WidgetData.addPending(widgetData, minor, category.name)
                    val money =
                        WidgetData.formatMoney(minor, WidgetData.currencySymbol(widgetData))
                    state.edit()
                        .remove(AMOUNT)
                        .putString(STATUS, "Added $money · ${category.label}")
                        .apply()
                    refresh(context, ExpenseWidgetProvider::class.java)
                }
            }
        }
        refresh(context, QuickAddWidgetProvider::class.java)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val state = state(context)
        val amount = state.getString(AMOUNT, null) ?: ""
        val category = selected(state)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.quick_add_widget).apply {
                setTextViewText(
                    R.id.quick_amount,
                    WidgetData.currencySymbol(widgetData) + amount.ifEmpty { "0" },
                )
                setTextViewText(R.id.quick_status, state.getString(STATUS, null) ?: category.label)
                for ((key, viewId) in keys) {
                    setOnClickPendingIntent(viewId, press(context, "quickadd://key/$key"))
                }
                for (c in categories) {
                    setInt(
                        c.viewId,
                        "setBackgroundResource",
                        if (c === category) R.drawable.widget_key_selected else R.drawable.widget_key,
                    )
                    setOnClickPendingIntent(
                        c.viewId,
                        press(context, "quickadd://category/${c.name}"),
                    )
                }
                setOnClickPendingIntent(R.id.quick_add, press(context, "quickadd://add"))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private fun state(context: Context): SharedPreferences =
        context.getSharedPreferences("quick_add_widget", Context.MODE_PRIVATE)

    private fun selected(state: SharedPreferences): Category {
        val name = state.getString(CATEGORY, null)
        return categories.firstOrNull { it.name == name } ?: categories.first()
    }

    /** The amount text after pressing [key]: at most two decimals, no leading zeros. */
    private fun type(amount: String, key: String): String = when {
        key == "back" -> amount.dropLast(1)
        key == "dot" -> when {
            '.' in amount -> amount
            amount.isEmpty() -> "0."
            else -> "$amount."
        }
        '.' in amount -> if (amount.substringAfter('.').length < 2) amount + key else amount
        amount == "0" -> key
        amount.length < 9 -> amount + key
        else -> amount
    }

    // The data URI is what tells one button's PendingIntent apart from another's.
    private fun press(context: Context, uri: String): PendingIntent {
        val intent = Intent(context, QuickAddWidgetProvider::class.java)
            .setAction(ACTION_PRESS)
            .setData(Uri.parse(uri))
        return PendingIntent.getBroadcast(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun refresh(context: Context, provider: Class<*>) {
        val ids = AppWidgetManager.getInstance(context)
            .getAppWidgetIds(ComponentName(context, provider))
        context.sendBroadcast(
            Intent(context, provider)
                .setAction(AppWidgetManager.ACTION_APPWIDGET_UPDATE)
                .putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids),
        )
    }

    private companion object {
        const val ACTION_PRESS = "com.eekan.expense_tracker.action.QUICK_ADD_PRESS"
        const val AMOUNT = "amount"
        const val CATEGORY = "category"
        const val STATUS = "status"
    }
}
