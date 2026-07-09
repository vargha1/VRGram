package com.example.vrgram

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "vrgram/bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // Start Go daemon before Flutter engine loads
        try {
            val dataDir = applicationContext.filesDir.absolutePath
            Log.d("VRGram", "Starting Go daemon, dataDir=$dataDir")
            GoBridge.startDaemon(
                9876,                    // grpcPort
                "",                      // relayList (comma-separated, empty = none)
                "msg.local-domain",      // zone
                "false",                 // forceBlackout
                dataDir,                 // dataDir
                4001,                    // p2pPort
                "",                      // bootstrapAddrs
            )
            Log.d("VRGram", "Go daemon started successfully")
        } catch (e: UnsatisfiedLinkError) {
            Log.e("VRGram", "Failed to load native library", e)
        } catch (e: Exception) {
            Log.e("VRGram", "Failed to start Go daemon", e)
        }

        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDataDir" -> {
                        result.success(applicationContext.filesDir.absolutePath)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
