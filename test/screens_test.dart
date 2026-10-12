import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_compare/app_state.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/main.dart';
import 'package:weather_compare/models.dart';
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
    expect(find.text('지금 위치를 알 수 없어요. 아래에서 도시를 고르거나 검색해 주세요.'), findsOneWidget);
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

  testWidgets('quick city chips add a city without searching', (tester) async {
    late AppState st;
    await tester.runAsync(() async {
      st = AppState(await Settings.load(), Fetcher(fakeNet(), dir), locator: () async => null);
    });
    await pump(tester, SearchScreen(state: st));
    await tester.runAsync(() async {
      await tester.tap(find.text('부산'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    });
    await tester.pump();
    expect(st.settings.places.map((p) => p.name), contains('부산'));
    expect(st.settings.places.firstWhere((p) => p.name == '부산').country, 'KR');
  });

  testWidgets('no-location screen offers quick cities too', (tester) async {
    late AppState st;
    await tester.runAsync(() async {
      st = AppState(await Settings.load(), Fetcher(fakeNet(), dir), locator: () async => null);
    });
    await pump(tester, HomeScreen(state: st));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.text('제주'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('refresh button in the top bar reloads the city on screen', (tester) async {
    late AppState st;
    await tester.runAsync(() async {
      st = AppState(await Settings.load(), Fetcher(fakeNet(), dir), locator: () async => (37.57, 126.98));
    });
    await pump(tester, HomeScreen(state: st));
    for (var i = 0; i < 100 && (st.places.isEmpty || st.isLoading(st.places.first)); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    final place = st.places.first;
    expect(st.isLoading(place), isFalse);
    await tester.tap(find.byTooltip('새로고침'));
    expect(st.isLoading(place), isTrue);
    for (var i = 0; i < 100 && st.isLoading(place); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byTooltip('새로고침'), findsOneWidget); // 다 받으면 다시 버튼
    expect(tester.takeException(), isNull);
  });

  testWidgets('saved city starts loading right away instead of offering retry while location is still being checked',
      (tester) async {
    late AppState st;
    final asking = Completer<(double, double)?>(); // 위치 권한 창이 떠 있는 동안
    await tester.runAsync(() async {
      st = AppState(await Settings.load(), Fetcher(fakeNet(), dir), locator: () => asking.future);
      await st.settings.update((s) => s.places = [const Place('부산', 'KR', 35.18, 129.08)]);
    });
    await pump(tester, HomeScreen(state: st));
    await tester.pump();
    expect(find.text('다시 시도'), findsNothing);
    expect(st.isLoading(st.places.first), isTrue);
    asking.complete(null);
    for (var i = 0; i < 100 && st.isLoading(st.places.first); i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 50));
    }
  });

  testWidgets('settings warns when the phone blocks notifications but alerts are on', (tester) async {
    late Settings s;
    await tester.runAsync(() async => s = await Settings.load());
    var asked = 0;
    var on = false;
    await pump(
        tester,
        SettingsScreen(
            settings: s,
            notificationsOn: () async => on,
            turnOnNotifications: () async {
              asked++;
              on = true;
            }));
    await tester.pumpAndSettle();
    expect(find.textContaining('알림이 꺼져 있어서'), findsOneWidget);
    await tester.tap(find.text('알림 켜기'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(find.textContaining('알림이 꺼져 있어서'), findsNothing); // 켠 뒤 다시 확인
  });

  testWidgets('no notification warning when every alert is off', (tester) async {
    late Settings s;
    await tester.runAsync(() async {
      s = await Settings.load();
      await s.update((x) => x
        ..alertRain = false
        ..alertAir = false
        ..alertStorm = false);
    });
    await pump(tester, SettingsScreen(settings: s, notificationsOn: () async => false));
    await tester.pumpAndSettle();
    expect(find.textContaining('알림이 꺼져 있어서'), findsNothing);
  });
}
