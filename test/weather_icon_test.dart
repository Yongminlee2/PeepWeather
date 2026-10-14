import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/ui/weather_icon.dart';

void main() {
  test('every sky has an icon file, day and night', () {
    for (final s in Sky.values) {
      for (final night in [false, true]) {
        final a = skyAsset(s, night: night);
        expect(File(a).existsSync(), isTrue, reason: a);
      }
    }
    expect(skyAsset(Sky.clear, night: true), 'assets/icons/clear-night.json');
    expect(skyAsset(Sky.partly, night: false), 'assets/icons/partly-cloudy-day.json');
    expect(skyAsset(Sky.thunder, night: false), 'assets/icons/thunderstorms-rain.json');
  });

  test('night by local hour of the place', () {
    expect(isNightAt(DateTime.utc(2026, 10, 11, 12), const Duration(hours: 9)), isTrue); // 21시
    expect(isNightAt(DateTime.utc(2026, 10, 11, 3), const Duration(hours: 9)), isFalse); // 12시
    expect(isNightAt(DateTime.utc(2026, 10, 11, 20), const Duration(hours: 9)), isTrue); // 새벽 5시
  });

  test('sky gradient differs for clear day, rain and night', () {
    final day = heroGradient(Sky.clear, night: false);
    final rain = heroGradient(Sky.rain, night: false);
    final night = heroGradient(Sky.clear, night: true);
    expect({day.first, rain.first, night.first}.length, 3);
    expect(day.length, 2);
  });

  test('still frame keeps rain drops, snowflakes and the lightning bolt visible', () {
    // 가운데 장면(0.5)은 빗줄기 하나뿐이고 번개가 없어 뇌우가 비와 같아 보였다
    for (final s in [Sky.rain, Sky.snow, Sky.thunder]) {
      expect(stillFrame(s), isNot(0.5), reason: '$s');
    }
    expect(stillFrame(Sky.clear), 0.5);
  });
}
