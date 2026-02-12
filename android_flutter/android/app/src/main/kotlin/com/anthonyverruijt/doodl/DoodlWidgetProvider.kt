package com.anthonyverruijt.doodl

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.widget.RemoteViews
import java.io.File

class DoodlWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        private const val PREFS = "FlutterSharedPreferences"
        private const val KEY_PATH = "flutter.widget_latest_path"
        private const val KEY_SENDER = "flutter.widget_latest_sender"

        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, DoodlWidgetProvider::class.java))
            if (ids.isNotEmpty()) {
                DoodlWidgetProvider().onUpdate(context, manager, ids)
            }
        }

        private fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val views = RemoteViews(context.packageName, R.layout.doodl_widget)

            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val path = prefs.getString(KEY_PATH, null)
            val sender = prefs.getString(KEY_SENDER, null)
            val bitmap = decodeSafeBitmap(path)

            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_image, bitmap)
            } else {
                views.setImageViewResource(R.id.widget_image, R.drawable.widget_placeholder)
            }

            if (sender.isNullOrBlank()) {
                views.setViewVisibility(R.id.widget_sender, android.view.View.GONE)
            } else {
                views.setViewVisibility(R.id.widget_sender, android.view.View.VISIBLE)
                views.setTextViewText(R.id.widget_sender, sender)
            }

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }

        private fun decodeSafeBitmap(path: String?): Bitmap? {
            if (path.isNullOrBlank()) return null
            val file = File(path)
            if (!file.exists()) return null

            val bounds = BitmapFactory.Options()
            bounds.inJustDecodeBounds = true
            BitmapFactory.decodeFile(path, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null

            val maxSize = 1024
            var sample = 1
            var w = bounds.outWidth
            var h = bounds.outHeight
            while (w / sample > maxSize || h / sample > maxSize) {
                sample *= 2
            }

            val opts = BitmapFactory.Options()
            opts.inSampleSize = sample
            opts.inPreferredConfig = Bitmap.Config.ARGB_8888
            return BitmapFactory.decodeFile(path, opts)
        }
    }
}
