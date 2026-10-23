/// Календарные границы локального дня.
///
/// Конец — начало следующего календарного дня, а не `+ Duration(days: 1)`:
/// в дни перехода на летнее/зимнее время сутки могут длиться 23 или 25 часов
/// (R02-008).
({DateTime start, DateTime end}) localDayBounds(DateTime now) => (
  start: DateTime(now.year, now.month, now.day),
  end: DateTime(now.year, now.month, now.day + 1),
);

/// Календарные границы локального месяца: [start, end).
({DateTime start, DateTime end}) localMonthBounds(DateTime now) => (
  start: DateTime(now.year, now.month),
  end: DateTime(now.year, now.month + 1),
);
