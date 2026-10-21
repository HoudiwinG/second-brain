import 'package:flutter/material.dart';

import '../../../app/feature_directions.dart';
import '../../../app/widgets/placeholder_section_screen.dart';

/// Экран дашборда. Этап 0: заглушка.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderSectionScreen(branch: FeatureBranch.dashboard);
  }
}
