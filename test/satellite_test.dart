import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/sources/satellite.dart';

void main() {
  List<SatKind> kinds(Place p) => satLayersFor(p).map((l) => l.kind).toList();

  test('Seoul uses Himawari and offers the KMA image', () {
    const p = Place('서울', 'KR', 37.57, 126.98);
    expect(kinds(p), [SatKind.infrared, SatKind.visible, SatKind.trueColor, SatKind.owmClouds, SatKind.owmPrecip, SatKind.kma]);
    expect(satLayersFor(p).first.tileUrl, contains('Himawari_AHI_Band13_Clean_Infrared'));
  });

  test('satellite by longitude', () {
    expect(satLayersFor(const Place('NY', 'US', 40.7, -74)).first.tileUrl, contains('GOES-East_ABI_Band13'));
    expect(satLayersFor(const Place('LA', 'US', 34, -118)).first.tileUrl, contains('GOES-West_ABI_Band13'));
    expect(satLayersFor(const Place('NY', 'US', 40.7, -74))[1].tileUrl, contains('GOES-East_ABI_GeoColor'));
  });

  test('frames go back from now minus 90 min in 10 min steps, oldest first', () {
    expect(satFrames(DateTime.utc(2026, 10, 11, 8, 7), count: 3),
        [DateTime.utc(2026, 10, 11, 6, 10), DateTime.utc(2026, 10, 11, 6, 20), DateTime.utc(2026, 10, 11, 6, 30)]);
  });

  test('urlAt fills time or default', () {
    final ir = satLayersFor(const Place('서울', 'KR', 37.57, 126.98)).first;
    expect(ir.urlAt(DateTime.utc(2026, 10, 11, 6, 40)), contains('/default/2026-10-11T06:40:00Z/GoogleMapsCompatible_Level6/{z}/{y}/{x}.png'));
    expect(ir.urlAt(null), contains('/default/default/'));
    expect(ir.animated, isTrue);
    expect(ir.maxZoom, 6);
  });

  test('KMA satellite image list takes the newest url', () {
    final u = parseKmaSat(File('test/fixtures/kma_sat.json').readAsStringSync());
    expect(u.toString(), endsWith('_202610110810.srv.png'));
  });

  test('KMA image url is upgraded to https (Android blocks cleartext)', () {
    expect(parseKmaSat(File('test/fixtures/kma_sat.json').readAsStringSync()).scheme, 'https');
  });

  test('Europe gets EUMETSAT Meteosat infrared and true colour first', () {
    final ls = satLayersFor(const Place('Paris', 'FR', 48.85, 2.35));
    expect(ls.map((l) => l.kind).take(3), [SatKind.infrared, SatKind.visible, SatKind.trueColor]);
    expect(ls[0].wmsLayer, 'mtg_fd:ir105_hrfi');
    expect(ls[1].wmsLayer, 'mtg_fd:rgb_truecolour');
    expect(ls[0].animated, isTrue);
    expect(ls[0].credit, contains('EUMETSAT'));
    expect(satLayersFor(const Place('서울', 'KR', 37.57, 126.98)).first.wmsLayer, isNull);
  });

  test('frames honour a per-layer lag', () {
    expect(satFrames(DateTime.utc(2026, 10, 11, 8, 7), count: 2, lag: const Duration(minutes: 20)),
        [DateTime.utc(2026, 10, 11, 7, 30), DateTime.utc(2026, 10, 11, 7, 40)]);
  });

  test('frame label says the local time for timed frames', () {
    expect(frameLabel(DateTime.utc(2026, 10, 11, 10, 30), const Duration(hours: 9)), '10/11 19:30');
  });

  test('map layers loop 2 hours in 12 frames (memory on small phones)', () {
    expect(satFrames(DateTime.utc(2026, 10, 11, 8, 7)).length, 12);
  });

  test('coastlines come from the layer that actually has lines', () {
    expect(coastlinesUrl, contains('Coastlines_15m'));
  });

  group('newest published picture', () {
    const seoul = Place('서울', 'KR', 37.57, 126.98);
    final ir = satLayersFor(seoul).first;
    final now = DateTime.utc(2026, 10, 12, 11, 55);

    test('steps back from now in 10 minutes until the picture over the place exists', () async {
      final asked = <String>[];
      final net = MockClient((r) async {
        asked.add(r.url.path);
        // 11:30 까지만 공개됨, 서울은 3단계 지도에서 (6, 3) 칸
        expect(r.url.path, endsWith('/3/3/6.png'));
        return http.Response('', r.url.path.contains('T11:50') || r.url.path.contains('T11:40') ? 404 : 200);
      });
      expect(await latestPublished(net, ir, now, seoul), DateTime.utc(2026, 10, 12, 11, 30));
      expect(asked.length, 3);
    });

    test('gives up (null) when nothing answers within three hours', () async {
      final net = MockClient((r) async => http.Response('', 404));
      expect(await latestPublished(net, ir, now, seoul), isNull);
    });

    test('frames can end at the newest published picture', () {
      final f = satFrames(DateTime.utc(2026, 10, 12, 11, 30), count: 2, lag: Duration.zero);
      expect(f, [DateTime.utc(2026, 10, 12, 11, 20), DateTime.utc(2026, 10, 12, 11, 30)]);
    });
  });

  test('in Korea the KMA image (newest, a few minutes old) comes first when its key is set', () {
    const p = Place('서울', 'KR', 37.57, 126.98);
    expect(satLayersFor(p, kmaFirst: true).first.kind, SatKind.kma);
    expect(satLayersFor(p, kmaFirst: true).length, 6);
    expect(satLayersFor(const Place('Paris', 'FR', 48.85, 2.35), kmaFirst: true).first.kind, SatKind.infrared);
  });

  test('KMA image lists are filed by UTC date: ask today and yesterday in UTC', () {
    // 한국 0시 5분 = UTC 전날 15시 5분 — 한국 날짜(13일)로 물으면 목록이 비어 "못 가져옴"이 됐다
    expect(kmaListDays(DateTime.utc(2026, 10, 12, 15, 5)), ['20261012', '20261011']);
    expect(kmaListDays(DateTime.utc(2026, 10, 13, 0, 3)), ['20261013', '20261012']);
  });

  group('daily true-colour pick', () {
    const seoul = Place('서울', 'KR', 37.57, 126.98);
    // 16시(한국) — 오후 위성 사진은 아직 처리 전이라 검은 조각, 아침 Terra 는 있음
    final now = DateTime.utc(2026, 10, 14, 7, 20);
    Future<(SatLayer, DateTime)?> pick(Set<String> filled) => latestDaily(
          MockClient((r) async {
            final hit = filled.any((f) => r.url.path.contains(f));
            return http.Response.bytes(hit ? [1] : [0], 200); // 바이트 1 = 찍힌 사진, 0 = 검은 조각(시험용 약속)
          }),
          seoul,
          now,
          const Duration(hours: 9),
          (b) async => b.first == 1 ? 0.02 : 1.0,
        );

    test('prefers the newest filled image today, in satellite order', () async {
      final r = await pick({'MODIS_Terra_CorrectedReflectance_TrueColor/default/2026-10-14'});
      expect(r!.$1.tileUrl, contains('MODIS_Terra'));
      expect(r.$2, DateTime.utc(2026, 10, 14));
      final both = await pick({'MODIS_Terra_CorrectedReflectance_TrueColor/default/2026-10-14', 'VIIRS_NOAA20_CorrectedReflectance_TrueColor/default/2026-10-14'});
      expect(both!.$1.tileUrl, contains('NOAA20')); // 오후에 지나는 위성이 더 최근
    });

    test('falls back to yesterday, then null when nothing is filled', () async {
      final r = await pick({'VIIRS_NOAA20_CorrectedReflectance_TrueColor/default/2026-10-13'});
      expect(r!.$2, DateTime.utc(2026, 10, 13));
      expect(await pick({}), isNull);
    });

    test('never asks Suomi NPP (only black tiles since 2026-10)', () {
      expect(dailyTrueColorIds.any((id) => id.contains('SNPP')), isFalse);
    });
  });
}
