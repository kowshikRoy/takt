package com.example.takt

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class WordOfTheDaySmallWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.word_of_the_day_small_widget)

            val word = widgetData.getString("widget_word", "das Wort") ?: "das Wort"
            val ipa = widgetData.getString("widget_ipa", "/vɔʁt/") ?: "/vɔʁt/"
            val definition = widgetData.getString("widget_definition", "word, term") ?: "word, term"
            val cefr = widgetData.getString("widget_cefr", "B1") ?: "B1"
            val streak = widgetData.getString("widget_streak", "🔥 0") ?: "🔥 0"
            val deepLink = widgetData.getString("widget_deep_link", "takt://word?term=Wort") ?: "takt://word?term=Wort"

            views.setTextViewText(R.id.widget_small_word, word)
            views.setTextViewText(R.id.widget_small_ipa, ipa)
            views.setTextViewText(R.id.widget_small_def, definition)
            views.setTextViewText(R.id.widget_small_cefr, cefr)
            views.setTextViewText(R.id.widget_small_streak, streak)

            val pendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(deepLink)
            )
            views.setOnClickPendingIntent(R.id.widget_small_root, pendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
