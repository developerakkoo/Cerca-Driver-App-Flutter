package com.example.driver_cerca

import android.content.Intent
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val LAUNCHER_CHANNEL = "com.example.driver_cerca/app_launcher"
    private val BROADCAST_CHANNEL = "com.example.driver_cerca/broadcast"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Method channel for app launcher
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LAUNCHER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "bringAppToForeground" -> {
                        try {
                            val intent = packageManager.getLaunchIntentForPackage(packageName)
                            intent?.let {
                                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                it.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                it.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                startActivity(it)
                            }
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        
        // Method channel for broadcasting ride acceptance
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, BROADCAST_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendRideAcceptedBroadcast" -> {
                        try {
                            val broadcastIntent = Intent("com.example.driver_cerca.RIDE_ACCEPTED")
                            broadcastIntent.setPackage(packageName)
                            sendBroadcast(broadcastIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
