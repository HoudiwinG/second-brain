import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/llm/application/privacy_guard.dart';

LlmContextItem _item({
  required String type,
  required int id,
  required bool isPrivate,
}) => LlmContextItem(
  entityType: type,
  entityId: id,
  title: 'title-$id',
  body: 'body-$id',
  isPrivateForLlm: isPrivate,
);

void main() {
  group('PrivacyGuard', () {
    test('не пропускает приватные сущности и считает типы', () {
      final result = PrivacyGuard.filter([
        _item(type: 'note', id: 1, isPrivate: false),
        _item(type: 'note', id: 2, isPrivate: true),
        _item(type: 'task', id: 3, isPrivate: true),
        _item(type: 'idea', id: 4, isPrivate: false),
      ]);

      expect(result.allowed.map((item) => item.entityId), [1, 4]);
      expect(result.filteredCount, 2);
      expect(result.filteredTypes, {'note', 'task'});
      expect(result.hasFiltered, isTrue);
      expect(
        result.allowed.any((item) => item.isPrivateForLlm),
        isFalse,
      );
    });

    test('пустой контекст не считается фильтрацией', () {
      final result = PrivacyGuard.filter(const []);

      expect(result.allowed, isEmpty);
      expect(result.filteredCount, 0);
      expect(result.filteredTypes, isEmpty);
      expect(result.hasFiltered, isFalse);
    });
  });
}
