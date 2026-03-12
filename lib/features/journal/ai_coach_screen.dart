import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/market_level.dart';
import '../../../core/services/market_level_service.dart';
import '../../../core/theme/app_theme.dart';

// ─── Checklist Data ───────────────────────────────────────────────────────────

enum CheckGroup { a, b, c, d, e, f, g }

class CheckItem {
  final CheckGroup group;
  final String text;
  bool checked;
  CheckItem(this.group, this.text, {this.checked = false});
}

// ─── AI Coach Screen ──────────────────────────────────────────────────────────

class AiCoachScreen extends StatefulWidget {
  const AiCoachScreen({super.key});
  @override
  State<AiCoachScreen> createState() => _AiCoachScreenState();
}

class _AiCoachScreenState extends State<AiCoachScreen> {
  final _symbolCtrl = TextEditingController();
  final _priceCtrl  = TextEditingController();
  final _levelSvc   = MarketLevelService();

  // Level alert state
  StockLevel? _stockLevel;     // data từ bảng HT/MT
  double?     _entryPrice;     // giá nhập realtime
  bool        _levelNotFound = false; // mã không có trong danh sách

  // ── 30 tiêu chí ──────────────────────────────────────────────────────────
  late final List<CheckItem> _items = [
    // A — Thị trường chung (≥ 2/3)
    CheckItem(CheckGroup.a, 'VN-Index đang trong Uptrend (không giai đoạn 4 / downtrend mạnh)?'),
    CheckItem(CheckGroup.a, 'Chưa có ≥ 3 phiên Phân Phối (PP) liên tiếp trong 15 phiên gần?'),
    CheckItem(CheckGroup.a, 'CP mạnh hơn VN-Index — RS tốt (giảm ít hơn, tăng nhiều hơn TT)?'),
    // B — Cổ phiếu & Giai đoạn (≥ 3/4)
    CheckItem(CheckGroup.b, 'CP đang ở Giai đoạn 2 (không phải giai đoạn 1/3/4)?'),
    CheckItem(CheckGroup.b, 'Giá đang trên MA200 và MA200 đang hướng lên?'),
    CheckItem(CheckGroup.b, 'CP thuộc nhóm ngành đang dẫn dắt (≥1 CP trong ngành vượt đỉnh trước)?'),
    CheckItem(CheckGroup.b, 'CP chưa nhân đôi từ vùng tích luỹ gốc (giá TB × 2)?'),
    // C — Sức mạnh CP (≥ 2/3)
    CheckItem(CheckGroup.c, 'CP đang gần đỉnh cũ ≤ 15% (Mạnh — không phải xa đỉnh > 20%)?'),
    CheckItem(CheckGroup.c, 'KL bắt đáy lớn hơn trung bình 20 phiên?'),
    CheckItem(CheckGroup.c, 'CP là Leader — bật lên đầu tiên khi TT tạo đáy, điều chỉnh ít hơn TT?'),
    // D — Wyckoff / VSA (≥ 5/7)
    CheckItem(CheckGroup.d, 'Xác định được pha Wyckoff (Pha D-E / LPS / BU — không đang pha PP)?'),
    CheckItem(CheckGroup.d, 'Nhận ra mẫu hình vào lệnh (TFS / No Supply / Spring / Shakeout / SOS / Pin Bar / Engulfing)?'),
    CheckItem(CheckGroup.d, 'Volume: KL thấp dần ở pullback/tích luỹ → KL cao khi đẩy lên?'),
    CheckItem(CheckGroup.d, 'Xuất hiện cặp bar No Supply + Test Cung liền kề 1-2 phiên?'),
    CheckItem(CheckGroup.d, 'Nến mới: spread hẹp + đóng cửa nửa trên (tích cực)?'),
    CheckItem(CheckGroup.d, 'KHÔNG có Upthrust / Shakeout mạnh trong 3-5 phiên gần nhất?'),
    CheckItem(CheckGroup.d, 'Nếu có Spring/Shakeout: CP đã quay lại TR với Vol thấp hơn Vol khi phá?'),
    // E — Ichimoku (≥ 3/4)
    CheckItem(CheckGroup.e, 'Giá đang trên Kijun-Sen — không kẹt trong Kumo?'),
    CheckItem(CheckGroup.e, 'Tenkan ≥ Kijun (Tenkan không cắt xuống Kijun)?'),
    CheckItem(CheckGroup.e, 'Chikou-Span cao hơn giá của 26 phiên trước?'),
    CheckItem(CheckGroup.e, 'Breakout không xuất phát từ Flat Kumo (hút giá ngược)?'),
    // F — Nền giá VCP (≥ 3/4)
    CheckItem(CheckGroup.f, 'Nền giá tích luỹ tối thiểu 3-4 tuần?'),
    CheckItem(CheckGroup.f, 'Nền giá chặt (biên độ hẹp, không trần/sàn loạn)?'),
    CheckItem(CheckGroup.f, 'Đây là nền 1 hoặc 2 từ vùng tích luỹ đầu tiên (không phải nền 4-5)?'),
    CheckItem(CheckGroup.f, 'Test đáy ≥ 2 lần không thủng + KL thấp dần + phiên sau hướng lên?'),
    // G — Quản lý rủi ro (BẮT BUỘC 4/4)
    CheckItem(CheckGroup.g, 'Tỷ lệ R:R ≥ 2:1 (tiềm năng lãi ≥ gấp đôi rủi ro)?'),
    CheckItem(CheckGroup.g, 'SL cứng đã tính: −4% → cắt 1/2; −8% → cắt hết?'),
    CheckItem(CheckGroup.g, 'Tỷ trọng lệnh ≤ 20% tổng danh mục (lần đầu chỉ 10%)?'),
    CheckItem(CheckGroup.g, 'KHÔNG vào lệnh vì cảm xúc (FOMO / trả thù TT / hy vọng mù quáng)?'),
  ];

  // ── Thresholds ────────────────────────────────────────────────────────────
  static const _threshold = {
    CheckGroup.a: 2, CheckGroup.b: 3, CheckGroup.c: 2,
    CheckGroup.d: 5, CheckGroup.e: 3, CheckGroup.f: 3,
    CheckGroup.g: 4, // bắt buộc tuyệt đối
  };

  static const _groupLabel = {
    CheckGroup.a: '🌍 A. Thị trường chung (≥ 2/3)',
    CheckGroup.b: '🏢 B. Cổ phiếu & Giai đoạn (≥ 3/4)',
    CheckGroup.c: '💪 C. Sức mạnh CP (≥ 2/3)',
    CheckGroup.d: '🔬 D. Wyckoff / VSA (≥ 5/7)',
    CheckGroup.e: '☁️ E. Ichimoku (≥ 3/4)',
    CheckGroup.f: '📐 F. Nền giá VCP (≥ 3/4)',
    CheckGroup.g: '💰 G. Quản lý rủi ro (BẮT BUỘC 4/4)',
  };

  int _count(CheckGroup g) => _items.where((e) => e.group == g && e.checked).length;
  int _total(CheckGroup g) => _items.where((e) => e.group == g).length;
  bool _pass(CheckGroup g) => _count(g) >= (_threshold[g] ?? 0);

  bool get _canTrade => CheckGroup.values.every(_pass);

  int get _totalPassed   => CheckGroup.values.where(_pass).length;
  int get _totalGroups   => CheckGroup.values.length;
  int get _checkedTotal  => _items.where((e) => e.checked).length;
  int get _itemsTotal    => _items.length;

  // ── Warnings (auto-detect) ────────────────────────────────────────────────
  final List<String> _warnings = [
    '⛔ CP đã tăng >50% từ đáy hoặc >3 nền giá → nguy cơ tạo đỉnh',
    '⛔ Nến Shakeout/Upthrust trong 3 phiên gần nhất → KHÔNG MUA',
    '⛔ Đang định mua ở giá Trần → không mua ở trần',
    '⛔ Danh mục đang thua lỗ → không gia tăng, không trung bình giá',
    '⚠️ KL phiên nổ >x3 TB → cẩn thận PP trong cây Break',
    '⚠️ VN-Index vừa có phiên PP thứ 3 → cân nhắc dừng mua mới',
  ];
  final Set<int> _activeWarnings = {};

  @override
  void initState() {
    super.initState();
    _symbolCtrl.addListener(_onSymbolChanged);
    _priceCtrl.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    _symbolCtrl.removeListener(_onSymbolChanged);
    _priceCtrl.removeListener(_onPriceChanged);
    _symbolCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  void _onSymbolChanged() async {
    final sym = _symbolCtrl.text.trim().toUpperCase();
    // Clear ngay lập tức để không hiện data cũ của mã trước
    if (mounted) setState(() { _stockLevel = null; _levelNotFound = false; });
    if (sym.length < 2) return;

    final level = await _levelSvc.findSymbol(sym);
    if (!mounted) return;
    // Kiểm tra mã vẫn còn đúng (người dùng có thể đã gõ khác)
    if (_symbolCtrl.text.trim().toUpperCase() != sym) return;

    setState(() {
      _stockLevel = level;
      _levelNotFound = level == null; // null = không tìm thấy
      _autoTickRR();
    });
  }

  void _onPriceChanged() {
    // Giá theo đơn vị nghìn đồng, giống JSON: 38.5 = 38,500đ
    // Chấp nhận cả dấu chấm và dấu phẩy làm dấu thập phân
    final raw = _priceCtrl.text.trim().replaceAll(',', '.');
    final price = double.tryParse(raw);
    if (mounted) setState(() {
      _entryPrice = price;
      _autoTickRR();
    });
  }

  /// Tự động tick/untick G.1 "R:R ≥ 2:1" dựa trên dữ liệu HT/MT
  void _autoTickRR() {
    if (_stockLevel == null || _entryPrice == null || _entryPrice! <= 0) return;
    final rr = _stockLevel!.rrRatio(_entryPrice!);
    if (rr == null) return;
    final rrItem = _items.firstWhere(
      (e) => e.group == CheckGroup.g && e.text.contains('R:R'),
      orElse: () => _items.first,
    );
    rrItem.checked = rr >= 2.0;
  }

  void _reset() {
    setState(() {
      for (final item in _items) item.checked = false;
      _activeWarnings.clear();
      _stockLevel = null;
      _entryPrice = null;
      _levelNotFound = false;
    });
    _symbolCtrl.clear();
    _priceCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('🤖 AI Coach — Pre-Trade Check'),
        actions: [
          TextButton(
            onPressed: _reset,
            child: const Text('Reset', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Input header ──────────────────────────────────────────────────
          _InputHeader(symbolCtrl: _symbolCtrl, priceCtrl: _priceCtrl),

          // ── Scrollable Body to prevent keyboard overflow ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              child: Column(
                children: [
                  // ── Level Alert (HT/MT smart) ─────────────────────────────────────
                  if (_stockLevel != null && _entryPrice != null && _entryPrice! > 0)
                    _LevelAlert(level: _stockLevel!, entryPrice: _entryPrice!)
                  else if (_levelNotFound)
                    _NotInListCard(symbol: _symbolCtrl.text.trim().toUpperCase()),

                  // ── Progress bar ──────────────────────────────────────────────────
                  _ProgressHeader(
                    checkedTotal: _checkedTotal,
                    itemsTotal: _itemsTotal,
                    totalPassed: _totalPassed,
                    totalGroups: _totalGroups,
                  ),

                  // ── Checklist ─────────────────────────────────────────────────────
                  ListView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    children: [
                for (final group in CheckGroup.values) ...[
                  _GroupHeader(
                    label: _groupLabel[group]!,
                    passed: _pass(group),
                    count: _count(group),
                    total: _total(group),
                    isMandatory: group == CheckGroup.g,
                  ),
                  ...(_items.where((e) => e.group == group).map(
                    (item) => _CheckTile(
                      item: item,
                      onChanged: (v) => setState(() => item.checked = v ?? false),
                    ),
                  )),
                  const SizedBox(height: 8),
                ],

                // ── Warnings ──────────────────────────────────────────────
                _WarningsSection(
                  warnings: _warnings,
                  active: _activeWarnings,
                  onToggle: (i) => setState(() {
                    if (_activeWarnings.contains(i)) _activeWarnings.remove(i);
                    else _activeWarnings.add(i);
                  }),
                ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom CTA ────────────────────────────────────────────────────
          _BottomCta(
            canTrade: _canTrade,
            symbol: _symbolCtrl.text,
            onProceed: () => context.push('/journal/add'),
            failedGroups: CheckGroup.values
                .where((g) => !_pass(g))
                .map((g) => _groupLabel[g]!)
                .toList(),
          ),
        ],
      ),
    );
  }
}

// ─── Sub Widgets ──────────────────────────────────────────────────────────────

class _InputHeader extends StatelessWidget {
  final TextEditingController symbolCtrl, priceCtrl;
  const _InputHeader({required this.symbolCtrl, required this.priceCtrl});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: AppColors.card,
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: TextField(
            controller: symbolCtrl,
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              labelText: 'Mã CK', hintText: 'VD: VNM',
              labelStyle: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              border: InputBorder.none,
            ),
          ),
        ),
        Container(width: 0.5, height: 32, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 12)),
        Expanded(
          flex: 3,
          child: TextField(
            controller: priceCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Giá vào (nghìn đ)', hintText: 'VD: 38.5',
              labelStyle: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ProgressHeader extends StatelessWidget {
  final int checkedTotal, itemsTotal, totalPassed, totalGroups;
  const _ProgressHeader({
    required this.checkedTotal, required this.itemsTotal,
    required this.totalPassed, required this.totalGroups,
  });

  @override
  Widget build(BuildContext context) {
    final pct = itemsTotal == 0 ? 0.0 : checkedTotal / itemsTotal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text('$checkedTotal/$itemsTotal tiêu chí',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const Spacer(),
              Text('$totalPassed/$totalGroups nhóm đạt',
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: totalPassed == totalGroups ? AppColors.increase : AppColors.accent,
                  )),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.border,
              valueColor: AlwaysStoppedAnimation(
                totalPassed == totalGroups ? AppColors.increase : AppColors.accent,
              ),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String label;
  final bool passed, isMandatory;
  final int count, total;
  const _GroupHeader({
    required this.label, required this.passed, required this.count,
    required this.total, required this.isMandatory,
  });

  @override
  Widget build(BuildContext context) {
    final color = passed ? AppColors.increase : (isMandatory ? AppColors.decrease : AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$count/$total',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
          ),
        ],
      ),
    );
  }
}

class _CheckTile extends StatelessWidget {
  final CheckItem item;
  final void Function(bool?) onChanged;
  const _CheckTile({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => onChanged(!item.checked),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: item.checked ? AppColors.increase.withValues(alpha: 0.07) : AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: item.checked ? AppColors.increase.withValues(alpha: 0.4) : AppColors.border,
          width: item.checked ? 1 : 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            item.checked ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 18,
            color: item.checked ? AppColors.increase : AppColors.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(item.text,
                style: TextStyle(
                  fontSize: 12,
                  color: item.checked ? AppColors.textPrimary : AppColors.textSecondary,
                  height: 1.4,
                )),
          ),
        ],
      ),
    ),
  );
}

class _WarningsSection extends StatelessWidget {
  final List<String> warnings;
  final Set<int> active;
  final void Function(int) onToggle;
  const _WarningsSection({required this.warnings, required this.active, required this.onToggle});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.fromLTRB(0, 16, 0, 8),
        child: Text('🔔 Tự kiểm tra cảnh báo',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
      ),
      ...warnings.asMap().entries.map((e) {
        final isActive = active.contains(e.key);
        final isError  = e.value.startsWith('⛔');
        final color    = isError ? AppColors.decrease : AppColors.accent;
        return GestureDetector(
          onTap: () => onToggle(e.key),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            margin: const EdgeInsets.only(bottom: 4),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isActive ? color.withValues(alpha: 0.1) : AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isActive ? color.withValues(alpha: 0.4) : AppColors.border,
                width: isActive ? 1 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isActive ? Icons.warning_rounded : Icons.check_box_outline_blank_rounded,
                  size: 16, color: isActive ? color : AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(e.value, style: TextStyle(
                    fontSize: 11,
                    color: isActive ? color : AppColors.textSecondary,
                    height: 1.4,
                  )),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 16),
    ],
  );
}

class _BottomCta extends StatelessWidget {
  final bool canTrade;
  final String symbol;
  final VoidCallback onProceed;   // luôn navigate dù pass/fail
  final List<String> failedGroups;
  const _BottomCta({
    required this.canTrade, required this.symbol,
    required this.onProceed, required this.failedGroups,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        border: Border(top: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Cảnh báo nếu chưa đủ ──────────────────────────────────────
          if (!canTrade && failedGroups.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.decrease.withValues(alpha: 0.07),
              child: Text(
                '⚠️ Chưa đủ: ${failedGroups.take(3).join(', ')}${failedGroups.length > 3 ? '...' : ''}',
                style: const TextStyle(fontSize: 11, color: AppColors.decrease),
              ),
            ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: canTrade
                // ── Đủ điều kiện → 1 nút xanh to ─────────────────────
                ? SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: onProceed,
                      icon: const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
                      label: Text(
                        '✅ Đủ điều kiện — Ghi lệnh${symbol.isNotEmpty ? ' $symbol' : ''}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.increase,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  )
                // ── Chưa đủ → nút bypass nhỏ hơn + nút chờ ───────────
                : Column(
                    children: [
                      // Nút bypass — vào lệnh luôn dù rủi ro
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: onProceed,
                          icon: const Icon(Icons.warning_amber_rounded, size: 16),
                          label: Text(
                            'Vào lệnh dù chưa đủ tiêu chí${symbol.isNotEmpty ? ' ($symbol)' : ''}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Gợi ý tiếp tục check
                      const Text(
                        'Tiếp tục tick để đủ điều kiện tốt hơn 💡',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Level Alert Widget ───────────────────────────────────────────────────────

class _LevelAlert extends StatelessWidget {
  final StockLevel level;
  final double entryPrice;
  const _LevelAlert({required this.level, required this.entryPrice});

  @override
  Widget build(BuildContext context) {
    final dHt1 = level.distanceFromHt1(entryPrice);
    final upMt1 = level.upsideToMt1(entryPrice);
    final upMt2 = level.upsideToMt2(entryPrice);
    final rr    = level.rrRatio(entryPrice);
    final cf    = level.cashFlowSignal;

    // Màu cảnh báo overall
    Color borderColor;
    String headerMsg;
    if (upMt1 != null && upMt1 < 0) {
      borderColor = AppColors.decrease;
      headerMsg = '🔴 Giá vượt MT1 — đang mua vào vùng kháng cự!';
    } else if (dHt1 != null && dHt1 > 8.0) {
      borderColor = AppColors.decrease;
      headerMsg = '🔴 Giá đã rời xa HT1 — rủi ro cao';
    } else if (rr != null && rr >= 2.0 && dHt1 != null && dHt1 <= 3.0) {
      borderColor = AppColors.increase;
      headerMsg = '🟢 Vị thế tốt — sát HT, R:R = ${rr.toStringAsFixed(1)}';
    } else {
      borderColor = AppColors.accent;
      headerMsg = '🟡 Kiểm tra kỹ — xem chi tiết bên dưới';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: borderColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: Text(headerMsg,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: borderColor)),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            child: Column(
              children: [
                // Row 1: HT1, HT2, MT1, MT2
                Row(
                  children: [
                    _LevelCell('HT1', level.ht1, entryPrice, isSupport: true),
                    _LevelCell('HT2', level.ht2, entryPrice, isSupport: true),
                    _LevelCell('MT1', level.mt1, entryPrice, isSupport: false),
                    _LevelCell('MT2', level.mt2, entryPrice, isSupport: false),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 2: Cách HT (gần = xanh, xa = đỏ)
                Row(
                  children: [
                    if (dHt1 != null)
                      _AlertChip(
                        label: 'Cách HT1',
                        value: '${dHt1 >= 0 ? '+' : ''}${dHt1.toStringAsFixed(1)}%',
                        color: dHt1 < 0
                            ? AppColors.decrease       // Phá HT1 → nguy hiểm
                            : dHt1 <= 2
                            ? AppColors.increase       // Sát HT1 ≤2% → lý tưởng
                            : dHt1 <= 5
                            ? Colors.orange            // Hơi xa 2-5% → cân nhắc
                            : AppColors.decrease,      // Xa >5% → rủi ro cao
                      ),
                    if (level.distanceFromHt2(entryPrice) != null)
                      _AlertChip(
                        label: 'Cách HT2',
                        value: () {
                          final d = level.distanceFromHt2(entryPrice)!;
                          return '${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)}%';
                        }(),
                        color: () {
                          final d = level.distanceFromHt2(entryPrice)!;
                          return d < 0
                              ? AppColors.decrease   // Thủng HT2 → rất nguy hiểm
                              : d <= 5
                              ? AppColors.increase   // Gần HT2 ≤5% → tốt
                              : Colors.orange;       // Xa HT2 >5% → cảnh báo
                        }(),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Row 3: Còn lên MT (nhiều = xanh, ít = đỏ) + R:R
                Row(
                  children: [
                    if (upMt1 != null)
                      _AlertChip(
                        label: 'Còn lên MT1',
                        value: '${upMt1 >= 0 ? '+' : ''}${upMt1.toStringAsFixed(1)}%',
                        color: upMt1 < 0
                            ? AppColors.decrease          // Đã vượt MT1
                            : upMt1 >= 8
                            ? AppColors.increase          // Lợi nhuận tốt ≥8%
                            : upMt1 >= 4
                            ? Colors.orange               // Trung bình 4-8%
                            : AppColors.decrease,         // <4% quá gần, không đáng vào
                      ),
                    if (upMt2 != null)
                      _AlertChip(
                        label: 'Còn lên MT2',
                        value: '${upMt2 >= 0 ? '+' : ''}${upMt2.toStringAsFixed(1)}%',
                        color: upMt2 < 0
                            ? AppColors.decrease
                            : upMt2 >= 15
                            ? AppColors.increase          // Tiềm năng ≥15% → rất tốt
                            : upMt2 >= 5
                            ? Colors.orange               // 5-15% → trung bình
                            : AppColors.textSecondary,    // <5% → chỉ tham khảo
                      ),
                    if (rr != null)
                      _AlertChip(
                        label: 'R:R',
                        value: '${rr.toStringAsFixed(1)}:1',
                        color: rr >= 2 ? AppColors.increase
                            : rr >= 1.5 ? Colors.orange
                            : AppColors.decrease,
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Row 3: Dòng tiền
                _CashFlowRow(level: level, signal: cf),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelCell extends StatelessWidget {
  final String label;
  final double? price;
  final double entryPrice;
  final bool isSupport;
  const _LevelCell(this.label, this.price, this.entryPrice, {required this.isSupport});

  @override
  Widget build(BuildContext context) {
    Color color;
    if (price == null) {
      color = AppColors.textSecondary;
    } else if (isSupport) {
      color = entryPrice > price! ? AppColors.increase : AppColors.decrease;
    } else {
      color = entryPrice < price! ? AppColors.textSecondary : AppColors.decrease;
    }
    return Expanded(
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(
            price != null ? price!.toStringAsFixed(1) : '—',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final String label, value;
  final Color color;
  const _AlertChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
          Text(value, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    ),
  );
}

class _CashFlowRow extends StatelessWidget {
  final StockLevel level;
  final CashFlowSignal signal;
  const _CashFlowRow({required this.level, required this.signal});

  @override
  Widget build(BuildContext context) {
    final color = signal == CashFlowSignal.strong ? AppColors.increase
        : signal == CashFlowSignal.weak ? AppColors.accent
        : AppColors.decrease;
    final icon = signal == CashFlowSignal.strong ? '💰'
        : signal == CashFlowSignal.weak ? '⚠️'
        : '🔴';
    final msg = signal == CashFlowSignal.strong ? 'Tiền lớn đang vào'
        : signal == CashFlowSignal.weak ? 'Tiền lớn T+0 đang rút — cẩn thận'
        : 'Tiền lớn bán ròng — không nên mua';
    final t0l = level.t0TienLon ?? 0;
    final togl = level.tongTienLon ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '$msg  |  T+0 Lớn: ${t0l >= 0 ? '+' : ''}${t0l.toStringAsFixed(0)}'
              '  Tổng Lớn: ${togl >= 0 ? '+' : ''}${togl.toStringAsFixed(0)}',
              style: TextStyle(fontSize: 10, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Not in list card ─────────────────────────────────────────────────────────

class _NotInListCard extends StatelessWidget {
  final String symbol;
  const _NotInListCard({required this.symbol});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.textSecondary.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.textSecondary, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '⚪ $symbol không có trong danh sách khuyến nghị hôm nay.\n'
              'Vẫn có thể tự kiểm tra checklist thủ công.',
              style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}
