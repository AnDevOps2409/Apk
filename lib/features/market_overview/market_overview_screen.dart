import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/stock_quote.dart';
import '../../core/providers/stock_providers.dart';

class MarketOverviewScreen extends ConsumerWidget {
  const MarketOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final indicesAsync = ref.watch(marketIndexProvider);
    final boardAsync   = ref.watch(priceBoardProvider);
    final indices      = indicesAsync.valueOrNull ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Tổng quan thị trường'),
        actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Builder(builder: (ctx) {
            final open = isMarketOpen();
            return Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: open ? AppColors.increase : AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  open ? 'Đang mở cửa' : 'Đã đóng cửa',
                  style: TextStyle(
                    fontSize: 11,
                    color: open ? AppColors.increase : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          }),
        ),
      ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async {
          ref.read(priceBoardProvider.notifier).refresh();
          await Future.delayed(const Duration(milliseconds: 800));
        },
        child: CustomScrollView(
          slivers: [
            // Chỉ số thị trường
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CHỈ SỐ',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: indices
                          .map((idx) => Expanded(child: _IndexCard(index: idx)))
                          .toList(),
                    ),
                  ],
                ),
              ),
            ),
            // Top movers
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'NỔI BẬT HÔM NAY',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    boardAsync.when(
                      loading: () => const SizedBox(height: 120, child: Center(child: CircularProgressIndicator(color: AppColors.accent))),
                      error: (e, _) => const SizedBox(),
                      data: (quotes) => _TopMovers(quotes: quotes),
                    ),
                  ],
                ),
              ),
            ),
            // Breadth
            SliverToBoxAdapter(
              child: boardAsync.when(
                loading: () => const SizedBox(),
                error: (e, _) => const SizedBox(),
                data: (quotes) => Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: _MarketBreadth(quotes: quotes),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Index Card ─────────────────────────────────────────────────────────────

class _IndexCard extends StatelessWidget {
  final MarketIndex index;
  const _IndexCard({required this.index});

  @override
  Widget build(BuildContext context) {
    final color = index.isUp ? AppColors.increase : AppColors.decrease;
    return Card(
      margin: const EdgeInsets.only(right: 8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              index.name,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              index.valueStr,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              index.changeStr,
              style: TextStyle(fontSize: 10, color: color),
            ),
            const SizedBox(height: 6),
            // Mini chart (đơn giản dùng CustomPaint)
            SizedBox(
              height: 32,
              child: _MiniChart(data: index.chartData, color: color),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniChart extends StatelessWidget {
  final List<double> data;
  final Color color;
  const _MiniChart({required this.data, required this.color});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MiniChartPainter(data: data, color: color),
      size: Size.infinite,
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  _MiniChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;
    final min = data.reduce((a, b) => a < b ? a : b);
    final max = data.reduce((a, b) => a > b ? a : b);
    final range = max - min == 0 ? 1.0 : max - min;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.02)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final y = size.height - (size.height * (data[i] - min) / range);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MiniChartPainter old) => old.data != data;
}

// ─── Top Movers ─────────────────────────────────────────────────────────────

class _TopMovers extends StatelessWidget {
  final List<StockQuote> quotes;
  const _TopMovers({required this.quotes});

  @override
  Widget build(BuildContext context) {
    final sorted = List<StockQuote>.from(quotes);
    sorted.sort((a, b) => b.changePercent.abs().compareTo(a.changePercent.abs()));
    final movers = sorted.take(6).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1.6,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: movers.length,
      itemBuilder: (ctx, i) => _MoverCard(quote: movers[i]),
    );
  }
}

class _MoverCard extends StatelessWidget {
  final StockQuote quote;
  const _MoverCard({required this.quote});

  Color get _color {
    if (quote.isUp) return AppColors.increase;
    if (quote.isDown) return AppColors.decrease;
    return AppColors.reference;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/chart/${quote.symbol}'),
      child: Container(
        decoration: BoxDecoration(
          color: _color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color.withValues(alpha: 0.3), width: 0.5),
        ),
        padding: const EdgeInsets.all(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              quote.symbol,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              quote.priceStr,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _color),
            ),
            Text(
              quote.changePctStr,
              style: TextStyle(fontSize: 10, color: _color),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Market Breadth Bar ──────────────────────────────────────────────────────

class _MarketBreadth extends StatelessWidget {
  final List<StockQuote> quotes;
  const _MarketBreadth({required this.quotes});

  @override
  Widget build(BuildContext context) {
    final up = quotes.where((q) => q.isUp).length;
    final down = quotes.where((q) => q.isDown).length;
    final flat = quotes.length - up - down;
    final total = quotes.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ĐỘ RỘNG THỊ TRƯỜNG',
              style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: AppColors.textSecondary, letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Row(
                children: [
                  Expanded(
                    flex: up,
                    child: Container(
                      height: 8,
                      color: AppColors.increase,
                    ),
                  ),
                  Expanded(
                    flex: flat == 0 ? 1 : flat,
                    child: Container(
                      height: 8,
                      color: AppColors.reference,
                    ),
                  ),
                  Expanded(
                    flex: down,
                    child: Container(
                      height: 8,
                      color: AppColors.decrease,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                breadthLabel('Tăng', up, total, AppColors.increase),
                breadthLabel('Đứng', flat, total, AppColors.reference),
                breadthLabel('Giảm', down, total, AppColors.decrease),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget breadthLabel(String label, int count, int total, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
