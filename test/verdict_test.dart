import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/repository.dart';
import 'package:weather_compare/verdict.dart';
import 'package:weather_compare/verify.dart';

void main() {
  const seoul = Place('서울', 'KR', 37.57, 126.98);
  final now = DateTime.utc(2026, 10, 11, 0); // 서울 9시

  Result<Forecast> fc(String id, double nowC, {int pop = 0, double dayHigh = 25, int dayPop = 0}) => Result(id,
      data: Forecast(
        now: Hour(now, nowC, Sky.cloudy),
        hours: [for (var h = 0; h <= 30; h++) Hour(now.add(Duration(hours: h)), nowC + (h < 8 ? h : 8 - (h - 8)), Sky.cloudy, pop: pop)],
        days: [Day(DateTime.utc(2026, 10, 12), dayHigh, dayHigh - 8, Sky.rain, pop: dayPop)],
      ));
  Report rep(List<Result<Forecast>> fs) => Report(seoul, fs, const [], const [], const Duration(hours: 9));

  test('agreeing sources: high confidence, middle value, rain unlikely', () {
    final v = verdict(rep([fc('a', 20), fc('b', 20.5), fc('c', 21), fc('d', 20.2)]), null, now)!;
    expect(v.tempNow, closeTo(20.35, 0.01));
    expect(v.weighted, isFalse);
    expect(v.tempConfidence, Confidence.high);
    expect(v.rain, RainCall.unlikely);
  });

  test('spread-out sources: low confidence', () {
    final v = verdict(rep([fc('a', 15), fc('b', 18), fc('c', 22), fc('d', 25)]), null, now)!;
    expect(v.tempConfidence, Confidence.low);
  });

  test('rain call: most say rain → likely; split → split', () {
    expect(verdict(rep([fc('a', 20, pop: 80), fc('b', 20, pop: 70), fc('c', 20, pop: 60), fc('d', 20, pop: 10)]), null, now)!.rain,
        RainCall.likely);
    expect(verdict(rep([fc('a', 20, pop: 80), fc('b', 20, pop: 70), fc('c', 20, pop: 10), fc('d', 20, pop: 0)]), null, now)!.rain,
        RainCall.split);
  });

  test('today high is the highest middle value left today', () {
    final v = verdict(rep([fc('a', 20), fc('b', 20), fc('c', 20)]), null, now)!;
    expect(v.todayHigh, 28); // 9시 20° → 8시간 뒤(17시) 28°
  });

  test('tomorrow: middle low/high and how many sources expect rain', () {
    final v = verdict(rep([fc('a', 20, dayHigh: 24, dayPop: 70), fc('b', 20, dayHigh: 26, dayPop: 60), fc('c', 20, dayHigh: 25, dayPop: 10)]), null, now)!;
    expect(v.tomorrow!.medHigh, 25);
    expect(v.tomorrowRain, (2, 3));
  });

  test('with enough history the middle value leans toward accurate sources and names the best one', () {
    final l = Ledger();
    for (final (id, err) in [('a', 0.4), ('b', 1.0), ('c', 3.5), ('d', 3.0)]) {
      final s = Score();
      for (var i = 0; i < 8; i++) {
        s.add(err, true);
      }
      l.scores[id] = s;
    }
    final v = verdict(rep([fc('a', 20), fc('b', 21), fc('c', 26), fc('d', 25)]), l, now)!;
    expect(v.weighted, isTrue);
    expect(v.tempNow, lessThan(22)); // 단순 가운데(23)보다 잘 맞춘 a·b 쪽
    expect(v.best!.$1, 'a');
    expect(v.comparisons, 32);
  });

  test('no forecasts → no verdict', () {
    expect(verdict(rep([const Result('a', fail: Fail.noKey)]), null, now), isNull);
  });
}
