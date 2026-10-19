package com.example.mobile

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class StreakGoalWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.widget_streak_goal).apply {
                val streak = widgetData.getInt("user_streak", 0)
                val todayMinutes = widgetData.getInt("today_minutes", 0)
                val goalMinutes = widgetData.getInt("goal_minutes", 15).coerceAtLeast(1)
                val actionPlanTitle = widgetData.getString("active_action_plan_title", "TODAY'S HABIT") ?: "TODAY'S HABIT"
                val actionItem = widgetData.getString("active_action_item", "Read or listen to today's Blink") ?: "Read or listen to today's Blink"

                setTextViewText(R.id.widget_streak_count, streak.toString())
                setTextViewText(R.id.widget_streak_label, if (streak == 1) "day streak" else "days streak")
                setTextViewText(R.id.widget_goal_text, "$todayMinutes / $goalMinutes min")

                setProgressBar(R.id.widget_goal_progress, goalMinutes, todayMinutes.coerceAtMost(goalMinutes), false)
                setTextViewText(R.id.widget_action_plan_title, actionPlanTitle.uppercase())
                setTextViewText(R.id.widget_action_item, actionItem)

                // Tap launches Action Plans / Habits view -> blinkist://action-plans
                val actionPlanIntent = HomeWidgetLaunchIntent.getActivity(
                    context,
                    MainActivity::class.java,
                    Uri.parse("blinkist://action-plans")
                )
                setOnClickPendingIntent(R.id.widget_container, actionPlanIntent)
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
