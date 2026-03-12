import 'dart:math';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stock_quote.dart';

/// Service cung cấp mock data (dự phòng khi fdata_server không chạy)
class MockDataService {
  static final _rng = Random();

  /// Gọi TradingView Scanner API để lấy giá EOD siêu nhanh
  static Future<StockQuote?> fetchEodQuote(String symbol) async {
    try {
      final symUP = symbol.toUpperCase().trim();
      final rs = await http.post(
        Uri.parse('https://scanner.tradingview.com/vietnam/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "symbols": {"tickers": ["HOSE:$symUP", "HNX:$symUP", "UPCOM:$symUP"]},
          "columns": ["close", "change", "change_abs", "high", "low", "open", "volume"]
        })
      );
      if (rs.statusCode == 200) {
        final body = jsonDecode(rs.body);
        final list = body['data'] as List?;
        if (list != null && list.isNotEmpty) {
          final sData = list[0];
          final exch = (sData['s'] as String).split(':').first;
          final d = sData['d'] as List; // 0:close, 1:change, 2:chAbs, 3:high, 4:low, 5:open, 6:vol
          
          final close = (d[0] as num).toDouble();
          final changePct = (d[1] as num).toDouble();
          final changeAbs = (d[2] as num).toDouble();
          final high = (d[3] as num).toDouble();
          final low = (d[4] as num).toDouble();
          final open = (d[5] as num).toDouble();
          final vol = (d[6] as num).toInt();
          
          final ref = close - changeAbs;
          double limit = 0.07;
          if (exch == 'HNX') limit = 0.1;
          if (exch == 'UPCOM') limit = 0.15;

          return StockQuote(
            symbol: symUP,
            exchange: exch,
            reference: double.parse(ref.toStringAsFixed(1)),
            ceiling: double.parse((ref * (1 + limit)).toStringAsFixed(1)),
            floor: double.parse((ref * (1 - limit)).toStringAsFixed(1)),
            open: open, high: high, low: low, price: close,
            change: changeAbs, changePercent: changePct,
            volume: vol,
            totalValue: (close * vol / 1000).round(),
            buy1: double.parse((close - 0.1).clamp(0, 9999).toStringAsFixed(1)), buyVol1: 0, 
            buy2: double.parse((close - 0.2).clamp(0, 9999).toStringAsFixed(1)), buyVol2: 0, 
            buy3: double.parse((close - 0.3).clamp(0, 9999).toStringAsFixed(1)), buyVol3: 0,
            sell1: double.parse((close + 0.1).clamp(0, 9999).toStringAsFixed(1)), sellVol1: 0, 
            sell2: double.parse((close + 0.2).clamp(0, 9999).toStringAsFixed(1)), sellVol2: 0, 
            sell3: double.parse((close + 0.3).clamp(0, 9999).toStringAsFixed(1)), sellVol3: 0,
            updatedAt: DateTime.now(),
          );
        }
      }
    } catch (_) {}
    return null;
  }

  /// Gọi TradingView Scanner API lấy D/S mã cùng lúc (Batch request)
  static Future<List<StockQuote>> fetchEodQuotes(List<String> symbols) async {
    try {
      if (symbols.isEmpty) return [];

      final tickers = <String>[];
      for (final sym in symbols) {
        final symUP = sym.toUpperCase().trim();
        tickers.addAll(["HOSE:$symUP", "HNX:$symUP", "UPCOM:$symUP"]);
      }

      final rs = await http.post(
        Uri.parse('https://scanner.tradingview.com/vietnam/scan'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "symbols": {"tickers": tickers},
          "columns": ["close", "change", "change_abs", "high", "low", "open", "volume"]
        })
      );

      final results = <StockQuote>[];
      if (rs.statusCode == 200) {
        final body = jsonDecode(rs.body);
        final list = body['data'] as List?;
        if (list != null && list.isNotEmpty) {
          for (final sData in list) {
            final exch = (sData['s'] as String).split(':').first;
            final symbol = (sData['s'] as String).split(':').last;
            final d = sData['d'] as List; 
            
            final close = (d[0] as num).toDouble();
            final changePct = (d[1] as num).toDouble();
            final changeAbs = (d[2] as num).toDouble();
            final high = (d[3] as num).toDouble();
            final low = (d[4] as num).toDouble();
            final open = (d[5] as num).toDouble();
            final vol = (d[6] as num).toInt();
            
            final ref = close - changeAbs;
            double limit = 0.07;
            if (exch == 'HNX') limit = 0.1;
            if (exch == 'UPCOM') limit = 0.15;

            results.add(StockQuote(
              symbol: symbol,
              exchange: exch,
              reference: double.parse(ref.toStringAsFixed(1)),
              ceiling: double.parse((ref * (1 + limit)).toStringAsFixed(1)),
              floor: double.parse((ref * (1 - limit)).toStringAsFixed(1)),
              open: open, high: high, low: low, price: close,
              change: changeAbs, changePercent: changePct,
              volume: vol,
              totalValue: (close * vol / 1000).round(),
              buy1: double.parse((close - 0.1).clamp(0, 9999).toStringAsFixed(1)), buyVol1: 0, 
              buy2: double.parse((close - 0.2).clamp(0, 9999).toStringAsFixed(1)), buyVol2: 0, 
              buy3: double.parse((close - 0.3).clamp(0, 9999).toStringAsFixed(1)), buyVol3: 0,
              sell1: double.parse((close + 0.1).clamp(0, 9999).toStringAsFixed(1)), sellVol1: 0, 
              sell2: double.parse((close + 0.2).clamp(0, 9999).toStringAsFixed(1)), sellVol2: 0, 
              sell3: double.parse((close + 0.3).clamp(0, 9999).toStringAsFixed(1)), sellVol3: 0,
              updatedAt: DateTime.now(),
            ));
          }
        }
      }
      return results;
    } catch (_) {}
    return [];
  }

  static List<StockQuote> generatePriceBoard() {
    final stocks = [
      _makeStock('VCB', 'HOSE', 87.1, 'Vietcombank'),
      _makeStock('BID', 'HOSE', 44.5, 'BIDV'),
      _makeStock('CTG', 'HOSE', 34.2, 'VietinBank'),
      _makeStock('HPG', 'HOSE', 26.8, 'Tập đoàn Hòa Phát'),
      _makeStock('VHM', 'HOSE', 38.4, 'Vinhomes'),
      _makeStock('VIC', 'HOSE', 42.3, 'Vingroup'),
      _makeStock('MSN', 'HOSE', 58.7, 'Masan Group'),
      _makeStock('TCB', 'HOSE', 22.1, 'Techcombank'),
      _makeStock('MBB', 'HOSE', 23.4, 'MB Bank'),
      _makeStock('ACB', 'HOSE', 28.6, 'ACB'),
      _makeStock('STB', 'HOSE', 35.5, 'Sacombank'),
      _makeStock('SSI', 'HOSE', 30.2, 'SSI Securities'),
      _makeStock('VND', 'HOSE', 16.8, 'VNDirect'),
      _makeStock('FPT', 'HOSE', 135.0, 'FPT Corp'),
      _makeStock('MWG', 'HOSE', 48.2, 'Mobile World'),
      _makeStock('DGC', 'HOSE', 62.3, 'Đức Giang Chemicals'),
      _makeStock('PVD', 'HOSE', 18.9, 'PV Drilling'),
      _makeStock('GAS', 'HOSE', 71.5, 'PetroVietnam Gas'),
      _makeStock('PLX', 'HOSE', 32.1, 'Petrolimex'),
      _makeStock('PNJ', 'HOSE', 98.5, 'Phú Nhuận Jewelry'),
    ];
    return stocks;
  }

  static StockQuote _makeStock(String symbol, String exchange, double ref, String name) {
    final ceiling = double.parse((ref * 1.07).toStringAsFixed(1));
    final floor = double.parse((ref * 0.93).toStringAsFixed(1));
    final changePct = (_rng.nextDouble() * 14) - 7; // -7% to +7%
    final change = double.parse((ref * changePct / 100).toStringAsFixed(1));
    double price = double.parse((ref + change).toStringAsFixed(1));

    // Clamp trong range sàn-trần
    price = price.clamp(floor, ceiling);
    final actualChange = double.parse((price - ref).toStringAsFixed(1));
    final actualChangePct = double.parse((actualChange / ref * 100).toStringAsFixed(2));

    final volume = (_rng.nextInt(10000000) + 500000);
    final totalValue = (price * volume / 1000).round();

    return StockQuote(
      symbol: symbol,
      exchange: exchange,
      reference: ref,
      ceiling: ceiling,
      floor: floor,
      open: double.parse((ref + (_rng.nextDouble() * 2 - 1)).toStringAsFixed(1)),
      high: double.parse((price + _rng.nextDouble() * 0.5).toStringAsFixed(1)).clamp(price, ceiling),
      low: double.parse((price - _rng.nextDouble() * 0.5).toStringAsFixed(1)).clamp(floor, price),
      price: price,
      change: actualChange,
      changePercent: actualChangePct,
      volume: volume,
      totalValue: totalValue,
      buy1: double.parse((price - 0.1).toStringAsFixed(1)).clamp(floor, price),
      buyVol1: _rng.nextInt(100000) + 10000,
      buy2: double.parse((price - 0.2).toStringAsFixed(1)).clamp(floor, price),
      buyVol2: _rng.nextInt(80000) + 5000,
      buy3: double.parse((price - 0.3).toStringAsFixed(1)).clamp(floor, price),
      buyVol3: _rng.nextInt(60000) + 3000,
      sell1: double.parse((price + 0.1).toStringAsFixed(1)).clamp(price, ceiling),
      sellVol1: _rng.nextInt(100000) + 10000,
      sell2: double.parse((price + 0.2).toStringAsFixed(1)).clamp(price, ceiling),
      sellVol2: _rng.nextInt(80000) + 5000,
      sell3: double.parse((price + 0.3).toStringAsFixed(1)).clamp(price, ceiling),
      sellVol3: _rng.nextInt(60000) + 3000,
      companyName: name,
      updatedAt: DateTime.now(),
    );
  }

  static List<MarketIndex> generateMarketIndices() {
    return [
      _makeIndex('VN-Index', 1285.34, 1.23),
      _makeIndex('HNX-Index', 237.48, -0.45),
      _makeIndex('UPCOM', 95.12, 0.08),
    ];
  }

  static MarketIndex _makeIndex(String name, double value, double pct) {
    final change = double.parse((value * pct / 100).toStringAsFixed(2));
    final total = 400 + _rng.nextInt(200);
    final advances = (total * (0.4 + _rng.nextDouble() * 0.2)).round();
    final declines = (total * (0.2 + _rng.nextDouble() * 0.2)).round();

    // Generate mini chart data (30 điểm trong ngày)
    final chartData = <double>[];
    double v = value - change;
    for (int i = 0; i < 30; i++) {
      v += (_rng.nextDouble() - 0.48) * (value * 0.002);
      chartData.add(double.parse(v.toStringAsFixed(2)));
    }
    chartData.add(value);

    return MarketIndex(
      name: name,
      value: value,
      change: change,
      changePercent: pct,
      advances: advances,
      declines: declines,
      noChange: total - advances - declines,
      totalVolume: 250 + _rng.nextDouble() * 150,
      totalValue: 8000 + _rng.nextDouble() * 4000,
      chartData: chartData,
    );
  }
}
