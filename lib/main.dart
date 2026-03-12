import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/stock_providers.dart';
import 'core/services/firebase_service.dart';
import 'core/services/migration_service.dart';
import 'core/auth_wrapper.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Firebase Init ────────────────────────────────────────────────────────
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseService.instance.init();

  // Migrate dữ liệu cũ từ SharedPreferences lên Firestore (chỉ chạy 1 lần)
  await MigrationService.runIfNeeded();

  // ── SharedPreferences (chỉ dùng cho Gemini API Key + migration flag) ─────
  final prefs = await SharedPreferences.getInstance();

  // Lock portrait orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Status bar style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const DnseStockApp(),
    ),
  );
}

class DnseStockApp extends StatelessWidget {
  const DnseStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthWrapper(
      child: MaterialApp.router(
        title: 'Magic',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        routerConfig: appRouter,
      ),
    );
  }
}
