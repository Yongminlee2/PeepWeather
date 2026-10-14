import 'package:flutter/material.dart';

import '../compare.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../repository.dart';
import 'format.dart';
import 'weather_icon.dart';

const _labelW = 104.0, _cellW = 64.0, _rowH = 64.0, _headH = 40.0;

/// 기관별 숫자 표(시간별·날짜별). 그래프 아래 "전부 보기"로 펼친다.
class DetailTables extends StatelessWidget {
  const DetailTables({super.key, required this.report, required this.fahrenheit, required this.nowUtc});
  final Report report;
  final bool fahrenheit;
  final DateTime nowUtc;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final st = Theme.of(context).textTheme.titleSmall;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l.hourlyTitle, style: st),
      const SizedBox(height: 6),
      _HourTable(report, fahrenheit, slotTimes(nowUtc, report.offset), nowUtc),
      const SizedBox(height: 16),
      Text(l.dailyTitle, style: st),
      const SizedBox(height: 6),
      _DayTable(report, fahrenheit, nowUtc),
    ]);
  }
}

/// 출처 이름 + (실패 이유 또는 오래된 자료 시각).
class _Label extends StatelessWidget {
  const _Label(this.result, this.nowUtc, this.offset);
  final Result<Object?> result;
  final DateTime nowUtc;
  final Duration offset;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sub = result.fail != null
        ? failText(l, result.fail!)
        : result.asOf != null && nowUtc.difference(result.asOf!) > const Duration(minutes: 30)
            ? l.asOf(localTime(result.asOf!, offset, Localizations.localeOf(context).toString(), 'HH:mm'))
            : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      // 긴 이름은 괄호 앞에서 줄을 바꾼다("Météo-France(프 / 랑스)" 처럼 끊기지 않게)
      Text(_wrapLabel(sourceLabel(l, result.source)), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
      if (sub != null)
        Text(sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: result.fail != null ? Theme.of(context).colorScheme.error : null)),
    ]);
  }
}

/// 왼쪽 출처 이름은 고정, 오른쪽 칸들은 가로로 넘긴다. 엇갈린 열은 주황 머리.
class _Grid extends StatelessWidget {
  const _Grid({required this.rows, required this.headers, required this.diverging, required this.cell, required this.nowUtc, required this.offset});
  final List<Result<Forecast>> rows;
  final List<String> headers;
  final List<bool> diverging;
  final Widget Function(Forecast f, int col) cell;
  final DateTime nowUtc;
  final Duration offset;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final warn = Colors.orange.withValues(alpha: 0.18);
    final ts = MediaQuery.textScalerOf(context); // 큰 글씨 설정이면 칸 높이도 같이 키운다
    final rowH = ts.scale(_rowH), headH = ts.scale(_headH);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (diverging.contains(true))
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            const Icon(Icons.warning_amber, size: 16, color: Colors.orange),
            const SizedBox(width: 4),
            Text(l.diverge, style: const TextStyle(fontSize: 12)),
          ]),
        ),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: _labelW,
          child: Column(children: [
            SizedBox(height: headH),
            for (final r in rows) SizedBox(height: rowH, child: Align(alignment: Alignment.centerLeft, child: _Label(r, nowUtc, offset))),
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (var c = 0; c < headers.length; c++)
                Container(
                  width: _cellW,
                  color: diverging[c] ? warn : null,
                  child: Column(children: [
                    SizedBox(
                      height: headH,
                      child: Center(
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                        if (diverging[c]) const Icon(Icons.warning_amber, size: 12, color: Colors.orange),
                        Flexible(
                            child: Text(headers[c],
                                textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11))),
                      ])),
                    ),
                    for (final r in rows) SizedBox(height: rowH, child: r.data == null ? const Center(child: Text('—')) : cell(r.data!, c)),
                  ]),
                ),
            ]),
          ),
        ),
      ]),
    ]);
  }
}

/// 글자가 길면(예: 68°F/50°F) 줄바꿈 대신 줄여서 한 줄로.
Widget _fit(String s, TextStyle st) => FittedBox(fit: BoxFit.scaleDown, child: Text(s, maxLines: 1, style: st));

// 그림은 위쪽 24시간·날짜별과 같은 하늘 판 아이콘(예전엔 머티리얼 선 아이콘이라 부분 구름이 주황 테두리 구름으로 보였다)
Widget _cell(Sky sky, String main, String? sub, {bool night = false}) =>
    Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      WeatherIcon(sky, night: night, size: 26, tile: true, animate: false),
      const SizedBox(height: 2),
      _fit(main, const TextStyle(fontSize: 13)),
      if (sub != null) _fit(sub, const TextStyle(fontSize: 10, color: Colors.blueGrey)),
    ]);

String? _rain(int? pop, double? mm) => pop != null ? '$pop%' : mm != null && mm > 0 ? '${mm.toStringAsFixed(1)}mm' : null;

class _HourTable extends StatelessWidget {
  const _HourTable(this.r, this.fahrenheit, this.slots, this.nowUtc);
  final Report r;
  final bool fahrenheit;
  final List<DateTime> slots;
  final DateTime nowUtc;
  @override
  Widget build(BuildContext context) {
    final loc = Localizations.localeOf(context).toString();
    Hour? at(Forecast f, int c) => hourAt(f.hours, slots[c]);
    return _Grid(
      rows: r.forecasts,
      nowUtc: nowUtc,
      offset: r.offset,
      headers: [
        for (var c = 0; c < slots.length; c++)
          localTime(slots[c], r.offset, loc, c == 0 || slots[c].add(r.offset).hour < 3 ? 'E j' : 'j')
      ],
      diverging: [for (var c = 0; c < slots.length; c++) divergesHours([for (final f in r.forecasts) f.data == null ? null : at(f.data!, c)])],
      cell: (f, c) {
        final h = at(f, c);
        return h == null
            ? const Center(child: Text('—'))
            : _cell(h.sky, tempText(h.tempC, fahrenheit), _rain(h.pop, h.mm), night: isNightAt(slots[c], r.offset));
      },
    );
  }
}

class _DayTable extends StatelessWidget {
  const _DayTable(this.r, this.fahrenheit, this.nowUtc);
  final Report r;
  final bool fahrenheit;
  final DateTime nowUtc;
  @override
  Widget build(BuildContext context) {
    final loc = Localizations.localeOf(context).toString();
    final today = nowUtc.add(r.offset);
    final dates = [for (var i = 0; i < 5; i++) DateTime.utc(today.year, today.month, today.day + i)];
    Day? at(Forecast f, int c) => f.days.where((d) => d.date == dates[c]).firstOrNull;
    return _Grid(
      rows: r.forecasts,
      nowUtc: nowUtc,
      offset: r.offset,
      headers: [for (final d in dates) localTime(d, Duration.zero, loc, 'M/d E')],
      diverging: [for (var c = 0; c < dates.length; c++) divergesDays([for (final f in r.forecasts) f.data == null ? null : at(f.data!, c)])],
      cell: (f, c) {
        final d = at(f, c);
        return d == null
            ? const Center(child: Text('—'))
            : _cell(d.sky, '${tempText(d.maxC, fahrenheit)}/${tempText(d.minC, fahrenheit)}', _rain(d.pop, null));
      },
    );
  }
}

String _wrapLabel(String s) => s.length > 12 ? s.replaceFirst('(', '\n(') : s;
