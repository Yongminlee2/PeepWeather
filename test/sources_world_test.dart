import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/sources/common.dart';
import 'package:weather_compare/sources/met_norway.dart';
import 'package:weather_compare/sources/openweather.dart';
import 'package:weather_compare/sources/visual_crossing.dart';
import 'package:weather_compare/sources/weatherapi.dart';

String fx(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  test('requireKey throws noKey on empty', () {
    expect(() => requireKey(''), throwsA(isA<FetchError>().having((e) => e.fail, 'fail', Fail.noKey)));
    requireKey('abc');
  });

  group('MET Norway', () {
    test('parses real response', () {
      final f = parseMet(fx('met.json'));
      expect(f.hours.length, 91); // 마지막 항목은 요약이 없어 빠진다
      expect(f.hours.first.time, DateTime.utc(2026, 10, 11, 7));
      expect(f.hours.first.tempC, 26.9);
      expect(f.hours.first.sky, Sky.rain); // heavyrainshowers_day
      expect(f.hours.first.mm, 1.1);
      expect(f.hours.first.pop, isNull);
      expect(f.now!.tempC, 26.9);
      expect(f.days, isEmpty); // 일별은 저장소가 장소 시간대로 묶는다
    });
    test('falls back to next_6_hours when next_1_hours is missing', () {
      final h = parseMet(fx('met.json')).hours.firstWhere((h) => h.time == DateTime.utc(2026, 10, 14));
      expect(h.mm, isNotNull);
    });
    test('symbol mapping', () {
      expect(metSky('clearsky_day'), Sky.clear);
      expect(metSky('fair_night'), Sky.partly);
      expect(metSky('partlycloudy_polartwilight'), Sky.partly);
      expect(metSky('cloudy'), Sky.cloudy);
      expect(metSky('fog'), Sky.fog);
      expect(metSky('lightrainshowersandthunder_day'), Sky.thunder);
      expect(metSky('heavysleet'), Sky.snow);
      expect(metSky('rain'), Sky.rain);
    });
  });

  group('OpenWeather', () {
    test('forecast + current', () {
      final f = parseOwmForecast(fx('owm_forecast.json'), fx('owm_weather.json'));
      expect(f.hours.length, 3);
      expect(f.hours.first.time, DateTime.utc(2026, 10, 11, 9));
      expect(f.hours.first.pop, 62);
      expect(f.hours.first.mm, 1.2);
      expect(f.hours.first.sky, Sky.rain);
      expect(f.hours[2].mm, 0);
      expect(f.now!.tempC, 22.1);
      expect(f.now!.sky, Sky.partly);
      expect(f.utcOffset, const Duration(hours: 9));
    });
    test('id mapping', () {
      expect(owmSky(211), Sky.thunder);
      expect(owmSky(301), Sky.rain);
      expect(owmSky(601), Sky.snow);
      expect(owmSky(741), Sky.fog);
      expect(owmSky(800), Sky.clear);
      expect(owmSky(802), Sky.partly);
      expect(owmSky(804), Sky.cloudy);
    });
    test('air', () {
      final a = parseOwmAir(fx('owm_air.json'));
      expect([a.pm10, a.pm25], [25.1, 12.3]);
    });
    test('reverse geocoding prefers local name', () {
      final p = parseOwmReverse(fx('owm_geo.json'), 37.57, 126.98, 'ko');
      expect([p.name, p.country, p.lat], ['서울', 'KR', 37.57]);
      expect(parseOwmReverse(fx('owm_geo.json'), 37.57, 126.98, 'en').name, 'Seoul');
    });
    test('direct search lists cities with state', () {
      final ps = parseOwmDirect(fx('owm_direct.json'), 'ko');
      expect(ps.length, 2);
      expect(ps.first.name, '파리, Ile-de-France');
      expect(ps.last.country, 'US');
    });
  });

  group('WeatherAPI', () {
    test('forecast with daily and offset', () {
      final f = parseWeatherApi(fx('weatherapi.json'));
      expect(f.now!.tempC, 21.0);
      expect(f.now!.sky, Sky.partly);
      expect(f.hours.length, 2);
      expect(f.hours.first.pop, 80);
      expect(f.hours.first.mm, 0.8);
      expect(f.days.length, 2);
      expect(f.days.first.date, DateTime.utc(2026, 10, 11));
      expect([f.days.first.maxC, f.days.first.minC, f.days.first.pop], [24.0, 15.0, 80]);
      expect(f.utcOffset, const Duration(hours: 9));
    });
    test('air', () {
      final a = parseWeatherApiAir(fx('weatherapi.json'));
      expect([a.pm10, a.pm25], [20.1, 10.5]);
    });
    test('code mapping', () {
      expect(weatherApiSky(1000), Sky.clear);
      expect(weatherApiSky(1003), Sky.partly);
      expect(weatherApiSky(1009), Sky.cloudy);
      expect(weatherApiSky(1135), Sky.fog);
      expect(weatherApiSky(1276), Sky.thunder);
      expect(weatherApiSky(1213), Sky.snow);
      expect(weatherApiSky(1189), Sky.rain);
    });
  });

  group('Visual Crossing', () {
    test('forecast', () {
      final f = parseVc(fx('vc.json'));
      expect(f.now!.tempC, 21.7);
      expect(f.now!.sky, Sky.partly);
      expect(f.hours.length, 2);
      expect(f.hours.first.time, DateTime.utc(2026, 10, 11, 9));
      expect([f.hours.first.pop, f.hours.first.mm], [65, 0.6]);
      expect(f.days.length, 2);
      expect(f.days.last.sky, Sky.clear);
      expect(f.utcOffset, const Duration(hours: 9));
    });
    test('icon mapping', () {
      expect(vcSky('clear-night'), Sky.clear);
      expect(vcSky('partly-cloudy-night'), Sky.partly);
      expect(vcSky('cloudy'), Sky.cloudy);
      expect(vcSky('fog'), Sky.fog);
      expect(vcSky('thunder-showers-day'), Sky.thunder);
      expect(vcSky('snow-showers-day'), Sky.snow);
      expect(vcSky('showers-night'), Sky.rain);
      expect(vcSky('wind'), Sky.cloudy);
    });
  });
}
