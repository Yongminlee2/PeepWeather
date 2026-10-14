// 누르면 나오는 화면 그림 뽑기(설명 창·칸별 기관 값·받지 못한 곳·기관별 숫자 표·다른 앱 목록).
// 평소엔 건너뛰고, SHOT_DIR 을 주면 폰 한 화면 크기 PNG 로 남긴다.
//   SHOT_DIR=/tmp/shots flutter test test/screens_tour_test.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/main.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/repository.dart';
import 'package:weather_compare/ui/more_games_screen.dart';
import 'package:weather_compare/ui/report_view.dart';

import 'repository_test.dart' show fakeNet;

final dir = Platform.environment['SHOT_DIR'];

Future<void> _font(String family, List<String> paths) async {
  final l = FontLoader(family);
  for (final p in paths) {
    l.addFont(Future.value(ByteData.view(File(p).readAsBytesSync().buffer)));
  }
  await l.load();
}

void main() {
  const seoul = Place('서울특별시', 'KR', 37.5665, 126.978);
  final key = GlobalKey();

  Future<void> setUp(WidgetTester tester, Widget home, {bool dark = false}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MediaQuery(
        data: MediaQueryData(
            size: const Size(1080 / 2.75, 2340 / 2.75),
            devicePixelRatio: 2.75,
            disableAnimations: true,
            padding: const EdgeInsets.only(top: 32),
            platformBrightness: dark ? Brightness.dark : Brightness.light),
        child: WeatherApp(locale: const Locale('ko'), home: home),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 400)));
    await tester.pumpAndSettle();
  }

  Future<void> snap(WidgetTester tester, String name) async {
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2.75);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  Future<void> closeSheet(WidgetTester tester) async {
    final sheet = find.byType(BottomSheet);
    if (sheet.evaluate().isNotEmpty) Navigator.of(tester.element(sheet.first)).pop();
    await tester.pumpAndSettle();
  }

  /// 목록을 직접 옮긴다 — 끌기는 그래프(터치를 받는다) 위에 떨어지면 목록이 안 움직였다.
  ScrollPosition pos(WidgetTester tester) => tester.state<ScrollableState>(find.byType(Scrollable).first).position;

  Future<void> tapVisible(WidgetTester tester, Finder f) async {
    // 맨 위에서부터 화면에 보일 때까지 조금씩 내린다(목록이 보이는 것만 만든다)
    pos(tester).jumpTo(0);
    await tester.pumpAndSettle();
    for (var i = 0; i < 80 && f.hitTestable().evaluate().isEmpty; i++) {
      final p = pos(tester);
      p.jumpTo(math.min(p.pixels + 250, p.maxScrollExtent));
      await tester.pumpAndSettle();
    }
    // 화면 가운데쯤으로 옮긴다(맨 아래에 걸치면 시트·여백에 가린다)
    final dy = tester.getCenter(f.hitTestable().first).dy - 420;
    final p = pos(tester);
    p.jumpTo((p.pixels + dy).clamp(0.0, p.maxScrollExtent));
    await tester.pumpAndSettle();
    await tester.tap(f.hitTestable().first);
  }

  testWidgets('tour', (tester) async {
    late Report report;
    await tester.runAsync(() async {
      Directory(dir!).createSync(recursive: true);
      await _font('Plex', ['assets/fonts/IBMPlexSansKR-Regular.ttf', 'assets/fonts/IBMPlexSansKR-SemiBold.ttf']);
      final flutter = Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter';
      await _font('MaterialIcons', ['$flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf']);
      SharedPreferences.setMockInitialValues({
        // 다른 앱 목록: 받아 둔 목록이 있는 모습
        'moreGames.json': '{"apps":[{"id":"com.peep.weather","name":"날씨 비교","desc":"여러 기관 예보를 나란히"},'
            '{"id":"com.peep.science","name":"삐약과학 - 물리 퍼즐 게임","desc":"부품 12종을 조립하고 ▶로 굴리면 진짜 물리로 풀리는 퍼즐."},'
            '{"id":"com.peep.math","name":"삐약수학","desc":"놀면서 배우는 셈"}]}',
      });
      report = await loadReport(Fetcher(fakeNet(), Directory.systemTemp.createTempSync('tour')), seoul,
          deviceOffset: const Duration(hours: 9));
    });

    for (final dark in [false, true]) {
      final sfx = dark ? '_dark' : '';
      await setUp(
          tester,
          Scaffold(
              appBar: AppBar(title: const Text('날씨 비교')),
              body: ReportView(report: report, fahrenheit: false, now: DateTime.utc(2026, 10, 11, 3), onSatellite: () {})),
          dark: dark);

      await tester.tap(find.textContaining('받지 못한 곳').first);
      await snap(tester, 'sheet_unavailable$sfx');
      await closeSheet(tester);

      for (final (i, t) in ['가운데 값이란?', '결론은 어떻게 내나요?', '그래프 읽는 법', '강수확률(%)이란?', '미세먼지 숫자 읽는 법'].indexed) {
        await tapVisible(tester, find.byTooltip(t));
        await snap(tester, 'info_$i$sfx');
        await closeSheet(tester);
      }

      // 비 막대 줄의 첫 시간 칸: 「칸을 누르면…」 안내 바로 위 왼쪽
      await tapVisible(tester, find.text('칸을 누르면 기관별 값을 볼 수 있어요'));
      await closeSheet(tester);
      final hint = tester.getTopLeft(find.text('칸을 누르면 기관별 값을 볼 수 있어요'));
      await tester.tapAt(hint + const Offset(20, -24));
      await snap(tester, 'sheet_hour$sfx');
      await closeSheet(tester);

      await tapVisible(tester, find.text('월'));
      await snap(tester, 'sheet_day$sfx');
      await closeSheet(tester);

      await tapVisible(tester, find.text('기관별 숫자 전부 보기'));
      await tester.pumpAndSettle();
      pos(tester).jumpTo(pos(tester).pixels + 500);
      await snap(tester, 'detail_table$sfx');
      pos(tester).jumpTo(math.min(pos(tester).pixels + 700, pos(tester).maxScrollExtent));
      await snap(tester, 'detail_table2$sfx');

      await setUp(tester, const MoreGamesScreen(), dark: dark);
      await snap(tester, 'more_apps$sfx');
    }
  }, skip: dir == null);
}
