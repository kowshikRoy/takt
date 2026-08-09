package com.example.takt

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

class WordOfTheDaySmallWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_NEXT_WORD = "com.example.takt.ACTION_NEXT_WORD"
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_NEXT_WORD) {
            val prefs = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            val jsonStr = prefs.getString("widget_words_json", null)

            val totalCount = if (!jsonStr.isNullOrEmpty()) {
                try {
                    JSONArray(jsonStr).length()
                } catch (e: Exception) {
                    1
                }
            } else 1

            if (totalCount > 1) {
                var currentIndex = prefs.getInt("widget_card_index", 0)
                currentIndex = (currentIndex + 1) % totalCount
                prefs.edit().putInt("widget_card_index", currentIndex).commit()

                val appWidgetManager = AppWidgetManager.getInstance(context)
                val component = ComponentName(context, WordOfTheDaySmallWidgetProvider::class.java)
                val ids = appWidgetManager.getAppWidgetIds(component)
                onUpdate(context, appWidgetManager, ids, prefs)
            }
        }
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        val jsonStr = widgetData.getString("widget_words_json", null)
        val currentIndex = widgetData.getInt("widget_card_index", 0)

        var word = widgetData.getString("widget_word", "das Wort") ?: "das Wort"
        var definition = widgetData.getString("widget_definition", "word, term") ?: "word, term"
        var cefr = widgetData.getString("widget_cefr", "B1") ?: "B1"
        var streak = widgetData.getString("widget_streak", "🔥 0") ?: "🔥 0"
        var deepLink = widgetData.getString("widget_deep_link", "takt://word?term=Wort") ?: "takt://word?term=Wort"
        var indexText = "1/1"

        if (!jsonStr.isNullOrEmpty()) {
            try {
                val array = JSONArray(jsonStr)
                if (array.length() > 0) {
                    val safeIndex = currentIndex % array.length()
                    val item = array.getJSONObject(safeIndex)
                    word = item.optString("word", word)
                    definition = item.optString("definition", definition)
                    cefr = item.optString("cefr", cefr)
                    streak = item.optString("streak", streak)
                    deepLink = item.optString("deepLink", deepLink)
                    indexText = "${safeIndex + 1}/${array.length()}"
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.word_of_the_day_small_widget)

            views.setTextViewText(R.id.widget_small_word, word)
            views.setTextViewText(R.id.widget_small_def, definition)
            views.setTextViewText(R.id.widget_small_cefr, cefr)

            // Setup Next Word Broadcast Intent
            val nextIntent = Intent(context, WordOfTheDaySmallWidgetProvider::class.java).apply {
                action = ACTION_NEXT_WORD
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            }
            val nextPendingIntent = PendingIntent.getBroadcast(
                context,
                1000 + appWidgetId,
                nextIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_small_next, nextPendingIntent)

            // Setup Open App Word Detail Intent specifically on word and definition
            val clickPendingIntent = HomeWidgetLaunchIntent.getActivity(
                context,
                MainActivity::class.java,
                Uri.parse(deepLink)
            )
            views.setOnClickPendingIntent(R.id.widget_small_word, clickPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_small_def, clickPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
