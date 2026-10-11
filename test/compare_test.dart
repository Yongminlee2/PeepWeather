import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/compare.dart';
import 'package:weather_compare/models.dart';

void main() {
  test('slotTimes are next local multiples of 3h', () {
    final s = slotTimes(DateTime.utc(2026, 10, 11, 1, 20), const Duration(hours: 9), count: 3);
    // 현지 10:20 → 12,15,18시 → UTC 3,6,9시
    expect(s, [DateTime.utc(2026, 10, 11, 3), DateTime.utc(2026, 10, 11, 6), DateTime.utc(2026, 10, 11, 9)]);
  });

  test('hourAt picks nearest within 90 min', () {
    final hs = [Hour(DateTime.utc(2026, 1, 1, 0), 1, Sky.clear), Hour(DateTime.utc(2026, 1, 1, 3), 2, Sky.rain)];
    expect(hourAt(hs, DateTime.utc(2026, 1, 1, 2))!.tempC, 2);
    expect(hourAt(hs, DateTime.utc(2026, 1, 1, 6)), isNull);
  });

  test('daysFromHours uses place offset', () {
    final hs = [
      Hour(DateTime.utc(2026, 10, 11, 3), 10, Sky.clear, pop: 10), // 뉴욕 10/10 23시
      Hour(DateTime.utc(2026, 10, 11, 5), 20, Sky.rain, pop: 70), // 뉴욕 10/11 01시
      Hour(DateTime.utc(2026, 10, 11, 8), 15, Sky.cloudy, pop: 30), // 뉴욕 10/11 04시
    ];
    final d = daysFromHours(hs, const Duration(hours: -4));
    expect(d.length, 2);
    expect(d[1].date, DateTime.utc(2026, 10, 11));
    expect(d[1].maxC, 20);
    expect(d[1].minC, 15);
    expect(d[1].sky, Sky.rain);
    expect(d[1].pop, 70);
  });

  test('diverges on temp spread > 3', () {
    final t = DateTime.utc(2026);
    expect(divergesHours([Hour(t, 10, Sky.clear), Hour(t, 13, Sky.clear)]), isFalse);
    expect(divergesHours([Hour(t, 10, Sky.clear), Hour(t, 13.5, Sky.clear), null]), isTrue);
  });

  test('diverges on wet vs dry', () {
    final t = DateTime.utc(2026);
    expect(divergesHours([Hour(t, 10, Sky.rain, pop: 60), Hour(t, 10, Sky.clear, pop: 10)]), isTrue);
    expect(divergesHours([Hour(t, 10, Sky.rain, mm: 1.0), Hour(t, 10, Sky.clear, mm: 0)]), isTrue);
    expect(divergesHours([Hour(t, 10, Sky.rain, pop: 40), Hour(t, 10, Sky.clear, pop: 20)]), isFalse);
  });

  test('single source never diverges', () {
    final t = DateTime.utc(2026);
    expect(divergesHours([Hour(t, 10, Sky.rain, pop: 60), null]), isFalse);
  });

  test('days diverge on max temp spread or wet vs dry', () {
    final d = DateTime.utc(2026);
    expect(divergesDays([Day(d, 20, 10, Sky.clear), Day(d, 24, 10, Sky.clear)]), isTrue);
    expect(divergesDays([Day(d, 20, 10, Sky.rain, pop: 80), Day(d, 20, 10, Sky.clear, pop: 0)]), isTrue);
    expect(divergesDays([Day(d, 20, 10, Sky.clear), Day(d, 22, 12, Sky.clear)]), isFalse);
  });

  test('pm grades boundaries', () {
    expect(pm10Grade(30), Grade.good);
    expect(pm10Grade(31), Grade.normal);
    expect(pm10Grade(150), Grade.bad);
    expect(pm10Grade(151), Grade.veryBad);
    expect(pm25Grade(15), Grade.good);
    expect(pm25Grade(16), Grade.normal);
    expect(pm25Grade(75), Grade.bad);
    expect(pm25Grade(76), Grade.veryBad);
  });

  test('worstGrade takes the worse of pm10 and pm25', () {
    final t = DateTime.utc(2026);
    expect(worstGrade(Air(pm10: 20, pm25: 40, time: t)), Grade.bad);
    expect(worstGrade(Air(time: t)), isNull);
  });

  test('distanceKm Seoul-Busan ~325km', () {
    expect(distanceKm(37.5665, 126.978, 35.1796, 129.0756), closeTo(325, 10));
  });

  test('distanceKm across dateline', () {
    expect(distanceKm(0, 179.5, 0, -179.5), closeTo(111, 2));
  });

  test('normName strips prefixes and year suffix', () {
    expect(normName('Tropical Cyclone ISAIAS-26'), 'ISAIAS');
    expect(normName('Isaias'), 'ISAIAS');
  });

  test('groupCyclones merges by name and by distance', () {
    final t = DateTime.utc(2026);
    final g = groupCyclones([
      Result('GDACS', data: [Cyclone('Tropical Cyclone ISAIAS-26', 35, -86.7, t)]),
      Result('NHC', data: [Cyclone('Isaias', 35.1, -86.6, t)]),
      Result('KMA', data: [Cyclone('하구핏', 20, 130, t)]),
      Result('JTWC', data: [Cyclone('HAGUPIT', 20.5, 130.2, t)]),
      const Result<List<Cyclone>>('X', fail: Fail.network),
    ]);
    expect(g.length, 2);
    expect(g.map((x) => x.length).toList()..sort(), [2, 2]);
  });

  test('place json round trip', () {
    const p = Place('서울', 'KR', 37.5, 127.0);
    final q = Place.fromJson(p.toJson());
    expect([q.name, q.country, q.lat, q.lon], ['서울', 'KR', 37.5, 127.0]);
  });

  test('days built from partial hours are marked partial and never diverge', () {
    final hs = [
      Hour(DateTime.utc(2026, 10, 11, 9), 17, Sky.clear), // 서울 18시부터만 — 오늘은 일부
      Hour(DateTime.utc(2026, 10, 11, 12), 15, Sky.clear),
      for (var h = 0; h < 24; h += 3) Hour(DateTime.utc(2026, 10, 11, 15).add(Duration(hours: h)), 20, Sky.clear), // 10/12 전체
    ];
    final d = daysFromHours(hs, const Duration(hours: 9));
    expect(d.map((x) => x.partial), [true, false]);
    final full = Day(DateTime.utc(2026, 10, 11), 24, 12, Sky.clear);
    expect(divergesDays([d.first, full]), isFalse);
  });
}
