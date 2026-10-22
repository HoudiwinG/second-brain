import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../l10n/generated/app_localizations.dart';
import 'feature_directions.dart';

/// Экран «Ещё»: доступ к второстепенным разделам на узких экранах.
class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const List<FeatureBranch> _secondary = [
    FeatureBranch.ideas,
    FeatureBranch.finance,
    FeatureBranch.learning,
    FeatureBranch.integrations,
    FeatureBranch.search,
    FeatureBranch.settings,
  ];

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    final shell = StatefulNavigationShell.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(lcm.moreTitle)),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final branch in _secondary)
            Card(
              child: ListTile(
                leading: Icon(branch.icon),
                title: Text(branch.label(lcm)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => shell.goBranch(
                  branch.index,
                  initialLocation: branch.index == shell.currentIndex,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
