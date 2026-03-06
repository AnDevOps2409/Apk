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
    final price  = (q['price']  as num).toDouble();
    final ref    = (q['reference'] as num).toDouble();
    final ceil   = (q['ceiling'] as num).toDouble();
    final floor  = (q['floor'] as num).toDouble();
    final change = (q['change'] as num).toDouble();
    final pct    = (q['change_pct'] as num).toDouble();
    final vol    = (q['volume'] as num).toInt();

    return StockQuote(
      symbol: q['symbol'] as String,
      exchange: 'HOSE',
      reference: ref,
      ceiling: ceil,
      floor: floor,
      open: (q['open'] as num).toDouble(),
      high: (q['high'] as num).toDouble(),
      low: (q['low'] as num).toDouble(),
      price: price,
      change: change,
      changePercent: pct,
      volume: vol,
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
