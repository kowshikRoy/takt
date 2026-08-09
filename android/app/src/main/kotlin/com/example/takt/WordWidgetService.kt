package com.example.takt

import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

class WordWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return WordWidgetFactory(applicationContext)
    }
}

class WordWidgetFactory(
    private val context: Context
) : RemoteViewsService.RemoteViewsFactory {

    private val words = mutableListOf<WidgetWordItem>()

    override fun onCreate() {
        loadWords()
    }

    override fun onDataSetChanged() {
        loadWords()
    }

    private fun loadWords() {
        words.clear()
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val jsonStr = prefs.getString("flutter.widget_words_json", null)
            ?: prefs.getString("widget_words_json", null)

        if (!jsonStr.isNullOrEmpty()) {
            try {
                val array = JSONArray(jsonStr)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    words.add(
                        WidgetWordItem(
                            word = obj.optString("word", "das Wort"),
                            definition = obj.optString("definition", "word, term"),
                            cefr = obj.optString("cefr", "B1"),
                            streak = obj.optString("streak", "🔥 0"),
                            deepLink = obj.optString("deepLink", "takt://word?term=Wort")
                        )
                    )
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        if (words.isEmpty()) {
            val word = prefs.getString("flutter.widget_word", null)
                ?: prefs.getString("widget_word", "das Wort") ?: "das Wort"
            val def = prefs.getString("flutter.widget_definition", null)
                ?: prefs.getString("widget_definition", "word, term") ?: "word, term"
            val cefr = prefs.getString("flutter.widget_cefr", null)
                ?: prefs.getString("widget_cefr", "A1") ?: "A1"
            val streak = prefs.getString("flutter.widget_streak", null)
                ?: prefs.getString("widget_streak", "🔥 0") ?: "🔥 0"
            val deepLink = prefs.getString("flutter.widget_deep_link", null)
                ?: prefs.getString("widget_deep_link", "takt://word?term=Wort") ?: "takt://word?term=Wort"

            words.add(WidgetWordItem(word, def, cefr, streak, deepLink))
        }
    }

    override fun onDestroy() {
        words.clear()
    }

    override fun getCount(): Int = words.size

    override fun getViewAt(position: Int): RemoteViews {
        if (position < 0 || position >= words.size) {
            return RemoteViews(context.packageName, R.layout.widget_word_item)
        }
        val item = words[position]
        val rv = RemoteViews(context.packageName, R.layout.widget_word_item)
        rv.setTextViewText(R.id.item_word, item.word)
        rv.setTextViewText(R.id.item_def, item.definition)
        rv.setTextViewText(R.id.item_cefr, item.cefr)
        rv.setTextViewText(R.id.item_streak, item.streak)

        val fillInIntent = Intent().apply {
            data = Uri.parse(item.deepLink)
        }
        rv.setOnClickFillInIntent(R.id.item_root, fillInIntent)
        return rv
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = true
}

data class WidgetWordItem(
    val word: String,
    val definition: String,
    val cefr: String,
    val streak: String,
    val deepLink: String
)
