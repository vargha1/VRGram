package com.example.vrgram

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * When using gomobile bind, uncomment and add:
 *   implementation(files("libs/gomobile.aar"))
 * to android/app/build.gradle.kts dependencies block.
 *
 * Then the Go daemon starts via native code before Flutter loads:
 *   GoRelayd.startEmbedded(9876, "", "msg.local-domain", "", dataDir, 4001, "")
 *
 * For now the Go daemon must be started separately on Android,
 * or desktop mode auto-starts the binary via GoBridge.
 */
class MainActivity : FlutterActivity() {
    private val CHANNEL = "vrgram/bridge"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
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
