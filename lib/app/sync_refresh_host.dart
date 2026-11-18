import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'di.dart';

/// Пересоздаёт экран при destructive sync restore, чтобы `initState`-кэши
/// перечитали данные. Не трогает Navigator/Router и состояние диалогов.
class SyncRefreshHost extends ConsumerWidget {
  const SyncRefreshHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(syncDataVersionProvider);
    return KeyedSubtree(key: ValueKey<int>(version), child: child);
  }
}
