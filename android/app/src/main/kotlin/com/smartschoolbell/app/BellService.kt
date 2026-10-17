package com.smartschoolbell.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import org.json.JSONObject
import java.io.File

class BellService : Service() {
    companion object {
        const val ACTION_PLAY = "com.smartschoolbell.app.PLAY"
        const val ACTION_STOP = "com.smartschoolbell.app.STOP"
        const val CHANNEL_ID = "bell_playback"
        @Volatile var ringing = false
    }

    private var player: MediaPlayer? = null
    private val handler = Handler(Looper.getMainLooper())
    private var stopRunnable: Runnable? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private var currentPayload: JSONObject? = null
    private var currentManual = false

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            finish("stopped", "")
            return START_NOT_STICKY
        }
        val payload = intent?.getStringExtra("payload")
        if (payload == null) {
            stopSelf()
            return START_NOT_STICKY
        }
        startForegroundCompat()
        play(payload, intent.getBooleanExtra("manual", false))
        return START_NOT_STICKY
    }

    private fun startForegroundCompat() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "تشغيل الجرس", NotificationManager.IMPORTANCE_LOW)
            )
        }
        val stop = PendingIntent.getService(
            this, 0,
            Intent(this, BellService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL_ID)
        else Notification.Builder(this)
        val n = b.setContentTitle("الجرس المدرسي الذكي")
            .setContentText("جارٍ تشغيل الجرس")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setOngoing(true)
            .addAction(Notification.Action.Builder(android.R.drawable.ic_media_pause, "إيقاف", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(1, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
        } else {
            startForeground(1, n)
        }
    }

    private fun play(payload: String, manual: Boolean) {
        val o = try { JSONObject(payload) } catch (e: Exception) {
            BellStore.log(this, null, manual, "error", "بيانات رنين غير صالحة")
            finish(null, "")
            return
        }
        if (!manual) {
            val key = "${o.optInt("eventId")}_${o.optString("date")}"
            if (BellStore.alreadyFired(this, key)) {
                BellStore.log(this, o, false, "skipped", "تم تجاهل تكرار الرنين للحدث نفسه")
                if (!ringing) finish(null, "")
                return
            }
        }
        // رنين جديد أثناء رنين قائم: أوقف القديم بهدوء
        releasePlayer()

        currentPayload = o
        currentManual = manual
        val dur = o.optInt("durationSec", 5).coerceIn(1, 300)
        val vol = o.optDouble("volume", 1.0).toFloat().coerceIn(0f, 1f)
        val usage = if (o.optString("usage", "alarm") == "media")
            AudioAttributes.USAGE_MEDIA else AudioAttributes.USAGE_ALARM
        try {
            val file = copyAsset(o.getString("sound"))
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(usage)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            mp.setDataSource(file.absolutePath)
            mp.setVolume(vol, vol)
            mp.isLooping = true
            mp.setOnErrorListener { _, _, _ ->
                finish("error", "تعذر تشغيل ملف الصوت")
                true
            }
            mp.prepare()
            mp.start()
            player = mp
            ringing = true
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "smartschoolbell:ring").apply {
                acquire((dur + 5) * 1000L)
            }
            // "success" هنا تعني: بدأ تشغيل الملف. لا تعني التأكد من سماعه في المكبرات.
            BellStore.log(this, o, manual, "success", "")
            val r = Runnable { finish(null, "") }
            stopRunnable = r
            handler.postDelayed(r, dur * 1000L)
        } catch (e: Exception) {
            BellStore.log(this, o, manual, "error", "فشل التشغيل: ${e.message}")
            finish(null, "")
        }
    }

    private fun copyAsset(assetPath: String): File {
        val out = File(cacheDir, "snd_" + assetPath.replace('/', '_'))
        if (!out.exists() || out.length() == 0L) {
            assets.open("flutter_assets/$assetPath").use { i ->
                out.outputStream().use { os -> i.copyTo(os) }
            }
        }
        return out
    }

    private fun releasePlayer() {
        stopRunnable?.let { handler.removeCallbacks(it) }
        stopRunnable = null
        try { player?.stop() } catch (e: Exception) { }
        try { player?.release() } catch (e: Exception) { }
        player = null
        try { if (wakeLock?.isHeld == true) wakeLock?.release() } catch (e: Exception) { }
        wakeLock = null
        ringing = false
    }

    private fun finish(logResult: String?, err: String) {
        if (logResult != null && (logResult != "stopped" || ringing)) {
            BellStore.log(this, currentPayload, currentManual, logResult, err)
        }
        releasePlayer()
        stopForeground(true)
        stopSelf()
    }

    override fun onDestroy() {
        releasePlayer()
        super.onDestroy()
    }
}
