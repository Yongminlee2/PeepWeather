import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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

  testWidgets('while pictures download it stays on the latest one and says so', (tester) async {
    await pump(tester, seoul, offset: const Duration(hours: 9));
    expect(find.byIcon(Icons.pause), findsOneWidget); // 재생은 켜져 있고
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('10/11 10:30'), findsOneWidget); // 다 받지 못한 장면으로는 넘어가지 않는다(검은 네모 대신)
    expect(find.text('위성 사진 받는 중'), findsOneWidget);
    await close(tester);
  });

  testWidgets('starts from the newest picture NASA has actually published', (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 03:00Z 기준 02:40Z 것까지 올라와 있다 → 서울 11:40
    final net = MockClient((r) async => http.Response('', r.url.path.contains('T02:50') || r.url.path.contains('T03:00') ? 404 : 200));
    await tester.pumpWidget(WeatherApp(
        locale: const Locale('ko'),
        home: SatelliteScreen(place: seoul, fetcher: Fetcher(net, dir), offset: const Duration(hours: 9), now: now)));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.text('10/11 11:40'), findsOneWidget);
    await close(tester);
  });

  group('frame readiness', () {
    test('a frame is ready when every tile it showed has loaded', () {
      final r = FrameReadiness();
      expect(r.ready(0), isFalse); // 아직 조각이 하나도 없음
      r.mark(0, 'a', false);
      r.mark(0, 'b', true);
      expect(r.ready(0), isFalse);
      r.mark(0, 'a', true);
      expect(r.ready(0), isTrue);
    });

    test('playback skips frames that are not ready and wraps around', () {
      final r = FrameReadiness()
        ..mark(0, 'a', true)
        ..mark(1, 'a', false)
        ..mark(2, 'a', true)
        ..mark(3, 'a', true);
      expect(r.next(0, 4), 2);
      expect(r.next(3, 4), 0);
      expect((FrameReadiness()..mark(3, 'a', true)).next(3, 4), 3); // 다른 장면이 준비 안 됐으면 그대로
    });

    test('mark reports whether anything changed, clear forgets everything', () {
      final r = FrameReadiness();
      expect(r.mark(0, 'a', false), isTrue);
      expect(r.mark(0, 'a', false), isFalse);
      r.clear();
      expect(r.ready(0), isFalse);
    });
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
