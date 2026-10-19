package com.example.mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class DailyBlinkWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_daily_blink).apply {
                val title = widgetData.getString("daily_title", "Daily Audio Blink") ?: "Daily Audio Blink"
                val author = widgetData.getString("daily_author", "Blinkist") ?: "Blinkist"
                val theme = widgetData.getString("daily_theme", "Morning Digest") ?: "Morning Digest"
                val minutes = widgetData.getString("daily_formatted_duration", "15 min") ?: "15 min"
                val prompt = widgetData.getString("daily_first_prompt", "1-tap play morning audio digest") ?: "1-tap play morning audio digest"

                setTextViewText(R.id.widget_title, title)
                setTextViewText(R.id.widget_author, author)
                setTextViewText(R.id.widget_theme, theme.uppercase())
                setTextViewText(R.id.widget_minutes, minutes)
                setTextViewText(R.id.widget_prompt, prompt)

                // 1-Tap Play Pending Intent -> blinkist://play-daily-digest
                val playIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("blinkist://play-daily-digest")
                )
                setOnClickPendingIntent(R.id.widget_play_btn, playIntent)

                // Tap entire widget -> blinkist://daily-digest
                val openIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("blinkist://daily-digest")
                )
                setOnClickPendingIntent(R.id.widget_container, openIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
