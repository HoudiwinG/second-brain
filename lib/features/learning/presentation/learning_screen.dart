import 'package:flutter/material.dart';

import '../../../app/feature_directions.dart';
import '../../../app/widgets/placeholder_section_screen.dart';

/// Экран обучения (трекеры, AI-тренер). Этап 0: заглушка.
class LearningScreen extends StatelessWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderSectionScreen(branch: FeatureBranch.learning);
  }
}
