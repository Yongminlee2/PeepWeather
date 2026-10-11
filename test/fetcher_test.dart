import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weather_compare/fetcher.dart';
import 'package:weather_compare/models.dart';

void main() {
  late Directory dir;
  late DateTime now;
  final url = Uri.parse('https://example.com/a?x=1');

  setUp(() {
    dir = Directory.systemTemp.createTempSync('fetcher');
    now = DateTime.utc(2026, 10, 11, 9);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  Matcher failWith(Fail f) => throwsA(isA<FetchError>().having((e) => e.fail, 'fail', f));

  test('fresh cache is reused without request', () async {
    var calls = 0;
    final f = Fetcher(MockClient((_) async => http.Response('body${++calls}', 200)), dir, now: () => now);
    expect((await f.get(url)).body, 'body1');
    now = now.add(const Duration(minutes: 29));
    final r = await f.get(url);
    expect(r.body, 'body1');
    expect(r.at, DateTime.utc(2026, 10, 11, 9));
    expect(calls, 1);
  });

  test('expired cache refetches', () async {
    var calls = 0;
    final f = Fetcher(MockClient((_) async => http.Response('body${++calls}', 200)), dir, now: () => now);
    await f.get(url);
    now = now.add(const Duration(minutes: 31));
    expect((await f.get(url)).body, 'body2');
    expect(calls, 2);
  });

  test('network error falls back to stale cache', () async {
    var calls = 0;
    final f = Fetcher(MockClient((_) async {
      if (++calls > 1) throw const SocketException('offline');
      return http.Response('old', 200);
    }), dir, now: () => now);
    await f.get(url);
    now = now.add(const Duration(hours: 5));
    final r = await f.get(url);
    expect(r.body, 'old');
    expect(r.at, DateTime.utc(2026, 10, 11, 9));
  });

  test('network error without cache throws network', () async {
    final f = Fetcher(MockClient((_) async => throw const SocketException('offline')), dir, now: () => now);
    await expectLater(f.get(url), failWith(Fail.network));
  });

  test('429 maps to quota, 401 to badKey, 500 to network', () async {
    for (final (code, fail) in [(429, Fail.quota), (401, Fail.badKey), (403, Fail.badKey), (500, Fail.network)]) {
      final f = Fetcher(MockClient((_) async => http.Response('x', code)), dir, now: () => now);
      await expectLater(f.get(Uri.parse('https://example.com/$code')), failWith(fail));
    }
  });

  test('sends User-Agent and extra headers', () async {
    late http.BaseRequest seen;
    final f = Fetcher(MockClient((r) async {
      seen = r;
      return http.Response('ok', 200);
    }), dir, now: () => now);
    await f.get(url, headers: {'X-API-Key': 'k'});
    expect(seen.headers['User-Agent'], startsWith('WeatherCompare/'));
    expect(seen.headers['X-API-Key'], 'k');
  });

  test('utf8 body survives cache', () async {
    final f = Fetcher(MockClient((_) async => http.Response.bytes(utf8.encode('서울'), 200)), dir, now: () => now);
    expect((await f.get(url)).body, '서울');
    expect((await f.get(url)).body, '서울');
  });

  test('concurrent requests for the same url share one call', () async {
    var calls = 0;
    final f = Fetcher(MockClient((_) async {
      calls++;
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return http.Response('one', 200);
    }), dir, now: () => now);
    final rs = await Future.wait([f.get(url), f.get(url)]);
    expect(rs.map((r) => r.body), ['one', 'one']);
    expect(calls, 1);
  });

  test('freshCap forces refetch of short-lived entries only', () async {
    var calls = 0;
    final f = Fetcher(MockClient((_) async => http.Response('b${++calls}', 200)), dir, now: () => now);
    final long = Uri.parse('https://example.com/stations');
    await f.get(url);
    await f.get(long, maxAge: const Duration(days: 30));
    now = now.add(const Duration(minutes: 6));
    f.freshCap = const Duration(minutes: 5);
    expect((await f.get(url)).body, 'b3');
    expect((await f.get(long, maxAge: const Duration(days: 30))).body, 'b2');
  });
}
