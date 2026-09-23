package com.locationsharing.sender.sender_app

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        const val CHANNEL = "com.locationsharing.sender/location_service"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startLocationService" -> {
                    val url = call.argument<String>("backend_url") ?: LocationForegroundService.DEFAULT_URL
                    val intervalSec = (call.argument<Number>("interval_seconds")?.toLong()) ?: LocationForegroundService.DEFAULT_INTERVAL_SECONDS

                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_START
                        putExtra("backend_url", url)
                        putExtra("interval_seconds", intervalSec)
                    }

                    ContextCompat.startForegroundService(this, intent)
                    result.success(true)
                }

                "stopLocationService" -> {
                    val intent = Intent(this, LocationForegroundService::class.java).apply {
                        action = LocationForegroundService.ACTION_STOP
                    }
                    stopService(intent)
                    result.success(true)
                }

                "isLocationServiceRunning" -> {
                    result.success(LocationForegroundService.isRunning)
                }

                "getLatestLocation" -> {
                    val prefs = getSharedPreferences(LocationForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
                    val latBits = prefs.getLong(LocationForegroundService.KEY_LAST_LAT, -1L)
                    val lngBits = prefs.getLong(LocationForegroundService.KEY_LAST_LNG, -1L)
                    val accBits = prefs.getLong(LocationForegroundService.KEY_LAST_ACC, -1L)
                    val time = prefs.getString(LocationForegroundService.KEY_LAST_TIME, null)
                    val timeMillis = prefs.getLong(LocationForegroundService.KEY_LAST_TIME_MILLIS, -1L)

                    if (latBits != -1L && lngBits != -1L && accBits != -1L) {
                        val lat = java.lang.Double.longBitsToDouble(latBits)
                        val lng = java.lang.Double.longBitsToDouble(lngBits)
                        val acc = java.lang.Double.longBitsToDouble(accBits)

                        val map = mutableMapOf<String, Any>(
                            "latitude" to lat,
                            "longitude" to lng,
                            "accuracy" to acc
                        )
                        if (time != null) {
                            map["timestamp"] = time
                        }
                        if (timeMillis != -1L) {
                            map["timestampMillis"] = timeMillis
                        }
                        result.success(map)
                    } else {
                        result.success(null)
                    }
                }

                "isBatteryOptimizationIgnored" -> {
                    val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val isIgnored = powerManager.isIgnoringBatteryOptimizations(packageName)
                    result.success(isIgnored)
                }

                "requestIgnoreBatteryOptimization" -> {
                    try {
                        val intent = Intent().apply {
                            action = Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
                            data = Uri.parse("package:$packageName")
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        try {
                            val fallbackIntent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            startActivity(fallbackIntent)
                            result.success(true)
                        } catch (e2: Exception) {
                            result.error("ERROR", e2.message, null)
                        }
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
