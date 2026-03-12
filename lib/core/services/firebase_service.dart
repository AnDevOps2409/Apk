import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase service — Anonymous Auth.
/// UID ổn định trên cùng thiết bị, tự tạo khi mới cài.
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

  Future<void> init() async {
    if (_initialized) return;

    _db = FirebaseFirestore.instance;
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Anonymous sign-in: UID ổn định trên thiết bị này
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
    _uid = auth.currentUser!.uid;
    _initialized = true;
  }

  String get uid => _uid;

  CollectionReference<Map<String, dynamic>> get tradeLogsRef =>
      _db.collection('users').doc(_uid).collection('trade_logs');

  DocumentReference<Map<String, dynamic>> get marketLevelRef =>
      _db.collection('users').doc(_uid).collection('market_levels').doc('latest');

  DocumentReference<Map<String, dynamic>> get watchlistRef =>
      _db.collection('users').doc(_uid).collection('watchlist').doc('data');
}
