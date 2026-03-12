import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../features/auth/login_screen.dart';

/// Bọc toàn bộ app — tự redirect đến LoginScreen nếu chưa đăng nhập.
/// Khi user đăng nhập thành công, stream thay đổi và child hiện ra.
class AuthWrapper extends StatelessWidget {
  final Widget child;
  const AuthWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Đang check trạng thái auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Chưa đăng nhập → Login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }
        // Đã đăng nhập → vào app
        return child;
      },
    );
  }
}
