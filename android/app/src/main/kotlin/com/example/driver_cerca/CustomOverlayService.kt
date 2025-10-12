package com.example.driver_cerca

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodChannel
import io.flutter.embedding.engine.FlutterEngine

object OverlayLauncher {
    private const val CHANNEL = "com.example.driver_cerca/overlay"
    
    fun setupMethodChannel(flutterEngine: FlutterEngine, context: Context) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "launchMainActivity" -> {
                        try {
                            val intent = context.packageManager
                                .getLaunchIntentForPackage(context.packageName)
                            intent?.let {
                                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                it.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                it.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                                it.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                                context.startActivity(it)
                            }
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

