package com.smartschoolbell.app

import android.content.Context
import android.content.Intent
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "smart_school_bell/native")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "scheduleAlarms" ->
                            result.success(BellScheduler.scheduleFromJson(this, call.arguments as String))
                        "cancelAll" -> {
                            BellScheduler.cancelAll(this)
                            result.success(true)
                        }
                        "playNow" -> {
                            val svc = Intent(this, BellService::class.java)
                                .setAction(BellService.ACTION_PLAY)
                                .putExtra("payload", call.arguments as String)
                                .putExtra("manual", true)
                            ContextCompat.startForegroundService(this, svc)
                            result.success(true)
                        }
                        "stop" -> {
                            if (BellService.ringing) {
                                startService(
                                    Intent(this, BellService::class.java).setAction(BellService.ACTION_STOP)
                                )
                            }
                            result.success(true)
                        }
                        "isRinging" -> result.success(BellService.ringing)
                        "canScheduleExact" -> result.success(BellScheduler.canExact(this))
                        "openExactAlarmSettings" -> {
                            if (Build.VERSION.SDK_INT >= 31) {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                        Uri.parse("package:$packageName")
                                    )
                                )
                            }
                            result.success(true)
                        }
                        "openBatterySettings" -> {
                            startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS))
                            result.success(true)
                        }
                        "openNotificationSettings" -> {
                            startActivity(
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            )
                            result.success(true)
                        }
                        "requestNotifications" -> {
                            if (Build.VERSION.SDK_INT >= 33) {
                                requestPermissions(arrayOf("android.permission.POST_NOTIFICATIONS"), 1001)
                            }
                            result.success(true)
                        }
                        "isIgnoringBatteryOptimizations" -> {
                            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                            result.success(pm.isIgnoringBatteryOptimizations(packageName))
                        }
                        "audioRoute" -> result.success(audioRoute())
                        "pullLogs" -> result.success(BellStore.drainLogs(this))
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("NATIVE_ERROR", e.message, null)
                }
            }
    }

    /** تقدير تقريبي لمسار الصوت: wired / bluetooth / speaker. */
    private fun audioRoute(): String {
        val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val devices = am.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        val wiredTypes = setOf(
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_LINE_ANALOG,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE
        )
        if (devices.any { it.type in wiredTypes }) return "wired"
        if (devices.any { it.type == AudioDeviceInfo.TYPE_BLUETOOTH_A2DP }) return "bluetooth"
        return "speaker"
    }
}
