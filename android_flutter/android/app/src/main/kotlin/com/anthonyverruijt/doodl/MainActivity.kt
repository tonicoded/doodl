package com.anthonyverruijt.doodl

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Needed when targeting SDK 35 (Android 15): ensure we render edge-to-edge and let Flutter handle insets.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "doodl/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        try {
                            DoodlWidgetProvider.updateAll(applicationContext)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("WIDGET_UPDATE_FAILED", e.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
