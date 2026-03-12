import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/trade_log.dart';
import '../../../core/services/trade_log_service.dart';
import '../../../core/services/ai_review_service.dart';
import '../../../core/theme/app_theme.dart';

/// Màn hình chi tiết 1 lệnh + AI Review
class TradeDetailScreen extends StatefulWidget {
  final String tradeId;
  const TradeDetailScreen({super.key, required this.tradeId});

  @override
  State<TradeDetailScreen> createState() => _TradeDetailScreenState();
}

class _TradeDetailScreenState extends State<TradeDetailScreen> {
  final _service   = TradeLogService();
  final _aiService = AiReviewService();
  TradeLog? _log;
  bool _loading    = true;
  bool _reviewing  = false;
  String? _aiError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final all = await _service.loadAll();
    setState(() {
      _log     = all.firstWhere((e) => e.id == widget.tradeId, orElse: () => all.first);
      _loading = false;
    });
  }

  Future<void> _requestAiReview() async {
    if (_log == null) return;
    setState(() { _reviewing = true; _aiError = null; });
    try {
      final text = await _aiService.reviewTrade(_log!);
      final updated = _log!.copyWith(aiReview: text);
      await _service.save(updated);
      setState(() => _log = updated);
    } catch (e) {
      setState(() => _aiError = e.toString());
    } finally {
      setState(() => _reviewing = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        title: const Text('Xoá lệnh?', style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Hành động này không thể hoàn tác.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Huỷ')),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Xoá', style: TextStyle(color: AppColors.decrease))),
        ],
      ),
    );
    if (confirm == true && _log != null) {
      await _service.delete(_log!.id);
      if (mounted) context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final log = _log!;
    final dateFmt  = DateFormat('dd/MM/yyyy');
    final priceFmt = NumberFormat('#,##0.##', 'vi_VN'); // 38000 → 38.000
    final pnl      = log.pnlPercent;
    final pnlColor = pnl == null ? AppColors.textSecondary
        : (pnl >= 0 ? AppColors.increase : AppColors.decrease);

    // Hàm tiện gọi nhanh
    String p(double v) => priceFmt.format(v);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(log.symbol),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_rounded),
            onPressed: () async {
              await context.push('/journal/${log.id}/edit');
              _load();
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.decrease),
            onPressed: _delete,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header card ──────────────────────────────────────────────────
          _InfoCard(children: [
            _Row('Mã CK',      log.symbol,                bold: true),
            _Row('Ngày',       dateFmt.format(log.tradeDate)),
            _Row('Mẫu hình',   log.pattern.label),
            _Row('Giá vào',    p(log.entryPrice)),
            _Row('KL',         NumberFormat('#,##0', 'vi_VN').format(log.entryQuantity)),
            _Row('SL −4%',     p(log.sl50Price),   color: AppColors.decrease),
            _Row('SL −8%',     p(log.sl100Price),  color: AppColors.decrease),
            _Divider(),
            _Row('Lý do vào',  log.entryReason, multiline: true),
          ]),

          // ── Exit card ────────────────────────────────────────────────────
          if (log.isClosed) ...[
            const SizedBox(height: 12),
            _InfoCard(children: [
              if (pnl != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          '${pnl >= 0 ? '+' : ''}${pnl.toStringAsFixed(2)}%',
                          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: pnlColor),
                        ),
                        if (log.pnlVnd != null)
                          Text(
                            '${log.pnlVnd! >= 0 ? '+' : ''}${NumberFormat('#,##0', 'vi_VN').format(log.pnlVnd!.round())} đ',
                            style: TextStyle(fontSize: 13, color: pnlColor),
                          ),
                      ],
                    ),
                  ),
                ),
              _Row('Giá ra',     p(log.exitPrice!)),
              _Row('KL bán',    NumberFormat('#,##0', 'vi_VN').format(log.soldQuantity)),
              if (log.isPartialExit)
                _Row('Còn giữ', NumberFormat('#,##0', 'vi_VN').format(log.remainingQuantity),
                    color: AppColors.accent),
              _Row('Loại thoát', log.exitType?.label ?? '-'),
              _Row('Cảm xúc',  log.exitEmotion?.label ?? '-'),
              _Divider(),
              _Row('Lý do bán', log.exitReason ?? '-', multiline: true),
            ]),
          ] else ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await context.push('/journal/${log.id}/edit');
                _load();
              },
              icon: const Icon(Icons.exit_to_app_rounded, size: 16),
              label: const Text('Ghi thông tin đóng lệnh'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: const BorderSide(color: AppColors.accent),
              ),
            ),
          ],

          // ── AI Review ────────────────────────────────────────────────────
          const SizedBox(height: 20),
          const Text('🤖 AI Review',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14)),
          const SizedBox(height: 10),

          if (_aiError != null)
            _ErrorBox(_aiError!),

          if (log.aiReview == null && !_reviewing)
            ElevatedButton.icon(
              onPressed: _requestAiReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              label: const Text('Nhờ AI Review lệnh này', style: TextStyle(color: Colors.white)),
            ),

          if (_reviewing)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Đang phân tích...', style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),

          if (log.aiReview != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MarkdownBody(
                    data: log.aiReview!,
                    styleSheet: MarkdownStyleSheet(
                      p: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.6),
                      h2: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                      strong: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700),
                      listBullet: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: log.aiReview!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Đã copy!')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        label: const Text('Copy'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                      ),
                      TextButton.icon(
                        onPressed: _requestAiReview,
                        icon: const Icon(Icons.refresh_rounded, size: 14),
                        label: const Text('Review lại'),
                        style: TextButton.styleFrom(foregroundColor: AppColors.accent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Sub Widgets ──────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border, width: 0.5),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
  );
}

class _Row extends StatelessWidget {
  final String label, value;
  final Color? color;
  final bool bold, multiline;
  const _Row(this.label, this.value, {this.color, this.bold = false, this.multiline = false});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: multiline
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Text(value, style: TextStyle(fontSize: 13, color: color ?? AppColors.textPrimary, height: 1.5)),
            ],
          )
        : Row(children: [
            SizedBox(width: 80,
                child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
            Expanded(child: Text(value, style: TextStyle(
              fontSize: 13, fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
              color: color ?? AppColors.textPrimary,
            ))),
          ]),
  );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Divider(color: AppColors.border, height: 1),
  );
}

class _ErrorBox extends StatelessWidget {
  final String text;
  const _ErrorBox(this.text);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.decrease.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(text, style: const TextStyle(color: AppColors.decrease, fontSize: 12)),
  );
}
