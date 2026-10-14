import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../models.dart';

/// 날씨 아이콘: Meteocons(MIT, Bas Milius) 로티 애니메이션.
String skyAsset(Sky s, {required bool night}) {
  final dn = night ? 'night' : 'day';
  final name = switch (s) {
    Sky.clear => 'clear-$dn',
    Sky.partly => 'partly-cloudy-$dn',
    Sky.cloudy => 'overcast',
    Sky.fog => 'fog',
    Sky.rain => 'rain',
    Sky.snow => 'snow',
    Sky.thunder => 'thunderstorms-rain',
  };
  return 'assets/icons/$name.json';
}

/// 장소 현지 시각으로 대략 밤인지(18시~6시).
// ponytail: 일출·일몰을 계산하지 않는다 — 여름·고위도에선 1~2시간 어긋날 수 있음
bool isNightAt(DateTime utc, Duration offset) {
  final h = utc.add(offset).hour;
  return h < 6 || h >= 18;
}

/// 맨 위 하늘 배경(위→아래). 지금 하늘과 낮·밤에 따라 바뀐다.
List<Color> heroGradient(Sky s, {required bool night}) {
  if (night) {
    return s.index <= Sky.partly.index
        ? const [Color(0xFF0E1A33), Color(0xFF2B4170)]
        : const [Color(0xFF1A2233), Color(0xFF3A4A63)];
  }
  // 아래쪽도 흰 글씨가 읽힐 만큼 진하게(밝은 하늘색까지 가면 알약·작은 글씨가 묻힌다)
  return switch (s) {
    Sky.clear => const [Color(0xFF2565A8), Color(0xFF4F8FCB)],
    Sky.partly => const [Color(0xFF34689C), Color(0xFF6194C2)],
    Sky.cloudy || Sky.fog => const [Color(0xFF4F5F75), Color(0xFF7C8CA1)],
    Sky.rain || Sky.thunder => const [Color(0xFF3D4B60), Color(0xFF627389)],
    Sky.snow => const [Color(0xFF5B7090), Color(0xFF8DA3BE)],
  };
}

/// 칸 안 그림 배율. 해·달만 있는 그림은 원래 꽉 차서 키우면 햇살이 칸 끝에 닿는다.
double tileZoom(Sky s) => s == Sky.clear ? 1.0 : 1.25;

/// 움직이지 않을 때 보여 줄 장면. 비·눈·번개는 떨어지고 번쩍이는 동안만 보여서, 가운데(0.5)를 고르면
/// 빗줄기 하나만 남거나 번개가 아예 없다(뇌우가 비와 똑같아 보였다). 장면마다 그려 보고 골랐다(test/icon_sheet_test.dart).
double stillFrame(Sky s) => switch (s) {
      Sky.rain || Sky.snow => 0.8,
      Sky.thunder => 0.7,
      _ => 0.5,
    };

/// 원래 빗줄기(짙은 파랑 #0A5AD4)·눈송이(옅은 청회색)는 흰 바탕용이라, 이 앱의 하늘색·회색 판 위에선
/// 거의 안 보였다. 밝은 하늘색·흰색으로 칠한다(채움은 다섯 칸 그라데이션이라 색도 다섯 개).
final _brighter = LottieDelegates(values: [
  for (final (k, c) in [('raindrops', const [Color(0xFFC4E8FF), Color(0xFFB0DFFF), Color(0xFF9CD6FF), Color(0xFF8ACDFB), Color(0xFF78C3F6)])] + [
    for (final f in ['snowflake-1', 'snowflake-2', 'snowflake-3']) (f, const [Color(0xFFFFFFFF), Color(0xFFF6FBFF), Color(0xFFEDF7FF), Color(0xFFE3F2FF), Color(0xFFD8EEFF)])
  ]) ...[
    ValueDelegate.gradientColor([k, '**'], value: c),
    ValueDelegate.strokeColor([k, '**'], value: c.last),
  ],
]);

/// 아이콘 하나. animate 가 꺼져 있거나 '동작 줄이기' 설정이면 멈춘 한 장면.
class WeatherIcon extends StatelessWidget {
  const WeatherIcon(this.sky, {super.key, this.night = false, this.size = 28, this.animate = true, this.tile = false});
  final Sky sky;
  final bool night;
  final double size;
  final bool animate;
  final bool tile; // 밝은 바탕 위: 흰 구름이 묻히지 않게 그 하늘색 작은 판 위에 올린다

  @override
  Widget build(BuildContext context) {
    final move = animate && !MediaQuery.disableAnimationsOf(context);
    if (tile) {
      // Meteocons 그림은 둘레 여백이 커서 그대로 넣으면 칸 가운데 작게 뜬다 — 키워서 칸을 채우고 판 밖은 자른다
      return Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: heroGradient(sky, night: night)),
        ),
        // 구름이 그림 위쪽에 있고 비·눈·안개 줄이 아래에 붙어 있어서, 조금 올려야 아래 줄이 칸 안에 들어온다
        child: OverflowBox(
          maxWidth: size * tileZoom(sky),
          maxHeight: size * tileZoom(sky),
          child: Transform.translate(
            offset: Offset(0, sky.index >= Sky.fog.index ? -size * 0.09 : 0), // 안개·비·눈·뇌우만
            child: WeatherIcon(sky, night: night, size: size * tileZoom(sky), animate: animate),
          ),
        ),
      );
    }
    return Lottie.asset(
      skyAsset(sky, night: night),
      width: size,
      height: size,
      controller: move ? null : AlwaysStoppedAnimation(stillFrame(sky)),
      delegates: _brighter,
      animate: move,
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
  }
}
