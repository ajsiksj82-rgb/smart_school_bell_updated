package com.smartschoolbell.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            BellScheduler.rearm(context)
        } catch (e: Exception) {
            BellStore.log(context, null, false, "error", "تعذرت إعادة الجدولة: ${e.message}")
        }
    }
}
