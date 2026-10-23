import 'package:flutter_test/flutter_test.dart';
import 'package:second_brain/features/dashboard/domain/dashboard_period.dart';

void main() {
  group('Календарные границы дашборда (R02-008)', () {
    test('конец дня — начало следующего календарного дня', () {
      final bounds = localDayBounds(DateTime(2026, 3, 29, 12, 30));

      expect(bounds.start, DateTime(2026, 3, 29));
      expect(bounds.end, DateTime(2026, 3, 30));
    });

    test('конец месяца — начало следующего месяца', () {
      final bounds = localMonthBounds(DateTime(2026, 12, 31, 23, 59));

      expect(bounds.start, DateTime(2026, 12));
      expect(bounds.end, DateTime(2027, 1));
    });
  });
}
