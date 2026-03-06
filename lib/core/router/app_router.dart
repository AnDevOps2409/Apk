// ignore: unused_import - GoRouter uses BuildContext indirectly
import 'package:go_router/go_router.dart';
import '../../features/price_board/price_board_screen.dart';
import '../../features/chart/chart_screen.dart';
import '../../features/watchlist/watchlist_screen.dart';
import '../../features/market_overview/market_overview_screen.dart';
import '../../features/shell/app_shell.dart';

final appRouter = GoRouter(
  initialLocation: '/market',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/market',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MarketOverviewScreen(),
          ),
        ),
        GoRoute(
          path: '/board',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: PriceBoardScreen(),
          ),
        ),
        GoRoute(
          path: '/watchlist',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: WatchlistScreen(),
          ),
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
  ],
);
