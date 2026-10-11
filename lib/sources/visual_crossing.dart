import 'dart:convert';

import '../fetcher.dart';
import '../keys.dart';
import '../models.dart';
import 'common.dart';

Sky vcSky(String icon) {
  if (icon.startsWith('thunder')) return Sky.thunder;
  if (icon.startsWith('snow')) return Sky.snow;
  if (icon == 'rain' || icon.startsWith('showers')) return Sky.rain;
  if (icon == 'fog') return Sky.fog;
  if (icon.startsWith('partly-cloudy')) return Sky.partly;
  if (icon.startsWith('clear')) return Sky.clear;
  return Sky.cloudy; // cloudy, wind
}

Forecast parseVc(String body) {
  final j = jsonDecode(body) as Map<String, dynamic>;
  final days = (j['days'] as List).cast<Map<String, dynamic>>();
  final cur = j['currentConditions'] as Map<String, dynamic>?;
  return Forecast(
    now: cur == null ? null : Hour(fromEpoch(cur['datetimeEpoch']), toD(cur['temp'])!, vcSky(cur['icon'] as String)),
    hours: [
      for (final d in days)
        for (final h in ((d['hours'] as List?) ?? const []).cast<Map<String, dynamic>>())
          Hour(fromEpoch(h['datetimeEpoch']), toD(h['temp'])!, vcSky(h['icon'] as String),
              pop: toD(h['precipprob'])?.round(), mm: toD(h['precip']))
    ],
    days: [
      for (final d in days)
        Day(dateOnly(d['datetime'] as String), toD(d['tempmax'])!, toD(d['tempmin'])!, vcSky(d['icon'] as String),
            pop: toD(d['precipprob'])?.round())
    ],
    utcOffset: Duration(minutes: ((toD(j['tzoffset']) ?? 0) * 60).round()),
  );
}

Future<Stamped<Forecast>> vcForecast(Fetcher f, Place p) async {
  requireKey(Keys.visualCrossing);
  final r = await f.get(Uri.https('weather.visualcrossing.com',
      '/VisualCrossingWebServices/rest/services/timeline/${coord(p.lat)},${coord(p.lon)}', {
    'unitGroup': 'metric',
    'include': 'hours,days,current',
    'key': Keys.visualCrossing,
    'contentType': 'json',
  }));
  return (parseVc(r.body), r.at);
}
