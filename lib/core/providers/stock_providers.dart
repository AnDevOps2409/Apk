import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stock_quote.dart';
import '../services/mock_data_service.dart';

// ─── Price Board Provider ───────────────────────────────────────────────────

final priceBoardProvider =
    StateNotifierProvider<PriceBoardNotifier, AsyncValue<List<StockQuote>>>((ref) {
  return PriceBoardNotifier();
});

class PriceBoardNotifier extends StateNotifier<AsyncValue<List<StockQuote>>> {
  PriceBoardNotifier() : super(const AsyncValue.loading()) {
    _init();
  }

  Timer? _refreshTimer;
  List<StockQuote> _quotes = [];

  void _init() {
    // Giả lập load data
    Future.delayed(const Duration(milliseconds: 500), () {
      _quotes = MockDataService.generatePriceBoard();
      state = AsyncValue.data(List.from(_quotes));
      // Simulate real-time updates mỗi 3 giây
      _startSimulation();
    });
  }

  void _startSimulation() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _simulateTick();
    });
  }

  void _simulateTick() {
    if (_quotes.isEmpty) return;
    // Chỉ update ngẫu nhiên 3-5 mã mỗi tick để giống real
    final rng = MockDataService.generatePriceBoard();
    final updateCount = 3 + (DateTime.now().millisecond % 3);
    final newQuotes = List<StockQuote>.from(_quotes);

    for (int i = 0; i < updateCount && i < rng.length; i++) {
      final idx = (DateTime.now().millisecondsSinceEpoch + i * 7) % _quotes.length;
      newQuotes[idx] = rng[idx];
    }
    _quotes = newQuotes;
    state = AsyncValue.data(List.from(_quotes));
  }

  void refresh() {
    state = const AsyncValue.loading();
    _quotes = MockDataService.generatePriceBoard();
    state = AsyncValue.data(List.from(_quotes));
  }

  void sortBy(SortField field, {bool ascending = true}) {
    if (_quotes.isEmpty) return;
    final sorted = List<StockQuote>.from(_quotes);
    sorted.sort((a, b) {
      int cmp;
      switch (field) {
        case SortField.symbol:
          cmp = a.symbol.compareTo(b.symbol);
        case SortField.price:
          cmp = a.price.compareTo(b.price);
        case SortField.change:
          cmp = a.changePercent.compareTo(b.changePercent);
        case SortField.volume:
          cmp = a.volume.compareTo(b.volume);
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
    StateNotifierProvider<MarketIndexNotifier, List<MarketIndex>>((ref) {
  return MarketIndexNotifier();
});

class MarketIndexNotifier extends StateNotifier<List<MarketIndex>> {
  MarketIndexNotifier() : super(MockDataService.generateMarketIndices()) {
    _startSimulation();
  }

  Timer? _timer;

  void _startSimulation() {
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      state = MockDataService.generateMarketIndices();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// ─── Watchlist Provider ─────────────────────────────────────────────────────

final watchlistProvider = StateNotifierProvider<WatchlistNotifier, List<String>>((ref) {
  return WatchlistNotifier();
});

class WatchlistNotifier extends StateNotifier<List<String>> {
  WatchlistNotifier() : super(['VCB', 'HPG', 'FPT', 'MBB']);

  void add(String symbol) {
    if (!state.contains(symbol)) {
      state = [...state, symbol];
    }
  }

  void remove(String symbol) {
    state = state.where((s) => s != symbol).toList();
  }

  bool contains(String symbol) => state.contains(symbol);
}

// ─── Selected Stock Provider (để navigate sang chart) ──────────────────────

final selectedSymbolProvider = StateProvider<String?>((ref) => null);
