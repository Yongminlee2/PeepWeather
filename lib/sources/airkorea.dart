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

Future<Stamped<Air>> airKorea(Fetcher f, Place p) async {
  requireKey(Keys.dataGoKr);
  Uri u(String path, Map<String, String> q) => Uri.https('apis.data.go.kr', '/B552584/$path',
      {'serviceKey': Keys.dataGoKr, 'returnType': 'json', 'pageNo': '1', ...q});
  final st = await f.get(u('MsrstnInfoInqireSvc/getMsrstnList', {'numOfRows': '1000'}),
      maxAge: const Duration(days: 30), check: checkDataGoKr);
  final name = nearestStation(parseStations(st.body), p.lat, p.lon);
  final r = await f.get(u('ArpltnInforInqireSvc/getMsrstnAcctoRltmMesureDnsty',
      {'numOfRows': '1', 'stationName': name, 'dataTerm': 'DAILY', 'ver': '1.3'}), check: checkDataGoKr);
  return (parseAirKorea(r.body, name), r.at);
}
