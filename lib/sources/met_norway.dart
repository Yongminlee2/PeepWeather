import 'dart:convert';

import '../fetcher.dart';
import '../models.dart';
import 'common.dart';

Sky metSky(String symbol) {
  final s = symbol.replaceAll(RegExp(r'_(day|night|polartwilight)$'), '');
  if (s.contains('thunder')) return Sky.thunder;
  if (s.contains('snow') || s.contains('sleet')) return Sky.snow;
  if (s.contains('rain') || s.contains('showers')) return Sky.rain;
  if (s == 'fog') return Sky.fog;
  if (s == 'cloudy') return Sky.cloudy;
  if (s == 'fair' || s == 'partlycloudy') return Sky.partly;
  return Sky.clear;
}

/// Locationforecast 2.0 compact. 강수확률은 없고 강수량(mm)만 있다.
Forecast parseMet(String body) {
  final ts = (jsonDecode(body)['properties']['timeseries'] as List).cast<Map<String, dynamic>>();
  final hours = <Hour>[];
  for (final t in ts) {
    final data = t['data'] as Map<String, dynamic>;
    final next = (data['next_1_hours'] ?? data['next_6_hours']) as Map<String, dynamic>?;
    final symbol = next?['summary']?['symbol_code'] as String?;
    if (symbol == null) continue;
    hours.add(Hour(DateTime.parse(t['time'] as String),
        toD(data['instant']['details']['air_temperature'])!, metSky(symbol),
        mm: toD(next!['details']?['precipitation_amount'])));
  }
  return Forecast(now: hours.isEmpty ? null : hours.first, hours: hours);
}

Future<Stamped<Forecast>> metForecast(Fetcher f, Place p) async {
  final r = await f.get(Uri.parse(
      'https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=${coord(p.lat)}&lon=${coord(p.lon)}'));
  return (parseMet(r.body), r.at);
}
