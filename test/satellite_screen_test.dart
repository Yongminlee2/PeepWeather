import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/main.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/ui/satellite_screen.dart';

import 'repository_test.dart' show fakeNet;

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('sat'));
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester, Place p) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WeatherApp(
        locale: const Locale('ko'),
        home: SatelliteScreen(place: p, fetcher: Fetcher(fakeNet(), dir), now: DateTime.utc(2026, 10, 11, 3))));
    await tester.pump();
  }

  ChoiceChip chip(WidgetTester t, String label) =>
      t.widget<ChoiceChip>(find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)));

  testWidgets('Seoul offers six layers, infrared first', (tester) async {
    await pump(tester, const Place('서울', 'KR', 37.57, 126.98));
    for (final t in ['적외선', '가시광', '실사(하루)', '구름(모델)', '강수(모델)', '천리안 2A']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(chip(tester, '적외선').selected, isTrue);
    expect(find.textContaining('NASA GIBS'), findsOneWidget);
  });

  testWidgets('Paris starts on true color and has no KMA chip', (tester) async {
    await pump(tester, const Place('Paris', 'FR', 48.85, 2.35));
    expect(find.text('천리안 2A'), findsNothing);
    expect(find.text('적외선'), findsNothing);
    expect(chip(tester, '실사(하루)').selected, isTrue);
  });

  testWidgets('model layers without key explain setup', (tester) async {
    await pump(tester, const Place('Paris', 'FR', 48.85, 2.35));
    await tester.tap(find.text('구름(모델)'));
    await tester.pump();
    expect(find.text('설정 필요'), findsOneWidget);
  });

  testWidgets('frame time is shown in the place time zone', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WeatherApp(
        locale: const Locale('ko'),
        home: SatelliteScreen(
            place: const Place('서울', 'KR', 37.57, 126.98),
            fetcher: Fetcher(fakeNet(), dir),
            offset: const Duration(hours: 9),
            now: DateTime.utc(2026, 10, 11, 3))));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pump();
    expect(find.text('10/11 08:50'), findsOneWidget); // 첫 프레임 23:50Z(=03:00−80분−110분) → 서울 08:50
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
  });
}
