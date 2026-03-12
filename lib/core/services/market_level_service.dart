import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/market_level.dart';
import 'firebase_service.dart';

/// Quản lý bảng phân tích HT/MT hàng ngày.
/// Flow: User export JSON từ ChatGPT → import vào app → lưu lên Firestore
///
/// Path: users/{uid}/market_levels/latest
/// Chỉ lưu 1 version duy nhất (ghi đè).
class MarketLevelService {
  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseService.instance.marketLevelRef;

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Load toàn bộ version history (luôn trả về list 0 hoặc 1 phần tử)
  Future<List<MarketLevelVersion>> loadHistory() async {
    final latest = await loadLatest();
    return latest == null ? [] : [latest];
  }

  /// Lấy version mới nhất (null nếu chưa có)
  Future<MarketLevelVersion?> loadLatest() async {
    try {
      final snap = await _doc.get(const GetOptions(source: Source.serverAndCache));
      if (!snap.exists || snap.data() == null) return null;
      return MarketLevelVersion.fromJson(snap.data()!);
    } catch (_) {
      // Fallback cache khi offline
      try {
        final snap = await _doc.get(const GetOptions(source: Source.cache));
        if (!snap.exists || snap.data() == null) return null;
        return MarketLevelVersion.fromJson(snap.data()!);
      } catch (_) {
        return null;
      }
    }
  }

  /// Tìm mức của 1 mã trong version mới nhất
  Future<StockLevel?> findSymbol(String symbol) async {
    final latest = await loadLatest();
    return latest?.forSymbol(symbol);
  }

  // ── Import ────────────────────────────────────────────────────────────────

  /// Parse JSON string từ file người dùng chọn.
  /// Trả về MarketLevelVersion hoặc throw Exception nếu format sai.
  MarketLevelVersion parseJson(String jsonString) {
    final decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON phải là object có key "stocks"');
    }

    // Ép version luôn là ngày hiện tại lúc import, bỏ qua version có sẵn trong file
    decoded['version'] = DateTime.now().toIso8601String();

    final version = MarketLevelVersion.fromJson(decoded);
    if (version.stocks.isEmpty) {
      throw const FormatException('Không tìm thấy mã nào trong JSON');
    }
    return version;
  }

  /// Lưu version mới ghi đè lên version cũ (chỉ giữ 1 bản duy nhất)
  Future<void> saveVersion(MarketLevelVersion version) async {
    await _doc.set(version.toJson());
  }

  /// Xoá version theo index (index 0 = latest → xóa hết)
  Future<void> deleteVersion(int index) async {
    if (index == 0) {
      await _doc.delete();
    }
  }

  /// Xoá toàn bộ
  Future<void> clearAll() async {
    await _doc.delete();
  }
}
