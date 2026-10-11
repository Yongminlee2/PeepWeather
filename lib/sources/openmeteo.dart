import 'dart:convert';

import '../compare.dart';
import '../fetcher.dart';
import '../models.dart';
import 'common.dart';

/// Open-Meteo 모델 이름 → 앱 출처 id. 한 번 요청으로 여러 나라 기상청 모델을 같이 받는다.
/// 무료 API 는 비상업 용도만 — 광고·유료화하면 유료 요금제로 바꾸거나 뺀다.
const openMeteoModels = {
  'ecmwf_ifs025': 'om_ecmwf', // 유럽중기예보센터
  'gfs_seamless': 'om_gfs', // 미국 NOAA
  'icon_seamless': 'om_icon', // 독일 DWD
  'jma_seamless': 'om_jma', // 일본 기상청
  'kma_seamless': 'om_kma', // 한국 기상청 모델
  'gem_seamless': 'om_gem', // 캐나다
  'meteofrance_seamless': 'om_meteofrance', // 프랑스
  'ukmo_seamless': 'om_ukmo', // 영국
  'cma_grapes_global': 'om_cma', // 중국
  'bom_access_global': 'om_bom', // 호주
};

/// WMO 날씨 코드.
Sky wmoSky(int c) => switch (c) {
      0 => Sky.clear,
      1 || 2 => Sky.partly,
      3 => Sky.cloudy,
      45 || 48 => Sky.fog,
      >= 71 && <= 77 || 85 || 86 => Sky.snow,
      >= 95 => Sky.thunder,
      _ => c >= 51 ? Sky.rain : Sky.cloudy,
    };

/// 현지 시각 글자("2026-10-11T19:00") − 오프셋 = UTC.
DateTime _utc(String local, Duration offset) => DateTime.parse('${local}Z').subtract(offset);

/// [model] 한 개의 예보. 그 지역을 계산하지 않는 모델(기온이 전부 비어 있음)이면 null — 줄을 숨긴다.
Forecast? parseOpenMeteo(String body, String model, {DateTime? now}) {
  final j = jsonDecode(body) as Map<String, dynamic>;
  final offset = Duration(seconds: (j['utc_offset_seconds'] as num).toInt());
  final h = j['hourly'] as Map<String, dynamic>;
  List<dynamic> col(Map<String, dynamic> m, String k) => (m['${k}_$model'] as List?) ?? const [];
  final times = (h['time'] as List).cast<String>();
  final temp = col(h, 'temperature_2m'), code = col(h, 'weather_code');
  final pop = col(h, 'precipitation_probability'), mm = col(h, 'precipitation');
  final hours = [
    for (var i = 0; i < times.length; i++)
      if (i < temp.length && temp[i] != null)
        Hour(_utc(times[i], offset), toD(temp[i])!, wmoSky((i < code.length ? code[i] as num? : null)?.toInt() ?? 3),
            pop: i < pop.length ? (pop[i] as num?)?.toInt() : null, mm: i < mm.length ? toD(mm[i]) : null)
  ];
  if (hours.isEmpty) return null;
  final d = j['daily'] as Map<String, dynamic>;
  final dates = (d['time'] as List).cast<String>();
  final max = col(d, 'temperature_2m_max'), min = col(d, 'temperature_2m_min');
  final dCode = col(d, 'weather_code'), dPop = col(d, 'precipitation_probability_max');
  final days = [
    for (var i = 0; i < dates.length; i++)
      if (i < max.length && max[i] != null && min[i] != null)
        Day(dateOnly(dates[i]), toD(max[i])!, toD(min[i])!, wmoSky((dCode[i] as num?)?.toInt() ?? 3),
            pop: i < dPop.length ? (dPop[i] as num?)?.toInt() : null)
  ];
  final n = (now ?? DateTime.now()).toUtc();
  return Forecast(
      now: hourAt(hours, DateTime.utc(n.year, n.month, n.day, n.hour)) ?? hours.first,
      hours: hours,
      days: days,
      utcOffset: offset);
}

Air parseOpenMeteoAir(String body) {
  final j = jsonDecode(body) as Map<String, dynamic>;
  final c = j['current'] as Map<String, dynamic>;
  return Air(
      pm10: toD(c['pm10']),
      pm25: toD(c['pm2_5']),
      time: _utc(c['time'] as String, Duration(seconds: (j['utc_offset_seconds'] as num).toInt())));
}

/// 모든 모델을 한 번에 받는다(요청기가 같은 주소를 합쳐서 모델 수만큼 다시 부르지 않는다).
Future<Stamped<String>> openMeteoRaw(Fetcher f, Place p) async {
  final r = await f.get(Uri.https('api.open-meteo.com', '/v1/forecast', {
    'latitude': coord(p.lat),
    'longitude': coord(p.lon),
    'hourly': 'temperature_2m,precipitation_probability,precipitation,weather_code',
    'daily': 'temperature_2m_max,temperature_2m_min,precipitation_probability_max,weather_code',
    'timezone': 'auto',
    'forecast_days': '7',
    'models': openMeteoModels.keys.join(','),
  }));
  return (r.body, r.at);
}

Future<Stamped<Air>> openMeteoAir(Fetcher f, Place p) async {
  final r = await f.get(Uri.https('air-quality-api.open-meteo.com', '/v1/air-quality', {
    'latitude': coord(p.lat),
    'longitude': coord(p.lon),
    'current': 'pm10,pm2_5',
    'timezone': 'auto',
  }));
  return (parseOpenMeteoAir(r.body), r.at);
}
