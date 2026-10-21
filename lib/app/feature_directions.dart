import 'package:flutter/material.dart';

import '../l10n/generated/app_localizations.dart';

/// Порядок веток навигации.
///
/// Индексы стабильны и используются навигационными виджетами;
/// изменение порядка — критическое изменение (см. decisions.md).
enum FeatureBranch {
  dashboard,
  notes,
  tasks,
  ideas,
  finance,
  learning,
  chat,
  integrations,
  search,
  settings,
  more,
}

extension FeatureBranchX on FeatureBranch {
  IconData get icon => switch (this) {
        FeatureBranch.dashboard => Icons.dashboard_outlined,
        FeatureBranch.notes => Icons.sticky_note_2_outlined,
        FeatureBranch.tasks => Icons.checklist_outlined,
        FeatureBranch.ideas => Icons.lightbulb_outline,
        FeatureBranch.finance => Icons.savings_outlined,
        FeatureBranch.learning => Icons.school_outlined,
        FeatureBranch.chat => Icons.forum_outlined,
        FeatureBranch.integrations => Icons.hub_outlined,
        FeatureBranch.search => Icons.search_outlined,
        FeatureBranch.settings => Icons.settings_outlined,
        FeatureBranch.more => Icons.more_horiz,
      };

  String label(AppLocalizations lcm) => switch (this) {
        FeatureBranch.dashboard => lcm.navDashboard,
        FeatureBranch.notes => lcm.navNotes,
        FeatureBranch.tasks => lcm.navTasks,
        FeatureBranch.ideas => lcm.navIdeas,
        FeatureBranch.finance => lcm.navFinance,
        FeatureBranch.learning => lcm.navLearning,
        FeatureBranch.chat => lcm.navChat,
        FeatureBranch.integrations => lcm.navIntegrations,
        FeatureBranch.search => lcm.navSearch,
        FeatureBranch.settings => lcm.navSettings,
        FeatureBranch.more => lcm.navMore,
      };
}

/// Полный список веток в порядке enum.
const List<FeatureBranch> kFeatureBranches = FeatureBranch.values;

/// Ветки нижней навигации на узких экранах (мобильные/узкое окно).
const List<FeatureBranch> kMobileNavBranches = [
  FeatureBranch.dashboard,
  FeatureBranch.notes,
  FeatureBranch.tasks,
  FeatureBranch.chat,
  FeatureBranch.more,
];
