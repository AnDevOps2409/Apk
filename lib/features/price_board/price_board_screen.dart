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

  // Kích thước các cột (Tổng khoảng 670px)
  static const double sw = 80;  // Symbol
  static const double pw = 70;  // Price
  static const double cw = 60;  // Change
  static const double cpw = 60; // Change %
  static const double vw = 80;  // Volume
  static const double hw = 60;  // High
  static const double lw = 60;  // Low
  static const double rw = 60;  // Ref (TC)
  static const double cew = 50; // Ceiling
  static const double flw = 50; // Floor

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

          if (filtered.isEmpty) {
            return Center(
              child: Text(
                'Không tìm thấy "$_filter"',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            );
          }

          // Bọc toàn bộ Header và ListView vào SingleChildScrollView cuộn ngang
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: sw + pw + cw + cpw + vw + hw + lw + rw + cew + flw + 16, // +16 padding
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length,
                      itemExtent: 44, // Giảm chiều cao row lại cho gọn giống TradingView
                      itemBuilder: (ctx, i) => _StockRow(
                        quote: filtered[i],
                        isEven: i % 2 == 0,
                        onTap: () => context.push('/chart/${filtered[i].symbol}'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          headerCell('Mã CK',   width: sw,  field: SortField.symbol),
          headerCell('Khớp',    width: pw,  field: SortField.price, textAlign: TextAlign.right),
          headerCell('+/-',     width: cw,  field: SortField.change, textAlign: TextAlign.right),
          headerCell('%',       width: cpw, field: SortField.change, textAlign: TextAlign.right),
          headerCell('Tổng KL', width: vw,  field: SortField.volume, textAlign: TextAlign.right),
          headerCell('Cao',     width: hw,  field: null, textAlign: TextAlign.right),
          headerCell('Thấp',    width: lw,  field: null, textAlign: TextAlign.right),
          headerCell('TC',      width: rw,  field: null, textAlign: TextAlign.right),
          headerCell('Trần',    width: cew, field: null, textAlign: TextAlign.right),
          headerCell('Sàn',     width: flw, field: null, textAlign: TextAlign.right),
        ],
      ),
    );
  }

  Widget headerCell(String label, {required double width, SortField? field, TextAlign textAlign = TextAlign.left}) {
    final active = field != null && _sortField == field;
    return SizedBox(
      width: width,
      child: GestureDetector(
        onTap: field == null ? null : () {
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
  final bool isEven;
  final VoidCallback onTap;

  const _StockRow({required this.quote, required this.isEven, required this.onTap});

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
          color: isEven ? Colors.transparent : AppColors.surfaceVariant.withValues(alpha: 0.3),
          border: Border(
            bottom: BorderSide(color: AppColors.border.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // Mã CK
            SizedBox(
              width: _PriceBoardScreenState.sw,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quote.symbol,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: quote.isCeiling ? AppColors.ceiling : quote.isFloor ? AppColors.floor : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Giá khớp
            SizedBox(
              width: _PriceBoardScreenState.pw,
              child: Text(
                quote.priceStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _priceColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            // Thay đổi
            SizedBox(
              width: _PriceBoardScreenState.cw,
              child: Text(
                quote.changeStr,
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 12,
                  color: _priceColor,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            // % thay đổi
            SizedBox(
              width: _PriceBoardScreenState.cpw,
              child: _PctBadge(pct: quote.changePercent, color: _priceColor),
            ),
            // Khối lượng
            SizedBox(
              width: _PriceBoardScreenState.vw,
              child: Text(
                quote.volumeStr,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  fontFamily: 'monospace',
                ),
              ),
            ),
            // Cao
            SizedBox(
              width: _PriceBoardScreenState.hw,
              child: Text(
                quote.highStr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: AppColors.increase, fontFamily: 'monospace'),
              ),
            ),
            // Thấp
            SizedBox(
              width: _PriceBoardScreenState.lw,
              child: Text(
                quote.lowStr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: AppColors.decrease, fontFamily: 'monospace'),
              ),
            ),
            // TC
            SizedBox(
              width: _PriceBoardScreenState.rw,
              child: Text(
                quote.referenceStr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: AppColors.reference, fontFamily: 'monospace'),
              ),
            ),
            // Trần
            SizedBox(
              width: _PriceBoardScreenState.cew,
              child: Text(
                quote.ceilingStr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: AppColors.ceiling, fontFamily: 'monospace'),
              ),
            ),
            // Sàn
            SizedBox(
              width: _PriceBoardScreenState.flw,
              child: Text(
                quote.floorStr,
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 12, color: AppColors.floor, fontFamily: 'monospace'),
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
    final sign = pct > 0 ? '+' : '';
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          '$sign${pct.toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
      ),
    );
  }
}
