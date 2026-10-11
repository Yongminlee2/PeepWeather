import 'dart:convert';

import '../fetcher.dart';
import '../keys.dart';
import '../models.dart';
import 'common.dart';

List<Map<String, dynamic>> _results(String body) =>
    (jsonDecode(body)['results'] as List).cast<Map<String, dynamic>>();

Set<int> parseCommercialLicenses(String body) =>
    {for (final r in _results(body)) if (r['commercialUseAllowed'] == true) r['id'] as int};

/// 상업 이용이 허용된 라이선스의 측정소 중 PM 센서가 있는 곳, 가까운 순.
/// (위치 id, 이름, 센서 id → 'pm10'|'pm25')
List<(int, String, Map<int, String>)> parseLocations(String body, Set<int> allowed) {
  final locs = _results(body)
      .where((l) => ((l['licenses'] as List?) ?? const []).any((x) => allowed.contains(x['id'])))
      .toList()
    ..sort((a, b) => (toD(a['distance']) ?? 0).compareTo(toD(b['distance']) ?? 0));
  return [
    for (final l in locs)
      if ({
        for (final s in (l['sensors'] as List).cast<Map<String, dynamic>>())
          if (s['parameter']['name'] == 'pm10' || s['parameter']['name'] == 'pm25')
            s['id'] as int: s['parameter']['name'] as String
      } case final sensors when sensors.isNotEmpty)
        (l['id'] as int, l['name'] as String, sensors)
  ];
}

Air parseOpenAqLatest(String body, Map<int, String> sensors, String name) {
  double? pm10, pm25;
  DateTime? t;
  for (final r in _results(body)) {
    final p = sensors[r['sensorsId']];
    if (p == null) continue;
    if (p == 'pm10') pm10 = toD(r['value']);
    if (p == 'pm25') pm25 = toD(r['value']);
    t ??= DateTime.parse(r['datetime']['utc'] as String);
  }
  if (t == null) throw const FormatException('no pm values');
  return Air(pm10: pm10, pm25: pm25, station: name, time: t);
}

Future<Stamped<Air>> openAq(Fetcher f, Place p) async {
  requireKey(Keys.openAq);
  final h = {'X-API-Key': Keys.openAq};
  Uri u(String path, [Map<String, String>? q]) => Uri.https('api.openaq.org', '/v3/$path', q);
  final (lic, locs) = await (
    f.get(u('licenses', {'limit': '1000'}), headers: h, maxAge: const Duration(days: 30)),
    f.get(u('locations', {'coordinates': '${coord(p.lat)},${coord(p.lon)}', 'radius': '25000', 'limit': '20'}),
        headers: h, maxAge: const Duration(days: 1)),
  ).wait;
  final found = parseLocations(locs.body, parseCommercialLicenses(lic.body));
  if (found.isEmpty) throw const FormatException('no station nearby');
  final (id, name, sensors) = found.first;
  final r = await f.get(u('locations/$id/latest'), headers: h);
  return (parseOpenAqLatest(r.body, sensors, name), r.at);
}
