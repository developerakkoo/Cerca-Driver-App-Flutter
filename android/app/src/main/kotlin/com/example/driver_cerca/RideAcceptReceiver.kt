package com.example.driver_cerca

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class RideAcceptReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == "com.example.driver_cerca.RIDE_ACCEPTED") {
            Log.d("RideAcceptReceiver", "Ride accepted, launching main activity")
            
            val launchIntent = context.packageManager
                .getLaunchIntentForPackage(context.packageName)
            
            launchIntent?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                it.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                it.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                it.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                context.startActivity(it)
            }
        }
    }
}

