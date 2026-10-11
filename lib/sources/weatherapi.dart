import 'dart:convert';

import '../fetcher.dart';
import '../keys.dart';
import '../models.dart';
import 'common.dart';

const _fog = {1030, 1135, 1147};
const _thunder = {1087, 1273, 1276, 1279, 1282};
const _snow = {1066, 1069, 1072, 1114, 1117, 1168, 1171, 1204, 1207, 1210, 1213, 1216, 1219, 1222, 1225,
  1237, 1249, 1252, 1255, 1258, 1261, 1264};

Sky weatherApiSky(int code) => switch (code) {
      1000 => Sky.clear,
      1003 => Sky.partly,
      1006 || 1009 => Sky.cloudy,
      _ when _fog.contains(code) => Sky.fog,
      _ when _thunder.contains(code) => Sky.thunder,
      _ when _snow.contains(code) => Sky.snow,
      _ => Sky.rain,
    };

int _code(Map<String, dynamic> j) => j['condition']['code'] as int;

Forecast parseWeatherApi(String body) {
  final j = jsonDecode(body) as Map<String, dynamic>;
  final loc = j['location'] as Map<String, dynamic>;
  // localtime("2026-10-11 18:00")을 UTC 로 읽은 값 − 실제 UTC = 시간대 오프셋(30분 단위로 반올림)
  final lt = RegExp(r'(\d+)-(\d+)-(\d+) (\d+):(\d+)').firstMatch(loc['localtime'] as String)!;
  final localAsUtc = DateTime.utc(int.parse(lt[1]!), int.parse(lt[2]!), int.parse(lt[3]!), int.parse(lt[4]!), int.parse(lt[5]!));
  final mins = localAsUtc.difference(fromEpoch(loc['localtime_epoch'])).inMinutes;
  final cur = j['current'] as Map<String, dynamic>;
  final days = (j['forecast']['forecastday'] as List).cast<Map<String, dynamic>>();
  return Forecast(
    now: Hour(fromEpoch(cur['last_updated_epoch']), toD(cur['temp_c'])!, weatherApiSky(_code(cur))),
    hours: [
      for (final d in days)
        for (final h in (d['hour'] as List).cast<Map<String, dynamic>>())
          Hour(fromEpoch(h['time_epoch']), toD(h['temp_c'])!, weatherApiSky(_code(h)),
              pop: (h['chance_of_rain'] as num?)?.toInt(), mm: toD(h['precip_mm']))
    ],
    days: [
      for (final d in days)
        Day(dateOnly(d['date'] as String), toD(d['day']['maxtemp_c'])!, toD(d['day']['mintemp_c'])!,
            weatherApiSky(_code(d['day'] as Map<String, dynamic>)),
            pop: (d['day']['daily_chance_of_rain'] as num?)?.toInt())
    ],
    utcOffset: Duration(minutes: (mins / 30).round() * 30),
  );
}

Air parseWeatherApiAir(String body) {
  final cur = jsonDecode(body)['current'] as Map<String, dynamic>;
  final aq = cur['air_quality'] as Map<String, dynamic>;
  return Air(pm10: toD(aq['pm10']), pm25: toD(aq['pm2_5']), time: fromEpoch(cur['last_updated_epoch']));
}

/// 한 번 요청으로 예보와 미세먼지를 같이 받는다(무료 한도가 작아서).
Future<Stamped<String>> weatherApiRaw(Fetcher f, Place p) async {
  requireKey(Keys.weatherApi);
  final r = await f.get(Uri.https('api.weatherapi.com', '/v1/forecast.json', {
    'key': Keys.weatherApi,
    'q': '${coord(p.lat)},${coord(p.lon)}',
    'days': '3',
    'aqi': 'yes',
    'alerts': 'no',
  }));
  return (r.body, r.at);
}
