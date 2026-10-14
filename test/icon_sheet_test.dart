// 날씨 아이콘 모아 보기. 평소엔 건너뛰고, SHOT_DIR 을 주면 칸 크기·낮밤·밝은/어두운 화면별로 한 장에 그린다.
//   SHOT_DIR=/tmp/shots flutter test test/icon_sheet_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lottie/lottie.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/ui/weather_icon.dart';

final dir = Platform.environment['SHOT_DIR'];

void main() {
  testWidgets('icon frames', (tester) async {
    tester.view.physicalSize = const Size(1700, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: Container(
          color: const Color(0xFF2565A8),
          child: Column(children: [
            for (final s in [Sky.rain, Sky.snow, Sky.thunder, Sky.partly, Sky.fog])
              Row(children: [
                for (var f = 0; f < 10; f++)
                  Lottie.asset(skyAsset(s, night: false), width: 160, height: 160, controller: AlwaysStoppedAnimation(f / 10)),
              ]),
          ]),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      File('$dir/frames.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }, skip: dir == null);

  testWidgets('icon sheet', (tester) async {
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    Widget row(bool night, double size, bool tile) => Row(children: [
          for (final s in Sky.values)
            Padding(
                padding: const EdgeInsets.all(4),
                child: WeatherIcon(s, night: night, size: size, tile: tile, animate: false)),
        ]);
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: RepaintBoundary(
          key: key,
          child: Container(
            color: const Color(0xFFEEF3F8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              for (final night in [false, true]) ...[
                row(night, 48, true),
                row(night, 36, true),
                Container(color: const Color(0xFF2565A8), child: row(night, 80, false)),
              ],
            ]),
          ),
        ),
      ),
    ));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.runAsync(() async {
      final img = await (key.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage(pixelRatio: 2);
      final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory(dir!).createSync(recursive: true);
      File('$dir/icons.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }, skip: dir == null);
}
