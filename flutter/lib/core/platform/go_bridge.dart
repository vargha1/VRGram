import 'dart:io';

class GoBridge {
  static Future<void> start() async {
    // Go daemon gRPC server is started natively before Flutter runs.
    // On Android/iOS: GoInit() called in MainActivity/AppDelegate.
    // On Windows: GoInit() called in main.cpp.
    //
    // Wait briefly for gRPC server to become ready.
    await Future.delayed(const Duration(milliseconds: 500));
  }

  static Future<void> stop() async {
    // Go daemon stops when process exits.
    // On Android/iOS: GoRelayd.stopGRPCServer() called in onDestroy/dealloc.
  }

  static bool get isDesktop => !Platform.isAndroid && !Platform.isIOS;
}
