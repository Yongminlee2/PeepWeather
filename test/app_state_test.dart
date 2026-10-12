import 'dart:async';
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

  test('locate without key detects the US by bounding box', () async {
    final st = AppState(await Settings.load(), Fetcher(fakeNet(), dir), locator: () async => (40.71, -74.01));
    await st.locate('en', 'Current location');
    expect(st.current!.country, 'US');
  });

  test('changing settings re-sends the first report (home widget units)', () async {
    final s = await Settings.load();
    var sent = 0;
    final st = AppState(s, Fetcher(fakeNet(), dir), locator: () async => (37.57, 126.98), onReport: (_) => sent++);
    await st.locate('ko', '현재 위치');
    await st.refresh(st.current!);
    expect(sent, 1);
    await s.update((s) => s.fahrenheit = true);
    expect(sent, 2);
  });

  test('refresh keeps the local accuracy ledger up to date', () async {
    final s = await Settings.load();
    final ledgerDir = Directory('${dir.path}/verify');
    final st = AppState(s, Fetcher(fakeNet(), dir),
        locator: () async => (37.57, 126.98), ledgerDir: ledgerDir, clock: () => DateTime.utc(2026, 10, 11, 8));
    await st.locate('ko', '현재 위치');
    await st.refresh(st.current!);
    expect(st.ledgerFor(st.current!), isNotNull);
    expect(st.ledgerFor(st.current!)!.pending, isNotEmpty); // 시험 자료의 MET 예보가 저장됨
    expect(ledgerDir.listSync(), isNotEmpty);
  });

  test('permission prompt closed with back: the plugin never answers, so re-check when the app comes back', () async {
    final never = Completer<String>().future; // 뒤로가기로 닫으면 플러그인이 답을 안 준다
    final back = Completer<void>();
    final answer = answerOrRecheck(never, back.future, () async => 'denied');
    back.complete();
    expect(await answer.timeout(const Duration(seconds: 2)), 'denied');
  });

  test('permission prompt answered normally: the plugin answer wins', () async {
    expect(await answerOrRecheck(Future.value('granted'), Completer<void>().future, () async => 'denied'), 'granted');
  });
}
