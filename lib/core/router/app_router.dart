// ignore: unused_import - GoRouter uses BuildContext indirectly
import 'package:go_router/go_router.dart';
import '../../features/price_board/price_board_screen.dart';
import '../../features/chart/chart_screen.dart';
import '../../features/chart/dual_chart_screen.dart';
import '../../features/watchlist/watchlist_screen.dart';
import '../../features/market_overview/market_overview_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/journal/journal_screen.dart';
import '../../features/journal/add_trade_screen.dart';
import '../../features/journal/trade_detail_screen.dart';
import '../../features/journal/ai_coach_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/journal',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/market',
          pageBuilder: (context, state) => const NoTransitionPage(child: MarketOverviewScreen()),
        ),
        GoRoute(
          path: '/board',
          pageBuilder: (context, state) => const NoTransitionPage(child: PriceBoardScreen()),
        ),
        GoRoute(
          path: '/watchlist',
          pageBuilder: (context, state) => const NoTransitionPage(child: WatchlistScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => const NoTransitionPage(child: SettingsScreen()),
        ),
        GoRoute(
          path: '/dual',
          pageBuilder: (context, state) => const NoTransitionPage(child: DualChartScreen()),
        ),
        GoRoute(
          path: '/journal',
          pageBuilder: (context, state) => const NoTransitionPage(child: JournalScreen()),
        ),
        GoRoute(
          path: '/coach',
          pageBuilder: (context, state) => const NoTransitionPage(child: AiCoachScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/chart/:symbol',
      builder: (context, state) {
        final symbol = state.pathParameters['symbol'] ?? '';
        return ChartScreen(symbol: symbol);
      },
    ),
    GoRoute(
      path: '/journal/add',
      builder: (_, __) => const AddTradeScreen(),
    ),
    GoRoute(
      path: '/journal/:id',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return TradeDetailScreen(tradeId: id);
      },
    ),
    GoRoute(
      path: '/journal/:id/edit',
      builder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        return AddTradeScreen(existingId: id);
      },
    ),
  ],
);
