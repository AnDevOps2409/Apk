import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/stock_providers.dart';

// Available timeframes
const _kTimeframes = ['1m', '5m', '15m', '1H', '1D'];

class DualChartScreen extends ConsumerStatefulWidget {
  const DualChartScreen({super.key});

  @override
  ConsumerState<DualChartScreen> createState() => _DualChartScreenState();
}

class _DualChartScreenState extends ConsumerState<DualChartScreen> {
  // Pane 1: phái sinh (default VN30F1M 5m)
  String _symbol1 = 'VN30F1M';
  String _tf1     = '5m';
  // Pane 2: cổ phiếu (default VCB 1H)
  String _symbol2 = 'VCB';
  String _tf2     = '1H';

  double _splitRatio = 0.5;

  late WebViewController _ctrl1;
  late WebViewController _ctrl2;
  bool _ready1  = false;
  bool _ready2  = false;
  String _htmlContent = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = ref.read(sharedPreferencesProvider);
    _splitRatio = prefs.getDouble('dual_split_ratio') ?? 0.5;
    _symbol1    = prefs.getString('dual_sym1') ?? 'VN30F1M';
    _tf1        = prefs.getString('dual_tf1')  ?? '5m';
    _symbol2    = prefs.getString('dual_sym2') ?? 'VCB';
    _tf2        = prefs.getString('dual_tf2')  ?? '1H';

    _htmlContent = await rootBundle.loadString('assets/chart.html');

    _ctrl1 = await _buildCtrl(_symbol1, _tf1, () { if (mounted) setState(() => _ready1 = true); });
    _ctrl2 = await _buildCtrl(_symbol2, _tf2, () { if (mounted) setState(() => _ready2 = true); });
    if (mounted) setState(() {});
  }

  Future<WebViewController> _buildCtrl(
      String symbol, String tf, VoidCallback onReady) async {
    final ctrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF131722));

    ctrl.addJavaScriptChannel('FlutterBridge', onMessageReceived: (msg) {
      if (msg.message.startsWith('DOM_READY') ||
          msg.message.startsWith('DATA_LOADED')) {
        _inject(ctrl, symbol, tf);
        if (msg.message.startsWith('DATA_LOADED')) onReady();
      }
    });
    ctrl.setNavigationDelegate(NavigationDelegate(
      onPageFinished: (_) => _inject(ctrl, symbol, tf),
    ));
    await ctrl.loadHtmlString(_htmlContent, baseUrl: 'about:blank');
    return ctrl;
  }

  Future<void> _inject(WebViewController ctrl, String sym, String tf) async {
    final serverUrl = ref.read(serverIpProvider);
    final safe = serverUrl.replaceAll("'", "\\'");
    final s    = sym.toUpperCase().replaceAll("'", "\\'");
    try {
      await ctrl.runJavaScript(
        "if(typeof setConfig==='function') setConfig('$safe','$s','$tf');",
      );
    } catch (_) {}
  }

  // ── Symbol / TF updaters ────────────────────────────────────────────────

  void _updatePane1(String sym, String tf) async {
    final s = sym.trim().toUpperCase();
    if (s.isEmpty) return;
    setState(() { _symbol1 = s; _tf1 = tf; _ready1 = false; });
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('dual_sym1', s); prefs.setString('dual_tf1', tf);
    _ctrl1 = await _buildCtrl(s, tf, () { if (mounted) setState(() => _ready1 = true); });
    if (mounted) setState(() {});
  }

  void _updatePane2(String sym, String tf) async {
    final s = sym.trim().toUpperCase();
    if (s.isEmpty) return;
    setState(() { _symbol2 = s; _tf2 = tf; _ready2 = false; });
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString('dual_sym2', s); prefs.setString('dual_tf2', tf);
    _ctrl2 = await _buildCtrl(s, tf, () { if (mounted) setState(() => _ready2 = true); });
    if (mounted) setState(() {});
  }

  // ── UI ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_htmlContent.isEmpty) {
      return const Scaffold(backgroundColor: Color(0xFF131722));
    }
    try { _ctrl1; _ctrl2; } catch (_) {
      return const Scaffold(backgroundColor: Color(0xFF131722));
    }

    const divH = 10.0;
    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final totalH = constraints.maxHeight;
          final topH   = (totalH - divH) * _splitRatio;
          final botH   = totalH - divH - topH;
          return Column(children: [
            SizedBox(
              height: topH,
              child: _ChartPane(
                symbol: _symbol1, tf: _tf1,
                controller: _ctrl1, loading: !_ready1,
                onChanged: _updatePane1,
                paneLabel: '🔶 Phái sinh',
              ),
            ),

            // Draggable divider
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (d) => setState(() {
                _splitRatio = (_splitRatio + d.delta.dy / totalH).clamp(0.20, 0.80);
              }),
              onVerticalDragEnd: (_) => ref
                  .read(sharedPreferencesProvider)
                  .setDouble('dual_split_ratio', _splitRatio),
              child: Container(
                height: divH,
                color: const Color(0xFF1E222D),
                child: Center(
                  child: Icon(Icons.drag_handle_rounded,
                      size: 14,
                      color: AppColors.textSecondary.withValues(alpha: 0.4)),
                ),
              ),
            ),

            SizedBox(
              height: botH,
              child: _ChartPane(
                symbol: _symbol2, tf: _tf2,
                controller: _ctrl2, loading: !_ready2,
                onChanged: _updatePane2,
                paneLabel: '📈 Cổ phiếu',
              ),
            ),
          ]);
        }),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
class _ChartPane extends StatefulWidget {
  final String symbol;
  final String tf;
  final WebViewController controller;
  final bool loading;
  final void Function(String sym, String tf) onChanged;
  final String paneLabel;

  const _ChartPane({
    required this.symbol, required this.tf,
    required this.controller, required this.loading,
    required this.onChanged, required this.paneLabel,
  });

  @override
  State<_ChartPane> createState() => _ChartPaneState();
}

class _ChartPaneState extends State<_ChartPane> {
  late TextEditingController _symCtrl;
  late String _selectedTf;

  @override
  void initState() {
    super.initState();
    _symCtrl     = TextEditingController(text: widget.symbol);
    _selectedTf  = widget.tf;
  }

  @override
  void didUpdateWidget(covariant _ChartPane old) {
    if (old.symbol != widget.symbol) _symCtrl.text = widget.symbol;
    if (old.tf != widget.tf)         _selectedTf   = widget.tf;
    super.didUpdateWidget(old);
  }

  @override
  void dispose() { _symCtrl.dispose(); super.dispose(); }

  void _submit() {
    final s = _symCtrl.text.trim().toUpperCase();
    if (s.isNotEmpty) widget.onChanged(s, _selectedTf);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      // WebView chart
      Positioned.fill(child: WebViewWidget(controller: widget.controller)),

      // Control bar overlay (top of each pane)
      Positioned(
        top: 0, left: 0, right: 0,
        child: Container(
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF1E222D).withValues(alpha: 0.92),
            border: const Border(bottom: BorderSide(color: Color(0xFF2A2E39))),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(children: [
            // Pane type label
            Text(widget.paneLabel,
                style: const TextStyle(fontSize: 9, color: AppColors.textSecondary)),
            const SizedBox(width: 6),

            // Symbol input
            SizedBox(
              width: 72,
              child: TextField(
                controller: _symCtrl,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary, fontFamily: 'monospace'),
                decoration: const InputDecoration(
                    isDense: true, border: InputBorder.none,
                    contentPadding: EdgeInsets.zero),
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _submit(),
              ),
            ),

            // TF selector chips
            const SizedBox(width: 4),
            ..._kTimeframes.map((tf) => GestureDetector(
              onTap: () {
                setState(() => _selectedTf = tf);
                widget.onChanged(_symCtrl.text.trim().toUpperCase(), tf);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 3),
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                decoration: BoxDecoration(
                  color: _selectedTf == tf
                      ? AppColors.accent
                      : const Color(0xFF2A2E39),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(tf,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _selectedTf == tf
                          ? Colors.white
                          : AppColors.textSecondary,
                    )),
              ),
            )),

            const Spacer(),

            // Confirm button
            GestureDetector(
              onTap: _submit,
              child: const Icon(Icons.refresh_rounded,
                  size: 16, color: AppColors.accent),
            ),
          ]),
        ),
      ),

      // Loading overlay
      if (widget.loading)
        Container(
          color: const Color(0xFF131722),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(
                  color: AppColors.accent, strokeWidth: 2),
              const SizedBox(height: 8),
              Text('${widget.symbol} (${widget.tf})...',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12)),
            ]),
          ),
        ),
    ]);
  }
}
