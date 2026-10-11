import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/sources/airkorea.dart';
import 'package:weather_compare/sources/common.dart';
import 'package:weather_compare/sources/kma.dart';
import 'package:weather_compare/sources/nws.dart';
import 'package:weather_compare/sources/openaq.dart';

String fx(String name) => File('test/fixtures/$name').readAsStringSync();
Matcher failWith(Fail f) => throwsA(isA<FetchError>().having((e) => e.fail, 'fail', f));

void main() {
  group('NWS', () {
    test('hourly url from points', () {
      expect(nwsHourlyUrl(fx('nws_points.json')).toString(),
          'https://api.weather.gov/gridpoints/OKX/33,42/forecast/hourly');
    });
    test('parses real hourly', () {
      final f = parseNwsHourly(fx('nws_hourly.json'));
      expect(f.hours.length, 6);
      expect(f.hours.first.time, DateTime.utc(2026, 10, 11, 8));
      expect(f.hours.first.tempC, closeTo(16.7, 0.05)); // 62F
      expect(f.hours.first.pop, 0);
      expect(f.utcOffset, const Duration(hours: -4));
    });
    test('fahrenheit', () => expect(fToC(50), 10));
    test('text mapping', () {
      expect(nwsSky('Chance Showers And Thunderstorms'), Sky.thunder);
      expect(nwsSky('Light Snow Likely'), Sky.snow);
      expect(nwsSky('Slight Chance Rain Showers'), Sky.rain);
      expect(nwsSky('Patchy Fog'), Sky.fog);
      expect(nwsSky('Mostly Cloudy'), Sky.cloudy);
      expect(nwsSky('Partly Sunny'), Sky.partly);
      expect(nwsSky('Mostly Clear'), Sky.partly);
      expect(nwsSky('Sunny'), Sky.clear);
    });
  });

  group('KMA', () {
    test('grid conversion', () {
      expect(kmaGrid(37.5665, 126.978), (60, 127));
      expect(kmaGrid(35.1796, 129.0756), (98, 76));
    });
    test('vilage base time', () {
      expect(kmaBase(DateTime(2026, 10, 11, 1, 30)), ('20261010', '2300'));
      expect(kmaBase(DateTime(2026, 10, 11, 2, 9)), ('20261010', '2300'));
      expect(kmaBase(DateTime(2026, 10, 11, 2, 10)), ('20261011', '0200'));
      expect(kmaBase(DateTime(2026, 10, 11, 23, 59)), ('20261011', '2300'));
    });
    test('ncst base time', () {
      expect(kmaNcstBase(DateTime(2026, 10, 11, 0, 30)), ('20261010', '2300'));
      expect(kmaNcstBase(DateTime(2026, 10, 11, 14, 40)), ('20261011', '1400'));
    });
    test('parses forecast', () {
      final f = parseKma(fx('kma_vilage.json'), fx('kma_ncst.json'));
      expect(f.hours.length, 4);
      expect(f.hours.first.time, DateTime.utc(2026, 10, 11, 9)); // 18시 KST
      expect([f.hours.first.tempC, f.hours.first.pop, f.hours.first.mm], [21.0, 70, 1.0]);
      expect(f.hours.first.sky, Sky.rain);
      expect(f.hours[1].sky, Sky.cloudy);
      expect(f.hours[3].mm, 0.5); // 1mm 미만
      expect(f.now!.tempC, 21.4);
      expect(f.utcOffset, const Duration(hours: 9));
      final d = f.days.firstWhere((d) => d.date == DateTime.utc(2026, 10, 12));
      expect([d.maxC, d.minC], [23.0, 12.0]); // TMX/TMN 우선
    });
    test('sky mapping', () {
      expect(kmaSky(1, 0), Sky.clear);
      expect(kmaSky(3, 0), Sky.partly);
      expect(kmaSky(4, 0), Sky.cloudy);
      expect(kmaSky(1, 4), Sky.rain);
      expect(kmaSky(4, 3), Sky.snow);
    });
    test('pcp text', () {
      expect(pcpMm('강수없음'), 0);
      expect(pcpMm('1mm 미만'), 0.5);
      expect(pcpMm('6.2mm'), 6.2);
      expect(pcpMm('30.0~50.0mm'), 30);
      expect(pcpMm('50.0mm 이상'), 50);
    });
    test('data.go.kr errors', () {
      expect(() => checkDataGoKr(fx('data_go_kr_badkey.xml')), failWith(Fail.badKey));
      expect(() => checkDataGoKr(fx('data_go_kr_quota.json')), failWith(Fail.quota));
      checkDataGoKr(fx('kma_ncst.json'));
    });
  });

  group('AirKorea', () {
    test('stations and nearest', () {
      final s = parseStations(fx('airkorea_stations.json'));
      expect(s.first, ('중구', 37.564639, 126.975961));
      expect(nearestStation(s, 35.18, 129.07), '연산동');
    });
    test('measure with missing value and 24:00', () {
      final a = parseAirKorea(fx('airkorea_measure.json'), '중구');
      expect(a.pm10, isNull);
      expect(a.pm25, 12);
      expect(a.station, '중구');
      expect(a.time, DateTime.utc(2026, 10, 11, 15)); // 10/12 00:00 KST
    });
  });

  group('OpenAQ', () {
    test('commercial licenses', () {
      expect(parseCommercialLicenses(fx('openaq_licenses.json')), {33, 40});
    });
    test('nearest commercial station with pm sensor', () {
      final locs = parseLocations(fx('openaq_locations.json'), {33, 40}, now: DateTime.utc(2026, 10, 11, 10), commercialOnly: true);
      expect(locs.map((l) => l.$1).toList(), [333, 222]);
      expect(locs.first.$3, {32: 'pm25'});
    });
    test('latest values', () {
      final a = parseOpenAqLatest(fx('openaq_latest.json'), {32: 'pm25'}, 'Near Station', now: DateTime.utc(2026, 10, 11, 10));
      expect([a.pm10, a.pm25, a.station], [null, 18.5, 'Near Station']);
      expect(a.time, DateTime.utc(2026, 10, 11, 8));
    });
  });

  test('requireKey still guards keyed sources', () => expect(() => requireKey(''), failWith(Fail.noKey)));

  group('OpenAQ real responses (2026-10-11)', () {
    final now = DateTime.utc(2026, 10, 11, 10);
    final allowed = parseCommercialLicenses(fx('openaq_licenses_real.json'));
    test('licenses: ACT copyright is not commercial', () {
      expect(allowed, containsAll([10, 33, 38, 39, 41]));
      expect(allowed, isNot(contains(37)));
    });
    test('Seoul, commercial only: only unlicensed or long-stopped stations, so none usable', () {
      expect(parseLocations(fx('openaq_locations_real.json'), allowed, now: now, commercialOnly: true), isEmpty);
    });
    test('Seoul, non-commercial: nearest station still measuring (stopped ones skipped)', () {
      final locs = parseLocations(fx('openaq_locations_real.json'), allowed, now: now, commercialOnly: false);
      expect(locs.first.$1, 2622782); // 동대문구 4.7km — 더 가까운 SPARTAN(2021)·고려대(2024)는 멈춤
      expect(locs.first.$3.values.toSet(), {'pm10', 'pm25'});
    });
    test('Tokyo: nearest fresh licensed station with its pm sensor', () {
      final locs = parseLocations(fx('openaq_locations_tokyo_real.json'), allowed, now: now, commercialOnly: true);
      expect(locs.first.$1, 1214509);
      expect(locs.first.$3, {6520423: 'pm25'});
    });
    test('Tokyo latest values', () {
      final a = parseOpenAqLatest(fx('openaq_latest_tokyo_real.json'), {6520423: 'pm25'}, 'Setagaya', now: now);
      expect([a.pm10, a.pm25], [null, 9.0]);
      expect(a.time, DateTime.utc(2026, 10, 11, 8));
    });
    test('stale latest values are ignored', () {
      expect(() => parseOpenAqLatest(fx('openaq_latest_tokyo_real.json'), {6520423: 'pm25'}, 'x', now: DateTime.utc(2026, 10, 13)),
          failWith(Fail.noStation));
    });
  });
}
