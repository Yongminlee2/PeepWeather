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

/// 정렬된 값의 분위수(선형 보간).
double quantile(List<double> sorted, double q) {
  final pos = (sorted.length - 1) * q;
  final lo = pos.floor(), hi = pos.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
}

/// 기관끼리 엇갈리나.
/// 3곳 이하: 기온 차 3°C 초과, 또는 "비 온다"와 "안 온다"가 함께.
/// 4곳 이상: 한 곳이 튀는 건 엇갈림이 아니다 — 가운데 절반이 2.5°C 넘게 벌어지거나,
/// 비 예보가 30~70% 로 갈릴 때만.
bool _diverges(List<double> temps, List<(int?, double?)> rain) {
  if (temps.length < 2) return false;
  if (temps.length < 4) {
    if (temps.reduce(max) - temps.reduce(min) > 3) return true;
    return rain.any((r) => isWet(r.$1, r.$2)) && rain.any((r) => isDry(r.$1, r.$2));
  }
  final s = [...temps]..sort();
  if (quantile(s, 0.75) - quantile(s, 0.25) > 2.5) return true;
  final known = rain.where((r) => r.$1 != null || r.$2 != null).toList();
  if (known.length < 4) return false;
  final wet = known.where((r) => isWet(r.$1, r.$2)).length / known.length;
  return wet >= 0.3 && wet <= 0.7;
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

/// 가장 많은 기관이 고른 하늘(같으면 더 나쁜 날씨 쪽).
Sky majoritySky(List<Sky> skies) {
  final votes = <Sky, int>{};
  for (final s in skies) {
    votes[s] = (votes[s] ?? 0) + 1;
  }
  return votes.entries.reduce((a, b) => b.value > a.value || (b.value == a.value && b.key.index > a.key.index) ? b : a).key;
}

double median(List<double> xs) {
  final s = [...xs]..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

/// 한 시각의 기관별 예보 퍼짐: 범위·가운데 값·비 예보 기관 수. cells 는 기온 낮은 순.
class HourSpread {
  final double min, max, median;
  final int count, wet;
  final bool diverges;
  final List<(String, Hour)> cells;
  const HourSpread(this.min, this.max, this.median, this.count, this.wet, this.diverges, this.cells);
}

HourSpread? hourSpread(List<Result<Forecast>> rs, DateTime t) {
  final cells = [
    for (final r in rs)
      if (r.data == null ? null : hourAt(r.data!.hours, t) case final h?) (r.source, h)
  ]..sort((a, b) => a.$2.tempC.compareTo(b.$2.tempC));
  if (cells.isEmpty) return null;
  final temps = [for (final c in cells) c.$2.tempC];
  return HourSpread(temps.first, temps.last, median(temps), cells.length,
      cells.where((c) => isWet(c.$2.pop, c.$2.mm)).length, divergesHours([for (final c in cells) c.$2]), cells);
}

/// 하루의 기관별 퍼짐: 최저기온 범위·최고기온 범위·가운데 값·비 확률 범위·가장 많은 기관이 고른 하늘.
class DaySpread {
  final double lowMin, lowMax, highMin, highMax, medLow, medHigh;
  final int? popMin, popMax;
  final int count;
  final Sky sky;
  final bool diverges;
  final List<(String, Day)> cells;
  const DaySpread(this.lowMin, this.lowMax, this.highMin, this.highMax, this.medLow, this.medHigh, this.popMin,
      this.popMax, this.count, this.sky, this.diverges, this.cells);
}

DaySpread? daySpread(List<Result<Forecast>> rs, DateTime date) {
  final cells = [
    for (final r in rs)
      if (r.data?.days.where((d) => d.date == date).firstOrNull case final d?) (r.source, d)
  ]..sort((a, b) => a.$2.maxC.compareTo(b.$2.maxC));
  if (cells.isEmpty) return null;
  final lows = [for (final c in cells) c.$2.minC]..sort();
  final highs = [for (final c in cells) c.$2.maxC];
  final pops = [for (final c in cells) c.$2.pop].whereType<int>().toList()..sort();
  final sky = majoritySky([for (final c in cells) c.$2.sky]);
  return DaySpread(lows.first, lows.last, highs.first, highs.last, median(lows), median(highs),
      pops.isEmpty ? null : pops.first, pops.isEmpty ? null : pops.last, cells.length, sky,
      divergesDays([for (final c in cells) c.$2]), cells);
}
