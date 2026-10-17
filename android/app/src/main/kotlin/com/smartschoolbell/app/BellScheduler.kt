package com.smartschoolbell.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray

object BellScheduler {
    const val ACTION_FIRE = "com.smartschoolbell.app.FIRE"

    fun canExact(c: Context): Boolean {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        return if (Build.VERSION.SDK_INT >= 31) am.canScheduleExactAlarms() else true
    }

    /** يلغي المواعيد القديمة المخزّنة، ثم يحفظ ويجدول القائمة الجديدة. يرجع عدد المواعيد المجدولة. */
    fun scheduleFromJson(c: Context, json: String): Int {
        cancelAll(c)
        val arr = JSONArray(json)
        BellStore.saveAlarms(c, json)
        return arm(c, arr)
    }

    /** بعد إعادة التشغيل أو تغيير الوقت/المنطقة الزمنية: ألغِ وأعد الجدولة من المخزّن. */
    fun rearm(c: Context) {
        cancelAll(c)
        arm(c, BellStore.loadAlarms(c))
    }

    fun cancelAll(c: Context) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val old = BellStore.loadAlarms(c)
        for (i in 0 until old.length()) {
            val id = old.getJSONObject(i).optInt("id", -1)
            if (id < 0) continue
            val pi = pending(c, id, null, true)
            if (pi != null) {
                am.cancel(pi)
                pi.cancel()
            }
        }
    }

    private fun arm(c: Context, arr: JSONArray): Int {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val exact = canExact(c)
        val now = System.currentTimeMillis()
        var n = 0
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val at = try {
                BellStore.localToMillis(o.getString("local"))
            } catch (e: Exception) {
                continue
            }
            if (at <= now) continue
            val pi = pending(c, o.getInt("id"), o.toString(), false) ?: continue
            if (exact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            }
            n++
        }
        return n
    }

    private fun pending(c: Context, id: Int, payload: String?, noCreate: Boolean): PendingIntent? {
        val i = Intent(c, AlarmReceiver::class.java).setAction(ACTION_FIRE)
        if (payload != null) i.putExtra("payload", payload)
        val flags = (if (noCreate) PendingIntent.FLAG_NO_CREATE else PendingIntent.FLAG_UPDATE_CURRENT) or
            PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getBroadcast(c, id, i, flags)
    }
}
