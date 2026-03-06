import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_quote.dart';
import '../models/data_source.dart';
import '../services/mock_data_service.dart';
import '../services/fdata_service.dart';

// ─── Data Source Config ─────────────────────────────────────────────────────

final dataSourceModeProvider = StateProvider<DataSourceMode>((ref) {
  return DataSourceMode.realtime; // Default: mock
});

final serverIpProvider = StateProvider<String>((ref) {
  return 'http://192.168.1.100:8765'; // User tự chỉnh trong Settings
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

  void _init() async {
    if (mode == DataSourceMode.fdata) {
      await _loadFData();
      // FData: refresh mỗi 30s (server không push, phải poll)
      _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadFData());
    } else {
      _loadMock();
      // Mock: simulate ticks mỗi 3s
      _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) => _simulateTick());
    }
  }

  Future<void> _loadFData() async {
    try {
      state = const AsyncValue.loading();
      _quotes = await fdataService.fetchQuotes(limit: 300);
      state = AsyncValue.data(List.from(_quotes));
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
      final idx = (DateTime.now().millisecondsSinceEpoch + i * 7) % _quotes.length;
      if (idx < fresh.length) newQuotes[idx] = fresh[idx];
    }
    _quotes = newQuotes;
    state = AsyncValue.data(List.from(_quotes));
  }

  void refresh() {
    if (mode == DataSourceMode.fdata) {
      _loadFData();
    } else {
      _loadMock();
    }
  }

  void sortBy(SortField field, {bool ascending = true}) {
    if (_quotes.isEmpty) return;
    final sorted = List<StockQuote>.from(_quotes);
    sorted.sort((a, b) {
      int cmp;
      switch (field) {
        case SortField.symbol:   cmp = a.symbol.compareTo(b.symbol);
        case SortField.price:    cmp = a.price.compareTo(b.price);
        case SortField.change:   cmp = a.changePercent.compareTo(b.changePercent);
        case SortField.volume:   cmp = a.volume.compareTo(b.volume);
      }
      return ascending ? cmp : -cmp;
    });
    _quotes = sorted;
    state = AsyncValue.data(List.from(_quotes));
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
    if (mode == DataSourceMode.fdata) {
      await _loadFData();
      _timer = Timer.periodic(const Duration(seconds: 60), (_) => _loadFData());
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
      state = AsyncValue.data(indices);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
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
  WatchlistNotifier() : super(['VCB', 'HPG', 'FPT', 'MBB']);

  void add(String symbol) {
    if (!state.contains(symbol)) state = [...state, symbol];
  }

  void remove(String symbol) {
    state = state.where((s) => s != symbol).toList();
  }

  bool contains(String symbol) => state.contains(symbol);
}

// ─── Selected Symbol ────────────────────────────────────────────────────────

final selectedSymbolProvider = StateProvider<String?>((ref) => null);
