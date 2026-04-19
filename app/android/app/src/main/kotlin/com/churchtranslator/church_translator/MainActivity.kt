package com.churchtranslator.church_translator

import android.net.wifi.WifiManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var multicastLock: WifiManager.MulticastLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.churchtranslator/multicast")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquireMulticastLock" -> {
                        val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
                        multicastLock = wifiManager.createMulticastLock("church_translator")
                        multicastLock?.acquire()
                        result.success(null)
                    }
                    "releaseMulticastLock" -> {
                        multicastLock?.release()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
