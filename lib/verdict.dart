import 'dart:math';

import 'compare.dart';
import 'models.dart';
import 'repository.dart';
import 'verify.dart';

/// 여러 기관 예보에서 내리는 결론: 지금 기온(잘 맞춘 기관에 무게), 얼마나 확신할 만한지,
/// 12시간 안 비, 오늘 최고, 내일, 이 동네에서 잘 맞춘 기관.

enum Confidence { high, medium, low }

enum RainCall { likely, unlikely, split }

class Verdict {
  const Verdict({
    required this.tempNow,
    required this.weighted,
    required this.tempConfidence,
    required this.midLow,
    required this.midHigh,
    required this.rain,
    required this.rainVotes,
    required this.todayHigh,
    required this.tomorrow,
    required this.tomorrowRain,
    required this.best,
    required this.comparisons,
  });
  final double tempNow;
  final bool weighted; // 잘 맞춘 기관에 무게를 둔 값인가
  final Confidence tempConfidence;
  final double midLow, midHigh; // 가운데 절반 기관의 범위(3곳 이하면 전체 범위)
  final RainCall rain;
  final (int, int) rainVotes; // 12시간 안 (비 예보 기관 수, 전체)
  final double? todayHigh;
  final DaySpread? tomorrow;
  final (int, int)? tomorrowRain; // (강수확률 50% 이상 기관 수, 확률을 준 기관 수)
  final (String, Score)? best; // 이 동네에서 평균 오차가 가장 작은 기관
  final int comparisons; // 지금까지 쌓인 비교 횟수
}

/// 기관끼리 얼마나 비슷한가: 4곳 이상이면 가운데 절반의 폭, 아니면 전체 폭.
Confidence confidenceOf(List<double> temps) {
  final s = [...temps]..sort();
  final spread = s.length >= 4 ? quantile(s, 0.75) - quantile(s, 0.25) : s.last - s.first;
  final (hi, mid) = s.length >= 4 ? (1.5, 3.0) : (2.0, 4.0);
  return spread <= hi
      ? Confidence.high
      : spread <= mid
          ? Confidence.medium
          : Confidence.low;
}

Verdict? verdict(Report r, Ledger? ledger, DateTime nowUtc) {
  final nows = {
    for (final f in r.forecasts)
      if (f.data?.now case final h?) f.source: h.tempC
  };
  if (nows.isEmpty) return null;
  final w = ledger == null ? null : weightedTemp(nows, ledger);

  final rain = rainHeadline(r.forecasts, nowUtc);
  final ratio = rain.$2 == 0 ? 0.0 : rain.$1 / rain.$2;

  // 오늘 남은 시간 중 가운데 기온이 가장 높은 때
  final local = nowUtc.add(r.offset);
  final midnight = DateTime.utc(local.year, local.month, local.day + 1).subtract(r.offset);
  double? high;
  // 저녁(18시 이후)엔 오늘이 얼마 안 남아 "오늘 최고"가 지금보다 낮게 나올 수 있어 뺀다
  for (var t = nowUtc; local.hour < 18 && t.isBefore(midnight); t = t.add(const Duration(hours: 1))) {
    final s = hourSpread(r.forecasts, t);
    if (s != null) high = high == null ? s.median : max(high, s.median);
  }

  final tomorrowDate = DateTime.utc(local.year, local.month, local.day + 1);
  final tomorrow = daySpread(r.forecasts, tomorrowDate);
  final pops = [for (final c in tomorrow?.cells ?? const <(String, Day)>[]) ?c.$2.pop];

  final rank = ledger == null ? const <(String, Score)>[] : ranking(ledger);
  final sorted = nows.values.toList()..sort();
  final quart = sorted.length >= 4;
  return Verdict(
    tempNow: w ?? median(nows.values.toList()),
    weighted: w != null,
    tempConfidence: confidenceOf(nows.values.toList()),
    midLow: quart ? quantile(sorted, 0.25) : sorted.first,
    midHigh: quart ? quantile(sorted, 0.75) : sorted.last,
    rain: ratio >= 0.6
        ? RainCall.likely
        : ratio <= 0.2
            ? RainCall.unlikely
            : RainCall.split,
    rainVotes: rain,
    todayHigh: high,
    tomorrow: tomorrow,
    tomorrowRain: pops.isEmpty ? null : (pops.where((p) => p >= 50).length, pops.length),
    best: rank.firstOrNull,
    comparisons: ledger?.scores.values.fold<int>(0, (a, s) => a + s.n) ?? 0,
  );
}
