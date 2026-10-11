import 'dart:math';

import 'models.dart';

/// 지금 이후의 현지 3의 배수 시각들(UTC로 돌려줌).
List<DateTime> slotTimes(DateTime nowUtc, Duration offset, {int count = 8}) {
  final local = nowUtc.add(offset);
  var t = DateTime.utc(local.year, local.month, local.day, (local.hour ~/ 3 + 1) * 3);
  return [for (var i = 0; i < count; i++) t.add(Duration(hours: 3 * i)).subtract(offset)];
}

/// t 에서 ±90분 안의 가장 가까운 예보.
Hour? hourAt(List<Hour> hours, DateTime t) {
  Hour? best;
  var bestDiff = const Duration(minutes: 91);
  for (final h in hours) {
    final d = h.time.difference(t).abs();
    if (d < bestDiff) {
      best = h;
      bestDiff = d;
    }
  }
  return best;
}

Sky worstSky(Iterable<Sky> s) => s.reduce((a, b) => a.index >= b.index ? a : b);

/// 시간별 예보를 현지 날짜로 묶어 하루 요약을 만든다.
List<Day> daysFromHours(List<Hour> hours, Duration offset) {
  final byDate = <DateTime, List<Hour>>{};
  for (final h in hours) {
    final l = h.time.add(offset);
    byDate.putIfAbsent(DateTime.utc(l.year, l.month, l.day), () => []).add(h);
  }
  final dates = byDate.keys.toList()..sort();
  return [
    for (final d in dates)
      () {
        final hs = byDate[d]!;
        final pops = hs.map((h) => h.pop).whereType<int>();
        final first = hs.first.time.add(offset).hour, last = hs.last.time.add(offset).hour;
        return Day(d, hs.map((h) => h.tempC).reduce(max), hs.map((h) => h.tempC).reduce(min),
            worstSky(hs.map((h) => h.sky)),
            pop: pops.isEmpty ? null : pops.reduce(max),
            // 새벽(3시 이전)부터 저녁(18시 이후)까지 있어야 하루치로 본다(MET 6시간 간격은 18시가 마지막)
            partial: first > 3 || last < 18);
      }()
  ];
}

bool isWet(int? pop, double? mm) => pop != null ? pop >= 50 : (mm != null && mm >= 0.5);
bool isDry(int? pop, double? mm) => pop != null ? pop < 20 : (mm != null && mm == 0);

bool _diverges(List<double> temps, List<(int?, double?)> rain) {
  if (temps.length < 2) return false;
  if (temps.reduce(max) - temps.reduce(min) > 3) return true;
  return rain.any((r) => isWet(r.$1, r.$2)) && rain.any((r) => isDry(r.$1, r.$2));
}

bool divergesHours(List<Hour?> cells) {
  final hs = cells.whereType<Hour>().toList();
  return _diverges([for (final h in hs) h.tempC], [for (final h in hs) (h.pop, h.mm)]);
}

bool divergesDays(List<Day?> cells) {
  final ds = cells.whereType<Day>().where((d) => !d.partial).toList();
  return _diverges([for (final d in ds) d.maxC], [for (final d in ds) (d.pop, null)]);
}

/// 한국 환경부 기준 등급(전 세계 공통으로 사용).
enum Grade { good, normal, bad, veryBad }

Grade pm10Grade(double v) =>
    v <= 30 ? Grade.good : v <= 80 ? Grade.normal : v <= 150 ? Grade.bad : Grade.veryBad;
Grade pm25Grade(double v) =>
    v <= 15 ? Grade.good : v <= 35 ? Grade.normal : v <= 75 ? Grade.bad : Grade.veryBad;

Grade? worstGrade(Air a) {
  final g = [if (a.pm10 != null) pm10Grade(a.pm10!), if (a.pm25 != null) pm25Grade(a.pm25!)];
  return g.isEmpty ? null : g.reduce((x, y) => x.index >= y.index ? x : y);
}

double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
  final a = pow(sin(dLat / 2), 2) + cos(rad(lat1)) * cos(rad(lat2)) * pow(sin(dLon / 2), 2);
  return 2 * r * asin(sqrt(a));
}

/// 태풍 이름 비교용: 마지막 영문 단어만 대문자로("Tropical Cyclone ISAIAS-26" → "ISAIAS").
/// 영문이 없으면(예: 한글 이름) '' — 그때는 거리로만 묶는다.
String normName(String s) {
  final words = RegExp(r'[A-Za-z]+').allMatches(s.replaceAll(RegExp(r'-\d+'), ''));
  return words.isEmpty ? '' : words.last.group(0)!.toUpperCase();
}

/// 여러 출처의 태풍을 같은 태풍끼리 묶는다(이름 일치 또는 300km 이내).
List<List<(String, Cyclone)>> groupCyclones(List<Result<List<Cyclone>>> rs) {
  final groups = <List<(String, Cyclone)>>[];
  for (final r in rs) {
    for (final c in r.data ?? const <Cyclone>[]) {
      final n = normName(c.name);
      final g = groups.where((g) => g.any((m) =>
          (n.isNotEmpty && normName(m.$2.name) == n) ||
          distanceKm(m.$2.lat, m.$2.lon, c.lat, c.lon) <= 300));
      if (g.isEmpty) {
        groups.add([(r.source, c)]);
      } else {
        g.first.add((r.source, c));
      }
    }
  }
  return groups;
}
