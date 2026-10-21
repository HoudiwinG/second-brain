import 'package:flutter/material.dart';

import '../../../app/feature_directions.dart';
import '../../../app/widgets/placeholder_section_screen.dart';

/// Экран дневника идей. Этап 0: заглушка.
class IdeasScreen extends StatelessWidget {
  const IdeasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderSectionScreen(branch: FeatureBranch.ideas);
  }
}
