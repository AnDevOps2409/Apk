// ─── MarketLevel Models ───────────────────────────────────────────────────────
// Lưu bảng phân tích HT/MT + dòng tiền mỗi ngày
// User dùng ChatGPT extract ảnh → JSON → import vào app

class StockLevel {
  final String symbol;
  final String group; // 'uu_tien' | 'khac'

  // Dòng tiền T+0
  final double? t0TienNho;  // Tăng/Giảm Tiền nhỏ T+0
  final double? t0TienLon;  // Tăng/Giảm Tiền lớn T+0

  // Tổng
  final double? tongTienNho;
  final double? tongTienLon;

  // Hỗ trợ (KC = MT theo thiết kế của user)
  final double? ht1;
  final double? ht2;

  // Mục tiêu
  final double? mt1;
  final double? mt2;

  const StockLevel({
    required this.symbol,
    required this.group,
    this.t0TienNho,
    this.t0TienLon,
    this.tongTienNho,
    this.tongTienLon,
    this.ht1,
    this.ht2,
    this.mt1,
    this.mt2,
  });

  // ── Serialization ────────────────────────────────────────────────────────
  factory StockLevel.fromJson(Map<String, dynamic> json) => StockLevel(
    symbol:      (json['symbol'] as String? ?? '').toUpperCase().trim(),
    group:       json['group'] as String? ?? 'khac',
    t0TienNho:   _parseNum(json['t0_tien_nho']),
    t0TienLon:   _parseNum(json['t0_tien_lon']),
    tongTienNho: _parseNum(json['tong_tien_nho']),
    tongTienLon: _parseNum(json['tong_tien_lon']),
    ht1:         _parseNum(json['ht1']),
    ht2:         _parseNum(json['ht2']),
    mt1:         _parseNum(json['mt1']),
    mt2:         _parseNum(json['mt2']),
  );

  Map<String, dynamic> toJson() => {
    'symbol':       symbol,
    'group':        group,
    't0_tien_nho':  t0TienNho,
    't0_tien_lon':  t0TienLon,
    'tong_tien_nho': tongTienNho,
    'tong_tien_lon': tongTienLon,
    'ht1': ht1,
    'ht2': ht2,
    'mt1': mt1,
    'mt2': mt2,
  };

  // ── Computed: Smart Alert ────────────────────────────────────────────────

  /// % giá vào cách HT1 (dương = trên HT1, âm = dưới)
  double? distanceFromHt1(double entryPrice) {
    if (ht1 == null || ht1 == 0) return null;
    return ((entryPrice - ht1!) / ht1!) * 100;
  }

  double? distanceFromHt2(double entryPrice) {
    if (ht2 == null || ht2 == 0) return null;
    return ((entryPrice - ht2!) / ht2!) * 100;
  }

  /// % còn lên đến MT1/MT2
  double? upsideToMt1(double entryPrice) {
    if (mt1 == null) return null;
    return ((mt1! - entryPrice) / entryPrice) * 100;
  }

  double? upsideToMt2(double entryPrice) {
    if (mt2 == null) return null;
    return ((mt2! - entryPrice) / entryPrice) * 100;
  }

  /// R:R = upside MT1 / 4% SL
  double? rrRatio(double entryPrice) {
    final up = upsideToMt1(entryPrice);
    if (up == null) return null;
    return up / 4.0; // SL cứng -4% cắt 1/2
  }

  /// Đánh giá dòng tiền
  CashFlowSignal get cashFlowSignal {
    final lon = tongTienLon ?? 0;
    final lonT0 = t0TienLon ?? 0;
    if (lon > 0 && lonT0 > 0) return CashFlowSignal.strong;
    if (lon > 0 && lonT0 <= 0) return CashFlowSignal.weak;
    return CashFlowSignal.negative;
  }
}

enum CashFlowSignal { strong, weak, negative }

// ── Helpers ─────────────────────────────────────────────────────────────────

/// Parse "101-102" → 101.5, "120+-" → 120.0, null → null
double? _parseNum(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().trim();
  if (s.isEmpty || s == 'null') return null;

  // Range "101-102" (after strip becomes "101102"? No — strip only trailing +-space)
  // Better: remove only trailing non-digit chars
  final stripped = s.replaceAll(RegExp(r'[^0-9.\-]'), '');

  // Try range split on '-' that's not a leading minus
  if (stripped.contains('-') && !stripped.startsWith('-')) {
    final parts = stripped.split('-');
    if (parts.length == 2) {
      final a = double.tryParse(parts[0]);
      final b = double.tryParse(parts[1]);
      if (a != null && b != null) return (a + b) / 2;
    }
  }

  return double.tryParse(stripped);
}

// ─── Version wrapper ─────────────────────────────────────────────────────────

class MarketLevelVersion {
  final String version;    // ISO datetime: "2026-03-08T09:00:00"
  final List<StockLevel> stocks;

  const MarketLevelVersion({
    required this.version,
    required this.stocks,
  });

  factory MarketLevelVersion.fromJson(Map<String, dynamic> json) =>
      MarketLevelVersion(
        version: json['version'] as String? ?? DateTime.now().toIso8601String(),
        stocks: (json['stocks'] as List<dynamic>? ?? [])
            .map((e) => StockLevel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
    'version': version,
    'stocks': stocks.map((s) => s.toJson()).toList(),
  };

  /// Tìm mức của 1 mã cụ thể (case-insensitive)
  StockLevel? forSymbol(String symbol) {
    final upper = symbol.toUpperCase().trim();
    try {
      return stocks.firstWhere((s) => s.symbol == upper);
    } catch (_) {
      return null;
    }
  }

  String get displayDate {
    try {
      final dt = DateTime.parse(version);
      return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return version;
    }
  }
}
