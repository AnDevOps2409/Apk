import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:candlesticks/candlesticks.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/models/stock_quote.dart';

class ChartScreen extends ConsumerStatefulWidget {
  final String symbol;
  const ChartScreen({super.key, required this.symbol});

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  bool _splitView = false;
  String _secondSymbol = '';
  String _timeframe = '1D';
  List<Candle> _candles = [];
  List<Candle> _candles2 = [];

  static const _timeframes = ['1p', '5p', '15p', '1h', '1D', '1W'];

  @override
  void initState() {
    super.initState();
    _candles = _generateCandles(widget.symbol);
  }

  List<Candle> _generateCandles(String symbol) {
    final seed = symbol.codeUnits.reduce((a, b) => a + b);
    final rng = seed % 100;
    final now = DateTime.now();
    final candles = <Candle>[];
    double price = 40 + (rng % 100);
    for (int i = 200; i >= 0; i--) {
      final open = price;
      final change = (rng % 5 == 0 ? -1 : 1) * (1 + (i % 3) * 0.5);
      final close = (open + change).clamp(10.0, 200.0);
      final high = [open, close].reduce((a, b) => a > b ? a : b) + 0.5 + (i % 2);
      final low = [open, close].reduce((a, b) => a < b ? a : b) - 0.5 - (i % 2);
      candles.add(Candle(
        date: now.subtract(Duration(days: i)),
        high: high,
        low: low,
        open: open,
        close: close,
        volume: 500000 + (i * 10000),
      ));
      price = close;
    }
    return candles;
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(priceBoardProvider);
    StockQuote? quote;
    boardAsync.whenData((quotes) {
      try {
        quote = quotes.firstWhere((q) => q.symbol == widget.symbol);
      } catch (_) {}
    });

    final priceColor = quote == null
        ? AppColors.textPrimary
        : (quote!.isUp ? AppColors.increase : quote!.isDown ? AppColors.decrease : AppColors.reference);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Text(
              widget.symbol,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            if (quote != null) ...[
              const SizedBox(width: 12),
              Text(
                quote!.priceStr,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: priceColor),
              ),
              const SizedBox(width: 8),
              Text(
                quote!.changePctStr,
                style: TextStyle(fontSize: 12, color: priceColor),
              ),
            ],
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => context.pop(),
        ),
        actions: [
          // Toggle split view
          IconButton(
            icon: Icon(
              _splitView ? Icons.view_agenda_rounded : Icons.vertical_split_rounded,
              color: _splitView ? AppColors.accent : null,
              size: 20,
            ),
            tooltip: 'Split view',
            onPressed: () => _toggleSplitView(boardAsync),
          ),
          // Watchlist toggle
          Consumer(builder: (context2, ref2, child2) {
            final inWatchlist = ref2.watch(watchlistProvider).contains(widget.symbol);
            return IconButton(
              icon: Icon(
                inWatchlist ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: inWatchlist ? AppColors.accent : null,
                size: 20,
              ),
              onPressed: () {
                final notifier = ref2.read(watchlistProvider.notifier);
                if (inWatchlist) {
                  notifier.remove(widget.symbol);
                } else {
                  notifier.add(widget.symbol);
                }
              },
            );
          }),
        ],
      ),
      body: Column(
        children: [
          // Timeframe selector
          _TimeframeBar(
            selected: _timeframe,
            onSelect: (tf) => setState(() => _timeframe = tf),
            timeframes: _timeframes,
          ),
          // Chart area
          Expanded(
            child: _splitView
                ? Column(
                    children: [
                      Expanded(child: _ChartPanel(symbol: widget.symbol, candles: _candles)),
                      Container(height: 0.5, color: AppColors.border),
                      _SplitSymbolBar(
                        selected: _secondSymbol,
                        allSymbols: boardAsync.valueOrNull?.map((q) => q.symbol).toList() ?? [],
                        onSelect: (sym) => setState(() {
                          _secondSymbol = sym;
                          _candles2 = _generateCandles(sym);
                        }),
                      ),
                      Expanded(
                        child: _secondSymbol.isEmpty
                            ? const Center(
                                child: Text(
                                  'Chọn mã CK thứ 2',
                                  style: TextStyle(color: AppColors.textSecondary),
                                ),
                              )
                            : _ChartPanel(symbol: _secondSymbol, candles: _candles2),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: _ChartPanel(symbol: widget.symbol, candles: _candles)),
                      if (quote != null) _QuoteDetailBar(quote: quote!),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  void _toggleSplitView(AsyncValue<List<StockQuote>> boardAsync) {
    setState(() {
      _splitView = !_splitView;
      if (_splitView && _secondSymbol.isEmpty) {
        // Chọn mã khác mặc định
        final others = boardAsync.valueOrNull
            ?.where((q) => q.symbol != widget.symbol)
            .toList() ?? [];
        if (others.isNotEmpty) {
          _secondSymbol = others.first.symbol;
          _candles2 = _generateCandles(_secondSymbol);
        }
      }
    });
  }
}

// ─── Chart Panel ─────────────────────────────────────────────────────────────

class _ChartPanel extends StatelessWidget {
  final String symbol;
  final List<Candle> candles;
  const _ChartPanel({required this.symbol, required this.candles});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Candlesticks(candles: candles),
        Positioned(
          top: 8, left: 12,
          child: Text(
            symbol,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Quote Detail Bar ────────────────────────────────────────────────────────

class _QuoteDetailBar extends StatelessWidget {
  final StockQuote quote;
  const _QuoteDetailBar({required this.quote});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          infoItem('Tham chiếu', quote.reference.toStringAsFixed(2), AppColors.reference),
          infoItem('Trần', quote.ceiling.toStringAsFixed(2), AppColors.ceiling),
          infoItem('Sàn', quote.floor.toStringAsFixed(2), AppColors.floor),
          infoItem('KL', quote.volumeStr, AppColors.textSecondary),
          infoItem('GT', quote.totalValueStr, AppColors.textSecondary),
        ],
      ),
    );
  }

  Widget infoItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ─── Timeframe Bar ───────────────────────────────────────────────────────────

class _TimeframeBar extends StatelessWidget {
  final String selected;
  final List<String> timeframes;
  final ValueChanged<String> onSelect;
  const _TimeframeBar({required this.selected, required this.timeframes, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: timeframes.map((tf) {
          final active = tf == selected;
          return GestureDetector(
            onTap: () => onSelect(tf),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? AppColors.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tf,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                  color: active ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Split Symbol Selector ───────────────────────────────────────────────────

class _SplitSymbolBar extends StatelessWidget {
  final String selected;
  final List<String> allSymbols;
  final ValueChanged<String> onSelect;
  const _SplitSymbolBar({required this.selected, required this.allSymbols, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          const Text('So sánh:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: allSymbols.map((sym) {
                  final active = sym == selected;
                  return GestureDetector(
                    onTap: () => onSelect(sym),
                    child: Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: active ? AppColors.accent.withValues(alpha: 0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: active ? AppColors.accent : AppColors.border,
                          width: 0.5,
                        ),
                      ),
                      child: Text(
                        sym,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                          color: active ? AppColors.accent : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
