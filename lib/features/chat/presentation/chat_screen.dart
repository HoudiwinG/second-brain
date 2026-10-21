import 'package:flutter/material.dart';

import '../../../app/feature_directions.dart';
import '../../../app/widgets/placeholder_section_screen.dart';

/// Экран чата с AI-ассистентом. Этап 0: заглушка (LLM-слой — этап 3).
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlaceholderSectionScreen(branch: FeatureBranch.chat);
  }
}
