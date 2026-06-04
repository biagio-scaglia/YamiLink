package com.example.yamilink

import android.content.Context
import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yamilink/multicast"
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "acquireMulticastLock" -> {
                    val success = acquireLock()
                    if (success) {
                        result.success(true)
                    } else {
                        result.error("UNAVAILABLE", "Multicast lock not available.", null)
                    }
                }
                "releaseMulticastLock" -> {
                    releaseLock()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun acquireLock(): Boolean {
        if (multicastLock?.isHeld == true) return true
        
        return try {
            val wifiManager = context.applicationContext.getSystemService(Context.WIFI_SERVICE) as WifiManager?
            if (wifiManager != null) {
                multicastLock = wifiManager.createMulticastLock("yamilinkMulticastLock")
                multicastLock?.setReferenceCounted(true)
                multicastLock?.acquire()
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun releaseLock() {
        try {
            if (multicastLock?.isHeld == true) {
                multicastLock?.release()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        releaseLock()
        super.onDestroy()
    }
}
