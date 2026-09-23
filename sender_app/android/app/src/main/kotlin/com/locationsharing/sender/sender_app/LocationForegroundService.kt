package com.locationsharing.sender.sender_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class LocationForegroundService : Service() {

    companion object {
        const val TAG = "LocationService"
        const val NOTIFICATION_ID = 9527
        const val CHANNEL_ID = "location_sharing_channel"
        const val CHANNEL_NAME = "Location Sharing Service"

        const val PREFS_NAME = "FlutterSharedPreferences"
        const val KEY_URL = "flutter.sender_backend_url"
        const val KEY_INTERVAL = "flutter.sender_update_interval_sec"
        const val KEY_IS_ACTIVE = "flutter.is_sharing_active"

        const val KEY_LAST_LAT = "flutter.sender_last_lat"
        const val KEY_LAST_LNG = "flutter.sender_last_lng"
        const val KEY_LAST_ACC = "flutter.sender_last_acc"
        const val KEY_LAST_TIME = "flutter.sender_last_time"
        const val KEY_LAST_TIME_MILLIS = "flutter.sender_last_time_millis"

        const val DEFAULT_URL = "https://location-9ql3.onrender.com"
        const val DEFAULT_INTERVAL_SECONDS = 900L // 15 minutes default

        const val ACTION_START = "ACTION_START"
        const val ACTION_STOP = "ACTION_STOP"

        @Volatile
        var isRunning = false
            private set
    }

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback
    private var wakeLock: PowerManager.WakeLock? = null
    private val serviceScope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    private var backendUrl: String = DEFAULT_URL
    private var intervalSeconds: Long = DEFAULT_INTERVAL_SECONDS

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "onCreate: Initializing native Android LocationForegroundService")

        createNotificationChannel()

        // Acquire WakeLock to prevent CPU suspension during location handling
        val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "LocationSender:ForegroundWakeLock").apply {
            setReferenceCounted(false)
            acquire(24 * 60 * 60 * 1000L) // 24h safety limit
        }

        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(locationResult: LocationResult) {
                val location = locationResult.lastLocation ?: return
                val lat = location.latitude
                val lng = location.longitude
                val acc = location.accuracy

                Log.i(TAG, "onLocationResult received from FusedLocation: lat=$lat, lng=$lng, acc=$acc")

                val nowMillis = System.currentTimeMillis()
                val nowStr = getIsoUtcString(Date(nowMillis))

                // 1. Save latest location to SharedPreferences for the Flutter UI
                saveLocationLocally(lat, lng, acc.toDouble(), nowStr, nowMillis)

                // 2. Transmit coordinates via native HTTP POST
                serviceScope.launch {
                    sendLocationToBackend(lat, lng, acc.toDouble())
                }
            }
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val action = intent?.action ?: ACTION_START

        if (action == ACTION_STOP) {
            Log.i(TAG, "onStartCommand: ACTION_STOP received. Stopping service.")
            stopSelf()
            return START_NOT_STICKY
        }

        Log.i(TAG, "onStartCommand: Starting native foreground service")
        isRunning = true

        // Promote to foreground service immediately with persistent notification
        val notification = buildNotification("Your location is being shared in the background.")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }

        // Load configuration
        loadConfig(intent)

        // Save active state to SharedPreferences
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_IS_ACTIVE, true).apply()

        // Request location updates from Android FusedLocationProviderClient
        requestLocationUpdates()

        // START_STICKY tells Android to recreate the service if memory pressure killed it
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.i(TAG, "onTaskRemoved: Flutter Activity cleared from Recent Apps. Service continues running independently!")
        // DO NOT call stopSelf(). The foreground service remains active.
    }

    private fun requestLocationUpdates() {
        try {
            val intervalMs = (intervalSeconds * 1000L).coerceAtLeast(5000L)
            val minIntervalMs = (intervalMs / 2).coerceAtLeast(3000L)

            val locationRequest = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, intervalMs).apply {
                setMinUpdateIntervalMillis(minIntervalMs)
                setMinUpdateDistanceMeters(0f) // 0m to receive updates even when stationary
                setWaitForAccurateLocation(false)
            }.build()

            fusedLocationClient.removeLocationUpdates(locationCallback)
            fusedLocationClient.requestLocationUpdates(locationRequest, locationCallback, Looper.getMainLooper())
            Log.i(TAG, "FusedLocationProvider updates requested with interval: ${intervalSeconds}s")

            // Also request last known location immediately
            fusedLocationClient.lastLocation.addOnSuccessListener { loc ->
                if (loc != null) {
                    Log.i(TAG, "Initial lastLocation acquired: ${loc.latitude}, ${loc.longitude}")
                    val nowMillis = System.currentTimeMillis()
                    val nowStr = getIsoUtcString(Date(nowMillis))
                    saveLocationLocally(loc.latitude, loc.longitude, loc.accuracy.toDouble(), nowStr, nowMillis)
                    serviceScope.launch {
                        sendLocationToBackend(loc.latitude, loc.longitude, loc.accuracy.toDouble())
                    }
                }
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException requesting location updates: ${e.message}")
        } catch (e: Exception) {
            Log.e(TAG, "Exception requesting location updates: ${e.message}")
        }
    }

    private fun getIsoUtcString(date: Date): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US).apply {
            timeZone = java.util.TimeZone.getTimeZone("UTC")
        }
        return sdf.format(date)
    }

    private fun loadConfig(intent: Intent?) {
        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

        val intentUrl = intent?.getStringExtra("backend_url")
        val intentInterval = intent?.getLongExtra("interval_seconds", -1L) ?: -1L

        backendUrl = when {
            !intentUrl.isNullOrBlank() -> intentUrl
            prefs.contains(KEY_URL) -> prefs.getString(KEY_URL, DEFAULT_URL) ?: DEFAULT_URL
            else -> DEFAULT_URL
        }.trim().trimEnd('/')

        intervalSeconds = when {
            intentInterval > 0 -> intentInterval
            prefs.contains(KEY_INTERVAL) -> prefs.getLong(KEY_INTERVAL, DEFAULT_INTERVAL_SECONDS)
            else -> DEFAULT_INTERVAL_SECONDS
        }

        Log.i(TAG, "Configuration loaded: url=$backendUrl, interval=${intervalSeconds}s")
    }

    private fun saveLocationLocally(lat: Double, lng: Double, acc: Double, timestampIso: String, timestampMillis: Long) {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
            prefs.edit().apply {
                putLong(KEY_LAST_LAT, java.lang.Double.doubleToRawLongBits(lat))
                putLong(KEY_LAST_LNG, java.lang.Double.doubleToRawLongBits(lng))
                putLong(KEY_LAST_ACC, java.lang.Double.doubleToRawLongBits(acc))
                putString(KEY_LAST_TIME, timestampIso)
                putLong(KEY_LAST_TIME_MILLIS, timestampMillis)
                apply()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error saving location to SharedPreferences: ${e.message}")
        }
    }

    private fun sendLocationToBackend(latitude: Double, longitude: Double, accuracy: Double) {
        val endpoint = "$backendUrl/api/location"
        var connection: HttpURLConnection? = null
        try {
            Log.d(TAG, "Sending HTTP POST to $endpoint: lat=$latitude, lng=$longitude, acc=$accuracy")
            val url = URL(endpoint)
            connection = url.openConnection() as HttpURLConnection
            connection.requestMethod = "POST"
            connection.setRequestProperty("Content-Type", "application/json")
            connection.setRequestProperty("Accept", "application/json")
            connection.connectTimeout = 15000
            connection.readTimeout = 15000
            connection.doOutput = true

            val jsonBody = JSONObject().apply {
                put("latitude", latitude)
                put("longitude", longitude)
                put("accuracy", accuracy)
            }

            OutputStreamWriter(connection.outputStream).use { writer ->
                writer.write(jsonBody.toString())
                writer.flush()
            }

            val responseCode = connection.responseCode
            Log.i(TAG, "HTTP response code: $responseCode from $endpoint")
            if (responseCode in 200..299) {
                val timeStr = SimpleDateFormat("hh:mm a", Locale.getDefault()).format(Date())
                updateNotification("Your location is being shared in the background. (Last updated: $timeStr)")
            }
        } catch (e: Exception) {
            Log.w(TAG, "Failed to send location to backend: ${e.message}. Will retry on next location update.")
        } finally {
            connection?.disconnect()
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Persistent notification for location sharing foreground service"
                setShowBadge(false)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager?.createNotificationChannel(channel)
        }
    }

    private fun buildNotification(bodyText: String): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName) ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Location sharing is active")
            .setContentText(bodyText)
            .setSmallIcon(applicationInfo.icon)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(bodyText: String) {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(bodyText))
        } catch (e: Exception) {
            Log.w(TAG, "Failed to update notification: ${e.message}")
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.i(TAG, "onDestroy: Native LocationForegroundService stopping")
        isRunning = false

        val prefs = getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit().putBoolean(KEY_IS_ACTIVE, false).apply()

        try {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        } catch (e: Exception) {
            Log.w(TAG, "Error removing location updates: ${e.message}")
        }

        if (wakeLock?.isHeld == true) {
            wakeLock?.release()
        }

        serviceScope.cancel()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
