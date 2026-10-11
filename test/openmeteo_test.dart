import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/sources/openmeteo.dart';

String fx(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  final body = fx('openmeteo_real.json');
  final now = DateTime.utc(2026, 10, 11, 10); // 서울 19시

  test('ECMWF model parses hours, days, now and offset', () {
    final f = parseOpenMeteo(body, 'ecmwf_ifs025', now: now)!;
    expect(f.hours.length, 168);
    expect(f.hours.first.time, DateTime.utc(2026, 10, 10, 15)); // 현지 10/11 00시
    expect(f.utcOffset, const Duration(hours: 9));
    expect(f.days.length, 7);
    expect(f.days.first.date, DateTime.utc(2026, 10, 11));
    expect(f.now!.time, DateTime.utc(2026, 10, 11, 10));
    expect(f.hours.every((h) => h.pop != null), isTrue);
  });

  test('models without probability keep amounts', () {
    final f = parseOpenMeteo(body, 'jma_seamless', now: now)!;
    expect(f.hours.every((h) => h.pop == null), isTrue);
    expect(f.hours.any((h) => h.mm != null), isTrue);
  });

  test('model with no data here is null (row hidden)', () {
    expect(parseOpenMeteo(body, 'kma_seamless', now: now), isNull);
    expect(parseOpenMeteo(body, 'bom_access_global', now: now), isNull);
  });

  test('WMO weather codes', () {
    expect(wmoSky(0), Sky.clear);
    expect(wmoSky(2), Sky.partly);
    expect(wmoSky(3), Sky.cloudy);
    expect(wmoSky(45), Sky.fog);
    expect(wmoSky(61), Sky.rain);
    expect(wmoSky(81), Sky.rain);
    expect(wmoSky(73), Sky.snow);
    expect(wmoSky(86), Sky.snow);
    expect(wmoSky(95), Sky.thunder);
  });

  test('CAMS air quality', () {
    final a = parseOpenMeteoAir(fx('openmeteo_air_real.json'));
    expect([a.pm10, a.pm25], [36.9, 35.9]);
    expect(a.time, DateTime.utc(2026, 10, 11, 10));
  });

  test('every model has a source id', () {
    expect(openMeteoModels.length, 10);
    expect(openMeteoModels.values.every((id) => id.startsWith('om_')), isTrue);
  });
}
