package com.example.vrgram

import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                    "startDaemon" -> {
                        try {
                            val args = call.arguments as Map<*, *>
                            val dataDir = args["dataDir"] as String
                            val grpcPort = args["grpcPort"] as Int
                            val p2pPort = args["p2pPort"] as Int
                            val zone = args["zone"] as String
                            val relays = args["relays"] as String
                            val bootstrap = args["bootstrap"] as String

                            // Default relay if none configured
                            val defaultRelay = "31.15.17.161:53"
                            val relayList = if (relays.isBlank()) defaultRelay else relays

                            Log.d("VRGram", "Starting Go daemon via method channel, dataDir=$dataDir relay=$relayList")
                            GoBridge.startDaemon(
                                grpcPort,
                                relayList,
                                zone,
                                "false",
                                dataDir,
                                p2pPort,
                                bootstrap,
                            )
                            Log.d("VRGram", "Go daemon startDaemon called")
                            result.success(true)
                        } catch (e: UnsatisfiedLinkError) {
                            Log.e("VRGram", "Failed to load native library", e)
                            result.error("LINK_ERROR", e.message, null)
                        } catch (e: Exception) {
                            Log.e("VRGram", "Failed to start Go daemon", e)
                            result.error("START_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }
}
