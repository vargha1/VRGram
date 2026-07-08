import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/grpc/client.dart';
import 'core/platform/go_bridge.dart';
import 'shared/constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start Go daemon (native code runs before Flutter, but ensure readiness)
  await GoBridge.start();

  // Initialize gRPC client
  await GrpcClient().init();

  runApp(const ProviderScope(child: VRGramApp()));
}

class VRGramApp extends ConsumerWidget {
  const VRGramApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      theme: ThemeData(
        colorSchemeSeed: AppColors.primary,
        useMaterial3: true,
      ),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
