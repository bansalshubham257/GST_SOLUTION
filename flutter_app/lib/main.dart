import 'dart:ui' show PlatformDispatcher;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/constants/app_constants.dart';
import 'core/storage/local_storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Capture Flutter errors to logcat for debugging release builds
  FlutterError.onError = (details) {
    debugPrint('=== FLUTTER ERROR ===');
    debugPrint(details.exceptionAsString());
    debugPrint(details.stack?.toString() ?? '');
    debugPrint('=====================');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('=== PLATFORM ERROR: $error ===');
    debugPrint(stack.toString());
    return true;
  };

  // Lock to portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase (graceful fallback for demo mode)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init skipped (demo mode): $e');
  }

  // Initialize Hive for offline caching
  await Hive.initFlutter();
  await LocalStorage.init();
  await LocalStorage.migrateInvoiceSlabs();

  // Status bar styling
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: RegisterApp()));
}

class RegisterApp extends ConsumerWidget {
  const RegisterApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
