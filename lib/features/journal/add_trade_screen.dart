import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/trade_log.dart';
import '../../../core/services/trade_log_service.dart';
import '../../../core/theme/app_theme.dart';

class AddTradeScreen extends StatefulWidget {
  final TradeLog? existing;
  final String?   existingId;
  const AddTradeScreen({super.key, this.existing, this.existingId});

  @override
  State<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends State<AddTradeScreen> {
  final _service  = TradeLogService();
  final _formKey  = GlobalKey<FormState>();
  bool _saving    = false;

  // ── Entry ──────────────────────────────────────────────────────────────────
  final _symbolCtrl      = TextEditingController();
  final _entryPriceCtrl  = TextEditingController();
  final _quantityCtrl    = TextEditingController();
  final _entryReasonCtrl = TextEditingController();
  TradePattern _pattern  = TradePattern.testForSupply;
  DateTime _tradeDate    = DateTime.now();

  // ── Mua thêm ───────────────────────────────────────────────────────────────
  final List<_AddBuyForm> _addBuys = [];

  // ── Bán (nhiều lệnh) ───────────────────────────────────────────────────────
  final List<_SellForm> _sells = [];

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _prefill(widget.existing!);
    } else if (widget.existingId != null) {
      _service.loadAll().then((all) {
        final found = all.where((e) => e.id == widget.existingId).firstOrNull;
        if (found != null && mounted) _prefill(found);
      });
    }
  }

  void _prefill(TradeLog e) {
    final fmt = NumberFormat('#,##0', 'vi_VN');
    setState(() {
      _symbolCtrl.text      = e.symbol;
      _entryPriceCtrl.text  = fmt.format(e.entryPrice.round());
      _quantityCtrl.text    = fmt.format(e.entryQuantity);
      _entryReasonCtrl.text = e.entryReason;
      _pattern  = e.pattern;
      _tradeDate = e.tradeDate;

      // Mua thêm
      _addBuys.clear();
      for (final b in e.addBuys) {
        _addBuys.add(_AddBuyForm(
          priceCtrl: TextEditingController(text: fmt.format(b.price.round())),
          qtyCtrl:   TextEditingController(text: fmt.format(b.quantity)),
          date:      b.date,
        ));
      }

      // Lệnh bán
      _sells.clear();
      for (final s in e.sellOrders) {
        _sells.add(_SellForm(
          priceCtrl:  TextEditingController(text: fmt.format(s.price.round())),
          qtyCtrl:    TextEditingController(text: fmt.format(s.quantity)),
          reasonCtrl: TextEditingController(text: s.reason ?? ''),
          exitType:   s.exitType,
          exitEmotion: s.exitEmotion,
          date:       s.date,
        ));
      }
    });
  }

  @override
  void dispose() {
    _symbolCtrl.dispose(); _entryPriceCtrl.dispose();
    _quantityCtrl.dispose(); _entryReasonCtrl.dispose();
    for (final b in _addBuys) { b.priceCtrl.dispose(); b.qtyCtrl.dispose(); }
    for (final s in _sells) {
      s.priceCtrl.dispose(); s.qtyCtrl.dispose(); s.reasonCtrl.dispose();
    }
    super.dispose();
  }

  double _parsePrice(String s) => double.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;
  int    _parseQty(String s)   => int.tryParse(s.replaceAll('.', '').replaceAll(',', '')) ?? 0;
  String _fmtPrice(double v)   => NumberFormat('#,##0', 'vi_VN').format(v.round());

  double? get _ep => double.tryParse(_entryPriceCtrl.text.replaceAll('.', ''));

  // Tính giá trung bình preview
  double _calcAvgPrice() {
    final ep  = _parsePrice(_entryPriceCtrl.text);
    final qty = _parseQty(_quantityCtrl.text);
    if (qty == 0) return ep;
    double cost = ep * qty;
    int    total = qty;
    for (final b in _addBuys) {
      final bp = _parsePrice(b.priceCtrl.text);
      final bq = _parseQty(b.qtyCtrl.text);
      if (bp > 0 && bq > 0) { cost += bp * bq; total += bq; }
    }
    return total > 0 ? cost / total : ep;
  }

  int _calcTotalBuyQty() {
    int total = _parseQty(_quantityCtrl.text);
    for (final b in _addBuys) {
      final bq = _parseQty(b.qtyCtrl.text);
      if (bq > 0) total += bq;
    }
    return total;
  }

  int _calcTotalSold() =>
      _sells.fold(0, (s, o) => s + _parseQty(o.qtyCtrl.text));

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final id = widget.existing?.id ?? widget.existingId ??
        DateTime.now().millisecondsSinceEpoch.toString();

    final addBuys = _addBuys
        .where((b) => _parseQty(b.qtyCtrl.text) > 0 && _parsePrice(b.priceCtrl.text) > 0)
        .map((b) => AddBuy(
              price:    _parsePrice(b.priceCtrl.text),
              quantity: _parseQty(b.qtyCtrl.text),
              date:     b.date,
            ))
        .toList();

    final sells = _sells
        .where((s) => _parseQty(s.qtyCtrl.text) > 0 && _parsePrice(s.priceCtrl.text) > 0)
        .map((s) => SellOrder(
              price:       _parsePrice(s.priceCtrl.text),
              quantity:    _parseQty(s.qtyCtrl.text),
              reason:      s.reasonCtrl.text.trim().isEmpty ? null : s.reasonCtrl.text.trim(),
              date:        s.date,
              exitType:    s.exitType,
              exitEmotion: s.exitEmotion,
            ))
        .toList();

    final log = TradeLog(
      id:            id,
      symbol:        _symbolCtrl.text.trim().toUpperCase(),
      tradeDate:     _tradeDate,
      entryPrice:    _parsePrice(_entryPriceCtrl.text),
      entryQuantity: _parseQty(_quantityCtrl.text),
      entryReason:   _entryReasonCtrl.text.trim(),
      pattern:       _pattern,
      addBuys:       addBuys,
      sellOrders:    sells,
      aiReview:      widget.existing?.aiReview,
    );

    await _service.save(log);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final avgPrice   = _calcAvgPrice();
    final totalBuyQty = _calcTotalBuyQty();
    final totalSold  = _calcTotalSold();
    final remaining  = totalBuyQty - totalSold;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text((widget.existing == null && widget.existingId == null)
            ? 'Ghi lệnh mới' : 'Chỉnh sửa lệnh'),
        actions: [
          if (_saving)
            const Padding(padding: EdgeInsets.all(14),
                child: SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2)))
          else
            TextButton(
              onPressed: _save,
              child: const Text('Lưu',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── VÀO LỆNH ───────────────────────────────────────────────────
            _SectionHeader('📥 THÔNG TIN VÀO LỆNH'),
            const SizedBox(height: 12),

            // Symbol + Date
            Row(children: [
              Expanded(child: _Field(
                controller: _symbolCtrl, label: 'Mã CK', hint: 'VD: VNM',
                textCapitalization: TextCapitalization.characters,
                validator: (v) => (v == null || v.isEmpty) ? 'Bắt buộc' : null,
              )),
              const SizedBox(width: 12),
              _DateButton(date: _tradeDate, onPicked: (d) => setState(() => _tradeDate = d)),
            ]),
            const SizedBox(height: 10),

            // Giá + KL
            Row(children: [
              Expanded(child: _Field(
                controller: _entryPriceCtrl, label: 'Giá vào', hint: '38.000',
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandInputFormatter()],
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Bắt buộc';
                  if (_parsePrice(v) == 0) return 'Số không hợp lệ';
                  return null;
                },
              )),
              const SizedBox(width: 12),
              Expanded(child: _Field(
                controller: _quantityCtrl, label: 'Khối lượng', hint: '1.000',
                keyboardType: TextInputType.number,
                inputFormatters: [ThousandInputFormatter()],
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Bắt buộc';
                  if (_parseQty(v) == 0) return 'Số nguyên';
                  return null;
                },
              )),
            ]),
            const SizedBox(height: 10),

            // SL display
            if (_ep != null && _ep! > 0)
              _SlBox(sl50: _ep! * 0.96, sl100: _ep! * 0.92, fmtPrice: _fmtPrice),
            const SizedBox(height: 10),

            // Pattern
            _DropdownField<TradePattern>(
              label: 'Mẫu hình nhận diện', value: _pattern,
              items: TradePattern.values, labelOf: (e) => e.label,
              onChanged: (e) => setState(() => _pattern = e!),
            ),
            const SizedBox(height: 10),

            _Field(
              controller: _entryReasonCtrl, label: 'Lý do vào lệnh',
              hint: 'Mô tả tín hiệu, bối cảnh...', maxLines: 3,
              validator: (v) => (v == null || v.isEmpty) ? 'Bắt buộc' : null,
            ),

            // ── MUA THÊM ───────────────────────────────────────────────────
            const SizedBox(height: 24),
            Row(children: [
              _SectionHeader('➕ MUA THÊM'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _addBuys.add(_AddBuyForm(
                  priceCtrl: TextEditingController(),
                  qtyCtrl:   TextEditingController(),
                  date:      DateTime.now(),
                ))),
                icon: const Icon(Icons.add, size: 16, color: AppColors.accent),
                label: const Text('Thêm', style: TextStyle(color: AppColors.accent, fontSize: 12)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ]),

            // Giá TB preview (nếu có mua thêm)
            if (_addBuys.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Row(children: [
                  const Icon(Icons.calculate_rounded, size: 14, color: AppColors.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'Giá TB: ${_fmtPrice(avgPrice)}  •  Tổng KL: ${NumberFormat('#,##0', 'vi_VN').format(totalBuyQty)}',
                    style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                  )),
                ]),
              ),
            ],

            ..._addBuys.asMap().entries.map((entry) {
              final i = entry.key;
              final b = entry.value;
              return _AddBuyRow(
                key: ValueKey('ab$i'),
                form: b,
                index: i,
                onRemove: () => setState(() => _addBuys.removeAt(i)),
                onChanged: () => setState(() {}),
              );
            }),

            // ── LỆNH BÁN ───────────────────────────────────────────────────
            const SizedBox(height: 24),
            Row(children: [
              _SectionHeader('📤 LỆNH BÁN'),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _sells.add(_SellForm(
                  priceCtrl:   TextEditingController(),
                  qtyCtrl:     TextEditingController(),
                  reasonCtrl:  TextEditingController(),
                  date:        DateTime.now(),
                ))),
                icon: const Icon(Icons.add, size: 16, color: AppColors.increase),
                label: const Text('Thêm lệnh bán',
                    style: TextStyle(color: AppColors.increase, fontSize: 12)),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
              ),
            ]),

            // Tổng còn lại
            if (_sells.isNotEmpty && totalBuyQty > 0) ...[
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: (remaining > 0 ? AppColors.accent : AppColors.increase).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: (remaining > 0 ? AppColors.accent : AppColors.increase).withValues(alpha: 0.3),
                    width: 0.5,
                  ),
                ),
                child: Text(
                  remaining > 0
                    ? '📦 Đã bán ${NumberFormat('#,##0','vi_VN').format(totalSold)}  •  Còn giữ ${NumberFormat('#,##0','vi_VN').format(remaining)}'
                    : '✅ Đã bán hết ${NumberFormat('#,##0','vi_VN').format(totalSold)} cổ phiếu',
                  style: TextStyle(
                    fontSize: 12,
                    color: remaining > 0 ? AppColors.accent : AppColors.increase,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],

            ..._sells.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              return _SellOrderRow(
                key: ValueKey('sell$i'),
                form: s,
                index: i,
                onRemove: () => setState(() => _sells.removeAt(i)),
                onChanged: () => setState(() {}),
              );
            }),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── State objects ────────────────────────────────────────────────────────────

class _AddBuyForm {
  final TextEditingController priceCtrl;
  final TextEditingController qtyCtrl;
  DateTime date;
  _AddBuyForm({required this.priceCtrl, required this.qtyCtrl, required this.date});
}

class _SellForm {
  final TextEditingController priceCtrl;
  final TextEditingController qtyCtrl;
  final TextEditingController reasonCtrl;
  ExitType?    exitType;
  ExitEmotion? exitEmotion;
  DateTime? date;
  _SellForm({
    required this.priceCtrl, required this.qtyCtrl,
    required this.reasonCtrl, this.exitType, this.exitEmotion, this.date,
  });
}

// ─── AddBuy Row ───────────────────────────────────────────────────────────────

class _AddBuyRow extends StatefulWidget {
  final _AddBuyForm form;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _AddBuyRow({super.key, required this.form, required this.index,
      required this.onRemove, required this.onChanged});

  @override
  State<_AddBuyRow> createState() => _AddBuyRowState();
}

class _AddBuyRowState extends State<_AddBuyRow> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('Mua thêm #${widget.index + 1}',
                  style: const TextStyle(fontSize: 10, color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
            const Spacer(),
            GestureDetector(
              onTap: widget.onRemove,
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Field(
              controller: widget.form.priceCtrl,
              label: 'Giá mua thêm', hint: '40.000',
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandInputFormatter()],
              onChanged: (_) => widget.onChanged(),
            )),
            const SizedBox(width: 10),
            Expanded(child: _Field(
              controller: widget.form.qtyCtrl,
              label: 'KL mua thêm', hint: '500',
              keyboardType: TextInputType.number,
              inputFormatters: [ThousandInputFormatter()],
              onChanged: (_) => widget.onChanged(),
            )),
          ]),
          // Ngày mua thêm
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: widget.form.date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (d != null) setState(() => widget.form.date = d);
            },
            child: Row(children: [
              const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(DateFormat('dd/MM/yyyy').format(widget.form.date),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ]),
          ),
        ],
      ),
    );
  }
}

// ─── Sell Order Row ───────────────────────────────────────────────────────────

class _SellOrderRow extends StatefulWidget {
  final _SellForm form;
  final int index;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  const _SellOrderRow({super.key, required this.form, required this.index,
      required this.onRemove, required this.onChanged});

  @override
  State<_SellOrderRow> createState() => _SellOrderRowState();
}

class _SellOrderRowState extends State<_SellOrderRow> {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.increase.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.increase.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text('Lệnh bán #${widget.index + 1}',
                style: const TextStyle(fontSize: 10, color: AppColors.increase, fontWeight: FontWeight.w700)),
          ),
          const Spacer(),
          GestureDetector(
            onTap: widget.onRemove,
            child: const Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
          ),
        ]),
        const SizedBox(height: 8),

        // Giá + KL bán
        Row(children: [
          Expanded(child: _Field(
            controller: widget.form.priceCtrl,
            label: 'Giá bán', hint: '42.000',
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandInputFormatter()],
            onChanged: (_) => widget.onChanged(),
          )),
          const SizedBox(width: 10),
          Expanded(child: _Field(
            controller: widget.form.qtyCtrl,
            label: 'KL bán', hint: '1.000',
            keyboardType: TextInputType.number,
            inputFormatters: [ThousandInputFormatter()],
            onChanged: (_) => widget.onChanged(),
          )),
        ]),
        const SizedBox(height: 8),

        // Loại thoát
        _DropdownField<ExitType?>(
          label: 'Loại thoát',
          value: widget.form.exitType,
          items: ExitType.values,
          labelOf: (e) => e?.label ?? '-',
          onChanged: (e) => setState(() => widget.form.exitType = e),
        ),
        const SizedBox(height: 8),

        // Lý do bán
        _Field(
          controller: widget.form.reasonCtrl,
          label: 'Lý do bán', hint: 'Tại sao bán?', maxLines: 2,
        ),
        const SizedBox(height: 8),

        // Cảm xúc
        const Text('Cảm xúc', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 6,
          children: ExitEmotion.values.map((e) => ChoiceChip(
            label: Text(e.label, style: const TextStyle(fontSize: 11)),
            selected: widget.form.exitEmotion == e,
            onSelected: (_) => setState(() => widget.form.exitEmotion = e),
            selectedColor: AppColors.accentGlow,
            labelStyle: TextStyle(
              fontSize: 11,
              color: widget.form.exitEmotion == e ? AppColors.accent : AppColors.textSecondary,
            ),
          )).toList(),
        ),

        // Ngày bán
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: widget.form.date ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (d != null) setState(() => widget.form.date = d);
          },
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, size: 13, color: AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              widget.form.date != null
                  ? DateFormat('dd/MM/yyyy').format(widget.form.date!)
                  : 'Chọn ngày bán',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ]),
        ),
      ]),
    );
  }
}

// ─── Sub Widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: AppColors.textSecondary, letterSpacing: 1));
}

class _DateButton extends StatelessWidget {
  final DateTime date;
  final void Function(DateTime) onPicked;
  const _DateButton({required this.date, required this.onPicked});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () async {
      final d = await showDatePicker(
        context: context, initialDate: date,
        firstDate: DateTime(2020), lastDate: DateTime.now(),
      );
      if (d != null) onPicked(d);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(DateFormat('dd/MM/yyyy').format(date),
            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
      ]),
    ),
  );
}

class _SlBox extends StatelessWidget {
  final double sl50, sl100;
  final String Function(double) fmtPrice;
  const _SlBox({required this.sl50, required this.sl100, required this.fmtPrice});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.decrease.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.decrease.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Row(children: [
      const Icon(Icons.shield_outlined, size: 16, color: AppColors.decrease),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'SL −4%: ${fmtPrice(sl50)}  (cắt 1/2)        SL −8%: ${fmtPrice(sl100)}  (cắt hết)',
        style: const TextStyle(fontSize: 11, color: AppColors.decrease),
      )),
    ]),
  );
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  const _Field({
    required this.controller, required this.label, required this.hint,
    this.maxLines = 1, this.keyboardType, this.validator, this.onChanged,
    this.textCapitalization = TextCapitalization.sentences,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller, maxLines: maxLines, keyboardType: keyboardType,
    textCapitalization: textCapitalization, validator: validator,
    onChanged: onChanged, inputFormatters: inputFormatters,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      labelText: label, hintText: hint,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      hintStyle:  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      filled: true, fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.accent)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final void Function(T?) onChanged;

  const _DropdownField({
    required this.label, required this.value, required this.items,
    required this.labelOf, required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    initialValue: value,
    items: items.map((e) => DropdownMenuItem(value: e, child: Text(labelOf(e)))).toList(),
    onChanged: onChanged,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
    dropdownColor: AppColors.card,
    decoration: InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      filled: true, fillColor: AppColors.card,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.border, width: 0.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

// ─── ThousandInputFormatter ───────────────────────────────────────────────────

class ThousandInputFormatter extends TextInputFormatter {
  final _fmt = NumberFormat('#,##0', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll('.', '').replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    final number = int.tryParse(raw);
    if (number == null) return oldValue;
    final formatted = _fmt.format(number);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
