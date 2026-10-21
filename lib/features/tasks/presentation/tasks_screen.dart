import 'package:flutter/material.dart';

import '../../../app/feature_directions.dart';
import '../../../app/widgets/placeholder_section_screen.dart';

/// Экран задач и напоминаний. Этап 0: заглушка.
class TasksScreen extends StatelessWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderSectionScreen(branch: FeatureBranch.tasks);
  }
}
