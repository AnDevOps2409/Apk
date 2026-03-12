import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/stock_providers.dart';
import 'core/services/firebase_service.dart';
import 'features/auth/login_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Bắt mọi lỗi Flutter không handled
  FlutterError.onError = (details) {
    debugPrint('Flutter error: ${details.exception}');
  };

  // ── Firebase Init ─────────────────────────────────────────────────────────
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await FirebaseService.instance.init();
  } catch (e) {
    debugPrint('Firebase init error: $e');
    // Vẫn tiếp tục chạy app — hiển thị UI rồi báo lỗi sau
  }

  // ── SharedPreferences ─────────────────────────────────────────────────────
  SharedPreferences? prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (e) {
    debugPrint('SharedPreferences error: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        if (prefs != null)
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
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // ── Đang check auth ───────────────────────────────────────────────
        if (snapshot.connectionState == ConnectionState.waiting) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: const Scaffold(
              backgroundColor: AppColors.background,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.accent),
                    SizedBox(height: 16),
                    Text('Đang khởi động...',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ),
          );
        }

        // ── Chưa đăng nhập ────────────────────────────────────────────────
        if (!snapshot.hasData || snapshot.data == null) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.dark,
            home: const LoginScreen(),
          );
        }

        // ── Đã đăng nhập ──────────────────────────────────────────────────
        return MaterialApp.router(
          title: 'Magic',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.dark,
          routerConfig: appRouter,
        );
      },
    );
  }
}
