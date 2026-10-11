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

  const seoul = Place('서울', 'KR', 37.57, 126.98);
  const paris = Place('Paris', 'FR', 48.85, 2.35);
  final now = DateTime.utc(2026, 10, 11, 3); // 서울 12시

  Future<void> pump(WidgetTester tester, Place p, {Duration? offset}) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WeatherApp(
        locale: const Locale('ko'),
        home: SatelliteScreen(place: p, fetcher: Fetcher(fakeNet(), dir), offset: offset, now: now)));
    await tester.pump();
  }

  // 자동 재생 타이머를 멈추려고 화면을 치운다.
  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  }

  ChoiceChip chip(WidgetTester t, String label) =>
      t.widget<ChoiceChip>(find.ancestor(of: find.text(label), matching: find.byType(ChoiceChip)));

  testWidgets('Seoul offers six layers, infrared first', (tester) async {
    await pump(tester, seoul);
    for (final t in ['적외선', '가시광', '실사(하루)', '구름(모델)', '강수(모델)', '천리안 2A']) {
      expect(find.text(t), findsOneWidget, reason: t);
    }
    expect(chip(tester, '적외선').selected, isTrue);
    expect(find.textContaining('NASA GIBS'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the image time is always shown in the place time zone', (tester) async {
    await pump(tester, seoul, offset: const Duration(hours: 9));
    // 가장 최근 프레임 = 03:00Z − 90분 = 01:30Z → 서울 10:30
    expect(find.text('10/11 10:30'), findsOneWidget);
    await close(tester);
  });

  testWidgets('animated layers play by themselves', (tester) async {
    await pump(tester, seoul, offset: const Duration(hours: 9));
    expect(find.byIcon(Icons.pause), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('10/11 10:30'), findsNothing); // 처음부터 다시 돌고 있음
    await close(tester);
  });

  testWidgets('daily and model layers say what kind of image they are', (tester) async {
    await pump(tester, paris);
    await tester.tap(find.text('실사(하루)'));
    await tester.pump();
    expect(find.text('하루 한 장 촬영(오늘 낮)'), findsOneWidget);
    await tester.tap(find.text('구름(모델)'));
    await tester.pump();
    expect(find.text('설정 필요'), findsOneWidget); // 시험 빌드엔 OWM 키가 없다
    await close(tester);
  });

  testWidgets('Paris starts on Meteosat infrared and has no KMA chip', (tester) async {
    await pump(tester, paris);
    expect(find.text('천리안 2A'), findsNothing);
    expect(chip(tester, '적외선').selected, isTrue);
    expect(find.textContaining('EUMETSAT'), findsOneWidget);
    await close(tester);
  });
}
