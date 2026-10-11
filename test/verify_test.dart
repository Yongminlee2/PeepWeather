import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/repository.dart';
import 'package:weather_compare/verify.dart';

void main() {
  const seoul = Place('서울', 'KR', 37.57, 126.98);
  const paris = Place('Paris', 'FR', 48.85, 2.35);
  final t0 = DateTime.utc(2026, 10, 11, 0);

  Result<Forecast> fc(String id, double base, {Hour? now, int pop = 0}) => Result(id,
      data: Forecast(now: now, hours: [
        for (var h = 0; h <= 40; h++) Hour(t0.add(Duration(hours: h)), base, Sky.cloudy, pop: pop),
      ]));
  Report rep(Place p, List<Result<Forecast>> fs) => Report(p, fs, const [], const [], const Duration(hours: 9));

  test('records one prediction per source and target hour, 12 to 36 hours ahead, first one wins', () {
    final l = Ledger();
    record(l, rep(seoul, [fc('a', 20), fc('b', 25)]), t0);
    expect(l.pending.length, 2 * 25); // 12..36시간 뒤 = 25개 시각 × 2곳
    record(l, rep(seoul, [fc('a', 99)]), t0.add(const Duration(hours: 1)));
    expect(l.pending['a|${t0.add(const Duration(hours: 13)).toIso8601String()}']!.tempC, 20); // 먼저 저장한 예보 유지
  });

  test('observation: KMA in Korea, OpenWeather elsewhere', () {
    final obsK = observation(rep(seoul, [fc('kma', 18, now: Hour(t0, 18.4, Sky.rain, mm: 1.5)), fc('owm', 0, now: Hour(t0, 30, Sky.clear))]))!;
    expect([obsK.source, obsK.tempC, obsK.wet], ['kma', 18.4, true]);
    final obsP = observation(rep(paris, [fc('owm', 0, now: Hour(t0, 12, Sky.clear, mm: 0))]))!;
    expect([obsP.source, obsP.wet], ['owm', false]);
    expect(observation(rep(paris, [fc('met', 1)])), isNull);
  });

  test('verify scores matched predictions and drops them; stale ones are pruned', () {
    final l = Ledger();
    record(l, rep(seoul, [fc('a', 20, pop: 70), fc('b', 25, pop: 0)]), t0);
    final target = t0.add(const Duration(hours: 20));
    verify(l, Observation('kma', target.add(const Duration(minutes: 20)), 21, true), target.add(const Duration(minutes: 20)));
    expect(l.scores['a']!.n, 1);
    expect(l.scores['a']!.mae, 1.0);
    expect(l.scores['a']!.rainHitRate, 1.0);
    expect(l.scores['b']!.mae, 4.0);
    expect(l.scores['b']!.rainHitRate, 0.0);
    expect(l.pending.keys.where((k) => k.endsWith(target.toIso8601String())), isEmpty);
    // 3시간 넘게 지난 예보는 비교 못 하고 버린다
    expect(l.pending.values.every((p) => p.target.isAfter(target.subtract(const Duration(hours: 3)))), isTrue);
  });

  test('ranking needs enough comparisons and sorts by average error', () {
    final l = Ledger()
      ..scores['a'] = (Score()..add(2, true)..add(2, true)..add(2, true)..add(2, true)..add(2, true))
      ..scores['b'] = (Score()..add(1, true)..add(1, false)..add(1, true)..add(1, true)..add(1, true))
      ..scores['c'] = (Score()..add(0.1, true));
    expect(ranking(l).map((e) => e.$1), ['b', 'a']);
  });

  test('weighted middle leans toward sources that were right here', () {
    final l = Ledger();
    for (final (id, err) in [('good', 0.5), ('ok', 1.5), ('bad', 4.0)]) {
      final s = Score();
      for (var i = 0; i < 6; i++) {
        s.add(err, true);
      }
      l.scores[id] = s;
    }
    final w = weightedTemp({'good': 20.0, 'ok': 22.0, 'bad': 30.0}, l)!;
    expect(w, lessThan(22)); // 잘 맞춘 곳 쪽으로
    expect(weightedTemp({'good': 20.0, 'x': 30.0}, Ledger()), isNull); // 자료가 모자라면 가중치 없음
  });

  test('ledger survives a save and load', () async {
    final dir = Directory.systemTemp.createTempSync('ledger');
    final l = Ledger();
    record(l, rep(seoul, [fc('a', 20)]), t0);
    l.scores['a'] = Score()..add(1.2, true);
    await saveLedger(dir, seoul, l);
    final back = await loadLedger(dir, seoul);
    expect(back.pending.length, l.pending.length);
    expect(back.scores['a']!.mae, closeTo(1.2, 1e-9));
    expect((await loadLedger(dir, paris)).pending, isEmpty);
    dir.deleteSync(recursive: true);
  });
}
