import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/sources/cyclones.dart';

String fx(String name) => File('test/fixtures/$name').readAsStringSync();

void main() {
  test('GDACS keeps only current tropical cyclones', () {
    final cs = parseGdacs(fx('gdacs.json'));
    expect(cs.map((c) => c.name).toList(), ['ISAIAS-26', 'SIMON-26']);
    expect([cs.first.lat, cs.first.lon], [35.0, -86.7]);
    expect(cs.first.windKt, isNull); // severity 는 일생 최대 풍속이라 현재 풍속으로 쓰지 않는다
    expect(cs.first.time, DateTime.utc(2026, 10, 11, 3, 29, 27));
  });

  test('NHC active storms', () {
    final cs = parseNhc(fx('nhc.json'));
    expect(cs.length, 3);
    expect([cs.first.name, cs.first.lat, cs.first.lon, cs.first.windKt], ['Isaias', 35.0, -86.7, 20.0]);
    expect(cs.first.time, DateTime.utc(2026, 10, 11, 3));
  });

  test('JTWC rss lists warning texts except summaries', () {
    final us = parseJtwcRss(fx('jtwc.rss'));
    expect(us.length, 5);
    expect(us.first.toString(), 'https://www.metoc.navy.mil/jtwc/products/ep1526web.txt');
    expect(us.any((u) => u.path.contains('abpw')), isFalse);
  });

  test('JTWC warning text', () {
    final c = parseJtwcWarning(fx('jtwc_warn.txt'), DateTime.utc(2026, 10, 11, 9))!;
    expect([c.name, c.lat, c.lon, c.windKt], ['NOLO', 31.0, 145.6, 35.0]);
    expect(c.time, DateTime.utc(2026, 10, 10, 12));
  });

  test('JTWC south and west hemispheres, previous month', () {
    const txt = 'SUBJ/TROPICAL CYCLONE 05P (ALFRED) WARNING NR 003//\n'
        '   302100Z --- NEAR 15.2S 170.1W\n   MAX SUSTAINED WINDS - 090 KT, GUSTS 110 KT\n';
    final c = parseJtwcWarning(txt, DateTime.utc(2026, 10, 1, 3))!;
    expect([c.name, c.lat, c.lon, c.windKt], ['ALFRED', -15.2, -170.1, 90.0]);
    expect(c.time, DateTime.utc(2026, 9, 30, 21));
  });

  test('JTWC unnamed system uses its number', () {
    const txt = 'SUBJ/TROPICAL DEPRESSION 28W WARNING NR 001//\n   111200Z --- NEAR 12.0N 135.0E\n';
    expect(parseJtwcWarning(txt, DateTime.utc(2026, 10, 11, 13))!.name, '28W');
  });

  test('KMA typhoon keeps latest per storm', () {
    final cs = parseKmaTyphoon(fx('kma_typhoon.json'));
    expect(cs.length, 1);
    expect([cs.first.name, cs.first.lat, cs.first.lon], ['하구핏 HAGUPIT', 20.5, 129.8]);
    expect(cs.first.windKt, closeTo(68.0, 0.1)); // 35 m/s
    expect(cs.first.time, DateTime.utc(2026, 10, 11, 6));
  });
}
