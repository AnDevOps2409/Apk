import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

/// Shell chứa bottom navigation 6 tabs — financial-style, không ripple
class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    if (location.startsWith('/journal'))   return 0;
    if (location.startsWith('/coach'))     return 1;
    if (location.startsWith('/settings'))  return 2;
    return 0;
  }

  static const _items = [
    _NavItem(icon: Icons.book_rounded,             label: 'Nhật ký',   route: '/journal'),
    _NavItem(icon: Icons.psychology_alt_rounded,   label: 'AI Coach',  route: '/coach'),
    _NavItem(icon: Icons.settings_rounded,         label: 'Cài đặt',   route: '/settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final idx = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(
        currentIndex: idx,
        items: _items,
        onTap: (i) => context.go(_items[i].route),
      ),
    );
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  const _NavItem({required this.icon, required this.label, required this.route});
}

// ─── Custom Bottom Nav ────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final void Function(int) onTap;
  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // safe area inset (home bar trên iPhone / gesture nav bar Android)
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 0.5),
        ),
      ),
      // padding top cố định 8, bottom = safeBottom + 8
      padding: EdgeInsets.only(top: 8, bottom: safeBottom + 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: items.asMap().entries.map((e) => Expanded(
          child: _NavButton(
            item: e.value,
            selected: e.key == currentIndex,
            onTap: () => onTap(e.key),
          ),
        )).toList(),
      ),
    );
  }
}

// ─── Individual Nav Button ────────────────────────────────────────────────────

class _NavButton extends StatelessWidget {
  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;
  const _NavButton({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [

          // ── Indicator line ở trên ──────────────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            height: 2,
            width: selected ? 24 : 0,
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Icon ──────────────────────────────────────────────────────
          AnimatedScale(
            scale: selected ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Icon(
              item.icon,
              size: 22,
              color: selected ? AppColors.accent : AppColors.textDisabled,
            ),
          ),

          // ── Label — chỉ hiện khi selected ─────────────────────────────
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: selected
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                item.label,
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accent,
                  letterSpacing: 0.1,
                ),
              ),
            ),
            secondChild: const SizedBox(height: 14.5), // giữ height ổn định
          ),
        ],
      ),
    );
  }
}
