package com.example.vrgram

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import mobile.GoRelayd

class MainActivity : FlutterActivity() {
    private val CHANNEL = "vrgram/bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Start Go daemon before Flutter engine loads
        val dataDir = applicationContext.filesDir.absolutePath
        GoRelayd.startDaemon(
            9876,                    // grpcPort
            "",                      // relayList (comma-separated, empty = none)
            "msg.local-domain",      // zone
            "false",                 // forceBlackout
            dataDir,                 // dataDir
            4001,                    // p2pPort
            "",                      // bootstrapAddrs
        )

        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDataDir" -> {
                        result.success(dataDir)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
