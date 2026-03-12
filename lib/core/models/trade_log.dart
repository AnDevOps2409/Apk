
// ─── Enums ────────────────────────────────────────────────────────────────────

enum TradePattern {
  testForSupply('Test for Supply'),
  noSupply('No Supply'),
  shakeout('Shakeout'),
  spring('Spring'),
  sos('SOS'),
  noDemand('No Demand'),
  pinBar('Pin Bar'),
  engulfing('Engulfing'),
  morningStar('Morning Star'),
  other('Khác');

  final String label;
  const TradePattern(this.label);
}

enum ExitType {
  takeProfit('Chốt lời'),
  stopLoss50('Cắt lỗ 50%'),
  stopLoss100('Cắt lỗ 100%'),
  manualExit('Thoát thủ công');

  final String label;
  const ExitType(this.label);
}

enum ExitEmotion {
  calm('Bình tĩnh'),
  fear('Sợ hãi'),
  greedy('Hứng khởi'),
  panic('Hoảng loạn');

  final String label;
  const ExitEmotion(this.label);
}

// ─── Model ───────────────────────────────────────────────────────────────────

class TradeLog {
  final String id;
  final String symbol;
  final DateTime tradeDate;

  // Entry
  final double entryPrice;
  final int entryQuantity;
  final String entryReason;
  final TradePattern pattern;

  // SL cứng (tính tự động từ entryPrice)
  double get sl50Price  => entryPrice * 0.96; // -4% → cắt 1/2
  double get sl100Price => entryPrice * 0.92; // -8% → cắt hết

  // Exit (nullable — chưa đóng lệnh)
  final double?      exitPrice;
  final int?         exitQuantity;  // null = đã bán toàn bộ
  final String?      exitReason;
  final DateTime?    exitDate;
  final ExitType?    exitType;
  final ExitEmotion? exitEmotion;

  // Số cổ phiếu bán thực tế (nếu null thì bán hết)
  int get soldQuantity => exitQuantity ?? entryQuantity;

  // Số cổ phiếu còn giữ lại sau khi bán
  int get remainingQuantity => entryQuantity - soldQuantity;

  // true nếu chỉ bán một phần
  bool get isPartialExit =>
      exitQuantity != null && exitQuantity! < entryQuantity;

  // PnL (tự tính)
  double? get pnlPercent {
    if (exitPrice == null) return null;
    return ((exitPrice! - entryPrice) / entryPrice) * 100;
  }

  double? get pnlVnd {
    if (exitPrice == null) return null;
    return (exitPrice! - entryPrice) * soldQuantity;
  }

  bool get isClosed => exitPrice != null;

  // AI review cache
  final String? aiReview;

  const TradeLog({
    required this.id,
    required this.symbol,
    required this.tradeDate,
    required this.entryPrice,
    required this.entryQuantity,
    required this.entryReason,
    required this.pattern,
    this.exitPrice,
    this.exitQuantity,
    this.exitReason,
    this.exitDate,
    this.exitType,
    this.exitEmotion,
    this.aiReview,
  });

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'symbol': symbol,
    'tradeDate': tradeDate.toIso8601String(),
    'entryPrice': entryPrice,
    'entryQuantity': entryQuantity,
    'entryReason': entryReason,
    'pattern': pattern.name,
    'exitPrice': exitPrice,
    'exitQuantity': exitQuantity,
    'exitReason': exitReason,
    'exitDate': exitDate?.toIso8601String(),
    'exitType': exitType?.name,
    'exitEmotion': exitEmotion?.name,
    'aiReview': aiReview,
  };

  factory TradeLog.fromJson(Map<String, dynamic> json) => TradeLog(
    id:             json['id'] as String,
    symbol:         json['symbol'] as String,
    tradeDate:      DateTime.parse(json['tradeDate'] as String),
    entryPrice:     (json['entryPrice'] as num).toDouble(),
    entryQuantity:  json['entryQuantity'] as int,
    entryReason:    json['entryReason'] as String,
    pattern:        TradePattern.values.firstWhere(
                      (e) => e.name == json['pattern'],
                      orElse: () => TradePattern.other,
                    ),
    exitPrice:      (json['exitPrice'] as num?)?.toDouble(),
    exitQuantity:   json['exitQuantity'] as int?,
    exitReason:     json['exitReason'] as String?,
    exitDate:       json['exitDate'] != null
                      ? DateTime.parse(json['exitDate'] as String)
                      : null,
    exitType:       json['exitType'] != null
                      ? ExitType.values.firstWhere(
                          (e) => e.name == json['exitType'],
                          orElse: () => ExitType.manualExit,
                        )
                      : null,
    exitEmotion:    json['exitEmotion'] != null
                      ? ExitEmotion.values.firstWhere(
                          (e) => e.name == json['exitEmotion'],
                          orElse: () => ExitEmotion.calm,
                        )
                      : null,
    aiReview:       json['aiReview'] as String?,
  );

  TradeLog copyWith({
    String?       id,
    String?       symbol,
    DateTime?     tradeDate,
    double?       entryPrice,
    int?          entryQuantity,
    String?       entryReason,
    TradePattern? pattern,
    double?       exitPrice,
    int?          exitQuantity,
    String?       exitReason,
    DateTime?     exitDate,
    ExitType?     exitType,
    ExitEmotion?  exitEmotion,
    String?       aiReview,
    bool          clearExit = false,
  }) => TradeLog(
    id:            id            ?? this.id,
    symbol:        symbol        ?? this.symbol,
    tradeDate:     tradeDate     ?? this.tradeDate,
    entryPrice:    entryPrice    ?? this.entryPrice,
    entryQuantity: entryQuantity ?? this.entryQuantity,
    entryReason:   entryReason   ?? this.entryReason,
    pattern:       pattern       ?? this.pattern,
    exitPrice:     clearExit ? null : (exitPrice    ?? this.exitPrice),
    exitQuantity:  clearExit ? null : (exitQuantity ?? this.exitQuantity),
    exitReason:    clearExit ? null : (exitReason   ?? this.exitReason),
    exitDate:      clearExit ? null : (exitDate     ?? this.exitDate),
    exitType:      clearExit ? null : (exitType     ?? this.exitType),
    exitEmotion:   clearExit ? null : (exitEmotion  ?? this.exitEmotion),
    aiReview:      aiReview      ?? this.aiReview,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TradeLog && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
