import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/models/data_source.dart';
import '../../core/providers/stock_providers.dart';

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
    final mode   = ref.watch(dataSourceModeProvider);
    final status = ref.watch(serverStatusProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Cài đặt nguồn dữ liệu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          // ── Chọn nguồn dữ liệu ──
          const _SectionLabel('NGUỒN DỮ LIỆU'),
          const SizedBox(height: 8),
          _DataSourceTile(
            mode: DataSourceMode.fdata,
            selected: mode == DataSourceMode.fdata,
            onTap: () {
              ref.read(dataSourceModeProvider.notifier).state = DataSourceMode.fdata;
              ref.invalidate(priceBoardProvider);
              ref.invalidate(marketIndexProvider);
            },
          ),
          const SizedBox(height: 8),
          _DataSourceTile(
            mode: DataSourceMode.realtime,
            selected: mode == DataSourceMode.realtime,
            onTap: () {
              ref.read(dataSourceModeProvider.notifier).state = DataSourceMode.realtime;
              ref.invalidate(priceBoardProvider);
              ref.invalidate(marketIndexProvider);
            },
          ),

          // ── FData Server Config ──
          if (mode == DataSourceMode.fdata) ...[
            const SizedBox(height: 24),
            const _SectionLabel('CÀI ĐẶT SERVER (FData)'),
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
            // Retry button
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
            // Hướng dẫn
            _HowToCard(),
          ],

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
                  Text('Phase 1 — FData + Mock data\nPhase 2 — MQTT Realtime',
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

class _DataSourceTile extends StatelessWidget {
  final DataSourceMode mode;
  final bool selected;
  final VoidCallback onTap;
  const _DataSourceTile({required this.mode, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accent : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentGlow : AppColors.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.accent : AppColors.border,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Row(
          children: [
            Icon(
              mode == DataSourceMode.fdata
                  ? Icons.folder_open_rounded
                  : Icons.wifi_rounded,
              color: color, size: 22,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.description,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
          ],
        ),
      ),
    );
  }
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
