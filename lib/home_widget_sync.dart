import 'dart:ui';

import 'package:home_widget/home_widget.dart';

import 'compare.dart';
import 'l10n/app_localizations.dart';
import 'repository.dart';
import 'ui/format.dart';

/// 위젯 줄: 지금 기온을 준 출처만, 최대 4줄.
List<String> widgetRows(Report r, bool fahrenheit, AppLocalizations l) => [
      for (final f in r.forecasts)
        if (f.data?.now case final h?) '${sourceLabel(l, f.source)} ${tempText(h.tempC, fahrenheit)}'
    ].take(4).toList();

/// 위젯 머리: 모든 기관 지금 기온의 가운데 값과 "N곳 최저 ~ 최고". 아무 곳도 없으면 null.
(String, String)? widgetHeadline(Report r, bool fahrenheit, AppLocalizations l) {
  final temps = [for (final f in r.forecasts) ?f.data?.now?.tempC];
  if (temps.isEmpty) return null;
  temps.sort();
  return (
    tempText(median(temps), fahrenheit),
    l.widgetRange(temps.length, '${tempText(temps.first, fahrenheit)} ~ ${tempText(temps.last, fahrenheit)}'),
  );
}

/// 안드로이드 홈 화면 위젯(CompareWidget)에 넣고 다시 그리게 한다. 실패해도 앱은 그대로.
Future<void> syncWidget(Report r, bool fahrenheit, AppLocalizations l) async {
  try {
    final rows = widgetRows(r, fahrenheit, l);
    final head = widgetHeadline(r, fahrenheit, l);
    await HomeWidget.saveWidgetData<String>('mid', head?.$1 ?? '—');
    await HomeWidget.saveWidgetData<String>('range', head?.$2 ?? '');
    final t = DateTime.now().toUtc().add(r.offset);
    await HomeWidget.saveWidgetData<String>('place', r.place.name);
    await HomeWidget.saveWidgetData<String>('time', '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}');
    for (var i = 0; i < 4; i++) {
      await HomeWidget.saveWidgetData<String>('row$i', i < rows.length ? rows[i] : '');
    }
    await HomeWidget.updateWidget(androidName: 'CompareWidget');
  } catch (_) {}
}

/// 폰 언어(한국어 아니면 영어). 화면 밖(백그라운드·위젯)에서 쓴다.
AppLocalizations deviceL10n() =>
    lookupAppLocalizations(Locale(PlatformDispatcher.instance.locale.languageCode == 'ko' ? 'ko' : 'en'));
