import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/repository.dart';
import 'package:weather_compare/settings.dart';

String fx(String name) => File('test/fixtures/$name').readAsStringSync();

/// 호스트별로 저장해 둔 실제 응답을 돌려주는 가짜 인터넷.
http.Client fakeNet({String? met}) => MockClient((r) async {
      final body = switch (r.url.host) {
        'api.met.no' => met ?? fx('met.json'),
        // Open-Meteo 시험 자료는 서울 것뿐 — 다른 도시는 못 받은 것으로
        'api.open-meteo.com' when r.url.queryParameters['latitude']!.startsWith('37.') => fx('openmeteo_real.json'),
        'air-quality-api.open-meteo.com' when r.url.queryParameters['latitude']!.startsWith('37.') =>
          fx('openmeteo_air_real.json'),
        'www.gdacs.org' => fx('gdacs.json'),
        'www.nhc.noaa.gov' => fx('nhc.json'),
        'www.metoc.navy.mil' => r.url.path.endsWith('.rss') ? fx('jtwc.rss') : fx('jtwc_warn.txt'),
        'api.weather.gov' => r.url.path.startsWith('/points') ? fx('nws_points.json') : fx('nws_hourly.json'),
        _ => null,
      };
      return body == null ? http.Response('not found', 404) : http.Response.bytes(utf8.encode(body), 200);
    });

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('repo'));
  tearDown(() => dir.deleteSync(recursive: true));

  const seoul = Place('서울', 'KR', 37.57, 126.98);
  const ny = Place('New York', 'US', 40.71, -74.01);
  const paris = Place('Paris', 'FR', 48.85, 2.35);

  Map<String, Fail?> fails<T>(List<Result<T>> rs) => {for (final r in rs) r.source: r.fail};

  test('loadReport with no keys', () async {
    final r = await loadReport(Fetcher(fakeNet(), dir), seoul, deviceOffset: const Duration(hours: 9));
    final fc = fails(r.forecasts);
    expect(fc['met'], isNull);
    expect(r.forecasts.firstWhere((x) => x.source == 'met').ok, isTrue);
    for (final s in ['owm', 'weatherapi', 'vc', 'kma']) {
      expect(fc[s], Fail.noKey, reason: s);
    }
    expect(fails(r.air), {'owm': Fail.noKey, 'weatherapi': Fail.noKey, 'openaq': Fail.noKey, 'om_cams': null, 'airkorea': Fail.noKey});
    final cy = fails(r.cyclones);
    expect([cy['gdacs'], cy['nhc'], cy['jtwc']], [null, null, null]);
    expect(cy['kma_typhoon'], Fail.noKey);
  });

  test('parse error isolates one source', () async {
    final r = await loadReport(Fetcher(fakeNet(met: '{}'), dir), seoul);
    expect(fails(r.forecasts)['met'], Fail.parse);
    expect(r.cyclones.firstWhere((x) => x.source == 'nhc').ok, isTrue);
  });

  test('sources depend on country', () {
    final f = Fetcher(fakeNet(), dir);
    List<String> names<T>(List<Source<T>> s) => s.map((e) => e.name).toList();
    const om = ['om_ecmwf', 'om_gfs', 'om_icon', 'om_jma', 'om_kma', 'om_gem', 'om_meteofrance', 'om_ukmo', 'om_cma', 'om_bom'];
    expect(names(forecastSources(f, seoul)), ['met', 'owm', 'weatherapi', 'vc', ...om, 'kma']);
    expect(names(airSources(f, seoul)), ['owm', 'weatherapi', 'openaq', 'om_cams', 'airkorea']);
    expect(names(cycloneSources(f, seoul)), ['gdacs', 'nhc', 'jtwc', 'kma_typhoon']);
    expect(names(forecastSources(f, ny)), ['met', 'owm', 'weatherapi', 'vc', ...om, 'nws']);
    expect(names(forecastSources(f, paris)), ['met', 'owm', 'weatherapi', 'vc', ...om]);
    expect(names(airSources(f, paris)), ['owm', 'weatherapi', 'openaq', 'om_cams']);
  });

  test('background skips small-quota sources', () {
    final f = Fetcher(fakeNet(), dir);
    expect(forecastSources(f, ny, background: true).map((e) => e.name), ['met', 'owm', 'nws']);
    expect(airSources(f, seoul, background: true).map((e) => e.name), ['owm', 'openaq', 'om_cams', 'airkorea']);
  });

  test('offset comes from a source and fills missing daily rows', () async {
    final r = await loadReport(Fetcher(fakeNet(), dir), ny, deviceOffset: const Duration(hours: 9));
    expect(r.offset, const Duration(hours: -4)); // NWS 가 알려준 뉴욕 시간대
    final met = r.forecasts.firstWhere((x) => x.source == 'met').data!;
    expect(met.days, isNotEmpty);
    final first = met.hours.first.time.add(const Duration(hours: -4));
    expect(met.days.first.date, DateTime.utc(first.year, first.month, first.day));
  });

  test('device offset is the fallback near the phone', () async {
    final r = await loadReport(Fetcher(fakeNet(), dir), paris, deviceOffset: const Duration(hours: 1));
    expect(r.offset, const Duration(hours: 1));
  });

  test('far-away city without a time zone source uses a longitude estimate, not the phone', () async {
    final r = await loadReport(Fetcher(fakeNet(), dir), paris, deviceOffset: const Duration(hours: 9));
    expect(r.offset, Duration.zero);
  });

  test('settings round trip', () async {
    SharedPreferences.setMockInitialValues({});
    final s = await Settings.load();
    expect([s.fahrenheit, s.alertRain, s.alertAir, s.alertStorm], [false, true, true, true]);
    await s.update((s) {
      s.fahrenheit = true;
      s.alertAir = false;
      s.places = [paris];
      s.lastPos = seoul;
    });
    final t = await Settings.load();
    expect([t.fahrenheit, t.alertAir], [true, false]);
    expect(t.places.single.name, 'Paris');
    expect(t.lastPos!.country, 'KR');
  });

  test('Open-Meteo models without data here are dropped, the rest shown', () async {
    final r = await loadReport(Fetcher(fakeNet(), dir), seoul, deviceOffset: const Duration(hours: 9));
    final ids = r.forecasts.map((x) => x.source).toList();
    expect(ids, containsAll(['om_ecmwf', 'om_gfs', 'om_icon', 'om_jma', 'om_gem', 'om_meteofrance', 'om_ukmo', 'om_cma']));
    expect(ids, isNot(contains('om_kma')));
    expect(ids, isNot(contains('om_bom')));
    expect(r.forecasts.firstWhere((x) => x.source == 'om_ecmwf').ok, isTrue);
    expect(r.air.firstWhere((x) => x.source == 'om_cams').data!.pm25, 35.9);
  });
}
