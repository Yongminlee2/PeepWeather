import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_compare/alerts.dart';
import 'package:weather_compare/l10n/app_localizations.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/repository.dart';
import 'package:weather_compare/settings.dart';

final now = DateTime.utc(2026, 10, 11, 0); // 서울 09:00
const seoul = Place('서울', 'KR', 37.57, 126.98);
final l = lookupAppLocalizations(const Locale('ko'));

Report report({int pop = 0, int rainAfterHours = 3, double pm10 = 20, double? stormLat}) => Report(
      seoul,
      [
        Result('met', data: Forecast(hours: [Hour(now.add(Duration(hours: rainAfterHours)), 15, Sky.rain, pop: pop)]), asOf: now),
        const Result('owm', fail: Fail.noKey),
      ],
      [Result('owm', data: Air(pm10: pm10, time: now), asOf: now)],
      [
        Result('nhc', data: [if (stormLat != null) Cyclone('Hagupit', stormLat, 126.98, now)], asOf: now),
      ],
      const Duration(hours: 9),
    );

void main() {
  late Settings s;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    s = await Settings.load();
  });

  List<Alert> decide(Report r, Map<String, String> sent) => decideAlerts(r, s, sent, now, l);
  Map<String, String> record(List<Alert> as, [Map<String, String>? sent]) => {...?sent, for (final a in as) a.key: a.value};


  test('rain 60% within 12h alerts once per day', () {
    final a = decide(report(pop: 60), {});
    expect(a.single.key, 'rain:2026-10-11');
    expect(a.single.title, contains('서울'));
    expect(a.single.body, contains('60%'));
    expect(decide(report(pop: 80), record(a)), isEmpty);
  });

  test('rain below 60 or beyond 12h does not alert', () {
    expect(decide(report(pop: 59), {}), isEmpty);
    expect(decide(report(pop: 90, rainAfterHours: 13), {}), isEmpty);
  });

  test('bad air alerts once per day', () {
    final a = decide(report(pm10: 90), {});
    expect(a.single.key, 'air:2026-10-11');
    expect(a.single.title, allOf(contains('나쁨'), contains('서울')));
    expect(decide(report(pm10: 200), record(a)), isEmpty);
  });

  test('storm within 500 km alerts, again when distance halves', () {
    final first = decide(report(stormLat: 37.57 - 4.0), {}); // 약 445km 남쪽
    expect(first.single.key, 'storm:HAGUPIT');
    expect(first.single.body, allOf(contains('서울'), contains('km')));
    final sent = record(first);
    expect(decide(report(stormLat: 37.57 - 3.6), sent), isEmpty); // 약 400km
    final half = decide(report(stormLat: 37.57 - 2.0), sent); // 약 222km
    expect(half.single.key, 'storm:HAGUPIT:half');
    expect(decide(report(stormLat: 37.57 - 1.0), record(half, sent)), isEmpty);
  });

  test('storm beyond 500 km does not alert', () {
    expect(decide(report(stormLat: 37.57 - 5.0), {}), isEmpty);
  });

  test('switched-off kinds do not alert', () async {
    await s.update((s) {
      s.alertRain = false;
      s.alertAir = false;
      s.alertStorm = false;
    });
    expect(decide(report(pop: 90, pm10: 200, stormLat: 36), {}), isEmpty);
  });

  test('sent records carry their date and old ones are pruned', () {
    final a = decide(report(stormLat: 37.57 - 4.0), {});
    expect(a.single.value, endsWith('@2026-10-11'));
    final sent = {
      'storm:TEN': '300@2026-09-01',
      'rain:2026-10-10': '2026-10-10@2026-10-10',
      'storm:HAGUPIT': '445@2026-10-11',
      'legacy': '123',
    };
    expect(pruneSent(sent, now).keys, ['rain:2026-10-10', 'storm:HAGUPIT']);
  });
}
