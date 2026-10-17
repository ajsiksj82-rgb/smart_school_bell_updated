package com.smartschoolbell.app

import android.content.Context
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/** تخزين محلي أصلي: قائمة المواعيد المجدولة، وسجل التنفيذ حتى يسحبه تطبيق Flutter. */
object BellStore {
    private const val PREFS = "bell_store"

    private fun prefs(c: Context): SharedPreferences =
        c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun saveAlarms(c: Context, json: String) {
        prefs(c).edit().putString("alarms", json).commit()
    }

    fun loadAlarms(c: Context): JSONArray = try {
        JSONArray(prefs(c).getString("alarms", "[]"))
    } catch (e: Exception) {
        JSONArray()
    }

    /** "yyyy-MM-dd HH:mm" بالتوقيت المحلي الحالي للجهاز => milliseconds. */
    fun localToMillis(local: String): Long {
        val dt = local.trim().split(" ")
        val d = dt[0].split("-")
        val t = dt[1].split(":")
        val cal = Calendar.getInstance()
        cal.set(d[0].toInt(), d[1].toInt() - 1, d[2].toInt(), t[0].toInt(), t[1].toInt(), 0)
        cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    @Synchronized
    fun log(c: Context, payload: JSONObject?, manual: Boolean, result: String, error: String) {
        val e = JSONObject()
        e.put("ts", System.currentTimeMillis())
        e.put("mode", if (manual) "manual" else "auto")
        e.put("result", result)
        e.put("error", error)
        if (payload != null) {
            e.put("eventId", payload.optInt("eventId", 0))
            e.put("eventIds", payload.optJSONArray("eventIds") ?: JSONArray())
            e.put("buildingId", payload.optInt("buildingId", 0))
            e.put("date", payload.optString("date", ""))
            e.put("schoolName", payload.optString("schoolName", ""))
            e.put("buildingName", payload.optString("buildingName", ""))
            e.put("label", payload.optString("label", ""))
        }
        val arr = try {
            JSONArray(prefs(c).getString("logs", "[]"))
        } catch (ex: Exception) {
            JSONArray()
        }
        arr.put(e)
        val start = if (arr.length() > 500) arr.length() - 500 else 0
        val trimmed = JSONArray()
        for (i in start until arr.length()) trimmed.put(arr.get(i))
        prefs(c).edit().putString("logs", trimmed.toString()).commit()
    }

    @Synchronized
    fun drainLogs(c: Context): String {
        val s = prefs(c).getString("logs", "[]") ?: "[]"
        prefs(c).edit().putString("logs", "[]").commit()
        return s
    }

    /** منع تكرار الرنين للحدث نفسه في اليوم نفسه. يرجع true إذا سُجّل من قبل. */
    @Synchronized
    fun alreadyFired(c: Context, key: String): Boolean {
        val p = prefs(c)
        val now = System.currentTimeMillis()
        val k = "fired_$key"
        if (p.contains(k)) return true
        val ed = p.edit()
        for ((name, v) in p.all) {
            if (name.startsWith("fired_") && v is Long && now - v > 3L * 24 * 3600 * 1000) ed.remove(name)
        }
        ed.putLong(k, now).commit()
        return false
    }
}
