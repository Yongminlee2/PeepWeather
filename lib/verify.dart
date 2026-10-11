import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'models.dart';
import 'repository.dart';

/// "이 동네에서 어느 기관이 잘 맞췄나" — 기관별 하루쯤 전 예보를 저장해 두고,
/// 그 시각에 실제 관측과 비교해 오차를 쌓는다.
///
/// 관측: 한국은 기상청 초단기실황(관측소), 그 밖은 OpenWeather 현재값.
/// 저장: 장소마다 파일 하나(verify_<위도>_<경도>.json).

const minLead = Duration(hours: 12), maxLead = Duration(hours: 36);

class Prediction {
  final String source;
  final DateTime target; // UTC, 정시
  final double tempC;
  final bool wet;
  const Prediction(this.source, this.target, this.tempC, this.wet);
  Map<String, dynamic> toJson() => {'s': source, 't': target.toIso8601String(), 'c': tempC, 'w': wet};
  factory Prediction.fromJson(Map<String, dynamic> j) =>
      Prediction(j['s'] as String, DateTime.parse(j['t'] as String), (j['c'] as num).toDouble(), j['w'] as bool);
}

class Score {
  int n = 0, rainHits = 0;
  double absErr = 0;
  void add(double err, bool rainHit) {
    n++;
    absErr += err.abs();
    if (rainHit) rainHits++;
  }

  double get mae => n == 0 ? double.nan : absErr / n;
  double get rainHitRate => n == 0 ? double.nan : rainHits / n;
  Map<String, dynamic> toJson() => {'n': n, 'e': absErr, 'r': rainHits};
  static Score fromJson(Map<String, dynamic> j) => Score()
    ..n = j['n'] as int
    ..absErr = (j['e'] as num).toDouble()
    ..rainHits = j['r'] as int;
}

class Ledger {
  final pending = <String, Prediction>{}; // "출처|시각"
  final scores = <String, Score>{};

  Map<String, dynamic> toJson() => {
        'p': [for (final p in pending.values) p.toJson()],
        's': {for (final e in scores.entries) e.key: e.value.toJson()},
      };
  static Ledger fromJson(Map<String, dynamic> j) {
    final l = Ledger();
    for (final p in (j['p'] as List? ?? const [])) {
      final x = Prediction.fromJson(p as Map<String, dynamic>);
      l.pending['${x.source}|${x.target.toIso8601String()}'] = x;
    }
    (j['s'] as Map? ?? const {}).forEach((k, v) => l.scores[k as String] = Score.fromJson(v as Map<String, dynamic>));
    return l;
  }
}

bool _wet(Hour h) => (h.pop != null && h.pop! >= 50) || (h.pop == null && (h.mm ?? 0) >= 0.5);

/// 12~36시간 뒤 정시 예보를 기관별로 저장(이미 있으면 먼저 저장한 것, 즉 더 먼저 한 예보를 둔다).
void record(Ledger l, Report r, DateTime nowUtc) {
  for (final f in r.forecasts) {
    for (final h in f.data?.hours ?? const <Hour>[]) {
      final lead = h.time.difference(nowUtc);
      if (h.time.minute != 0 || lead < minLead || lead > maxLead) continue;
      l.pending.putIfAbsent('${f.source}|${h.time.toIso8601String()}', () => Prediction(f.source, h.time, h.tempC, _wet(h)));
    }
  }
}

class Observation {
  final String source; // 'kma' | 'owm'
  final DateTime time;
  final double tempC;
  final bool wet;
  const Observation(this.source, this.time, this.tempC, this.wet);
}

/// 지금 관측값: 한국이면 기상청 실황, 아니면 OpenWeather 현재값.
Observation? observation(Report r) {
  final id = isKorea(r.place) ? 'kma' : 'owm';
  final h = r.forecasts.where((f) => f.source == id).firstOrNull?.data?.now;
  if (h == null) return null;
  return Observation(id, h.time, h.tempC, (h.mm ?? 0) > 0 || h.sky.index >= Sky.rain.index);
}

/// 관측 시각을 가장 가까운 정시로 맞춰 그 시각 예보와 비교해 점수에 더하고 지운다.
/// 3시간 넘게 지난 예보는 비교할 관측이 없으니 버린다.
void verify(Ledger l, Observation o, DateTime nowUtc) {
  final hour = DateTime.utc(o.time.year, o.time.month, o.time.day, o.time.hour)
      .add(Duration(hours: o.time.minute >= 30 ? 1 : 0));
  final done = <String>[];
  l.pending.forEach((k, p) {
    if (p.target == hour) {
      l.scores.putIfAbsent(p.source, Score.new).add(p.tempC - o.tempC, p.wet == o.wet);
      done.add(k);
    } else if (p.target.isBefore(nowUtc.subtract(const Duration(hours: 3)))) {
      done.add(k);
    }
  });
  done.forEach(l.pending.remove);
}

/// 비교가 [minN] 번 넘게 쌓인 기관을 평균 오차 작은 순으로.
List<(String, Score)> ranking(Ledger l, {int minN = 5}) =>
    [for (final e in l.scores.entries) if (e.value.n >= minN) (e.key, e.value)]..sort((a, b) => a.$2.mae.compareTo(b.$2.mae));

/// 잘 맞춘 기관에 무게를 둔 기온(가중치 1/(평균오차+0.5)²). 자료가 넉넉한 기관이 3곳 미만이면 null.
double? weightedTemp(Map<String, double> temps, Ledger l, {int minN = 5}) {
  final eligible = [
    for (final e in temps.entries)
      if ((l.scores[e.key]?.n ?? 0) >= minN) (e.value, 1 / pow(l.scores[e.key]!.mae + 0.5, 2))
  ];
  if (eligible.length < 3) return null;
  final wsum = eligible.fold(0.0, (a, e) => a + e.$2);
  return eligible.fold(0.0, (a, e) => a + e.$1 * e.$2) / wsum;
}

File _file(Directory dir, Place p) =>
    File('${dir.path}/verify_${p.lat.toStringAsFixed(2)}_${p.lon.toStringAsFixed(2)}.json');

Future<Ledger> loadLedger(Directory dir, Place p) async {
  try {
    final f = _file(dir, p);
    if (!await f.exists()) return Ledger();
    return Ledger.fromJson(jsonDecode(await f.readAsString()) as Map<String, dynamic>);
  } catch (_) {
    return Ledger(); // 깨졌으면 새로 시작
  }
}

Future<void> saveLedger(Directory dir, Place p, Ledger l) async {
  await dir.create(recursive: true);
  final f = _file(dir, p);
  final tmp = File('${f.path}.tmp');
  await tmp.writeAsString(jsonEncode(l.toJson()));
  await tmp.rename(f.path);
}

/// 보고서 하나가 들어올 때마다: 불러오기 → 관측과 비교 → 새 예보 저장 → 쓰기.
Future<Ledger> updateLedger(Directory dir, Report r, DateTime nowUtc) async {
  final l = await loadLedger(dir, r.place);
  if (observation(r) case final o?) verify(l, o, nowUtc);
  record(l, r, nowUtc);
  await saveLedger(dir, r.place, l);
  return l;
}
