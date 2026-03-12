import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/models/stock_quote.dart';

class ChartScreen extends ConsumerStatefulWidget {
  final String symbol;
  const ChartScreen({super.key, required this.symbol});

  @override
  ConsumerState<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends ConsumerState<ChartScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF131722))
      ..addJavaScriptChannel(
        'FlutterBridge',
        onMessageReceived: (msg) {
          debugPrint('Chart → Flutter: ${msg.message}');
          if (msg.message.startsWith('DOM_READY')) {
            _injectConfig();
            // DATA_LOADED: chart has rendered
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) => _injectConfig(),
        onWebResourceError: (e) => debugPrint('WebView err: ${e.description}'),
      ));

    final html = await rootBundle.loadString('assets/chart.html');
    await _controller.loadHtmlString(html, baseUrl: 'about:blank');
  }

  Future<void> _injectConfig() async {
    final serverUrl = ref.read(serverIpProvider);
    final sym = widget.symbol.toUpperCase().trim();
    final safeUrl = serverUrl.replaceAll("'", "\\'");
    final js = '''
      if (typeof setConfig === 'function') {
        setConfig('$safeUrl', '${sym.replaceAll("'", "\\'")}', '1D');
      }
    ''';
    try {
      await _controller.runJavaScript(js);
    } catch (e) {
      debugPrint('injectConfig error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final boardAsync = ref.watch(priceBoardProvider);
    StockQuote? quote;
    boardAsync.whenData((quotes) {
      try { quote = quotes.firstWhere((q) => q.symbol == widget.symbol); }
      catch (_) {}
    });

    final priceColor = quote == null ? AppColors.textPrimary
        : quote!.isUp ? AppColors.increase
        : quote!.isDown ? AppColors.decrease
        : AppColors.reference;

    return Scaffold(
      backgroundColor: const Color(0xFF131722),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E222D),
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Row(children: [
          Text(widget.symbol,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary)),
          if (quote != null) ...[
            const SizedBox(width: 10),
            Text(quote!.priceStr,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: priceColor, fontFamily: 'monospace')),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: priceColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(quote!.changePctStr,
                  style: TextStyle(fontSize: 11, color: priceColor,
                      fontWeight: FontWeight.w700, fontFamily: 'monospace')),
            ),
          ],
        ]),
        actions: [
          Consumer(builder: (ctx, ref2, _) {
            final inWl = ref2.watch(watchlistProvider).contains(widget.symbol);
            return IconButton(
              icon: Icon(
                inWl ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                color: inWl ? AppColors.accent : AppColors.textSecondary,
                size: 22,
              ),
              onPressed: () {
                final n = ref2.read(watchlistProvider.notifier);
                inWl ? n.remove(widget.symbol) : n.add(widget.symbol);
              },
            );
          }),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
