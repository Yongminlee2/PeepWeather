import 'dart:convert';

import '../fetcher.dart';
import '../models.dart';
import 'common.dart';

double fToC(num f) => (f - 32) * 5 / 9;

Sky nwsSky(String text) {
  final t = text.toLowerCase();
  if (t.contains('thunder')) return Sky.thunder;
  if (t.contains('snow') || t.contains('sleet') || t.contains('flurr')) return Sky.snow;
  if (t.contains('rain') || t.contains('shower') || t.contains('drizzle')) return Sky.rain;
  if (t.contains('fog') || t.contains('haze')) return Sky.fog;
  if (t.contains('partly') || t.contains('mostly sunny') || t.contains('mostly clear')) return Sky.partly;
  if (t.contains('cloudy') || t.contains('overcast')) return Sky.cloudy;
  return Sky.clear;
}

Uri nwsHourlyUrl(String pointsBody) =>
    Uri.parse(jsonDecode(pointsBody)['properties']['forecastHourly'] as String);

Forecast parseNwsHourly(String body) {
  final ps = (jsonDecode(body)['properties']['periods'] as List).cast<Map<String, dynamic>>();
  final hours = [
    for (final p in ps)
      Hour(DateTime.parse(p['startTime'] as String).toUtc(),
          p['temperatureUnit'] == 'F' ? fToC(p['temperature'] as num) : toD(p['temperature'])!,
          nwsSky(p['shortForecast'] as String),
          pop: (p['probabilityOfPrecipitation']?['value'] as num?)?.toInt())
  ];
  final m = ps.isEmpty ? null : RegExp(r'([+-])(\d\d):(\d\d)$').firstMatch(ps.first['startTime'] as String);
  final offset = m == null
      ? null
      : Duration(hours: int.parse(m[2]!), minutes: int.parse(m[3]!)) * (m[1] == '-' ? -1 : 1);
  return Forecast(now: hours.isEmpty ? null : hours.first, hours: hours, utcOffset: offset);
}

/// 미국 안에서만 응답한다(밖이면 404 → network 실패로 표시되지 않도록 저장소가 미국일 때만 부름).
Future<Stamped<Forecast>> nwsForecast(Fetcher f, Place p) async {
  final pts = await f.get(Uri.parse('https://api.weather.gov/points/${p.lat.toStringAsFixed(4)},${p.lon.toStringAsFixed(4)}'),
      maxAge: const Duration(days: 30));
  final r = await f.get(nwsHourlyUrl(pts.body), headers: {'Accept': 'application/geo+json'});
  return (parseNwsHourly(r.body), r.at);
}
