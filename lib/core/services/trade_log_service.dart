import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trade_log.dart';
import 'firebase_service.dart';

/// Lưu/tải TradeLog bằng Firebase Firestore.
/// Path: users/{uid}/trade_logs/{id}
///
/// Firestore tự cache offline — app đọc được dữ liệu cũ ngay cả khi mất mạng.
class TradeLogService {
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseService.instance.tradeLogsRef;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<List<TradeLog>> loadAll() async {
    try {
      final snap = await _col
          .orderBy('tradeDate', descending: true)
          .get(const GetOptions(source: Source.serverAndCache));
      return snap.docs
          .map((d) => TradeLog.fromJson(d.data()))
          .toList();
    } catch (_) {
      // Fallback: đọc cache khi offline
      final snap = await _col
          .orderBy('tradeDate', descending: true)
          .get(const GetOptions(source: Source.cache));
      return snap.docs
          .map((d) => TradeLog.fromJson(d.data()))
          .toList();
    }
  }

  // ── Save (upsert) ─────────────────────────────────────────────────────────

  Future<void> save(TradeLog log) async {
    await _col.doc(log.id).set(log.toJson());
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
