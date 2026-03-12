import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 100 + MediaQuery.of(context).padding.bottom),
        children: [

          // ── FData Server Config (luôn hiện) ──
          const _SectionLabel('📶 DNSE SERVER'),
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
                      labelText: 'Địa chỉ PC (IP:Port)',
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
              text: 'Đang kết nối đến server...',
            ),
            data: (ok) => _StatusRow(
              icon: ok ? Icons.check_circle_rounded : Icons.error_rounded,
              color: ok ? AppColors.increase : AppColors.decrease,
              text: ok
                  ? 'Kết nối thành công ✅'
                  : 'Không kết nối được ❌\nKiểm tra:\n  • PC và điện thoại cùng WiFi\n  • fdata_server.py đang chạy\n  • Firewall cho phép port 8765',
            ),
            error: (e, _) => _StatusRow(
              icon: Icons.error_outline_rounded,
              color: AppColors.decrease,
              text: 'Lỗi: $e',
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
            label: const Text('Kiểm tra kết nối lại'),
          ),

          const SizedBox(height: 24),
          _HowToCard(),

          // ── AI Coach ──
          const SizedBox(height: 24),
          const _SectionLabel('🤖 AI COACH'),
          const SizedBox(height: 8),
          _GeminiKeyTile(),

          // ── Bảng Phân Tích HT/MT ──
          const SizedBox(height: 24),
          const _SectionLabel('📊 BẢNG PHÂN TÍCH HỖ TRỢ / MỤC TIÊU'),
          const SizedBox(height: 8),
          _MarketLevelsSection(),

          // ── Cập nhật ứng dụng ──
          const SizedBox(height: 24),
          const _SectionLabel('⬆️ CẬP NHẬT ỨNG DỤNG'),
          const SizedBox(height: 8),
          const _UpdateSection(),

          // ── About ──
          const SizedBox(height: 24),
          const _SectionLabel('THÔNG TIN'),
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


// ─── Sub Widgets ─────────────────────────────────────────────────────────────

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
            Text('Cách chạy FData Server', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            SizedBox(height: 8),
            Text(
              '1. Mở CMD/PowerShell trên PC\n'
              '2. Chạy lệnh:\n'
              '   python D:\\ChungKhoan\\fdata_server.py\n\n'
              '3. Xem IP của PC hiển thị trong terminal\n'
              '4. Nhập IP đó vào ô "Địa chỉ PC" bên trên\n'
              '5. Nhấn "Kiểm tra kết nối"',
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
        const Text('Dùng để AI Review giao dịch. Lấy key tại aistudio.google.com',
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
              child: Text(_saved ? '✓ Đã lưu' : 'Lưu',
                  style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
      ],
    ),
  );
}

// ─── Market Levels Section ────────────────────────────────────────────────────

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
      if (bytes == null) throw Exception('Không đọc được file');

      final jsonStr = utf8.decode(bytes);
      final version = _svc.parseJson(jsonStr);
      await _svc.saveVersion(version);
      await _loadHistory();

      setState(() {
        _successMsg = '✅ Đã import ${version.stocks.length} mã — ${version.displayDate}';
      });
    } catch (e) {
      setState(() => _errorMsg = 'Lỗi: $e\n\nHãy kiểm tra format JSON và thử lại.');
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
            'Bảng HT/MT + Dòng Tiền',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          const Text(
            'Dùng ChatGPT extract ảnh bảng sáng → tải JSON về → import vào đây.\n'
            'AI Coach sẽ tự tính khoảng cách HT/MT và cảnh báo thông minh khi anh nhập giá.',
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
                      'Version hiện tại: ${latest.displayDate} — ${latest.stocks.length} mã',
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
                    child: Text('Chưa có bảng phân tích — Import JSON để bắt đầu',
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
                _loading ? 'Đang import...' : '📂 Import JSON bảng mới',
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
            const Text('📜 Lịch sử versions',
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
                                  child: const Text('MỚI NHẤT',
                                      style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700)),
                                ),
                              Text(v.displayDate,
                                  style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700,
                                    color: isLatest ? AppColors.accent : AppColors.textPrimary,
                                  )),
                            ],
                          ),
                          Text('${v.stocks.length} mã',
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

// ── ChatGPT Prompt Card ──────────────────────────────────────────────────────

class _ChatGptPromptCard extends StatelessWidget {
  static const _promptText =
      'Đây là bảng phân tích chứng khoán. Hãy đọc và trả về JSON format sau'
      ' (không giải thích thêm):\n\n'
      '{ "version": "<ISO datetime>", "stocks": [\n'
      '  { "symbol": "GAS", "group": "uu_tien",\n'
      '    "t0_tien_nho": -2, "t0_tien_lon": -4,\n'
      '    "tong_tien_nho": -1, "tong_tien_lon": 9,\n'
      '    "ht1": 106, "ht2": 101, "mt1": 120, "mt2": 130 }\n'
      '] }\n\n'
      'Lưu ý: "101-102" → 101.5 | "120+-" → 120 | '
      'group: "uu_tien" hoặc "khac" | dùng 0 nếu không có số.';

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
            child: const Text('💬 Prompt cho ChatGPT (nhấn giữ để copy):',
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

// ─── Update Section ───────────────────────────────────────────────────────────

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
                  'Cập nhật ứng dụng',
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
                  child: const Text('Mới nhất ✓',
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
                      'Có phiên bản mới: v$_latestVersion',
                      style: const TextStyle(fontSize: 12, color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_state == _UpdateState.error) ...[
            const SizedBox(height: 8),
            Text('❌ $_errorMsg', style: const TextStyle(fontSize: 11, color: AppColors.decrease, height: 1.5)),
          ],

          if (_state == _UpdateState.downloading) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Đang tải...', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
                  Text('Tải xong! Nhấn "Cài đặt" để tiếp tục.',
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
        return _btn(icon: null, label: 'Đang kiểm tra...', onPressed: null, loading: true);
      case _UpdateState.downloading:
        return _btn(icon: null, label: 'Đang tải APK...', onPressed: null, loading: true);
      case _UpdateState.updateAvailable:
        return _btn(
          icon: Icons.download_rounded,
          label: 'Tải bản mới (v$_latestVersion)',
          onPressed: _download,
          color: AppColors.increase,
        );
      case _UpdateState.readyToInstall:
        return _btn(
          icon: Icons.install_mobile_rounded,
          label: 'Cài đặt ngay 🚀',
          onPressed: () => _svc.installApk(_apkPath),
          color: AppColors.increase,
        );
      default:
        return _btn(icon: Icons.search_rounded, label: 'Kiểm tra cập nhật', onPressed: _checkUpdate);
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
