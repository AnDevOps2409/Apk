import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/models/trade_log.dart';
import '../../../core/services/trade_log_service.dart';
import '../../../core/theme/app_theme.dart';

class AddTradeScreen extends StatefulWidget {
  final TradeLog? existing;
  final String?   existingId; // dùng khi navigate từ router
  const AddTradeScreen({super.key, this.existing, this.existingId});

  @override
  State<AddTradeScreen> createState() => _AddTradeScreenState();
}

class _AddTradeScreenState extends State<AddTradeScreen> {
  final _service  = TradeLogService();
  final _formKey  = GlobalKey<FormState>();
  bool _saving    = false;
  bool _showExit  = false;

  // Controllers — Entry
  final _symbolCtrl       = TextEditingController();
  final _entryPriceCtrl   = TextEditingController();
  final _quantityCtrl     = TextEditingController();
  final _entryReasonCtrl  = TextEditingController();
  TradePattern _pattern   = TradePattern.testForSupply;
  DateTime _tradeDate     = DateTime.now();

  // Controllers — Exit
  final _exitPriceCtrl    = TextEditingController();
  final _exitQuantityCtrl = TextEditingController();
  final _exitReasonCtrl   = TextEditingController();
  ExitType?    _exitType;
  ExitEmotion? _exitEmotion;

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _prefill(widget.existing!);
    } else if (widget.existingId != null) {
      // Load from service when opened via router with ID
      _service.loadAll().then((all) {
        final found = all.where((e) => e.id == widget.existingId).firstOrNull;
        if (found != null && mounted) _prefill(found);
      });
    }
  }

  void _prefill(TradeLog e) {
    final fmt  = NumberFormat('#,##0', 'vi_VN');
    setState(() {
      _symbolCtrl.text      = e.symbol;
      _entryPriceCtrl.text  = fmt.format(e.entryPrice.round());
      _quantityCtrl.text    = fmt.format(e.entryQuantity);
      _entryReasonCtrl.text = e.entryReason;
      _pattern              = e.pattern;
      _tradeDate            = e.tradeDate;
      if (e.isClosed) {
        _showExit = true;
        _exitPriceCtrl.text    = fmt.format(e.exitPrice!.round());
        if (e.exitQuantity != null) {
          _exitQuantityCtrl.text = fmt.format(e.exitQuantity!);
        }
        _exitReasonCtrl.text = e.exitReason ?? '';
        _exitType            = e.exitType;
        _exitEmotion         = e.exitEmotion;
      }
    });
  }

  @override
  void dispose() {
    _symbolCtrl.dispose(); _entryPriceCtrl.dispose();
    _quantityCtrl.dispose(); _entryReasonCtrl.dispose();
    _exitPriceCtrl.dispose(); _exitQuantityCtrl.dispose();
    _exitReasonCtrl.dispose();
    super.dispose();
  }

  /// Strip dấu chấm ngàn trước khi parse ("38.000" → 38000.0)
  double? get _ep    => double.tryParse(_entryPriceCtrl.text.replaceAll('.', ''));
  double  get _sl50  => (_ep ?? 0) * 0.96;
  double  get _sl100 => (_ep ?? 0) * 0.92;

  /// Format giá kiểu Việt: 38000 → 38.000
  String _fmtPrice(double v) => NumberFormat('#,##0', 'vi_VN').format(v.round());

  /// Strip dấu chấm ngàn trước parse
  double _parsePrice(String s) => double.tryParse(s.replaceAll('.', '')) ?? 0;
  int    _parseQty(String s)   => int.tryParse(s.replaceAll('.', '')) ?? 0;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final id  = widget.existing?.id ?? widget.existingId ?? DateTime.now().millisecondsSinceEpoch.toString();
    double? exitPrice;
    int? exitQuantity;
    if (_showExit && _exitPriceCtrl.text.isNotEmpty) {
      exitPrice = _parsePrice(_exitPriceCtrl.text);
      // Chỉ lưu exitQuantity nếu user nhập (khác rỗng)
      if (_exitQuantityCtrl.text.isNotEmpty) {
        exitQuantity = _parseQty(_exitQuantityCtrl.text);
      }
    }

    final log = TradeLog(
      id:            id,
      symbol:        _symbolCtrl.text.trim().toUpperCase(),
      tradeDate:     _tradeDate,
      entryPrice:    _parsePrice(_entryPriceCtrl.text),
      entryQuantity: _parseQty(_quantityCtrl.text),
      entryReason:   _entryReasonCtrl.text.trim(),
      pattern:       _pattern,
      exitPrice:     exitPrice,
      exitQuantity:  exitQuantity,
      exitReason:    _showExit ? _exitReasonCtrl.text.trim() : null,
      exitDate:      (_showExit && exitPrice != null) ? DateTime.now() : null,
      exitType:      _showExit ? _exitType : null,
      exitEmotion:   _showExit ? _exitEmotion : null,
      aiReview:      widget.existing?.aiReview,
    );

    await _service.save(log);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Ghi lệnh mới' : 'Chỉnh sửa lệnh'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else
            TextButton(
              onPressed: _save,
              child: const Text('Lưu', style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── ENTRY ──────────────────────────────────────────────────────
            _SectionHeader('📥 THÔNG TIN VÀO LỆNH'),
            const SizedBox(height: 12),

            // Symbol + Date row
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _symbolCtrl,
                    label: 'Mã CK',
                    hint: 'VD: VNM',
                    textCapitalization: TextCapitalization.characters,
                    validator: (v) => (v == null || v.isEmpty) ? 'Bắt buộc' : null,
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: _tradeDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (d != null) setState(() => _tradeDate = d);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border, width: 0.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text(dateFmt.format(_tradeDate),
                            style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Price + Qty row
            Row(
              children: [
                Expanded(
                  child: _Field(
                    controller: _entryPriceCtrl,
                    label: 'Giá vào',
                    hint: '38.000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandInputFormatter()],
                    onChanged: (_) => setState(() {}),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Bắt buộc';
                      if (int.tryParse(v.replaceAll('.', '')) == null) return 'Số không hợp lệ';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Field(
                    controller: _quantityCtrl,
                    label: 'Khối lượng',
                    hint: '1.000',
                    keyboardType: TextInputType.number,
                    inputFormatters: [ThousandInputFormatter()],
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Bắt buộc';
                      if (int.tryParse(v.replaceAll('.', '')) == null) return 'Số nguyên';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // SL display (auto)
            if (_ep != null && _ep! > 0)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.decrease.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.decrease.withValues(alpha: 0.3), width: 0.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, size: 16, color: AppColors.decrease),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'SL −4%: ${_fmtPrice(_sl50)}  (cắt 1/2)        '
                        'SL −8%: ${_fmtPrice(_sl100)}  (cắt hết)',
                        style: const TextStyle(fontSize: 11, color: AppColors.decrease),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),

            // Pattern dropdown
            _DropdownField<TradePattern>(
              label: 'Mẫu hình nhận diện',
              value: _pattern,
              items: TradePattern.values,
              labelOf: (e) => e.label,
              onChanged: (e) => setState(() => _pattern = e!),
            ),
            const SizedBox(height: 10),

            // Reason
            _Field(
              controller: _entryReasonCtrl,
              label: 'Lý do vào lệnh',
              hint: 'Mô tả tín hiệu, bối cảnh...',
              maxLines: 3,
              validator: (v) => (v == null || v.isEmpty) ? 'Bắt buộc' : null,
            ),

            // ── EXIT ───────────────────────────────────────────────────────
            const SizedBox(height: 24),
            Row(
              children: [
                _SectionHeader('📤 THÔNG TIN RA LỆNH'),
                const Spacer(),
                Switch(
                  value: _showExit,
                  onChanged: (v) => setState(() => _showExit = v),
                  activeThumbColor: AppColors.accent,
                ),
              ],
            ),

            if (_showExit) ...[
              const SizedBox(height: 12),
              // Hàng 1: Giá ra + KL bán
              Row(
                children: [
                  Expanded(
                    child: _Field(
                      controller: _exitPriceCtrl,
                      label: 'Giá ra',
                      hint: '42.000',
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandInputFormatter()],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _Field(
                      controller: _exitQuantityCtrl,
                      label: 'KL bán',
                      hint: 'Để trống = bán hết',
                      keyboardType: TextInputType.number,
                      inputFormatters: [ThousandInputFormatter()],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              // Chip "Còn giữ" khi nhập KL bán một phần
              Builder(builder: (_) {
                final entryQty = _parseQty(_quantityCtrl.text);
                final soldQty  = _parseQty(_exitQuantityCtrl.text);
                if (_exitQuantityCtrl.text.isEmpty ||
                    soldQty <= 0 ||
                    soldQty >= entryQty) {
                  return const SizedBox.shrink();
                }
                final remaining = entryQty - soldQty;
                final fmt = NumberFormat('#,##0', 'vi_VN');
                return Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentGlow,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.4), width: 0.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 13, color: AppColors.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Còn giữ: ${fmt.format(remaining)} cổ phiếu',
                          style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 6),
              // Hàng 2: Loại thoát
              _DropdownField<ExitType?>(
                label: 'Loại thoát',
                value: _exitType,
                items: ExitType.values,
                labelOf: (e) => e?.label ?? '-',
                onChanged: (e) => setState(() => _exitType = e),
              ),
              const SizedBox(height: 10),
              _Field(
                controller: _exitReasonCtrl,
                label: 'Lý do bán',
                hint: 'Tại sao bán?',
                maxLines: 2,
              ),
              const SizedBox(height: 10),
              // Emotion chips
              const Text('Cảm xúc khi bán',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: ExitEmotion.values.map((e) => ChoiceChip(
                  label: Text(e.label),
                  selected: _exitEmotion == e,
                  onSelected: (_) => setState(() => _exitEmotion = e),
                  selectedColor: AppColors.accentGlow,
                  labelStyle: TextStyle(
                    fontSize: 12,
                    color: _exitEmotion == e ? AppColors.accent : AppColors.textSecondary,
                  ),
                )).toList(),
              ),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ─── Sub Widgets ──────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
        color: AppColors.textSecondary, letterSpacing: 1),
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
  final List<TextInputFormatter>? inputFormatters; // ← mới

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.maxLines = 1,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.sentences,
    this.validator,
    this.onChanged,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) => TextFormField(
    controller:         controller,
    maxLines:           maxLines,
    keyboardType:       keyboardType,
    textCapitalization: textCapitalization,
    validator:          validator,
    onChanged:          onChanged,
    inputFormatters:    inputFormatters,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
    decoration: InputDecoration(
      labelText:     label,
      hintText:      hint,
      labelStyle:    const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      hintStyle:     const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      filled:        true,
      fillColor:     AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: AppColors.border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: AppColors.border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: AppColors.accent),
      ),
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
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<T>(
    value: value,
    items: items.map((e) => DropdownMenuItem(value: e, child: Text(labelOf(e)))).toList(),
    onChanged: onChanged,
    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
    dropdownColor: AppColors.card,
    decoration: InputDecoration(
      labelText:   label,
      labelStyle:  const TextStyle(fontSize: 12, color: AppColors.textSecondary),
      filled:      true,
      fillColor:   AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: AppColors.border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:   const BorderSide(color: AppColors.border, width: 0.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

// ─── ThousandInputFormatter ───────────────────────────────────────────────────

/// Tự động thêm dấu . ngàn (kiểu Việt) trong lúc gõ.
/// Gõ 38000 → hiển thị 38.000. Parse lại: s.replaceAll('.', '').
class ThousandInputFormatter extends TextInputFormatter {
  final _fmt = NumberFormat('#,##0', 'vi_VN');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Strip tất cả dấu . đã format trước
    final raw = newValue.text.replaceAll('.', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');

    final number = int.tryParse(raw);
    if (number == null) return oldValue; // gõ ký tự lạ → bỏ qua

    final formatted = _fmt.format(number);
    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
