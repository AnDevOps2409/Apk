import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_quote.dart';

/// Service gọi API từ fdata_server.py chạy trên PC
class FDataService {
  final String baseUrl;

  FDataService(this.baseUrl);

  /// Kiểm tra kết nối server
  Future<bool> isAvailable() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/health'))
          .timeout(const Duration(seconds: 3));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Lấy danh sách bảng giá (tất cả mã hiện có trong 15m/stock)
  Future<List<StockQuote>> fetchQuotes({int limit = 300}) async {
    final uri = Uri.parse('$baseUrl/api/quotes?limit=$limit');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');

    final body = json.decode(utf8.decode(res.bodyBytes));
    final List<dynamic> raw = body['quotes'] ?? [];
    return raw.map((q) => _mapQuote(q)).toList();
  }

  /// Lấy candle data cho 1 mã theo timeframe
  Future<List<RawCandle>> fetchCandles(
    String symbol, {
    String timeframe = '15m',
    int limit = 300,
  }) async {
    final uri = Uri.parse(
        '$baseUrl/api/candles/$symbol?timeframe=$timeframe&limit=$limit');
    final res = await http.get(uri).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');

    final body = json.decode(utf8.decode(res.bodyBytes));
    final List<dynamic> raw = body['candles'] ?? [];
    return raw.map((c) => RawCandle.fromJson(c)).toList();
  }

  /// Lấy bid/ask orderbook 3 mức
  Future<OrderBook> fetchOrderbook(String symbol) async {
    final uri = Uri.parse('$baseUrl/api/orderbook/$symbol');
    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return OrderBook(symbol: symbol, bid: [], ask: []);
    final body = json.decode(utf8.decode(res.bodyBytes));
    return OrderBook.fromJson(body);
  }

  /// Lấy danh sách tick giao dịch gần nhất
  Future<List<TickData>> fetchTicks(String symbol, {int limit = 50}) async {
    final uri = Uri.parse('$baseUrl/api/ticks/$symbol?limit=$limit');
    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) return [];
    final body = json.decode(utf8.decode(res.bodyBytes));
    final List<dynamic> raw = body['ticks'] ?? [];
    return raw.map((t) => TickData.fromJson(t)).toList();
  }

  /// Lấy chỉ số thị trường
  Future<List<MarketIndex>> fetchIndices() async {
    final uri = Uri.parse('$baseUrl/api/indices');
    final res = await http.get(uri).timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');

    final body = json.decode(utf8.decode(res.bodyBytes));
    final List<dynamic> raw = body['indices'] ?? [];
    return raw.map((i) => _mapIndex(i)).toList();
  }

  StockQuote _mapQuote(Map<String, dynamic> q) {
    double n(String k, [double def = 0]) =>
        (q[k] as num?)?.toDouble() ?? def;
    final price  = n('price');
    final ref    = n('reference');
    final ceil   = n('ceiling',   price * 1.07);
    final floor  = n('floor',     price * 0.93);
    final change = n('change',    price - ref);
    final pct    = n('change_pct', ref > 0 ? (price - ref) / ref * 100 : 0);
    final vol    = (q['volume'] as num?)?.toInt() ?? 0;

    return StockQuote(
      symbol: q['symbol'] as String? ?? '',
      exchange: 'HOSE',
      reference: ref > 0 ? ref : price,
      ceiling:   ceil > 0 ? ceil : price * 1.07,
      floor:     floor > 0 ? floor : price * 0.93,
      open:      n('open',  price),
      high:      n('high',  price),
      low:       n('low',   price),
      price:     price,
      change:    change,
      changePercent: pct,
      volume:    vol,
      totalValue: (price * vol / 1000).round(),
      updatedAt: DateTime.now(),
    );
  }

  MarketIndex _mapIndex(Map<String, dynamic> i) {
    final value  = (i['price']  as num?)?.toDouble() ?? 0;
    final change = (i['change'] as num?)?.toDouble() ?? 0;
    final pct    = (i['change_pct'] as num?)?.toDouble() ?? 0;
    return MarketIndex(
      name: (i['name'] as String?) ?? (i['symbol'] as String),
      value: value,
      change: change,
      changePercent: pct,
      advances: 0,
      declines: 0,
      noChange: 0,
      totalVolume: 0,
      totalValue: 0,
      chartData: [value],
    );
  }
}

/// Candle data thô từ server (trước khi convert sang Candlesticks package format)
class RawCandle {
  final int date;     // YYYYMMDD
  final int time;     // HHMMSS
  final double open, high, low, close;
  final int volume;

  const RawCandle({
    required this.date, required this.time,
    required this.open, required this.high,
    required this.low,  required this.close,
    required this.volume,
  });

  factory RawCandle.fromJson(Map<String, dynamic> j) => RawCandle(
    date:   (j['date'] as num).toInt(),
    time:   (j['time'] as num).toInt(),
    open:   (j['open'] as num).toDouble(),
    high:   (j['high'] as num).toDouble(),
    low:    (j['low']  as num).toDouble(),
    close:  (j['close'] as num).toDouble(),
    volume: (j['volume'] as num).toInt(),
  );

  /// Convert sang DateTime để dùng với Candlesticks package
  DateTime get dateTime {
    final d = date;
    final t = time;
    return DateTime(
      d ~/ 10000,
      (d % 10000) ~/ 100,
      d % 100,
      t ~/ 10000,
      (t % 10000) ~/ 100,
      t % 100,
    );
  }
}

/// Một mức giá trong orderbook (Bid hoặc Ask)
class PriceLevel {
  final double price;
  final int qty;
  const PriceLevel({required this.price, required this.qty});
  factory PriceLevel.fromJson(Map<String, dynamic> j) => PriceLevel(
    price: (j['price'] as num).toDouble(),
    qty:   (j['qty']   as num).toInt(),
  );
}

/// Bid/Ask orderbook 3 mức từ DNSE realtime
class OrderBook {
  final String symbol;
  final List<PriceLevel> bid;
  final List<PriceLevel> ask;
  final int? totalBidQty;
  final int? totalAskQty;
  final int? updatedAt;

  const OrderBook({
    required this.symbol,
    required this.bid,
    required this.ask,
    this.totalBidQty,
    this.totalAskQty,
    this.updatedAt,
  });

  factory OrderBook.fromJson(Map<String, dynamic> j) => OrderBook(
    symbol:      j['symbol'] as String? ?? '',
    bid:         ((j['bid']  as List?) ?? []).map((e) => PriceLevel.fromJson(e as Map<String, dynamic>)).toList(),
    ask:         ((j['ask']  as List?) ?? []).map((e) => PriceLevel.fromJson(e as Map<String, dynamic>)).toList(),
    totalBidQty: (j['totalBidQty'] as num?)?.toInt(),
    totalAskQty: (j['totalAskQty'] as num?)?.toInt(),
    updatedAt:   (j['updatedAt']   as num?)?.toInt(),
  );

  bool get isEmpty => bid.isEmpty && ask.isEmpty;
}

/// Một tick giao dịch realtime
class TickData {
  final int time;
  final double price;
  final int qty;

  const TickData({required this.time, required this.price, required this.qty});

  factory TickData.fromJson(Map<String, dynamic> j) => TickData(
    time:  (j['time']  as num).toInt(),
    price: (j['price'] as num).toDouble(),
    qty:   (j['qty']   as num).toInt(),
  );
}
