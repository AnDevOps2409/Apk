import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/market_level.dart';
import '../../../core/models/trade_log.dart';
import '../../../core/providers/stock_providers.dart';
import '../../../core/services/fdata_service.dart';
import '../../../core/services/market_level_service.dart';
import '../../../core/services/trade_log_service.dart';
import '../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';

class JournalScreen extends ConsumerStatefulWidget {
  const JournalScreen({super.key});

  @override
  ConsumerState<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends ConsumerState<JournalScreen>
    with SingleTickerProviderStateMixin {
  final _service = TradeLogService();
  late TabController _tab;
  List<TradeLog> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await _service.loadAll();
    setState(() {
      _all     = logs;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  List<TradeLog> get _closed => _all.where((e) => e.isClosed).toList();
  List<TradeLog> get _open   => _all.where((e) => !e.isClosed).toList();

  /// Tab "Tất cả": đang giữ lên trước, đã đóng bên dưới
  List<TradeLog> get _allSorted => [
    ..._all.where((e) => !e.isClosed),
    ..._all.where((e) => e.isClosed),
  ];

  int    get _winCount  => _closed.where((e) => (e.pnlPercent ?? 0) > 0).length;
  double get _winRate   => _closed.isEmpty ? 0 : _winCount / _closed.length * 100;
  double get _totalPnl  => _closed.fold(0, (s, e) => s + (e.pnlVnd ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Nhật ký giao dịch'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () async {
                await context.push('/coach');
                _load();
              },
              icon: const Icon(Icons.psychology_alt_rounded, size: 16),
              label: const Text('AI Check', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.accent,
                backgroundColor: AppColors.accentGlow,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: [
            Tab(text: 'Tất cả (${_all.length})'),
            Tab(text: 'Đang giữ (${_open.length})'),
            Tab(text: 'Đã đóng (${_closed.length})'),
          ],
          indicatorColor: AppColors.accent,
          labelColor: AppColors.accent,
          unselectedLabelColor: AppColors.textSecondary,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await context.push('/journal/add');
          _load();
        },
        backgroundColor: AppColors.accent,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Ghi lệnh', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _StatsBar(
                  totalPnl: _totalPnl,
                  winRate:  _winRate,
                  total:    _all.length,
                  closed:   _closed.length,
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tab,
                    children: [
                      _TradeList(logs: _allSorted, onRefresh: _load),
                      _TradeList(logs: _open,      onRefresh: _load),
                      _TradeList(logs: _closed,    onRefresh: _load),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

// ─── Stats Bar ────────────────────────────────────────────────────────────────

class _StatsBar extends StatelessWidget {
  final double totalPnl, winRate;
  final int total, closed;
  const _StatsBar({
    required this.totalPnl, required this.winRate,
    required this.total,    required this.closed,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0', 'vi_VN');
    final pnlColor = totalPnl >= 0 ? AppColors.increase : AppColors.decrease;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(
        children: [
          _Stat(
            label: 'Tổng PnL',
            value: (totalPnl >= 0 ? '+' : '') + fmt.format(totalPnl / 1000) + 'K',
            color: pnlColor,
          ),
          const _Sep(),
          _Stat(
            label: 'Win Rate',
            value: closed == 0 ? '-' : '${winRate.toStringAsFixed(0)}%',
            color: winRate >= 50 ? AppColors.increase : AppColors.decrease,
          ),
          const _Sep(),
          _Stat(label: 'Lệnh', value: '$total', color: AppColors.textPrimary),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
      ],
    ),
  );
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => Container(
    height: 28, width: 0.5, color: AppColors.border,
    margin: const EdgeInsets.symmetric(horizontal: 8),
  );
}

// ─── Trade List ───────────────────────────────────────────────────────────────

class _TradeList extends ConsumerWidget {
  final List<TradeLog> logs;
  final VoidCallback onRefresh;
  const _TradeList({required this.logs, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.book_outlined, size: 48, color: AppColors.textSecondary),
            SizedBox(height: 8),
            Text('Chưa có lệnh nào', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }
    final levelSvc = MarketLevelService();
    final fdataSvc = ref.read(fdataServiceProvider);
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) => _TradeTile(
          log: logs[i],
          levelSvc: levelSvc,
          fdataSvc: fdataSvc,
          onTap: () async {
            await context.push('/journal/${logs[i].id}');
            onRefresh();
          },
        ),
      ),
    );
  }
}

// ─── Trade Tile ───────────────────────────────────────────────────────────────

class _TradeTile extends StatelessWidget {
  final TradeLog log;
  final VoidCallback onTap;
  final MarketLevelService levelSvc;
  final FDataService fdataSvc;
  const _TradeTile({
    required this.log,
    required this.onTap,
    required this.levelSvc,
    required this.fdataSvc,
  });

  @override
  Widget build(BuildContext context) {
    final dateFmt  = DateFormat('dd/MM/yyyy');
    final numFmt   = NumberFormat('#,##0', 'vi_VN');
    final pnl      = log.pnlPercent;
    final isOpen   = !log.isClosed;

    final stripeColor = isOpen
        ? AppColors.accent
        : (pnl == null || pnl >= 0)
            ? AppColors.increase
            : AppColors.decrease;

    final pnlColor = (pnl == null || pnl >= 0)
        ? AppColors.increase
        : AppColors.decrease;

    final entryDisplay = log.entryPrice > 1000
        ? numFmt.format(log.entryPrice.round())
        : numFmt.format((log.entryPrice * 1000).round());
    final exitDisplay  = log.exitPrice == null
        ? null
        : log.exitPrice! > 1000
            ? numFmt.format(log.exitPrice!.round())
            : numFmt.format((log.exitPrice! * 1000).round());

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border, width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left color stripe
              Container(width: 4, color: stripeColor),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // Row 1: Symbol + pattern + status chip
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            log.symbol,
                            style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary, letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _PatternChip(log.pattern.label),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: stripeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: stripeColor.withValues(alpha: 0.4),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              isOpen ? 'ĐANG GIỮ' : 'ĐÃ CHỐT',
                              style: TextStyle(
                                fontSize: 9, fontWeight: FontWeight.w700,
                                color: stripeColor, letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      // Row 2: date + entry → exit + PnL badge
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 10, color: AppColors.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            dateFmt.format(log.tradeDate),
                            style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            entryDisplay,
                            style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (exitDisplay != null) ...[
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: Icon(Icons.arrow_forward_rounded,
                                  size: 12, color: AppColors.textDisabled),
                            ),
                            Text(
                              exitDisplay,
                              style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: pnlColor,
                              ),
                            ),
                          ] else ...[
                            const SizedBox(width: 6),
                            const Text('→ ?',
                                style: TextStyle(fontSize: 12, color: AppColors.textDisabled)),
                          ],
                          const Spacer(),

                          // PnL badge (đã chốt) hoặc giá hiện tại (đang giữ)
                          if (pnl != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: pnlColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                                style: TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w800,
                                  color: pnlColor,
                                ),
                              ),
                            )
                          else
                            _UnrealizedPnl(log: log, fdataSvc: fdataSvc),
                        ],
                      ),

                      // HT/MT chips (chỉ khi đang giữ)
                      if (isOpen)
                        FutureBuilder<StockLevel?>(
                          future: levelSvc.findSymbol(log.symbol),
                          builder: (context, snap) {
                            final level = snap.data;
                            if (level == null) return const SizedBox.shrink();

                            final entry = log.entryPrice > 1000
                                ? log.entryPrice / 1000
                                : log.entryPrice;

                            Color htColor(double? d) {
                              if (d == null) return AppColors.textSecondary;
                              if (d >= 0 && d <= 3) return AppColors.increase;
                              if (d > 3 && d <= 7)  return Colors.orange;
                              return AppColors.decrease;
                            }
                            Color mtColor(double? u) {
                              if (u == null) return AppColors.textSecondary;
                              if (u >= 10) return AppColors.increase;
                              if (u >= 5)  return Colors.orange;
                              if (u >= 0)  return AppColors.textSecondary;
                              return AppColors.decrease;
                            }
                            String pctStr(double? v) {
                              if (v == null) return '-';
                              final sign = v >= 0 ? '+' : '';
                              return '$sign${v.toStringAsFixed(1)}%';
                            }
                            String priceStr(double? v) => v == null
                                ? '-'
                                : NumberFormat('#,##0', 'vi_VN').format((v * 1000).round());

                            final chips = <_LevelChip>[
                              if (level.ht1 != null)
                                _LevelChip(
                                  label: 'HT1 ${priceStr(level.ht1)}',
                                  pct: pctStr(level.distanceFromHt1(entry)),
                                  color: htColor(level.distanceFromHt1(entry)),
                                ),
                              if (level.ht2 != null)
                                _LevelChip(
                                  label: 'HT2 ${priceStr(level.ht2)}',
                                  pct: pctStr(level.distanceFromHt2(entry)),
                                  color: htColor(level.distanceFromHt2(entry)),
                                ),
                              if (level.mt1 != null)
                                _LevelChip(
                                  label: 'MT1 ${priceStr(level.mt1)}',
                                  pct: pctStr(level.upsideToMt1(entry)),
                                  color: mtColor(level.upsideToMt1(entry)),
                                ),
                              if (level.mt2 != null)
                                _LevelChip(
                                  label: 'MT2 ${priceStr(level.mt2)}',
                                  pct: pctStr(level.upsideToMt2(entry)),
                                  color: mtColor(level.upsideToMt2(entry)),
                                ),
                            ];

                            if (chips.isEmpty) return const SizedBox.shrink();

                            return Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Wrap(
                                spacing: 6, runSpacing: 6,
                                children: chips.map((c) => Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: c.color.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: c.color.withValues(alpha: 0.3), width: 0.5),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(c.label,
                                        style: const TextStyle(
                                          fontSize: 10, color: AppColors.textSecondary)),
                                      const SizedBox(width: 5),
                                      Text(c.pct,
                                        style: TextStyle(
                                          fontSize: 10, fontWeight: FontWeight.w700,
                                          color: c.color)),
                                    ],
                                  ),
                                )).toList(),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelChip {
  final String label, pct;
  final Color color;
  const _LevelChip({required this.label, required this.pct, required this.color});
}

class _PatternChip extends StatelessWidget {
  final String label;
  const _PatternChip(this.label);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.border.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
  );
}

// ─── Unrealized PnL ──────────────────────────────────────────────────────────

class _UnrealizedPnl extends StatelessWidget {
  final TradeLog log;
  final FDataService fdataSvc;
  const _UnrealizedPnl({required this.log, required this.fdataSvc});

  Future<double?> _fetchCurrentPrice() async {
    try {
      final candles = await fdataSvc.fetchCandles(log.symbol, timeframe: '1D', limit: 1);
      if (candles.isNotEmpty) return candles.last.close;
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final entryVnd = log.entryPrice;

    return FutureBuilder<double?>(
      future: _fetchCurrentPrice(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.accent),
          );
        }

        final currentPrice = snap.data;
        if (currentPrice == null) {
          return const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary);
        }

        final entryK = entryVnd > 1000 ? entryVnd / 1000 : entryVnd;
        final pct    = entryK > 0 ? (currentPrice - entryK) / entryK * 100 : 0.0;
        final isUp   = pct >= 0;
        final color  = pct > 0.05  ? AppColors.increase
                     : pct < -0.05 ? AppColors.decrease
                     : AppColors.reference;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${isUp ? '+' : ''}${pct.toStringAsFixed(2)}%',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              NumberFormat('#,##0', 'vi_VN').format((currentPrice * 1000).round()),
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        );
      },
    );
  }
}
