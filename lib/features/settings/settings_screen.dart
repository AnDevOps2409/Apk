import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/market_level.dart';
import '../../core/providers/stock_providers.dart';
import '../../core/services/market_level_service.dart';
import '../../core/services/update_service.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _ipCtrl;

  @override
  void initState() {
    super.initState();
    _ipCtrl = TextEditingController(
      text: ref.read(serverIpProvider),
    );
  }

  @override
  void dispose() {
    _ipCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(serverStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('CÃ i Ä‘áº·t')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + MediaQuery.of(context).padding.bottom),
        children: [

          // â”€â”€ FData Server Config (luÃ´n hiá»‡n) â”€â”€
          const _SectionLabel('ðŸ“¶ DNSE SERVER'),
          const SizedBox(height: 8),
          // IP input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.border, width: 0.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.computer_rounded, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _ipCtrl,
                    style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'http://192.168.1.x:8765',
                      hintStyle: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      border: InputBorder.none,
                      labelText: 'Äá»‹a chá»‰ PC (IP:Port)',
                      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                    ),
                    onChanged: (v) {
                      ref.read(serverIpProvider.notifier).state = v.trim();
                      ref.invalidate(serverStatusProvider);
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Connection status
          status.when(
            loading: () => _StatusRow(
              icon: Icons.sync_rounded,
              color: AppColors.accent,
              text: 'Äang káº¿t ná»‘i Ä‘áº¿n server...',
            ),
            data: (ok) => _StatusRow(
              icon: ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: ok ? AppColors.increase : AppColors.decrease,
              text: ok
                  ? 'Káº¿t ná»‘i thÃ nh cÃ´ng âœ…'
                  : 'KhÃ´ng káº¿t ná»‘i Ä‘Æ°á»£c âŒ\nKiá»ƒm tra:\n  â€¢ PC vÃ  Ä‘iá»‡n thoáº¡i cÃ¹ng WiFi\n  â€¢ fdata_server.py Ä‘ang cháº¡y\n  â€¢ Firewall cho phÃ©p port 8765',
            ),
            error: (e, _) => _StatusRow(
              icon: Icons.error_outline_rounded,
              color: AppColors.decrease,
              text: 'Lá»—i: $e',
            ),
          ),

          const SizedBox(height: 16),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: const BorderSide(color: AppColors.accent),
              padding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onPressed: () => ref.invalidate(serverStatusProvider),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Kiá»ƒm tra káº¿t ná»‘i láº¡i'),
          ),

          const SizedBox(height: 24),
          _HowToCard(),

          // â”€â”€ AI Coach â”€â”€
          const SizedBox(height: 24),
          const _SectionLabel('ðŸ¤– AI COACH'),
          const SizedBox(height: 8),
          _GeminiKeyTile(),

          // â”€â”€ Báº£ng PhÃ¢n TÃ­ch HT/MT â”€â”€
          const SizedBox(height: 24),
          const _SectionLabel('ðŸ“Š Báº¢NG PHÃ‚N TÃCH Há»– TRá»¢ / Má»¤C TIÃŠU'),
          const SizedBox(height: 8),
          _MarketLevelsSection(),

          // â”€â”€ Cáº­p nháº­t á»©ng dá»¥ng â”€â”€
          const SizedBox(height: 24),
          const _SectionLabel('â¬†ï¸ Cáº¬P NHáº¬T á»¨NG Dá»¤NG'),
          const SizedBox(height: 8),
          const _UpdateSection(),

          // â”€â”€ TÃ i khoáº£n â”€â”€
          const SizedBox(height: 24),
          const _SectionLabel('ðŸ‘¤ TÃ€I KHOáº¢N'),
          const SizedBox(height: 8),
          _AccountSection(),

          // â”€â”€ About â”€â”€
          const SizedBox(height: 24),
          const _SectionLabel('THÃ”NG TIN'),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('DNSE Stock App', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                  SizedBox(height: 4),
                  Text('DNSE Stock App\nFData Server + DNSE WebSocket SDK\nTrading Journal + AI Coach',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// â”€â”€â”€ Sub Widgets â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10, fontWeight: FontWeight.w700,
      color: AppColors.textSecondary, letterSpacing: 1.2,
    ),
  );
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _StatusRow({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.6)),
        ),
      ],
    ),
  );
}

class _HowToCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('CÃ¡ch cháº¡y FData Server', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text(
              '1. Má»Ÿ CMD/PowerShell trÃªn PC\n'
              '2. Cháº¡y lá»‡nh:\n'
              '   python D:\\ChungKhoan\\fdata_server.py\n\n'
              '3. Xem IP cá»§a PC hiá»ƒn thá»‹ trong terminal\n'
              '4. Nháº­p IP Ä‘Ã³ vÃ o Ã´ "Äá»‹a chá»‰ PC" bÃªn trÃªn\n'
              '5. Nháº¥n "Kiá»ƒm tra káº¿t ná»‘i"',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeminiKeyTile extends StatefulWidget {
  @override
  State<_GeminiKeyTile> createState() => _GeminiKeyTileState();
}

class _GeminiKeyTileState extends State<_GeminiKeyTile> {
  final _ctrl    = TextEditingController();
  bool _obscure  = true;
  bool _saved    = false;
  static const _prefKey = 'gemini_api_key';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final key = p.getString(_prefKey) ?? '';
      if (mounted) setState(() => _ctrl.text = key);
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKey, _ctrl.text.trim());
    setState(() => _saved = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _saved = false);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.border, width: 0.5),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gemini API Key',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
        const SizedBox(height: 4),
        const Text('DÃ¹ng Ä‘á»ƒ AI Review giao dá»‹ch. Láº¥y key táº¡i aistudio.google.com',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                obscureText: _obscure,
                style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'AIza...',
                  hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: AppColors.border, width: 0.5),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        size: 18, color: AppColors.textSecondary),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _saved ? AppColors.increase : AppColors.accent,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
              child: Text(_saved ? 'âœ“ ÄÃ£ lÆ°u' : 'LÆ°u',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ],
    ),
  );
}

// â”€â”€â”€ Market Levels Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _MarketLevelsSection extends StatefulWidget {
  @override
  State<_MarketLevelsSection> createState() => _MarketLevelsSectionState();
}

class _MarketLevelsSectionState extends State<_MarketLevelsSection> {
  final _svc = MarketLevelService();
  List<MarketLevelVersion> _history = [];
  bool _loading = false;
  String? _errorMsg;
  String? _successMsg;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final h = await _svc.loadHistory();
    if (mounted) setState(() => _history = h);
  }

  Future<void> _importJson() async {
    setState(() { _loading = true; _errorMsg = null; _successMsg = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final bytes = result.files.first.bytes;
      if (bytes == null) throw Exception('KhÃ´ng Ä‘á»c Ä‘Æ°á»£c file');

      final jsonStr = utf8.decode(bytes);
      final version = _svc.parseJson(jsonStr);
      await _svc.saveVersion(version);
      await _loadHistory();

      setState(() {
        _successMsg = 'âœ… ÄÃ£ import ${version.stocks.length} mÃ£ â€” ${version.displayDate}';
      });
    } catch (e) {
      setState(() => _errorMsg = 'Lá»—i: $e\n\nHÃ£y kiá»ƒm tra format JSON vÃ  thá»­ láº¡i.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteVersion(int index) async {
    await _svc.deleteVersion(index);
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final latest = _history.isEmpty ? null : _history.first;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Báº£ng HT/MT + DÃ²ng Tiá»n',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'DÃ¹ng ChatGPT extract áº£nh báº£ng sÃ¡ng â†’ táº£i JSON vá» â†’ import vÃ o Ä‘Ã¢y.\n'
            'AI Coach sáº½ tá»± tÃ­nh khoáº£ng cÃ¡ch HT/MT vÃ  cáº£nh bÃ¡o thÃ´ng minh khi anh nháº­p giÃ¡.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.6),
          ),

          const SizedBox(height: 10),
          _ChatGptPromptCard(),

          const SizedBox(height: 12),
          if (latest != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.increase.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.increase.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.increase, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Version hiá»‡n táº¡i: ${latest.displayDate} â€” ${latest.stocks.length} mÃ£',
                      style: const TextStyle(fontSize: 12, color: AppColors.increase),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 16),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text('ChÆ°a cÃ³ báº£ng phÃ¢n tÃ­ch â€” Import JSON Ä‘á»ƒ báº¯t Ä‘áº§u',
                        style: TextStyle(fontSize: 12, color: AppColors.accent)),
                  ),
                ],
              ),
            ),

          if (_successMsg != null) ...[
            const SizedBox(height: 8),
            Text(_successMsg!, style: const TextStyle(fontSize: 12, color: AppColors.increase)),
          ],
          if (_errorMsg != null) ...[
            const SizedBox(height: 8),
            Text(_errorMsg!, style: const TextStyle(fontSize: 11, color: AppColors.decrease, height: 1.5)),
          ],

          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _importJson,
              icon: _loading
                  ? const SizedBox(
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 16, color: Colors.white),
              label: Text(
                _loading ? 'Äang import...' : 'ðŸ“‚ Import JSON báº£ng má»›i',
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),

          if (_history.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('ðŸ“œ Lá»‹ch sá»­ versions',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            ..._history.asMap().entries.map((entry) {
              final i = entry.key;
              final v = entry.value;
              final isLatest = i == 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: isLatest ? AppColors.accent.withValues(alpha: 0.06) : AppColors.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isLatest ? AppColors.accent.withValues(alpha: 0.3) : AppColors.border,
                    width: 0.5,
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isLatest)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('Má»šI NHáº¤T',
                                      style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              Text(v.displayDate,
                                  style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: isLatest ? AppColors.accent : AppColors.textPrimary,
                                  )),
                            ],
                          ),
                          Text('${v.stocks.length} mÃ£',
                              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (!isLatest)
                      GestureDetector(
                        onTap: () => _deleteVersion(i),
                        child: const Icon(Icons.delete_outline_rounded,
                            size: 18, color: AppColors.textSecondary),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

// â”€â”€ ChatGPT Prompt Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

class _ChatGptPromptCard extends StatelessWidget {
  static const _promptText =
      'ÄÃ¢y lÃ  báº£ng phÃ¢n tÃ­ch chá»©ng khoÃ¡n. HÃ£y Ä‘á»c vÃ  tráº£ vá» JSON format sau'
      ' (khÃ´ng giáº£i thÃ­ch thÃªm):\n\n'
      '{ "version": "<ISO datetime>", "stocks": [\n'
      '  { "symbol": "GAS", "group": "uu_tien",\n'
      '    "t0_tien_nho": -2, "t0_tien_lon": -4,\n'
      '    "tong_tien_nho": -1, "tong_tien_lon": 9,\n'
      '    "ht1": 106, "ht2": 101, "mt1": 120, "mt2": 130 }\n'
      '] }\n\n'
      'LÆ°u Ã½: "101-102" â†’ 101.5 | "120+-" â†’ 120 | '
      'group: "uu_tien" hoáº·c "khac" | dÃ¹ng 0 náº¿u khÃ´ng cÃ³ sá»‘.';

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
            child: const Text('ðŸ’¬ Prompt cho ChatGPT (nháº¥n giá»¯ Ä‘á»ƒ copy):',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: SelectableText(
              _promptText,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                height: 1.6,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// â”€â”€â”€ Update Section â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

enum _UpdateState { idle, checking, upToDate, updateAvailable, downloading, readyToInstall, error }

class _UpdateSection extends StatefulWidget {
  const _UpdateSection();

  @override
  State<_UpdateSection> createState() => _UpdateSectionState();
}

class _UpdateSectionState extends State<_UpdateSection> {
  final _svc = UpdateService();
  _UpdateState _state = _UpdateState.idle;
  String _latestVersion = '';
  String _apkUrl = '';
  String _apkPath = '';
  double _downloadProgress = 0;
  String _errorMsg = '';

  Future<void> _checkUpdate() async {
    setState(() { _state = _UpdateState.checking; _errorMsg = ''; });
    try {
      final info = await _svc.checkForUpdate();
      if (!mounted) return;
      if (info.hasUpdate) {
        setState(() {
          _state = _UpdateState.updateAvailable;
          _latestVersion = info.latestVersion;
          _apkUrl = info.downloadUrl;
        });
      } else {
        setState(() { _state = _UpdateState.upToDate; _latestVersion = info.latestVersion; });
      }
    } catch (e) {
      if (mounted) setState(() { _state = _UpdateState.error; _errorMsg = e.toString(); });
    }
  }

  Future<void> _download() async {
    setState(() { _state = _UpdateState.downloading; _downloadProgress = 0; });
    try {
      final path = await _svc.downloadApk(_apkUrl, (p) {
        if (mounted) setState(() => _downloadProgress = p);
      });
      if (mounted) setState(() { _state = _UpdateState.readyToInstall; _apkPath = path; });
    } catch (e) {
      if (mounted) setState(() { _state = _UpdateState.error; _errorMsg = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              const Icon(Icons.system_update_rounded, size: 16, color: AppColors.accent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Cáº­p nháº­t á»©ng dá»¥ng',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ),
              if (_state == _UpdateState.upToDate)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.increase.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Má»›i nháº¥t âœ“',
                      style: TextStyle(fontSize: 10, color: AppColors.increase, fontWeight: FontWeight.w700)),
                ),
            ],
          ),

          if (_state == _UpdateState.updateAvailable) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accent.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.new_releases_rounded, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'CÃ³ phiÃªn báº£n má»›i: v$_latestVersion',
                      style: const TextStyle(fontSize: 12, color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_state == _UpdateState.error) ...[
            const SizedBox(height: 8),
            Text('âŒ $_errorMsg', style: const TextStyle(fontSize: 11, color: AppColors.decrease, height: 1.5)),
          ],

          if (_state == _UpdateState.downloading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Äang táº£i...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(width: 8),
                Text(
                  '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(fontSize: 12, color: AppColors.accent, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.accent),
                minHeight: 6,
              ),
            ),
          ],

          if (_state == _UpdateState.readyToInstall) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.increase.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.increase.withValues(alpha: 0.3), width: 0.5),
              ),
              child: const Row(
                children: [
                  Icon(Icons.download_done_rounded, color: AppColors.increase, size: 16),
                  SizedBox(width: 8),
                  Text('Táº£i xong! Nháº¥n "CÃ i Ä‘áº·t" Ä‘á»ƒ tiáº¿p tá»¥c.',
                      style: TextStyle(fontSize: 12, color: AppColors.increase)),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: _buildButton(),
          ),
        ],
      ),
    );
  }

  Widget _buildButton() {
    switch (_state) {
      case _UpdateState.checking:
        return _btn(icon: null, label: 'Äang kiá»ƒm tra...', onPressed: null, loading: true);
      case _UpdateState.downloading:
        return _btn(icon: null, label: 'Äang táº£i APK...', onPressed: null, loading: true);
      case _UpdateState.updateAvailable:
        return _btn(
          icon: Icons.download_rounded,
          label: 'Táº£i báº£n má»›i (v$_latestVersion)',
          onPressed: _download,
          color: AppColors.increase,
        );
      case _UpdateState.readyToInstall:
        return _btn(
          icon: Icons.install_mobile_rounded,
          label: 'CÃ i Ä‘áº·t ngay ðŸš€',
          onPressed: () => _svc.installApk(_apkPath),
          color: AppColors.increase,
        );
      default:
        return _btn(icon: Icons.search_rounded, label: 'Kiá»ƒm tra cáº­p nháº­t', onPressed: _checkUpdate);
    }
  }

  Widget _btn({
    required IconData? icon,
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
    Color? color,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: loading
          ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Icon(icon ?? Icons.search_rounded, size: 16, color: Colors.white),
      label: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color ?? AppColors.accent,
        padding: const EdgeInsets.symmetric(vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _AccountSection extends StatefulWidget {
  const _AccountSection();
  @override
  State<_AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends State<_AccountSection> {
  bool _signingOut = false;

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppColors.accent.withValues(alpha: 0.15),
          backgroundImage: user.photoURL != null ? NetworkImage(user.photoURL!) : null,
          child: user.photoURL == null
              ? const Icon(Icons.person_rounded, color: AppColors.accent, size: 24)
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.displayName ?? 'Nguoi dung',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            if (user.email != null)
              Text(user.email!,
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          ],
        )),
        if (_signingOut)
          const SizedBox(width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.decrease))
        else
          TextButton(
            onPressed: _signOut,
            style: TextButton.styleFrom(foregroundColor: AppColors.decrease),
            child: const Text('Dang xuat', style: TextStyle(fontSize: 12)),
          ),
      ]),
    );
  }
}
