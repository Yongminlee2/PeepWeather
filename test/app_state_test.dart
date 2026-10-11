import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:weather_compare/app_state.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/settings.dart';

import 'repository_test.dart' show fakeNet;

void main() {
  late Directory dir;
  setUp(() {
    dir = Directory.systemTemp.createTempSync('state');
    SharedPreferences.setMockInitialValues({});
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('locate without reverse geocoding key falls back to name and Korea box', () async {
    final s = await Settings.load();
    final st = AppState(s, Fetcher(fakeNet(), dir), locator: () async => (37.57, 126.98));
    await st.locate('ko', '현재 위치');
    expect(st.current!.name, '현재 위치');
    expect(st.current!.country, 'KR');
    expect(st.locationFailed, isFalse);
    expect(s.lastPos!.lat, 37.57);
    expect(st.places.first, same(st.current));
  });

  test('denied location marks failure and keeps saved cities', () async {
    final s = await Settings.load();
    final st = AppState(s, Fetcher(fakeNet(), dir), locator: () async => null);
    await st.locate('ko', '현재 위치');
    expect(st.current, isNull);
    expect(st.locationFailed, isTrue);
  });

  test('refresh stores the report by place', () async {
    final s = await Settings.load();
    final st = AppState(s, Fetcher(fakeNet(), dir), locator: () async => (40.71, -74.01));
    await st.locate('en', 'Current location');
    await st.refresh(st.current!);
    expect(st.reportFor(st.current!)!.forecasts.first.source, 'met');
    expect(st.isLoading(st.current!), isFalse);
  });

  test('report older than 30 minutes is stale', () async {
    final s = await Settings.load();
    var t = DateTime.now().toUtc();
    final st = AppState(s, Fetcher(fakeNet(), dir), locator: () async => (40.71, -74.01));
    await st.locate('en', 'Current location');
    final p = st.current!;
    expect(st.isStale(p), isTrue); // 아직 없음
    await st.refresh(p);
    expect(st.isStale(p, now: t.add(const Duration(minutes: 10))), isFalse);
    expect(st.isStale(p, now: t.add(const Duration(minutes: 31))), isTrue);
  });
}
