import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase service — dùng Google Sign-In, uid ổn định qua cài lại app.
class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance {
    _instance ??= FirebaseService._();
    return _instance!;
  }
  FirebaseService._();

  late final FirebaseFirestore _db;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _db = FirebaseFirestore.instance;
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    _initialized = true;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String get uid {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception('Not logged in');
    return user.uid;
  }

  /// users/{uid}/trade_logs/{id}
  CollectionReference<Map<String, dynamic>> get tradeLogsRef =>
      _db.collection('users').doc(uid).collection('trade_logs');

  /// users/{uid}/market_levels/latest
  DocumentReference<Map<String, dynamic>> get marketLevelRef =>
      _db.collection('users').doc(uid).collection('market_levels').doc('latest');

  /// users/{uid}/watchlist/data
  DocumentReference<Map<String, dynamic>> get watchlistRef =>
      _db.collection('users').doc(uid).collection('watchlist').doc('data');

  // ── Sign out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}
