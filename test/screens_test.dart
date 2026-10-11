import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_compare/app_state.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/main.dart';
import 'package:weather_compare/settings.dart';
import 'package:weather_compare/ui/home_screen.dart';
import 'package:weather_compare/ui/search_screen.dart';
import 'package:weather_compare/ui/settings_screen.dart';

import 'repository_test.dart' show fakeNet;

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('screens');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Future<void> pump(WidgetTester tester, Widget home) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WeatherApp(locale: const Locale('ko'), home: home));
  }

  testWidgets('no location shows guidance with search and settings buttons', (tester) async {
    late AppState st;
    await tester.runAsync(() async {
      st = AppState(await Settings.load(), Fetcher(fakeNet(), dir), locator: () async => null);
    });
    await pump(tester, HomeScreen(state: st));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.text('위치를 알 수 없어요. 도시를 검색해서 추가하세요.'), findsOneWidget);
    expect(find.text('도시 검색'), findsWidgets);
    expect(find.text('위치 권한 설정 열기'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings switches persist', (tester) async {
    late Settings s;
    await tester.runAsync(() async => s = await Settings.load());
    await pump(tester, SettingsScreen(settings: s));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await tester.tap(find.text('화씨(°F)로 보기'));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pump();
    expect(s.fahrenheit, isTrue);
    expect(find.text('알림'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('개인정보처리방침'), 300);
    expect(find.text('개인정보처리방침'), findsOneWidget);
  });

  testWidgets('search without key explains setup is needed', (tester) async {
    late AppState st;
    await tester.runAsync(() async {
      st = AppState(await Settings.load(), Fetcher(fakeNet(), dir), locator: () async => null);
    });
    await pump(tester, SearchScreen(state: st));
    await tester.enterText(find.byType(TextField), 'Paris');
    await tester.runAsync(() async {
      await tester.testTextInput.receiveAction(TextInputAction.search);
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(find.text('설정 필요'), findsOneWidget);
  });

  testWidgets('search shows how to use it before typing', (tester) async {
    late AppState st;
    await tester.runAsync(() async {
      st = AppState(await Settings.load(), Fetcher(fakeNet(), dir), locator: () async => null);
    });
    await pump(tester, SearchScreen(state: st));
    expect(find.textContaining('도시 이름을 입력'), findsOneWidget);
  });

  testWidgets('settings explains how to add a city when none are saved', (tester) async {
    late Settings s;
    await tester.runAsync(() async => s = await Settings.load());
    await pump(tester, SettingsScreen(settings: s));
    await tester.pumpAndSettle();
    expect(find.textContaining('돋보기'), findsOneWidget);
  });
}
