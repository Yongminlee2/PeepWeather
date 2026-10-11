import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/main.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/repository.dart';
import 'package:weather_compare/ui/format.dart';
import 'package:weather_compare/ui/report_view.dart';
import 'package:weather_compare/l10n/app_localizations.dart';

final now = DateTime.utc(2026, 10, 11, 1, 20); // 서울 10:20
const seoul = Place('서울', 'KR', 37.57, 126.98);

Report fakeReport() {
  List<Hour> hours(double base) => [
        for (var i = 0; i < 40; i++)
          Hour(DateTime.utc(2026, 10, 11, 0).add(Duration(hours: 3 * i)), base + i % 4, Sky.values[i % 7], pop: (i * 13) % 100)
      ];
  final met = hours(15);
  final owm = hours(15).map((h) => h.time == DateTime.utc(2026, 10, 11, 3) ? Hour(h.time, 30, Sky.clear, pop: 0) : h).toList();
  return Report(
    seoul,
    [
      Result('met', data: Forecast(now: met.first, hours: met, days: [Day(DateTime.utc(2026, 10, 11), 20, 10, Sky.rain, pop: 70)]), asOf: now),
      Result('owm', data: Forecast(now: owm.first, hours: owm, days: [Day(DateTime.utc(2026, 10, 11), 21, 11, Sky.clear, pop: 0)]), asOf: now),
      const Result('vc', fail: Fail.noKey),
    ],
    [
      Result('owm', data: Air(pm10: 120, pm25: 40, time: now), asOf: now),
      const Result('openaq', fail: Fail.quota),
    ],
    [
      Result('nhc', data: [Cyclone('Hagupit', 33, 129, now, windKt: 80)], asOf: now), // 서울에서 약 550km
      Result('gdacs', data: [Cyclone('FARAWAY-26', -20, 60, now)], asOf: now),
    ],
    const Duration(hours: 9),
  );
}

Future<void> pumpReport(WidgetTester tester, {bool fahrenheit = false}) async {
  tester.view.physicalSize = const Size(360, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(WeatherApp(
      locale: const Locale('ko'),
      home: Scaffold(body: ReportView(report: fakeReport(), fahrenheit: fahrenheit, now: now))));
  await tester.pumpAndSettle();
}

/// '동작 줄이기' 설정 — 날씨 아이콘 애니메이션이 멈춰서 pumpAndSettle 이 끝난다.
void calm(WidgetTester tester) {
  tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
}

void main() {
  testWidgets('report shows comparison, divergence, failures, storms, attribution', (tester) async {
    calm(tester);
    await pumpReport(tester);
    expect(tester.takeException(), isNull);
    expect(find.text('서울'), findsOneWidget);
    expect(find.text('가운데 값'), findsWidgets);
    expect(find.textContaining('2곳 예보 범위'), findsOneWidget);
    expect(find.text('받지 못한 곳'), findsOneWidget);
    expect(find.textContaining('설정 필요'), findsWidgets);
    expect(find.text('예보가 엇갈려요'), findsWidgets);

    // 칸을 누르면 기관별 값
    await tester.tap(find.textContaining(RegExp(r'^(없음|\d+곳)$')).first);
    await tester.pumpAndSettle();
    expect(find.text('노르웨이 기상청'), findsWidgets);
    expect(find.text('OpenWeather'), findsWidgets);
    Navigator.of(tester.element(find.text('노르웨이 기상청').first)).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('오늘 한도 초과'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('나쁨'), findsWidgets);

    await tester.scrollUntilVisible(find.textContaining('Hagupit'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('FARAWAY'), findsNothing); // 1000km 밖
    expect(find.textContaining('km'), findsWidgets);

    await tester.scrollUntilVisible(find.textContaining('Data from MET Norway'), 300, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  testWidgets('fahrenheit setting changes temperatures', (tester) async {
    calm(tester);
    await pumpReport(tester, fahrenheit: true);
    expect(find.textContaining('°F'), findsWidgets);
  });

  testWidgets('no overflow at 2x text scale', (tester) async {
    calm(tester);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WeatherApp(
        locale: const Locale('ko'),
        home: MediaQuery(
            data: const MediaQueryData(size: Size(360, 800), textScaler: TextScaler.linear(2)),
            child: Scaffold(body: ReportView(report: fakeReport(), fahrenheit: false, now: now)))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.textContaining('Hagupit'), 300, scrollable: find.byType(Scrollable).first);
    expect(tester.takeException(), isNull);
  });

  test('no-station failure has its own words', () {
    expect(failText(lookupAppLocalizations(const Locale('ko')), Fail.noStation), '근처 측정소 없음');
  });

  test('every source id has a human label', () {
    final l = lookupAppLocalizations(const Locale('ko'));
    for (final id in ['om_ecmwf', 'om_gfs', 'om_icon', 'om_jma', 'om_kma', 'om_gem', 'om_meteofrance', 'om_ukmo', 'om_cma', 'om_bom', 'om_cams']) {
      expect(sourceLabel(l, id), isNot(id), reason: id);
    }
    expect(sourceLabel(l, 'om_ecmwf'), 'ECMWF(유럽)');
  });

  testWidgets('Open-Meteo credit appears once for many models', (tester) async {
    calm(tester);
    final base = fakeReport();
    final f = base.forecasts.first.data!;
    final r = Report(base.place, [
      Result('om_ecmwf', data: f, asOf: now),
      Result('om_gfs', data: f, asOf: now),
      Result('om_icon', data: f, asOf: now),
    ], base.air, base.cyclones, base.offset);
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(WeatherApp(
        locale: const Locale('ko'), home: Scaffold(body: ReportView(report: r, fahrenheit: false, now: now))));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.textContaining('Open-Meteo'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Open-Meteo'), findsOneWidget);
  });
}
