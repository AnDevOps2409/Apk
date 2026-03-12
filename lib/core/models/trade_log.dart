
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

// ─── SellOrder (một lần bán) ──────────────────────────────────────────────────

class SellOrder {
  final double      price;
  final int         quantity;
  final String?     reason;
  final DateTime?   date;
  final ExitType?   exitType;
  final ExitEmotion? exitEmotion;

  const SellOrder({
    required this.price,
    required this.quantity,
    this.reason,
    this.date,
    this.exitType,
    this.exitEmotion,
  });

  Map<String, dynamic> toJson() => {
    'price':      price,
    'quantity':   quantity,
    'reason':     reason,
    'date':       date?.toIso8601String(),
    'exitType':   exitType?.name,
    'exitEmotion': exitEmotion?.name,
  };

  factory SellOrder.fromJson(Map<String, dynamic> j) => SellOrder(
    price:      (j['price'] as num).toDouble(),
    quantity:   j['quantity'] as int,
    reason:     j['reason'] as String?,
    date:       j['date'] != null ? DateTime.parse(j['date'] as String) : null,
    exitType:   j['exitType'] != null
                  ? ExitType.values.firstWhere((e) => e.name == j['exitType'],
                      orElse: () => ExitType.manualExit)
                  : null,
    exitEmotion: j['exitEmotion'] != null
                  ? ExitEmotion.values.firstWhere((e) => e.name == j['exitEmotion'],
                      orElse: () => ExitEmotion.calm)
                  : null,
  );

  SellOrder copyWith({
    double? price, int? quantity, String? reason,
    DateTime? date, ExitType? exitType, ExitEmotion? exitEmotion,
  }) => SellOrder(
    price:       price       ?? this.price,
    quantity:    quantity    ?? this.quantity,
    reason:      reason      ?? this.reason,
    date:        date        ?? this.date,
    exitType:    exitType    ?? this.exitType,
    exitEmotion: exitEmotion ?? this.exitEmotion,
  );
}

// ─── AddBuy (mua thêm cùng mã) ───────────────────────────────────────────────

class AddBuy {
  final double   price;
  final int      quantity;
  final DateTime date;

  const AddBuy({
    required this.price,
    required this.quantity,
    required this.date,
  });

  Map<String, dynamic> toJson() => {
    'price':    price,
    'quantity': quantity,
    'date':     date.toIso8601String(),
  };

  factory AddBuy.fromJson(Map<String, dynamic> j) => AddBuy(
    price:    (j['price'] as num).toDouble(),
    quantity: j['quantity'] as int,
    date:     DateTime.parse(j['date'] as String),
  );
}

// ─── Model ───────────────────────────────────────────────────────────────────

class TradeLog {
  final String id;
  final String symbol;
  final DateTime tradeDate;

  // Entry (lần mua đầu)
  final double entryPrice;
  final int entryQuantity;
  final String entryReason;
  final TradePattern pattern;

  // Mua thêm (có thể nhiều lần)
  final List<AddBuy> addBuys;

  // === Computed: giá trung bình & tổng KL sau tất cả lần mua ===
  double get avgPrice {
    if (addBuys.isEmpty) return entryPrice;
    double totalCost = entryPrice * entryQuantity;
    int    totalQty  = entryQuantity;
    for (final b in addBuys) {
      totalCost += b.price * b.quantity;
      totalQty  += b.quantity;
    }
    return totalCost / totalQty;
  }

  int get totalBuyQuantity {
    return entryQuantity + addBuys.fold(0, (s, b) => s + b.quantity);
  }

  // SL cứng (tính từ avgPrice)
  double get sl50Price  => avgPrice * 0.96;
  double get sl100Price => avgPrice * 0.92;

  // Nhiều lệnh bán
  final List<SellOrder> sellOrders;

  // === Computed từ sellOrders ===
  int get totalSold => sellOrders.fold(0, (s, o) => s + o.quantity);
  int get remainingQuantity => totalBuyQuantity - totalSold;
  bool get isClosed => totalSold >= totalBuyQuantity && sellOrders.isNotEmpty;
  bool get hasAnySell => sellOrders.isNotEmpty;

  // PnL chỉ tính được nếu có ít nhất 1 lệnh bán
  double? get pnlPercent {
    if (sellOrders.isEmpty) return null;
    // Weighted average exit price
    double totalVal = sellOrders.fold(0.0, (s, o) => s + o.price * o.quantity);
    double avgExit  = totalVal / totalSold;
    return ((avgExit - avgPrice) / avgPrice) * 100;
  }

  double? get pnlVnd {
    if (sellOrders.isEmpty) return null;
    return sellOrders.fold<double>(0.0, (s, o) => s + (o.price - avgPrice) * o.quantity);
  }

  // AI review cache
  final String? aiReview;

  // ── Legacy compat getters (để trade_detail_screen khỏi lỗi) ─────────────
  double? get exitPrice    => sellOrders.isEmpty ? null : sellOrders.last.price;
  int?    get exitQuantity => sellOrders.isEmpty ? null : sellOrders.last.quantity;
  String? get exitReason   => sellOrders.isEmpty ? null : sellOrders.last.reason;
  DateTime? get exitDate   => sellOrders.isEmpty ? null : sellOrders.last.date;
  ExitType? get exitType   => sellOrders.isEmpty ? null : sellOrders.last.exitType;
  ExitEmotion? get exitEmotion => sellOrders.isEmpty ? null : sellOrders.last.exitEmotion;
  int get soldQuantity => totalSold;
  bool get isPartialExit => remainingQuantity > 0 && hasAnySell;

  const TradeLog({
    required this.id,
    required this.symbol,
    required this.tradeDate,
    required this.entryPrice,
    required this.entryQuantity,
    required this.entryReason,
    required this.pattern,
    this.addBuys     = const [],
    this.sellOrders  = const [],
    this.aiReview,
  });

  // ── Serialization ──────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id':            id,
    'symbol':        symbol,
    'tradeDate':     tradeDate.toIso8601String(),
    'entryPrice':    entryPrice,
    'entryQuantity': entryQuantity,
    'entryReason':   entryReason,
    'pattern':       pattern.name,
    'addBuys':       addBuys.map((b) => b.toJson()).toList(),
    'sellOrders':    sellOrders.map((s) => s.toJson()).toList(),
    'aiReview':      aiReview,
  };

  factory TradeLog.fromJson(Map<String, dynamic> json) {
    // ── Legacy migration: nếu JSON cũ có exitPrice → tạo SellOrder ──
    List<SellOrder> sells = [];
    if (json['sellOrders'] != null) {
      sells = (json['sellOrders'] as List)
          .map((e) => SellOrder.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (json['exitPrice'] != null) {
      // Migrate từ schema cũ
      sells = [
        SellOrder(
          price:      (json['exitPrice'] as num).toDouble(),
          quantity:   json['exitQuantity'] as int? ??
                      json['entryQuantity'] as int,
          reason:     json['exitReason'] as String?,
          date:       json['exitDate'] != null
                        ? DateTime.parse(json['exitDate'] as String)
                        : null,
          exitType:   json['exitType'] != null
                        ? ExitType.values.firstWhere(
                            (e) => e.name == json['exitType'],
                            orElse: () => ExitType.manualExit)
                        : null,
          exitEmotion: json['exitEmotion'] != null
                        ? ExitEmotion.values.firstWhere(
                            (e) => e.name == json['exitEmotion'],
                            orElse: () => ExitEmotion.calm)
                        : null,
        ),
      ];
    }

    List<AddBuy> addBuys = [];
    if (json['addBuys'] != null) {
      addBuys = (json['addBuys'] as List)
          .map((e) => AddBuy.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    return TradeLog(
      id:            json['id'] as String,
      symbol:        json['symbol'] as String,
      tradeDate:     DateTime.parse(json['tradeDate'] as String),
      entryPrice:    (json['entryPrice'] as num).toDouble(),
      entryQuantity: json['entryQuantity'] as int,
      entryReason:   json['entryReason'] as String,
      pattern:       TradePattern.values.firstWhere(
                       (e) => e.name == json['pattern'],
                       orElse: () => TradePattern.other,
                     ),
      addBuys:     addBuys,
      sellOrders:  sells,
      aiReview:    json['aiReview'] as String?,
    );
  }

  TradeLog copyWith({
    String?        id,
    String?        symbol,
    DateTime?      tradeDate,
    double?        entryPrice,
    int?           entryQuantity,
    String?        entryReason,
    TradePattern?  pattern,
    List<AddBuy>?  addBuys,
    List<SellOrder>? sellOrders,
    String?        aiReview,
  }) => TradeLog(
    id:            id            ?? this.id,
    symbol:        symbol        ?? this.symbol,
    tradeDate:     tradeDate     ?? this.tradeDate,
    entryPrice:    entryPrice    ?? this.entryPrice,
    entryQuantity: entryQuantity ?? this.entryQuantity,
    entryReason:   entryReason   ?? this.entryReason,
    pattern:       pattern       ?? this.pattern,
    addBuys:       addBuys       ?? this.addBuys,
    sellOrders:    sellOrders    ?? this.sellOrders,
    aiReview:      aiReview      ?? this.aiReview,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is TradeLog && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
