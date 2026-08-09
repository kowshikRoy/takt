package com.example.takt

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class WordOfTheDayWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.word_of_the_day_widget)

            // Read serialized data with fallbacks
            val word = widgetData.getString("widget_word", "das Wort") ?: "das Wort"
            val ipa = widgetData.getString("widget_ipa", "/vɔʁt/") ?: "/vɔʁt/"
            val definition = widgetData.getString("widget_definition", "word, term") ?: "word, term"
            val cefr = widgetData.getString("widget_cefr", "B1") ?: "B1"
            val streak = widgetData.getString("widget_streak", "🔥 0") ?: "🔥 0"
            val dueCount = widgetData.getString("widget_due_count", "⚡ 0") ?: "⚡ 0"
            val exampleDe = widgetData.getString("widget_example_de", "") ?: ""
            val exampleEn = widgetData.getString("widget_example_en", "") ?: ""
            val deepLink = widgetData.getString("widget_deep_link", "takt://word?term=Wort") ?: "takt://word?term=Wort"

            // Bind values to RemoteViews
            views.setTextViewText(R.id.widget_word_title, word)
            views.setTextViewText(R.id.widget_word_definition, definition)
            views.setTextViewText(R.id.widget_cefr_badge, cefr)
            views.setTextViewText(R.id.widget_streak_text, streak)
            views.setTextViewText(R.id.widget_due_count, dueCount)

            if (exampleDe.isNotEmpty()) {
                views.setViewVisibility(R.id.widget_example_container, View.VISIBLE)
                views.setTextViewText(R.id.widget_example_de, exampleDe)
                views.setTextViewText(R.id.widget_example_en, exampleEn)
            } else {
                views.setViewVisibility(R.id.widget_example_container, View.GONE)
            }

            // Set up Click PendingIntent to launch app via deep link
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(deepLink)
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
