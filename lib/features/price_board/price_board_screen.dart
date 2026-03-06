import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/stock_quote.dart';
import '../../core/providers/stock_providers.dart';

class PriceBoardScreen extends ConsumerStatefulWidget {
  const PriceBoardScreen({super.key});

  @override
  ConsumerState<PriceBoardScreen> createState() => _PriceBoardScreenState();
}

class _PriceBoardScreenState extends ConsumerState<PriceBoardScreen> {
  SortField _sortField = SortField.symbol;
  bool _ascending = true;
  String _filter = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(priceBoardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Bảng giá'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: () => ref.read(priceBoardProvider.notifier).refresh(),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(44),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Tìm mã CK...',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary, size: 18),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (v) => setState(() => _filter = v.toUpperCase()),
            ),
          ),
        ),
      ),
      body: boardAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
        error: (e, _) => Center(
          child: Text('Lỗi: $e', style: const TextStyle(color: AppColors.decrease)),
        ),
        data: (quotes) {
          final filtered = _filter.isEmpty
              ? quotes
              : quotes.where((q) => q.symbol.contains(_filter)).toList();

          return Column(
            children: [
              _buildHeader(),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Không tìm thấy "$_filter"',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemExtent: 52,
                        itemBuilder: (ctx, i) => _StockRow(
                          quote: filtered[i],
                          onTap: () => context.push('/chart/${filtered[i].symbol}'),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          headerCell('Mã CK', flex: 2, field: SortField.symbol),
          headerCell('Giá', flex: 2, field: SortField.price, textAlign: TextAlign.right),
          headerCell('+/-', flex: 2, field: SortField.change, textAlign: TextAlign.right),
          headerCell('%', flex: 2, field: SortField.change, textAlign: TextAlign.right),
          headerCell('KL (CP)', flex: 3, field: SortField.volume, textAlign: TextAlign.right),
        ],
      ),
    );
  }

  Widget headerCell(String label, {required int flex, required SortField field, TextAlign textAlign = TextAlign.left}) {
    final active = _sortField == field;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: () {
          setState(() {
            if (_sortField == field) {
              _ascending = !_ascending;
            } else {
              _sortField = field;
              _ascending = field == SortField.symbol;
            }
          });
          ref.read(priceBoardProvider.notifier).sortBy(field, ascending: _ascending);
        },
        child: Row(
          mainAxisAlignment: textAlign == TextAlign.right ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? AppColors.accent : AppColors.textSecondary,
              ),
            ),
            if (active) ...[
              const SizedBox(width: 2),
              Icon(
                _ascending ? Icons.arrow_upward : Icons.arrow_downward,
                size: 10,
                color: AppColors.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Stock Row ──────────────────────────────────────────────────────────────

class _StockRow extends StatelessWidget {
  final StockQuote quote;
  final VoidCallback onTap;

  const _StockRow({required this.quote, required this.onTap});

  Color get _priceColor {
    if (quote.isCeiling) return AppColors.ceiling;
    if (quote.isFloor) return AppColors.floor;
    if (quote.isUp) return AppColors.increase;
    if (quote.isDown) return AppColors.decrease;
    return AppColors.reference;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.4), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Mã CK
            Expanded(
              flex: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.symbol,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    quote.exchange,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            // Giá khớp
            Expanded(
              flex: 2,
              child: Text(
                quote.priceStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _priceColor,
                ),
              ),
            ),
            // Thay đổi
            Expanded(
              flex: 2,
              child: Text(
                quote.changeStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: _priceColor,
                ),
              ),
            ),
            // % thay đổi
            Expanded(
              flex: 2,
              child: _PctBadge(pct: quote.changePercent, color: _priceColor),
            ),
            // Khối lượng
            Expanded(
              flex: 3,
              child: Text(
                quote.volumeStr,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PctBadge extends StatelessWidget {
  final double pct;
  final Color color;
  const _PctBadge({required this.pct, required this.color});

  @override
  Widget build(BuildContext context) {
    final sign = pct >= 0 ? '+' : '';
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '$sign${pct.toStringAsFixed(2)}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }
}
