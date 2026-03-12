import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/stock_quote.dart';
import '../models/data_source.dart';
import '../services/mock_data_service.dart';
import '../services/fdata_service.dart';
import '../services/firebase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Core Services ──────────────────────────────────────────────────────────

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider not initialized');
});

// ─── Data Source Config ─────────────────────────────────────────────────────

final dataSourceModeProvider = StateProvider<DataSourceMode>((ref) {
  return DataSourceMode.realtime; // Default: realtime (DNSE)
});

/// Kiểm tra có đang trong giờ giao dịch không (08:30-11:30, 13:00-15:00 ICT)
bool isMarketOpen() {
  final now = DateTime.now();
  // Thứ 2-6 (weekday 1-5)
  if (now.weekday > 5) return false;
  final hm = now.hour * 60 + now.minute;
  return (hm >= 8 * 60 + 30 && hm < 11 * 60 + 30) ||
         (hm >= 13 * 60 && hm < 15 * 60);
}

final serverIpProvider = StateProvider<String>((ref) {
  return 'http://192.168.1.15:8765'; // User tự chỉnh trong Settings
});

final fdataServiceProvider = Provider<FDataService>((ref) {
  final ip = ref.watch(serverIpProvider);
  return FDataService(ip);
});

final serverStatusProvider = FutureProvider.autoDispose<bool>((ref) async {
  final svc = ref.watch(fdataServiceProvider);
  return svc.isAvailable();
});

// ─── Price Board Provider ───────────────────────────────────────────────────

final priceBoardProvider =
    StateNotifierProvider<PriceBoardNotifier, AsyncValue<List<StockQuote>>>((ref) {
  final mode = ref.watch(dataSourceModeProvider);
  final svc  = ref.watch(fdataServiceProvider);
  return PriceBoardNotifier(mode: mode, fdataService: svc);
});

class PriceBoardNotifier extends StateNotifier<AsyncValue<List<StockQuote>>> {
  final DataSourceMode mode;
  final FDataService fdataService;

  PriceBoardNotifier({required this.mode, required this.fdataService})
      : super(const AsyncValue.loading()) {
    _init();
  }

  Timer? _refreshTimer;
  List<StockQuote> _quotes = [];
  bool _serverAvailable = false;

  void _init() async {
    // Bước 1: thử kết nối server
    _serverAvailable = await fdataService.isAvailable();

    if (_serverAvailable) {
      await _loadFromServer();
      _scheduleSmartRefresh();
    } else {
      // Fallback mock khi server chưa chạy
      _loadMock();
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _simulateTick());
      // Thử lại kết nối mỗi 10s
      Timer.periodic(const Duration(seconds: 10), (t) async {
        if (!mounted) { t.cancel(); return; }
        _serverAvailable = await fdataService.isAvailable();
        if (_serverAvailable) {
          t.cancel();
          _refreshTimer?.cancel();
          await _loadFromServer();
          _scheduleSmartRefresh();
        }
      });
    }
  }

  /// Poll thông minh: 5s trong giờ GD, 60s ngoài giờ
  void _scheduleSmartRefresh() {
    _refreshTimer?.cancel();
    final interval = isMarketOpen()
        ? const Duration(seconds: 5)
        : const Duration(seconds: 60);
    _refreshTimer = Timer.periodic(interval, (_) async {
      await _loadFromServer();
      // Khi giờ GD thay đổi → reschedule
      final newInterval = isMarketOpen()
          ? const Duration(seconds: 5)
          : const Duration(seconds: 60);
      if (newInterval != interval) _scheduleSmartRefresh();
    });
  }

  Future<void> _loadFromServer() async {
    try {
      final quotes = await fdataService.fetchQuotes(limit: 500);
      if (quotes.isEmpty) return; // server chưa có data, giữ nguyên
      _quotes = quotes;
      state = AsyncValue.data(List.from(_quotes));
    } catch (e, st) {
      if (_quotes.isEmpty) state = AsyncValue.error(e, st);
      // Có data cũ → giữ nguyên, không báo lỗi
    }
  }

  void _loadMock() {
    Future.delayed(const Duration(milliseconds: 400), () {
      _quotes = MockDataService.generatePriceBoard();
      state = AsyncValue.data(List.from(_quotes));
    });
  }

  void _simulateTick() {
    if (_quotes.isEmpty) return;
    final fresh = MockDataService.generatePriceBoard();
    final newQuotes = List<StockQuote>.from(_quotes);
    final count = 3 + (DateTime.now().millisecond % 3);
    for (int i = 0; i < count && i < fresh.length; i++) {
      final idx = (DateTime.now().millisecondsSinceEpoch + i * 7) % fresh.length;
      final freshQuote = fresh[idx];
      final existingIdx = newQuotes.indexWhere((q) => q.symbol == freshQuote.symbol);
      if (existingIdx != -1) newQuotes[existingIdx] = freshQuote;
    }
    _quotes = newQuotes;
    state = AsyncValue.data(List.from(_quotes));
  }

  void refresh() => _serverAvailable ? _loadFromServer() : _loadMock();

  void sortBy(SortField field, {bool ascending = true}) {
    if (_quotes.isEmpty) return;
    final sorted = List<StockQuote>.from(_quotes)
      ..sort((a, b) {
        int cmp;
        switch (field) {
          case SortField.symbol: cmp = a.symbol.compareTo(b.symbol);
          case SortField.price:  cmp = a.price.compareTo(b.price);
          case SortField.change: cmp = a.changePercent.compareTo(b.changePercent);
          case SortField.volume: cmp = a.volume.compareTo(b.volume);
        }
        return ascending ? cmp : -cmp;
      });
    _quotes = sorted;
    state = AsyncValue.data(List.from(_quotes));
  }

  /// Đảm bảo symbol có trong danh sách (fetch từ server nếu cần)
  Future<void> requireSymbol(String symbol) async {
    final sym = symbol.toUpperCase().trim();
    if (_quotes.any((q) => q.symbol == sym)) return;

    if (_serverAvailable) {
      // Gọi riêng EOD candle 1 nến để lấy giá
      try {
        final candles = await fdataService.fetchCandles(sym, timeframe: '1D', limit: 1);
        if (candles.isNotEmpty) {
          final c = candles.last;
          final q = StockQuote(
            symbol: sym, exchange: 'HOSE',
            reference: c.close, ceiling: c.close * 1.07, floor: c.close * 0.93,
            open: c.open, high: c.high, low: c.low,
            price: c.close, change: 0, changePercent: 0,
            volume: c.volume, totalValue: 0, updatedAt: DateTime.now(),
          );
          if (!_quotes.any((q) => q.symbol == sym)) {
            _quotes.add(q);
            state = AsyncValue.data(List.from(_quotes));
          }
        }
      } catch (_) {}
    } else {
      final quote = await MockDataService.fetchEodQuote(sym);
      if (quote != null && !_quotes.any((q) => q.symbol == sym)) {
        _quotes.add(quote);
        _simulateTick();
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

enum SortField { symbol, price, change, volume }

// ─── Market Index Provider ──────────────────────────────────────────────────

final marketIndexProvider =
    StateNotifierProvider<MarketIndexNotifier, AsyncValue<List<MarketIndex>>>((ref) {
  final mode = ref.watch(dataSourceModeProvider);
  final svc  = ref.watch(fdataServiceProvider);
  return MarketIndexNotifier(mode: mode, fdataService: svc);
});

class MarketIndexNotifier extends StateNotifier<AsyncValue<List<MarketIndex>>> {
  final DataSourceMode mode;
  final FDataService fdataService;

  MarketIndexNotifier({required this.mode, required this.fdataService})
      : super(const AsyncValue.loading()) {
    _init();
  }

  Timer? _timer;

  void _init() async {
    final ok = await fdataService.isAvailable();
    if (ok) {
      await _loadFData();
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadFData());
    } else {
      state = AsyncValue.data(MockDataService.generateMarketIndices());
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        state = AsyncValue.data(MockDataService.generateMarketIndices());
      });
    }
  }

  Future<void> _loadFData() async {
    try {
      final indices = await fdataService.fetchIndices();
      if (indices.isNotEmpty) state = AsyncValue.data(indices);
    } catch (e, st) {
      if (state is! AsyncData) state = AsyncValue.error(e, st);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ─── Candle Provider (FData aware) ──────────────────────────────────────────

final candleProvider = FutureProvider.autoDispose.family<List<RawCandle>, CandleArgs>((ref, args) async {
  final mode = ref.watch(dataSourceModeProvider);
  final svc  = ref.watch(fdataServiceProvider);

  if (mode == DataSourceMode.fdata) {
    return svc.fetchCandles(args.symbol, timeframe: args.timeframe, limit: 300);
  } else {
    // Mock candles: trả async empty, chart_screen dùng generated data
    return [];
  }
});

class CandleArgs {
  final String symbol;
  final String timeframe;
  const CandleArgs(this.symbol, this.timeframe);

  @override
  bool operator ==(Object other) =>
      other is CandleArgs && other.symbol == symbol && other.timeframe == timeframe;
  @override
  int get hashCode => Object.hash(symbol, timeframe);
}

// ─── Watchlist Provider ─────────────────────────────────────────────────────

final watchlistProvider = StateNotifierProvider<WatchlistNotifier, List<String>>((ref) {
  return WatchlistNotifier();
});

class WatchlistNotifier extends StateNotifier<List<String>> {
  static const _defaultWatchlist = ['VCB', 'HPG', 'FPT', 'MBB'];

  DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseService.instance.watchlistRef;

  WatchlistNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    try {
      final snap = await _doc.get(const GetOptions(source: Source.serverAndCache));
      if (snap.exists && snap.data() != null) {
        final symbols = List<String>.from(snap.data()!['symbols'] as List? ?? []);
        state = symbols.isNotEmpty ? symbols : _defaultWatchlist;
      } else {
        state = _defaultWatchlist;
        await _persist(_defaultWatchlist);
      }
    } catch (_) {
      // Fallback cache khi offline
      try {
        final snap = await _doc.get(const GetOptions(source: Source.cache));
        if (snap.exists && snap.data() != null) {
          final symbols = List<String>.from(snap.data()!['symbols'] as List? ?? []);
          state = symbols.isNotEmpty ? symbols : _defaultWatchlist;
          return;
        }
      } catch (_) {}
      state = _defaultWatchlist;
    }
  }

  void add(String symbol) {
    if (!state.contains(symbol)) {
      final next = [...state, symbol];
      state = next;
      _persist(next);
    }
  }

  void remove(String symbol) {
    final next = state.where((s) => s != symbol).toList();
    state = next;
    _persist(next);
  }

  bool contains(String symbol) => state.contains(symbol);

  Future<void> _persist(List<String> symbols) async {
    await _doc.set({'symbols': symbols});
  }
}

final watchlistQuotesProvider = FutureProvider.autoDispose<List<StockQuote>>((ref) async {
  final watchlist = ref.watch(watchlistProvider);
  if (watchlist.isEmpty) return [];
  // Lấy giá EOD realtime từ TradingView thay vì dùng mock data
  return MockDataService.fetchEodQuotes(watchlist);
});

// ─── Selected Symbol ────────────────────────────────────────────────────────

final selectedSymbolProvider = StateProvider<String?>((ref) => null);
