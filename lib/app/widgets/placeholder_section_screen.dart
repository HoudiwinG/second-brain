import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../feature_directions.dart';

/// Универсальный пустой экран фичи (этап 0).
///
/// Каждая фича владеет собственной папкой уже сейчас; экран будет
/// заменён реальной фичей на следующих этапах, сохраняя публичный путь.
class PlaceholderSectionScreen extends StatelessWidget {
  const PlaceholderSectionScreen({super.key, required this.branch});

  final FeatureBranch branch;

  @override
  Widget build(BuildContext context) {
    final lcm = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(branch.label(lcm))),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(branch.icon, size: 56),
              const SizedBox(height: 12),
              Text(
                branch.label(lcm),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(lcm.emptyStateMessage, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
