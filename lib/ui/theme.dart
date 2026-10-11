import 'package:flutter/material.dart';

/// 날씨 비교의 색 토큰. 핵심은 "기관끼리 얼마나 맞는가":
/// 퍼짐 띠는 하늘색, 가운데 값은 진한 남색, 엇갈림만 호박색으로 눈에 띄게.
@immutable
class Wx extends ThemeExtension<Wx> {
  const Wx({
    required this.paper,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.band,
    required this.rain,
    required this.disagree,
    required this.line,
  });
  final Color paper, surface, ink, muted, band, rain, disagree, line;

  static const light = Wx(
    paper: Color(0xFFEEF3F8),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF10233F),
    muted: Color(0xFF5B6B82),
    band: Color(0xFF9CC3E6),
    rain: Color(0xFF2563EB),
    disagree: Color(0xFFE8892B),
    line: Color(0xFFD6DFEA),
  );
  static const dark = Wx(
    paper: Color(0xFF0B1424),
    surface: Color(0xFF13203A),
    ink: Color(0xFFE7EEF7),
    muted: Color(0xFF8FA0B8),
    band: Color(0xFF2E5A88),
    rain: Color(0xFF5B8CFF),
    disagree: Color(0xFFF2A541),
    line: Color(0xFF223252),
  );

  @override
  Wx copyWith() => this;

  @override
  Wx lerp(Wx? other, double t) => t < 0.5 || other == null ? this : other;
}

Wx wx(BuildContext c) => Theme.of(c).extension<Wx>()!;

const font = 'Plex';
const tabular = [FontFeature.tabularFigures()];

ThemeData buildTheme(Brightness b) {
  final w = b == Brightness.light ? Wx.light : Wx.dark;
  final scheme = ColorScheme.fromSeed(seedColor: w.ink, brightness: b).copyWith(
    surface: w.paper,
    onSurface: w.ink,
    onSurfaceVariant: w.muted,
    primary: w.rain,
    outlineVariant: w.line,
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true, fontFamily: font, brightness: b);
  return base.copyWith(
    scaffoldBackgroundColor: w.paper,
    extensions: [w],
    appBarTheme: AppBarTheme(
      backgroundColor: w.paper,
      foregroundColor: w.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: TextStyle(fontFamily: font, fontSize: 18, fontWeight: FontWeight.w600, color: w.ink),
    ),
    dividerTheme: DividerThemeData(color: w.line, thickness: 1, space: 1),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: w.surface,
      selectedColor: w.ink,
      labelStyle: TextStyle(fontFamily: font, color: w.ink),
      secondaryLabelStyle: TextStyle(fontFamily: font, color: w.paper),
      side: BorderSide(color: w.line),
      shape: const StadiumBorder(),
      showCheckmark: false,
    ),
    bottomSheetTheme: BottomSheetThemeData(backgroundColor: w.surface, showDragHandle: true),
  );
}
