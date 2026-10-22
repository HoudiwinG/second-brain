import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/logging/app_logger.dart';
import '../features/chat/presentation/chat_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/finance/presentation/finance_screen.dart';
import '../features/ideas/presentation/ideas_screen.dart';
import '../features/integrations/presentation/integrations_screen.dart';
import '../features/learning/presentation/learning_screen.dart';
import '../features/notes/presentation/notes_screen.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../l10n/generated/app_localizations.dart';
import 'feature_directions.dart';
import 'more_screen.dart';

/// Путь ветки в схеме URL роутинга.
String pathForBranch(FeatureBranch branch) => switch (branch) {
  FeatureBranch.dashboard => '/',
  FeatureBranch.notes => '/notes',
  FeatureBranch.tasks => '/tasks',
  FeatureBranch.ideas => '/ideas',
  FeatureBranch.finance => '/finance',
  FeatureBranch.learning => '/learning',
  FeatureBranch.chat => '/chat',
  FeatureBranch.integrations => '/integrations',
  FeatureBranch.search => '/search',
  FeatureBranch.settings => '/settings',
  FeatureBranch.more => '/more',
};

Widget _screenForBranch(FeatureBranch branch) => switch (branch) {
  FeatureBranch.dashboard => const DashboardScreen(),
  FeatureBranch.notes => const NotesScreen(),
  FeatureBranch.tasks => const TasksScreen(),
  FeatureBranch.ideas => const IdeasScreen(),
  FeatureBranch.finance => const FinanceScreen(),
  FeatureBranch.learning => const LearningScreen(),
  FeatureBranch.chat => const ChatScreen(),
  FeatureBranch.integrations => const IntegrationsScreen(),
  FeatureBranch.search => const SearchScreen(),
  FeatureBranch.settings => const SettingsScreen(),
  FeatureBranch.more => const MoreScreen(),
};

/// Контроллер роутинга (go_router) поверх Riverpod.
///
/// Каждая ветка StatefulShellRoute соответствует одной фиче; порядок веток
/// зафиксирован в [FeatureBranch]. Изменение порядка/числа веток — критическое
/// изменение (см. decisions.md).
class RouterController {
  RouterController() {
    final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

    router = GoRouter(
      navigatorKey: rootNavigatorKey,
      initialLocation: pathForBranch(FeatureBranch.dashboard),
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) =>
              _HomeShell(navigationShell: navigationShell),
          branches: [
            for (final branch in kFeatureBranches)
              StatefulShellBranch(
                navigatorKey: GlobalKey<NavigatorState>(
                  debugLabel: branch.name,
                ),
                routes: [
                  GoRoute(
                    path: pathForBranch(branch),
                    pageBuilder: (context, state) => NoTransitionPage<void>(
                      key: state.pageKey,
                      child: _screenForBranch(branch),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
    AppLogger.d('RouterController: go_router инициализирован');
  }

  late final GoRouter router;
}

/// Корневой шелл: боковой NavigationRail на широких окнах (Windows-first),
/// нижняя навигация из пяти основных разделов на узких экранах.
class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (isWide)
              _SideRail(navigationShell: navigationShell)
            else
              const SizedBox.shrink(),
            Expanded(child: navigationShell),
          ],
        ),
      ),
      bottomNavigationBar: isWide
          ? null
          : _BottomBar(navigationShell: navigationShell),
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final currentIndex = navigationShell.currentIndex;
    if (currentIndex >= kFeatureBranches.length) {
      AppLogger.w('Навигация: неожиданный индекс ветки $currentIndex');
    }
    return NavigationRail(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) => navigationShell.goBranch(
        index,
        initialLocation: index == navigationShell.currentIndex,
      ),
      labelType: NavigationRailLabelType.all,
      // Окно может быть ниже, чем 11 пунктов rail: без прокрутки внизу
      // возникает RenderFlex overflow. Прокрутка сохраняет доступ ко всем
      // разделам и убирает жёлто-чёрную полосу.
      scrollable: true,
      destinations: [
        for (final branch in kFeatureBranches)
          NavigationRailDestination(
            icon: Icon(branch.icon),
            selectedIcon: Icon(branch.icon),
            label: Text(branch.label(AppLocalizations.of(context)!)),
          ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final current = kFeatureBranches[navigationShell.currentIndex];
    final index = kMobileNavBranches.indexOf(current);
    // Ветки вне нижней панели (settings, ideas и т.п.) открываются из «Ещё»,
    // поэтому активной считается именно эта вкладка, а не «Дашборд» (TD-04).
    final selectedIndex = index >= 0
        ? index
        : kMobileNavBranches.indexOf(FeatureBranch.more);
    return NavigationBar(
      selectedIndex: selectedIndex,
      destinations: [
        for (final branch in kMobileNavBranches)
          NavigationDestination(
            icon: Icon(branch.icon),
            label: branch.label(AppLocalizations.of(context)!),
          ),
      ],
      onDestinationSelected: (index) {
        final branch = kMobileNavBranches[index];
        navigationShell.goBranch(
          branch.index,
          initialLocation: branch.index == navigationShell.currentIndex,
        );
      },
    );
  }
}
