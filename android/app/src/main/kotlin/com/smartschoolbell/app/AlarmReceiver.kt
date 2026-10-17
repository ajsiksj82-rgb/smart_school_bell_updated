package com.smartschoolbell.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.content.ContextCompat
import org.json.JSONObject

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val payload = intent.getStringExtra("payload") ?: return
        val svc = Intent(context, BellService::class.java)
            .setAction(BellService.ACTION_PLAY)
            .putExtra("payload", payload)
            .putExtra("manual", false)
        try {
            ContextCompat.startForegroundService(context, svc)
        } catch (e: Exception) {
            val o = try { JSONObject(payload) } catch (x: Exception) { null }
            BellStore.log(context, o, false, "error", "تعذر بدء خدمة الرنين: ${e.message}")
        }
    }
}
