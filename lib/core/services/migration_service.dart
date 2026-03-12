import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_service.dart';
import '../models/trade_log.dart';
import '../models/market_level.dart';

/// Chạy một lần duy nhất khi user update app và có dữ liệu cũ ở SharedPreferences.
/// Sau khi migrate xong, đánh dấu flag để không chạy lại.
class MigrationService {
  static const _migrationDoneKey = 'firebase_migration_done_v1';

  static Future<void> runIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool(_migrationDoneKey) ?? false;
    if (done) return;

    await _migrateTradeLogs(prefs);
    await _migrateMarketLevels(prefs);
    await _migrateWatchlist(prefs);

    // Đánh dấu đã xong
    await prefs.setBool(_migrationDoneKey, true);
  }

  // ── Trade Logs ───────────────────────────────────────────────────────────

  static Future<void> _migrateTradeLogs(SharedPreferences prefs) async {
    const key = 'trade_logs_v1';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final logs = list
          .map((e) => TradeLog.fromJson(e as Map<String, dynamic>))
          .toList();

      final batch = FirebaseService.instance.tradeLogsRef;
      for (final log in logs) {
        await batch.doc(log.id).set(log.toJson());
      }

      // Xóa SharedPreferences key sau khi migrate
      await prefs.remove(key);
    } catch (e) {
      // Migration lỗi không critical, app vẫn chạy được
    }
  }

  // ── Market Levels ────────────────────────────────────────────────────────

  static Future<void> _migrateMarketLevels(SharedPreferences prefs) async {
    const key = 'market_levels_history_v1';
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return;

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      if (list.isEmpty) return;
      final latest = MarketLevelVersion.fromJson(list.first as Map<String, dynamic>);
      await FirebaseService.instance.marketLevelRef.set(latest.toJson());
      await prefs.remove(key);
    } catch (e) {
      // Silent fail
    }
  }

  // ── Watchlist ────────────────────────────────────────────────────────────

  static Future<void> _migrateWatchlist(SharedPreferences prefs) async {
    const key = 'dnse_watchlist';
    final saved = prefs.getStringList(key);
    if (saved == null || saved.isEmpty) return;

    try {
      await FirebaseService.instance.watchlistRef.set({'symbols': saved});
      await prefs.remove(key);
    } catch (e) {
      // Silent fail
    }
  }
}
