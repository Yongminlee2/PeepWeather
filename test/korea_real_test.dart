import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weather_compare/fetcher.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/sources/airkorea.dart';
import 'package:weather_compare/sources/cyclones.dart';
import 'package:weather_compare/sources/kma.dart';
import 'package:weather_compare/sources/satellite.dart';

String fx(String name) => File('test/fixtures/$name').readAsStringSync();

/// 공공데이터포털 실제 응답(2026-10-11 저녁, 서울 격자 60,127).
void main() {
  test('KMA short-term forecast and nowcast', () {
    final f = parseKma(fx('kma_vilage_real.json'), fx('kma_ncst_real.json'));
    expect(f.hours.length, greaterThan(60));
    expect(f.utcOffset, const Duration(hours: 9));
    expect(f.now!.tempC, 26.0); // 초단기실황 T1H
    expect(f.days.length, greaterThanOrEqualTo(3));
    expect(f.hours.every((h) => h.pop != null && h.mm != null), isTrue);
  });

  test('AirKorea station measurement', () {
    final a = parseAirKorea(fx('airkorea_measure_real.json'), '중구');
    expect(a.pm10, 25);
    expect(a.station, '중구');
  });

  test('KMA typhoon KOGUMA with English name for grouping', () {
    final cs = parseKmaTyphoon(fx('kma_typhoon_real.json'));
    final k = cs.firstWhere((c) => c.name.contains('KOGUMA'));
    expect(k.name, '고구마 KOGUMA');
    expect([k.lat, k.lon], [25.3, 147.8]);
    expect(k.windKt, closeTo(95.2, 0.1)); // 49 m/s
  });

  test('KMA satellite list gives the newest full-size image', () {
    final u = parseKmaSat(fx('kma_sat_real.json'));
    expect(u.toString(), endsWith('_202610111032.srv.png'));
    expect(u.scheme, 'https');
  });

  test('typhoon fixture keeps one entry per storm', () {
    final cs = parseKmaTyphoon(fx('kma_typhoon_real.json'));
    expect(cs.map((c) => c.name).toSet().length, cs.length);
  });

  test('no data.go.kr error in real bodies', () {
    for (final f in ['kma_vilage_real.json', 'kma_ncst_real.json', 'airkorea_measure_real.json', 'kma_typhoon_real.json']) {
      expect(fx(f).contains('SERVICE_KEY'), isFalse, reason: f);
    }
  });

  test('station list parse still works on a real-shaped row', () {
    const body = '{"response":{"body":{"items":[{"dmX":"34.76479","dmY":"127.078068","stationName":"보성읍"}]},"header":{"resultCode":"00"}}}';
    expect(parseStations(body).single, ('보성읍', 34.76479, 127.078068));
  });

  test('Fail enum unaffected', () => expect(Fail.values, contains(Fail.notCovered)));

  test('KMA satellite frames: every 10 minutes, oldest first, full size, with UTC time', () {
    final fs = parseKmaSatFrames(fx('kma_sat_real.json'), count: 18);
    expect(fs.length, 18);
    expect(fs.last.$1, DateTime.utc(2026, 10, 11, 10, 32));
    expect(fs[fs.length - 2].$1, DateTime.utc(2026, 10, 11, 10, 22));
    expect(fs.first.$1.isBefore(fs.last.$1), isTrue);
    expect(fs.every((f) => f.$2.toString().endsWith('.srv.png') && f.$2.scheme == 'https'), isTrue);
  });

  test('KMA observation carries the last hour rain amount', () {
    expect(parseKma(fx('kma_vilage_real.json'), fx('kma_ncst_real.json')).now!.mm, 0.0); // RN1 = 0
  });

  test('station list is fetched in pages: one big page times out on the real server (504)', () async {
    final dir = Directory.systemTemp.createTempSync('stations');
    addTearDown(() => dir.deleteSync(recursive: true));
    final all = [for (var i = 0; i < 672; i++) {'stationName': 's$i', 'dmX': '${33 + i * 0.005}', 'dmY': '127.0'}];
    final net = MockClient((r) async {
      final n = int.parse(r.url.queryParameters['numOfRows']!), page = int.parse(r.url.queryParameters['pageNo']!);
      if (n > 700) return http.Response('', 504);
      final items = all.skip((page - 1) * n).take(n).toList();
      return http.Response(
          jsonEncode({'response': {'header': {'resultCode': '00'}, 'body': {'totalCount': all.length, 'items': items}}}), 200);
    });
    Uri u(Map<String, String> q) => Uri.https('apis.data.go.kr', '/B552584/MsrstnInfoInqireSvc/getMsrstnList', q);
    final s = await fetchStations(Fetcher(net, dir), u);
    expect(s.length, 672);
    expect(s.last.$1, 's671');
  });
}
