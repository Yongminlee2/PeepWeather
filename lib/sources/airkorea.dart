import 'dart:convert';

import '../compare.dart';
import '../fetcher.dart';
import '../keys.dart';
import '../models.dart';
import 'common.dart';

List<Map<String, dynamic>> _items(String body) {
  checkDataGoKr(body);
  return (jsonDecode(body)['response']['body']['items'] as List).cast<Map<String, dynamic>>();
}

/// 측정소 목록 → (이름, 위도, 경도). dmX/dmY 중 30~45 범위인 쪽을 위도로 본다.
List<(String, double, double)> parseStations(String body) => [
      for (final it in _items(body))
        if (toD(it['dmX']) != null && toD(it['dmY']) != null)
          () {
            final a = toD(it['dmX'])!, b = toD(it['dmY'])!;
            return (it['stationName'] as String, a < 45 ? a : b, a < 45 ? b : a);
          }()
    ];

String nearestStation(List<(String, double, double)> s, double lat, double lon) =>
    (s.toList()..sort((x, y) => distanceKm(lat, lon, x.$2, x.$3).compareTo(distanceKm(lat, lon, y.$2, y.$3))))
        .first
        .$1;

Air parseAirKorea(String body, String station) {
  final it = _items(body).first;
  final m = RegExp(r'(\d+)-(\d+)-(\d+) (\d+):(\d+)').firstMatch(it['dataTime'] as String)!;
  final t = DateTime.utc(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!), int.parse(m[4]!))
      .subtract(const Duration(hours: 9)); // "24:00" 도 DateTime 이 다음날 0시로 넘겨준다
  return Air(pm10: toD(it['pm10Value']), pm25: toD(it['pm25Value']), station: station, time: t);
}

/// 측정소 목록(약 670곳)을 300곳씩 나눠 받는다. 한 번에 1000곳을 달라면 서버가 504 로 끊는다(2026-10-12 확인).
Future<List<(String, double, double)>> fetchStations(Fetcher f, Uri Function(Map<String, String> q) u) async {
  const per = 300;
  final out = <(String, double, double)>[];
  for (var page = 1, total = per; (page - 1) * per < total; page++) {
    final r = await f.get(u({'numOfRows': '$per', 'pageNo': '$page'}),
        maxAge: const Duration(days: 30), check: checkDataGoKr);
    total = (jsonDecode(r.body)['response']['body']['totalCount'] as num).toInt();
    out.addAll(parseStations(r.body));
  }
  return out;
}

Future<Stamped<Air>> airKorea(Fetcher f, Place p) async {
  requireKey(Keys.dataGoKr);
  Uri u(String path, Map<String, String> q) => Uri.https('apis.data.go.kr', '/B552584/$path',
      {'serviceKey': Keys.dataGoKr, 'returnType': 'json', 'pageNo': '1', ...q});
  final name = nearestStation(await fetchStations(f, (q) => u('MsrstnInfoInqireSvc/getMsrstnList', q)), p.lat, p.lon);
  final r = await f.get(u('ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty',
      {'numOfRows': '1', 'stationName': name, 'dataTerm': 'DAILY', 'ver': '1.3'}), check: checkDataGoKr);
  return (parseAirKorea(r.body, name), r.at);
}
