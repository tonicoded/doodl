package com.anthonyverruijt.doodl

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL
import java.util.Base64

class DoodlMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        val kind = data["kind"] ?: ""
        if (kind != "group") return

        val groupCode = (data["group_code"] ?: "").trim()
        val doodleId = (data["doodle_id"] ?: "").trim()
        if (groupCode.isEmpty() || doodleId.isEmpty()) return

        val title = (data["title"] ?: "new doodl.").trim()
        val body = (data["body"] ?: "someone sent you a doodl.").trim()
        val senderUsername = (data["sender_username"] ?: "").trim()

        // Update widget in background (best-effort).
        try {
            updateWidgetLatest(groupCode, doodleId, senderUsername)
        } catch (_: Exception) {
            // ignore
        }

        // Show notification (best-effort).
        try {
            showNotification(title, body, groupCode, doodleId)
        } catch (_: Exception) {
            // ignore
        }
    }

    private fun showNotification(title: String, body: String, groupCode: String, doodleId: String) {
        val channelId = "doodl"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(channelId) == null) {
            nm.createNotificationChannel(
                NotificationChannel(channelId, "DOODL.", NotificationManager.IMPORTANCE_HIGH)
            )
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse("doodl://open?code=$groupCode&id=$doodleId")
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()

        nm.notify(doodleId.hashCode(), notification)
    }

    private fun updateWidgetLatest(groupCode: String, doodleId: String, senderUsername: String) {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val supabaseUrl = prefs.getString("flutter.doodl_supabase_url", null) ?: return
        val anonKey = prefs.getString("flutter.doodl_supabase_anon_key", null) ?: return
        val profileId = prefs.getString("flutter.onboarding_profile_id", null) ?: return

        val content = fetchDoodleContent(
            supabaseUrl = supabaseUrl,
            anonKey = anonKey,
            groupCode = groupCode,
            requesterProfileId = profileId,
            doodleId = doodleId
        ) ?: return

        val bytes = decodeDataUrl(content) ?: return

        val dir = filesDir
        val file = File(dir, "doodl_widget_latest.png")
        file.writeBytes(bytes)

        val editor = prefs.edit()
        editor.putString("flutter.widget_latest_path", file.absolutePath)
        if (senderUsername.isNotBlank()) {
            val normalized = if (senderUsername.startsWith("@")) senderUsername else "@$senderUsername"
            editor.putString("flutter.widget_latest_sender", normalized)
        } else {
            editor.remove("flutter.widget_latest_sender")
        }
        editor.apply()
        DoodlWidgetProvider.updateAll(applicationContext)
    }

    private fun fetchDoodleContent(
        supabaseUrl: String,
        anonKey: String,
        groupCode: String,
        requesterProfileId: String,
        doodleId: String
    ): String? {
        val url = URL("$supabaseUrl/rest/v1/rpc/doodle_contents_secure")
        val conn = (url.openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            connectTimeout = 6000
            readTimeout = 12000
            doOutput = true
            setRequestProperty("content-type", "application/json")
            setRequestProperty("apikey", anonKey)
            setRequestProperty("authorization", "Bearer $anonKey")
        }

        val body = JSONObject()
            .put("p_code", groupCode)
            .put("p_requester_profile_id", requesterProfileId)
            .put("p_doodle_ids", JSONArray().put(doodleId))
            .toString()

        conn.outputStream.use { it.write(body.toByteArray(Charsets.UTF_8)) }

        val status = conn.responseCode
        val stream = if (status in 200..299) conn.inputStream else conn.errorStream
        val text = stream?.bufferedReader()?.use { it.readText() } ?: return null
        if (status !in 200..299) return null

        val arr = JSONArray(text)
        if (arr.length() == 0) return null
        val row = arr.getJSONObject(0)
        val content = row.optString("content_base64", "")
        return if (content.isNotEmpty()) content else null
    }

    private fun decodeDataUrl(value: String): ByteArray? {
        val text = value.trim()
        if (text.isEmpty()) return null
        val comma = text.indexOf(',')
        val b64 = if (comma != -1 && text.substring(0, comma).contains("base64")) text.substring(comma + 1) else text
        return try {
            Base64.getDecoder().decode(b64)
        } catch (_: Exception) {
            null
        }
    }
}
