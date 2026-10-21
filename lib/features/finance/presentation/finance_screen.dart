import 'package:flutter/material.dart';

import '../../../app/feature_directions.dart';
import '../../../app/widgets/placeholder_section_screen.dart';

/// Экран финансов. Этап 0: заглушка.
class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderSectionScreen(branch: FeatureBranch.finance);
  }
}
