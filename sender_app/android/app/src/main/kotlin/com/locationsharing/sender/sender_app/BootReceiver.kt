package com.locationsharing.sender.sender_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.core.content.ContextCompat

class BootReceiver : BroadcastReceiver() {
    companion object {
        const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.i(TAG, "onReceive: Broadcast received with action: $action")

        if (action == Intent.ACTION_BOOT_COMPLETED || action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val prefs = context.getSharedPreferences(LocationForegroundService.PREFS_NAME, Context.MODE_PRIVATE)
            val wasSharingActive = prefs.getBoolean(LocationForegroundService.KEY_IS_ACTIVE, false)

            if (wasSharingActive) {
                Log.i(TAG, "Sharing was previously active. Restoring native LocationForegroundService on boot...")
                val serviceIntent = Intent(context, LocationForegroundService::class.java).apply {
                    this.action = LocationForegroundService.ACTION_START
                }
                ContextCompat.startForegroundService(context, serviceIntent)
            } else {
                Log.i(TAG, "Sharing was not active prior to restart. Not starting service.")
            }
        }
    }
}
