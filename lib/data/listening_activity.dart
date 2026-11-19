/// Écoute datée à partir de `lastPlayedAt` : tout le temps de l’épisode
/// est compté le jour local de cette dernière lecture.
class ListenSample {
  const ListenSample({
    required this.at,
    required this.seconds,
    this.categories = const [],
  });

  final DateTime at;
  final int seconds;
  final List<String> categories;
}

class CategoryListen {
  const CategoryListen({required this.name, required this.seconds});

  final String name;
  final int seconds;
}

class IndexExtreme {
  const IndexExtreme({required this.busiest, required this.calmest});

  final List<int> busiest;
  final List<int> calmest;
}

class HeatWeek {
  const HeatWeek({required this.labelMonth, required this.days});

  /// Mois (1–12) dont le 1er tombe dans cette colonne.
  final int? labelMonth;
  final List<HeatDay?> days;
}

class HeatDay {
  const HeatDay({required this.day, required this.seconds});

  final DateTime day;
  final int seconds;
}

class ListeningActivity {
  const ListeningActivity({
    required this.totalSeconds,
    required this.dailyStreak,
    required this.weeklyStreak,
    required this.daySeconds,
    required this.categories,
    required this.today,
  });

  final int totalSeconds;
  final int dailyStreak;
  final int weeklyStreak;

  /// Jours locaux (minuit) où l’écoute est strictement positive.
  final Map<DateTime, int> daySeconds;
  final List<CategoryListen> categories;
  final DateTime today;

  int get year => today.year;

  int get semesterStartMonth => today.month <= 6 ? 1 : 7;

  int get semesterEndMonth => today.month <= 6 ? 6 : 12;

  int secondsOn(DateTime day) => daySeconds[_day(day)] ?? 0;

  IndexExtreme get weekExtremes {
    final included = [
      for (var i = 0; i < 7; i++)
        if (!DateTime(
          today.year,
          today.month,
          today.day - today.weekday + 1 + i,
        ).isAfter(today))
          i,
    ];
    final values = [for (var i = 0; i < 7; i++) secondsOn(_weekDay(i))];
    return _extremes(values, included);
  }

  int weekDaySeconds(int weekdayIndex) => secondsOn(_weekDay(weekdayIndex));

  bool weekDayIsFuture(int weekdayIndex) =>
      _weekDay(weekdayIndex).isAfter(today);

  IndexExtreme get yearExtremes {
    final included = [
      for (var month = 1; month <= today.month; month++) month - 1,
    ];
    final values = [
      for (var month = 1; month <= 12; month++) monthSeconds(month),
    ];
    return _listenedExtremes(values, included);
  }

  int monthSeconds(int month) {
    var total = 0;
    for (final entry in daySeconds.entries) {
      final day = entry.key;
      if (day.year == today.year && day.month == month) total += entry.value;
    }
    return total;
  }

  IndexExtreme get weekdayExtremes {
    if (totalSeconds <= 0) {
      return const IndexExtreme(busiest: [], calmest: []);
    }
    final totals = List<int>.filled(7, 0);
    for (final entry in daySeconds.entries) {
      totals[entry.key.weekday - 1] += entry.value;
    }
    return _listenedExtremes(totals, const [0, 1, 2, 3, 4, 5, 6]);
  }

  int get semesterSeconds {
    final start = DateTime(today.year, semesterStartMonth, 1);
    final end = DateTime(today.year, semesterEndMonth + 1, 0);
    var total = 0;
    for (final entry in daySeconds.entries) {
      final day = entry.key;
      if (!day.isBefore(start) && !day.isAfter(end)) total += entry.value;
    }
    return total;
  }

  List<HeatWeek> get semesterWeeks {
    final start = DateTime(today.year, semesterStartMonth, 1);
    final end = DateTime(today.year, semesterEndMonth + 1, 0);
    var cursor = DateTime(
      start.year,
      start.month,
      start.day - (start.weekday - 1),
    );
    final weeks = <HeatWeek>[];
    while (!cursor.isAfter(end)) {
      int? labelMonth;
      final days = <HeatDay?>[];
      for (var i = 0; i < 7; i++) {
        final day = DateTime(cursor.year, cursor.month, cursor.day + i);
        if (day.isBefore(start) || day.isAfter(end)) {
          days.add(null);
          continue;
        }
        if (day.day == 1) labelMonth = day.month;
        days.add(HeatDay(day: day, seconds: secondsOn(day)));
      }
      weeks.add(HeatWeek(labelMonth: labelMonth, days: days));
      cursor = DateTime(cursor.year, cursor.month, cursor.day + 7);
    }
    return weeks;
  }

  List<({int year, int month, int seconds})> get monthsWithListening {
    final totals = <(int, int), int>{};
    for (final entry in daySeconds.entries) {
      final key = (entry.key.year, entry.key.month);
      totals[key] = (totals[key] ?? 0) + entry.value;
    }
    final rows =
        [
          for (final entry in totals.entries)
            (year: entry.key.$1, month: entry.key.$2, seconds: entry.value),
        ]..sort((a, b) {
          final byYear = b.year.compareTo(a.year);
          if (byYear != 0) return byYear;
          return b.month.compareTo(a.month);
        });
    return rows;
  }

  DateTime _weekDay(int weekdayIndex) {
    return DateTime(
      today.year,
      today.month,
      today.day - (today.weekday - 1) + weekdayIndex,
    );
  }
}

ListeningActivity buildListeningActivity(
  List<ListenSample> samples, {
  required DateTime now,
}) {
  final localNow = now.toLocal();
  final today = DateTime(localNow.year, localNow.month, localNow.day);
  final days = <DateTime, int>{};
  final categories = <String, _CategoryBucket>{};
  var total = 0;

  for (final sample in samples) {
    if (sample.seconds <= 0) continue;
    final local = sample.at.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    days[day] = (days[day] ?? 0) + sample.seconds;
    total += sample.seconds;
    if (sample.categories.isEmpty) continue;
    final name = sample.categories.first.trim();
    if (name.isEmpty) continue;
    final bucket = categories.putIfAbsent(
      name.toLowerCase(),
      () => _CategoryBucket(name),
    );
    bucket.seconds += sample.seconds;
  }

  final ranked =
      [
        for (final bucket in categories.values)
          CategoryListen(name: bucket.name, seconds: bucket.seconds),
      ]..sort((a, b) {
        final byTime = b.seconds.compareTo(a.seconds);
        if (byTime != 0) return byTime;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

  return ListeningActivity(
    totalSeconds: total,
    dailyStreak: _dailyStreak(days, today),
    weeklyStreak: _weeklyStreak(days, today),
    daySeconds: days,
    categories: ranked,
    today: today,
  );
}

int _dailyStreak(Map<DateTime, int> days, DateTime today) {
  var cursor = today;
  if ((days[cursor] ?? 0) <= 0) {
    cursor = _day(DateTime(today.year, today.month, today.day - 1));
    if ((days[cursor] ?? 0) <= 0) return 0;
  }
  var count = 0;
  while ((days[cursor] ?? 0) > 0) {
    count++;
    cursor = _day(DateTime(cursor.year, cursor.month, cursor.day - 1));
  }
  return count;
}

int _weeklyStreak(Map<DateTime, int> days, DateTime today) {
  var monday = _day(
    DateTime(today.year, today.month, today.day - (today.weekday - 1)),
  );
  if (!_weekHasListening(days, monday)) {
    monday = _day(DateTime(monday.year, monday.month, monday.day - 7));
    if (!_weekHasListening(days, monday)) return 0;
  }
  var count = 0;
  while (_weekHasListening(days, monday)) {
    count++;
    monday = _day(DateTime(monday.year, monday.month, monday.day - 7));
  }
  return count;
}

bool _weekHasListening(Map<DateTime, int> days, DateTime monday) {
  for (var i = 0; i < 7; i++) {
    final day = _day(DateTime(monday.year, monday.month, monday.day + i));
    if ((days[day] ?? 0) > 0) return true;
  }
  return false;
}

/// Le plus actif et le plus calme, parmi les périodes où il y a eu de
/// l’écoute. Un seul niveau d’écoute n’est pas aussi « le plus calme ».
IndexExtreme _listenedExtremes(List<int> values, List<int> included) {
  final active = [
    for (final index in included)
      if (values[index] > 0) index,
  ];
  final ranked = _extremes(values, active);
  if (ranked.busiest.length == active.length) {
    return IndexExtreme(busiest: ranked.busiest, calmest: const []);
  }
  return ranked;
}

IndexExtreme _extremes(List<int> values, List<int> included) {
  if (included.isEmpty) {
    return const IndexExtreme(busiest: [], calmest: []);
  }
  var maxValue = 0;
  var minValue = values[included.first];
  for (final index in included) {
    final value = values[index];
    if (value > maxValue) maxValue = value;
    if (value < minValue) minValue = value;
  }
  if (maxValue == 0) {
    return IndexExtreme(busiest: const [], calmest: List<int>.from(included));
  }
  return IndexExtreme(
    busiest: [
      for (final index in included)
        if (values[index] == maxValue) index,
    ],
    calmest: [
      for (final index in included)
        if (values[index] == minValue) index,
    ],
  );
}

DateTime _day(DateTime value) => DateTime(value.year, value.month, value.day);

class _CategoryBucket {
  _CategoryBucket(this.name);

  final String name;
  var seconds = 0;
}
