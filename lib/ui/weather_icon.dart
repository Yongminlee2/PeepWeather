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
      return Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * 0.08),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.28),
          gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: heroGradient(sky, night: night)),
        ),
        child: WeatherIcon(sky, night: night, size: size * 0.84, animate: animate),
      );
    }
    return Lottie.asset(
      skyAsset(sky, night: night),
      width: size,
      height: size,
      // 멈춘 아이콘은 그림이 다 보이는 중간 장면으로
      controller: move ? null : const AlwaysStoppedAnimation(0.5),
      animate: move,
      errorBuilder: (_, _, _) => SizedBox(width: size, height: size),
    );
  }
}
