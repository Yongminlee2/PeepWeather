// 화면 그림 뽑기(에뮬레이터 대신). 평소엔 건너뛰고, SHOT_DIR 을 주면 실제 글꼴·아이콘으로 PNG 를 그린다.
//   SHOT_DIR=C:/tmp/shots flutter test test/screenshots_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_compare/app_state.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/main.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/repository.dart';
import 'package:weather_compare/settings.dart';
import 'package:weather_compare/ui/home_screen.dart';
import 'package:weather_compare/ui/report_view.dart';
import 'package:weather_compare/ui/search_screen.dart';
import 'package:weather_compare/ui/settings_screen.dart';
import 'package:weather_compare/verify.dart';

import 'repository_test.dart' show fakeNet;

final dir = Platform.environment['SHOT_DIR'];

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    l.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await l.load();
}

Future<void> _fonts() async {
  await _font('Plex', ['assets/fonts/IBMPlexSansKR-Regular.ttf', 'assets/fonts/IBMPlexSansKR-SemiBold.ttf']);
  final flutter = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
  await _font('MaterialIcons', ['$flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
}

/// 폰 한 화면(1080x2340, 2.75배) 크기로 그려 저장.
Future<void> shot(WidgetTester tester, String name, Widget home, {bool dark = false, double height = 2340}) async {
  tester.view.physicalSize = Size(1080, height);
  tester.view.devicePixelRatio = 2.75;
  addTearDown(tester.view.reset);
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: MediaQuery(
      data: MediaQueryData(
          size: Size(1080 / 2.75, height / 2.75),
          devicePixelRatio: 2.75,
          disableAnimations: true,
          padding: const EdgeInsets.only(top: 32),
          platformBrightness: dark ? Brightness.dark : Brightness.light),
      child: WeatherApp(locale: const Locale('ko'), home: home),
    ),
  ));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400))); // 로티 파일
  await tester.pump(const Duration(milliseconds: 300));
  await tester.runAsync(() async {
    final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2.75);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  const seoul = Place('서울특별시', 'KR', 37.5665, 126.978);
  late Report report;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('screens', (tester) async {
    await tester.runAsync(() async {
      Directory(dir!).createSync(recursive: true);
      await _fonts();
      report = await loadReport(Fetcher(fakeNet(), Directory.systemTemp.createTempSync('shot')), seoul,
          deviceOffset: const Duration(hours: 9));
    });
    // 며칠 쓴 뒤처럼 정확도 기록을 채운 모습도
    final ledger = Ledger();
    for (final (id, err, hits) in [('kma', 0.9, 6), ('om_ecmwf', 1.1, 6), ('om_icon', 1.4, 5), ('met', 1.6, 5), ('owm', 2.3, 4), ('om_gfs', 2.8, 4)]) {
      final sc = Score();
      for (var i = 0; i < 7; i++) {
        sc.add(err, i < hits);
      }
      ledger.scores[id] = sc;
    }
    for (final (name, hour, dark, led) in [
      ('report_day', 3, false, null),
      ('report_night', 12, false, ledger),
      ('report_dark', 12, true, ledger),
    ]) {
      await shot(
          tester,
          name,
          Scaffold(
              appBar: AppBar(title: const Text('날씨 비교')),
              body: ReportView(
                  report: report, fahrenheit: false, now: DateTime.utc(2026, 10, 11, hour), onSatellite: () {}, ledger: led)),
          dark: dark,
          height: 6400);
    }
    late Settings settings;
    late AppState noLoc;
    await tester.runAsync(() async {
      settings = await Settings.load();
      noLoc = AppState(settings, Fetcher(fakeNet(), Directory.systemTemp.createTempSync('s')), locator: () async => null);
      await noLoc.locate('ko', '현재 위치');
    });
    for (final dark in [false, true]) {
      final sfx = dark ? '_dark' : '';
      await shot(tester, 'search$sfx', SearchScreen(state: noLoc), dark: dark);
      await shot(tester, 'settings$sfx', SettingsScreen(settings: settings), dark: dark);
      await shot(tester, 'home_no_location$sfx', HomeScreen(state: noLoc), dark: dark);
    }
  }, skip: dir == null);
}
