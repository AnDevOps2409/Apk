import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase service — khởi tạo Anonymous Auth và cung cấp Firestore instance.
///
/// Mỗi thiết bị tự đăng nhập ẩn danh (Anonymous Auth).
/// Toàn bộ dữ liệu được lưu dưới path: users/{uid}/...
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance {
    _instance ??= FirebaseService._();
    return _instance!;
  }

  FirebaseService._();

  late final FirebaseFirestore _db;
  late final String _uid;

  bool _initialized = false;

  /// Gọi một lần trong main() sau Firebase.initializeApp()
  Future<void> init() async {
    if (_initialized) return;

    _db = FirebaseFirestore.instance;

    // Enable offline persistence (tự động cache khi mất mạng)
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Anonymous sign-in: tạo UID ổn định cho thiết bị
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    _uid = auth.currentUser!.uid;

    _initialized = true;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String get uid => _uid;

  /// users/{uid}/trade_logs/{id}
  CollectionReference<Map<String, dynamic>> get tradeLogsRef =>
      _db.collection('users').doc(_uid).collection('trade_logs');

  /// users/{uid}/market_levels/latest
  DocumentReference<Map<String, dynamic>> get marketLevelRef =>
      _db.collection('users').doc(_uid).collection('market_levels').doc('latest');

  /// users/{uid}/watchlist/data
  DocumentReference<Map<String, dynamic>> get watchlistRef =>
      _db.collection('users').doc(_uid).collection('watchlist').doc('data');
}
