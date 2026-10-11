import 'dart:convert';
import 'dart:math';

import '../compare.dart';
import '../fetcher.dart';
import '../keys.dart';
import '../models.dart';
import 'common.dart';

const kst = Duration(hours: 9);

/// 위경도 → 기상청 동네예보 격자(람베르트 정각원추도법).
(int, int) kmaGrid(double lat, double lon) {
  const re = 6371.00877 / 5.0, deg = pi / 180;
  const slat1 = 30 * deg, slat2 = 60 * deg, olon = 126 * deg, olat = 38 * deg;
  var sn = tan(pi * 0.25 + slat2 * 0.5) / tan(pi * 0.25 + slat1 * 0.5);
  sn = log(cos(slat1) / cos(slat2)) / log(sn);
  final sf = pow(tan(pi * 0.25 + slat1 * 0.5), sn) * cos(slat1) / sn;
  final ro = re * sf / pow(tan(pi * 0.25 + olat * 0.5), sn);
  final ra = re * sf / pow(tan(pi * 0.25 + lat * deg * 0.5), sn);
  var theta = lon * deg - olon;
  if (theta > pi) theta -= 2 * pi;
  if (theta < -pi) theta += 2 * pi;
  theta *= sn;
  return ((ra * sin(theta) + 43 + 0.5).floor(), (ro - ra * cos(theta) + 136 + 0.5).floor());
}

DateTime _naive(DateTime d) => DateTime.utc(d.year, d.month, d.day, d.hour, d.minute);

/// 단기예보 발표 시각: 02·05·…·23시, 발표 10분 뒤부터 조회 가능.
(String, String) kmaBase(DateTime nowKst) {
  final t = _naive(nowKst).subtract(const Duration(minutes: 10));
  final h = (t.hour + 1) ~/ 3 * 3 - 1;
  final d = h < 0 ? t.subtract(const Duration(days: 1)) : t;
  return (ymd(d), '${two(h < 0 ? 23 : h)}00');
}

/// 초단기실황: 매시 정각 자료가 40분 뒤부터 조회 가능.
(String, String) kmaNcstBase(DateTime nowKst) {
  final t = _naive(nowKst).subtract(const Duration(minutes: 40));
  return (ymd(t), '${two(t.hour)}00');
}

Sky kmaSky(int sky, int pty) => switch (pty) {
      1 || 4 || 5 || 6 => Sky.rain,
      2 || 3 || 7 => Sky.snow,
      _ => sky == 1 ? Sky.clear : sky == 3 ? Sky.partly : Sky.cloudy,
    };

/// 강수량 글자("강수없음", "1mm 미만", "6.2mm", "30.0~50.0mm", "50.0mm 이상") → mm.
double pcpMm(String s) {
  if (s.contains('없음')) return 0;
  if (s.contains('미만')) return 0.5;
  return double.tryParse(RegExp(r'[\d.]+').firstMatch(s)?.group(0) ?? '') ?? 0;
}

List<Map<String, dynamic>> _items(String body) {
  checkDataGoKr(body);
  return (jsonDecode(body)['response']['body']['items']['item'] as List).cast<Map<String, dynamic>>();
}

DateTime _kstToUtc(String date, String hhmm) => DateTime.utc(int.parse(date.substring(0, 4)),
        int.parse(date.substring(4, 6)), int.parse(date.substring(6, 8)), int.parse(hhmm.substring(0, 2)))
    .subtract(kst);

Forecast parseKma(String vilageBody, String ncstBody) {
  final slots = <String, Map<String, String>>{};
  for (final it in _items(vilageBody)) {
    slots.putIfAbsent('${it['fcstDate']}${it['fcstTime']}', () => {})[it['category'] as String] = '${it['fcstValue']}';
  }
  final keys = slots.keys.toList()..sort();
  final hours = <Hour>[];
  final tmx = <DateTime, double>{}, tmn = <DateTime, double>{};
  for (final k in keys) {
    final v = slots[k]!;
    final date = dateOnly('${k.substring(0, 4)}-${k.substring(4, 6)}-${k.substring(6, 8)}');
    if (v['TMX'] != null) tmx[date] = double.parse(v['TMX']!);
    if (v['TMN'] != null) tmn[date] = double.parse(v['TMN']!);
    if (v['TMP'] == null) continue;
    hours.add(Hour(_kstToUtc(k.substring(0, 8), k.substring(8)), double.parse(v['TMP']!),
        kmaSky(int.parse(v['SKY'] ?? '1'), int.parse(v['PTY'] ?? '0')),
        pop: int.tryParse(v['POP'] ?? ''), mm: v['PCP'] == null ? null : pcpMm(v['PCP']!)));
  }
  final days = [
    for (final d in daysFromHours(hours, kst))
      Day(d.date, tmx[d.date] ?? d.maxC, tmn[d.date] ?? d.minC, d.sky,
          pop: d.pop, partial: d.partial && !(tmx.containsKey(d.date) && tmn.containsKey(d.date)))
  ];
  final n = {for (final it in _items(ncstBody)) it['category'] as String: '${it['obsrValue']}'};
  final first = _items(ncstBody).first;
  final pty = int.tryParse(n['PTY'] ?? '0') ?? 0;
  final now = n['T1H'] == null
      ? null
      : Hour(_kstToUtc(first['baseDate'] as String, first['baseTime'] as String), double.parse(n['T1H']!),
          pty > 0 ? kmaSky(4, pty) : (hours.isEmpty ? Sky.clear : hours.first.sky),
          mm: n['RN1'] == null ? null : pcpMm(n['RN1']!)); // 지난 1시간 실제 강수량(관측)
  return Forecast(now: now, hours: hours, days: days, utcOffset: kst);
}

Future<Stamped<Forecast>> kmaForecast(Fetcher f, Place p) async {
  requireKey(Keys.dataGoKr);
  final (nx, ny) = kmaGrid(p.lat, p.lon);
  final nowKst = DateTime.now().toUtc().add(kst);
  Uri u(String op, (String, String) base, String rows) =>
      Uri.https('apis.data.go.kr', '/1360000/VilageFcstInfoService_2.0/$op', {
        'serviceKey': Keys.dataGoKr,
        'pageNo': '1',
        'numOfRows': rows,
        'dataType': 'JSON',
        'base_date': base.$1,
        'base_time': base.$2,
        'nx': '$nx',
        'ny': '$ny',
      });
  final (v, n) = await (
    f.get(u('getVilageFcst', kmaBase(nowKst), '1500'), check: checkDataGoKr),
    f.get(u('getUltraSrtNcst', kmaNcstBase(nowKst), '20'), check: checkDataGoKr)
  ).wait;
  return (parseKma(v.body, n.body), oldest([v.at, n.at]));
}
