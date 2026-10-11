import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
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

  test('Europe has no geostationary layer, true color first, no KMA', () {
    final k = kinds(const Place('Paris', 'FR', 48.85, 2.35));
    expect(k.first, SatKind.trueColor);
    expect(k, isNot(contains(SatKind.infrared)));
    expect(k, isNot(contains(SatKind.kma)));
  });

  test('frames go back from now minus 80 min in 10 min steps, oldest first', () {
    expect(satFrames(DateTime.utc(2026, 10, 11, 8, 7), count: 3),
        [DateTime.utc(2026, 10, 11, 6, 20), DateTime.utc(2026, 10, 11, 6, 30), DateTime.utc(2026, 10, 11, 6, 40)]);
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
}
