import 'dart:convert';

import '../fetcher.dart';
import '../keys.dart';
import '../models.dart';
import 'common.dart';

const _base = 'https://api.openweathermap.org';

Sky owmSky(int id) {
  if (id < 300) return Sky.thunder;
  if (id < 600) return Sky.rain;
  if (id < 700) return Sky.snow;
  if (id < 800) return Sky.fog;
  if (id == 800) return Sky.clear;
  if (id <= 802) return Sky.partly;
  return Sky.cloudy;
}

Hour _hour(Map<String, dynamic> j, {int? pop, double? mm}) => Hour(fromEpoch(j['dt']),
    toD(j['main']['temp'])!, owmSky((j['weather'] as List).first['id'] as int), pop: pop, mm: mm);

/// 5일/3시간 예보 + 현재 날씨. 일별은 저장소가 시간별을 묶어 만든다.
Forecast parseOwmForecast(String forecastBody, String weatherBody) {
  final fc = jsonDecode(forecastBody) as Map<String, dynamic>;
  final hours = [
    for (final j in (fc['list'] as List).cast<Map<String, dynamic>>())
      _hour(j,
          pop: ((toD(j['pop']) ?? 0) * 100).round(),
          mm: (toD(j['rain']?['3h']) ?? 0) + (toD(j['snow']?['3h']) ?? 0))
  ];
  final w = jsonDecode(weatherBody) as Map<String, dynamic>;
  return Forecast(
      now: _hour(w, mm: (toD(w['rain']?['1h']) ?? 0) + (toD(w['snow']?['1h']) ?? 0)),
      hours: hours,
      utcOffset: Duration(seconds: (fc['city']['timezone'] as num).toInt()));
}

Air parseOwmAir(String body) {
  final j = (jsonDecode(body)['list'] as List).first as Map<String, dynamic>;
  return Air(
      pm10: toD(j['components']['pm10']), pm25: toD(j['components']['pm2_5']), time: fromEpoch(j['dt']));
}

String _name(Map<String, dynamic> j, String lang) =>
    (j['local_names'] as Map<String, dynamic>?)?[lang] as String? ?? j['name'] as String;

Place parseOwmReverse(String body, double lat, double lon, String lang) {
  final j = (jsonDecode(body) as List).first as Map<String, dynamic>;
  return Place(_name(j, lang), j['country'] as String? ?? '', lat, lon);
}

List<Place> parseOwmDirect(String body, String lang) => [
      for (final j in (jsonDecode(body) as List).cast<Map<String, dynamic>>())
        Place([_name(j, lang), if (j['state'] != null) j['state']].join(', '),
            j['country'] as String? ?? '', toD(j['lat'])!, toD(j['lon'])!)
    ];

Uri _u(String path, Map<String, String> q) =>
    Uri.parse('$_base$path').replace(queryParameters: {...q, 'appid': Keys.owm});

Map<String, String> _ll(Place p) => {'lat': coord(p.lat), 'lon': coord(p.lon)};

Future<Stamped<Forecast>> owmForecast(Fetcher f, Place p) async {
  requireKey(Keys.owm);
  final q = {..._ll(p), 'units': 'metric'};
  final (fc, w) = await (f.get(_u('/data/2.5/forecast', q)), f.get(_u('/data/2.5/weather', q))).wait;
  return (parseOwmForecast(fc.body, w.body), oldest([fc.at, w.at]));
}

Future<Stamped<Air>> owmAir(Fetcher f, Place p) async {
  requireKey(Keys.owm);
  final r = await f.get(_u('/data/2.5/air_pollution', _ll(p)));
  return (parseOwmAir(r.body), r.at);
}

Future<Place> owmReverse(Fetcher f, double lat, double lon, String lang) async {
  requireKey(Keys.owm);
  final r = await f.get(_u('/geo/1.0/reverse', {'lat': coord(lat), 'lon': coord(lon), 'limit': '1'}),
      maxAge: const Duration(days: 7));
  return parseOwmReverse(r.body, lat, lon, lang);
}

Future<List<Place>> owmSearch(Fetcher f, String q, String lang) async {
  requireKey(Keys.owm);
  final r = await f.get(_u('/geo/1.0/direct', {'q': q, 'limit': '5'}), maxAge: const Duration(days: 7));
  return parseOwmDirect(r.body, lang);
}
