import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/models/stock_quote.dart';

class WatchlistScreen extends ConsumerWidget {
  const WatchlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final watchlist = ref.watch(watchlistProvider);
    final watchlistQuotesAsync = ref.watch(watchlistQuotesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Danh mục theo dõi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showAddDialog(context, ref),
          ),
        ],
      ),
      body: watchlistQuotesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (quotes) {
          // Trả về danh sách chứng khoán đã được sắp xếp theo đúng thứ tự của watchlist (nếu cần)
          // TradingView API có thể trả về không đúng thứ tự, nên map lại:
          final watched = watchlist.map((sym) {
            final matches = quotes.where((q) => q.symbol == sym).toList();
            if (matches.isNotEmpty) return matches.first;
            // Fallback trong trường hợp API lỗi cho mã cụ thể
            return StockQuote(
              symbol: sym, exchange: 'HOSE', reference: 0, ceiling: 0, floor: 0,
              open: 0, high: 0, low: 0, price: 0, change: 0, changePercent: 0,
              volume: 0, totalValue: 0,
              buy1: 0, buyVol1: 0, buy2: 0, buyVol2: 0, buy3: 0, buyVol3: 0,
              sell1: 0, sellVol1: 0, sell2: 0, sellVol2: 0, sell3: 0, sellVol3: 0,
              updatedAt: DateTime.now(),
            );
          }).toList();

          if (watched.isEmpty) {
            return _EmptyWatchlist(onAdd: () => _showAddDialog(context, ref));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: watched.length,
            separatorBuilder: (context2, index2) => Divider(
              color: AppColors.border.withValues(alpha: 0.4),
              height: 0.5,
              indent: 16, endIndent: 16,
            ),
            itemBuilder: (ctx, i) {
              final q = watched[i];
              final color = q.isUp ? AppColors.increase : q.isDown ? AppColors.decrease : AppColors.reference;
              return Dismissible(
                key: Key(q.symbol),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: AppColors.decrease.withValues(alpha: 0.15),
                  child: const Icon(Icons.delete_outline_rounded, color: AppColors.decrease),
                ),
                onDismissed: (_) {
                  ref.read(watchlistProvider.notifier).remove(q.symbol);
                },
                child: ListTile(
                  onTap: () => context.push('/chart/${q.symbol}'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: Row(
                    children: [
                      Text(
                        q.symbol,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          q.exchange,
                          style: const TextStyle(fontSize: 9, color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    q.companyName ?? '',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        q.priceStr,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          q.changePctStr,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Thêm mã CK', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          decoration: const InputDecoration(
            hintText: 'VD: VCB, HPG, FPT',
            hintStyle: TextStyle(color: AppColors.textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accent)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              final sym = ctrl.text.trim().toUpperCase();
              if (sym.isNotEmpty) {
                ref.read(watchlistProvider.notifier).add(sym);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Thêm', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _EmptyWatchlist extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyWatchlist({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.bookmark_border_rounded, size: 64, color: AppColors.textDisabled),
          const SizedBox(height: 12),
          const Text(
            'Chưa có mã nào trong danh mục',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18, color: Colors.white),
            label: const Text('Thêm mã CK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
