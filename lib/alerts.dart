import 'compare.dart';
import 'l10n/app_localizations.dart';
import 'models.dart';
import 'repository.dart';
import 'settings.dart';
import 'ui/format.dart';

class Alert {
  final String key; // 중복 방지 기록 키
  final String value; // 기록값 "<값>@<보낸 날짜>" (태풍은 값 = 처음 알린 거리 km)
  final String title, body;
  const Alert(this.key, this.value, this.title, this.body);
}

/// 알림 판정(순수 함수). 주의: 생성된 번역 함수의 인자는 자리표시자 이름 알파벳순. sent 는 이전에 보낸 알림 기록(key → value).
List<Alert> decideAlerts(Report r, Settings s, Map<String, String> sent, DateTime nowUtc, AppLocalizations l) {
  final local = nowUtc.add(r.offset);
  final today = '${local.year}-${two(local.month)}-${two(local.day)}';
  final place = r.place.name;
  final out = <Alert>[];

  if (s.alertRain && !sent.containsKey('rain:$today')) {
    final end = nowUtc.add(const Duration(hours: 12));
    final hits = [
      for (final f in r.forecasts)
        for (final h in f.data?.hours ?? const <Hour>[])
          if (h.time.isAfter(nowUtc) && !h.time.isAfter(end) && (h.pop ?? 0) >= 60) (f.source, h)
    ]..sort((a, b) => a.$2.time.compareTo(b.$2.time));
    if (hits.isNotEmpty) {
      final (src, h) = hits.first;
      final t = h.time.add(r.offset); // 백그라운드에선 intl 날짜 자료가 없어서 DateFormat 대신 직접
      out.add(Alert('rain:$today', '$today@$today', l.rainSoon(place),
          l.rainSoonBody('${h.pop}', sourceLabel(l, src), '${two(t.hour)}:${two(t.minute)}')));
    }
  }

  if (s.alertAir && !sent.containsKey('air:$today')) {
    final worst = [
      for (final a in r.air)
        if (a.data == null ? null : worstGrade(a.data!) case final g?) (a.source, g)
    ]..sort((a, b) => b.$2.index.compareTo(a.$2.index));
    if (worst.isNotEmpty && worst.first.$2.index >= Grade.bad.index) {
      out.add(Alert('air:$today', '$today@$today', l.airBad(gradeText(l, worst.first.$2), place),
          l.airBadBody(sourceLabel(l, worst.first.$1))));
    }
  }

  if (s.alertStorm) {
    for (final g in groupCyclones(r.cyclones)) {
      final km = g.map((m) => distanceKm(r.place.lat, r.place.lon, m.$2.lat, m.$2.lon)).reduce((a, b) => a < b ? a : b);
      if (km > 500) continue;
      final name = g.map((m) => normName(m.$2.name)).firstWhere((n) => n.isNotEmpty, orElse: () => g.first.$2.name);
      final key = 'storm:$name';
      final first = double.tryParse((sent[key] ?? '').split('@').first);
      final title = l.stormNear(name), body = l.stormNearBody(km.round().toString(), place);
      if (first == null) {
        out.add(Alert(key, '${km.round()}@$today', title, body));
      } else if (km <= first / 2 && !sent.containsKey('$key:half')) {
        out.add(Alert('$key:half', '${km.round()}@$today', title, body));
      }
    }
  }
  return out;
}

/// 30일 넘은 기록은 지운다 — 번호 이름 태풍(TEN 등)은 해마다 다시 오고, 기록이 끝없이 쌓이지 않게.
Map<String, String> pruneSent(Map<String, String> sent, DateTime nowUtc) => {
      for (final e in sent.entries)
        if (DateTime.tryParse(e.value.split('@').last) case final d?
            when nowUtc.difference(d) < const Duration(days: 30))
          e.key: e.value
    };

String two(int v) => v.toString().padLeft(2, '0');
