package com.example.takt

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.RenderMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val POS_CHANNEL = "com.example.takt/pos_tagger"

    override fun getRenderMode(): RenderMode {
        return RenderMode.texture
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Initialize OpenNLP Universal Dependencies model in background thread
        GermanPosTagger.initModelAsync(applicationContext)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, POS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "tagPOS" -> {
                    val text = call.argument<String>("text")
                    if (text == null) {
                        result.error("INVALID_ARGUMENTS", "Text argument is required", null)
                        return@setMethodCallHandler
                    }
                    val taggedTokens = GermanPosTagger.tagText(text)
                    result.success(taggedTokens)
                }
                else -> result.notImplemented()
            }
        }
    }
}
