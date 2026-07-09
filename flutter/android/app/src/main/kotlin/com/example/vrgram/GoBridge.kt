package com.example.vrgram

object GoBridge {
    init {
        System.loadLibrary("vrgram")
    }

    @JvmStatic
    external fun startDaemon(
        grpcPort: Int,
        relayList: String,
        zone: String,
        forceBlackout: String,
        dataDir: String,
        p2pPort: Int,
        bootstrapAddrs: String,
    )
}
