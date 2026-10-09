package com.eekan.expense_tracker

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget: this month's total and a button that opens the add-expense form. */
class ExpenseWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val total = WidgetData.formatMoney(
            WidgetData.monthTotalMinor(widgetData),
            WidgetData.currencySymbol(widgetData),
        )

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.expense_widget).apply {
                setTextViewText(R.id.widget_total, total)
                setOnClickPendingIntent(
                    R.id.widget_root,
                    HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
                )
                setOnClickPendingIntent(
                    R.id.widget_add,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java,
                        Uri.parse("expensetracker://add"),
                    ),
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
