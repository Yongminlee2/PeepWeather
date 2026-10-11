import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import 'theme.dart';

/// 검색 없이 바로 넣는 도시들(좌표는 시청·도심 기준).
const quickCities = [
  Place('서울', 'KR', 37.5665, 126.9780),
  Place('부산', 'KR', 35.1796, 129.0756),
  Place('제주', 'KR', 33.4996, 126.5312),
  Place('대전', 'KR', 36.3504, 127.3845),
  Place('광주', 'KR', 35.1595, 126.8526),
  Place('대구', 'KR', 35.8714, 128.6014),
  Place('도쿄', 'JP', 35.6762, 139.6503),
  Place('뉴욕', 'US', 40.7128, -74.0060),
  Place('런던', 'GB', 51.5072, -0.1276),
  Place('파리', 'FR', 48.8566, 2.3522),
];

/// 저장 도시에 넣는다(이미 있으면 그대로).
Future<void> addPlace(AppState st, Place p) async {
  final s = st.settings;
  if (!s.places.any((x) => placeKey(x) == placeKey(p))) {
    await s.update((s) => s.places = [...s.places, p]);
  }
}

class QuickCityChips extends StatelessWidget {
  const QuickCityChips({super.key, required this.onPick, this.onDark = false});
  final void Function(Place p) onPick;
  final bool onDark; // 하늘 배경 위
  @override
  Widget build(BuildContext context) {
    final w = wx(context);
    return Wrap(spacing: 8, runSpacing: 8, children: [
      for (final p in quickCities)
        ActionChip(
          label: Text(p.name),
          onPressed: () => onPick(p),
          // 하늘 배경 위에선 흰 알약에 남색 글씨(밝은 배경 아래쪽에서도 읽히게)
          backgroundColor: onDark ? Colors.white.withValues(alpha: 0.92) : w.surface,
          side: BorderSide(color: onDark ? Colors.transparent : w.line),
          labelStyle: TextStyle(color: onDark ? Wx.light.ink : w.ink),
          shape: const StadiumBorder(),
        ),
    ]);
  }
}
