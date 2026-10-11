import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../compare.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../repository.dart';
import 'format.dart';

const _labelW = 104.0, _cellW = 64.0, _rowH = 64.0, _headH = 40.0;

/// 장소 하나의 비교 화면(머리 → 시간별 → 날짜별 → 미세먼지 → 태풍 → 위성 → 출처).
class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.report, required this.fahrenheit, this.now, this.onSatellite});
  final Report report;
  final bool fahrenheit;
  final DateTime? now;
  final VoidCallback? onSatellite;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final r = report;
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final loc = Localizations.localeOf(context).toString();
    final latest = [...r.forecasts, ...r.air].map((x) => x.asOf).whereType<DateTime>().fold<DateTime?>(
        null, (a, b) => a == null || b.isAfter(a) ? b : a);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(r.place.name, style: Theme.of(context).textTheme.headlineSmall),
        if (latest != null)
          Text(l.asOf(localTime(latest, r.offset, loc, 'M/d HH:mm')), style: Theme.of(context).textTheme.bodySmall),
        _Section(l.nowTitle, [for (final f in r.forecasts) _NowRow(f, fahrenheit, nowUtc, r.offset)]),
        _Section(l.hourlyTitle, [_HourTable(r, fahrenheit, slotTimes(nowUtc, r.offset), nowUtc)]),
        _Section(l.dailyTitle, [_DayTable(r, fahrenheit, nowUtc)]),
        _Section(l.airTitle, [for (final a in r.air) _AirRow(a)]),
        _Section(l.stormTitle, [_Storms(r)]),
        if (onSatellite != null)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: FilledButton.icon(onPressed: onSatellite, icon: const Icon(Icons.satellite_alt), label: Text(l.satellite)),
          ),
        _Section(l.attribution, [
          for (final id in {
            for (final x in [...r.forecasts, ...r.air, ...r.cyclones]) attributionKey(x.source),
            'gibs',
          })
            if (attributions[id] case (final text, final url))
              InkWell(
                onTap: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(text, style: const TextStyle(decoration: TextDecoration.underline, fontSize: 12))),
              ),
        ]),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title, this.children);
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...children,
        ]),
      );
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
      Text(sourceLabel(l, result.source), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
      if (sub != null)
        Text(sub,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: result.fail != null ? Theme.of(context).colorScheme.error : null)),
    ]);
  }
}

class _NowRow extends StatelessWidget {
  const _NowRow(this.f, this.fahrenheit, this.nowUtc, this.offset);
  final Result<Forecast> f;
  final bool fahrenheit;
  final DateTime nowUtc;
  final Duration offset;
  @override
  Widget build(BuildContext context) {
    final h = f.data?.now;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44), // 글씨가 크면 줄이 늘어난다
      child: Row(children: [
        Expanded(child: _Label(f, nowUtc, offset)),
        if (h != null) ...[
          Icon(skyIcon(h.sky), color: skyColor(h.sky)),
          const SizedBox(width: 8),
          SizedBox(width: 56, child: Text(tempText(h.tempC, fahrenheit), textAlign: TextAlign.end, style: const TextStyle(fontSize: 18))),
        ],
      ]),
    );
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

Widget _cell(Sky sky, String main, String? sub) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(skyIcon(sky), size: 20, color: skyColor(sky)),
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
        return h == null ? const Center(child: Text('—')) : _cell(h.sky, tempText(h.tempC, fahrenheit), _rain(h.pop, h.mm));
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

class _AirRow extends StatelessWidget {
  const _AirRow(this.a);
  final Result<Air> a;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final d = a.data;
    Widget pm(String name, double? v, Grade Function(double) g) => Expanded(
          child: v == null
              ? Text('$name —', style: const TextStyle(fontSize: 12))
              : Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 4, children: [
                  Text('$name ${v.round()}', style: const TextStyle(fontSize: 12)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(color: gradeColor(g(v)), borderRadius: BorderRadius.circular(8)),
                    child: Text(gradeText(l, g(v)), style: const TextStyle(color: Colors.white, fontSize: 11)),
                  ),
                ]),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(
          width: _labelW,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(sourceLabel(l, a.source), style: const TextStyle(fontSize: 13)),
            if (a.fail != null)
              Text(failText(l, a.fail!), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error))
            else if (d?.station != null)
              Text(d!.station!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
          ]),
        ),
        if (d != null) ...[pm(l.pm10, d.pm10, pm10Grade), pm(l.pm25, d.pm25, pm25Grade)],
      ]),
    );
  }
}

/// 1,000km 안 태풍만, 같은 태풍은 카드 하나에 기관별로.
class _Storms extends StatelessWidget {
  const _Storms(this.r);
  final Report r;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loc = Localizations.localeOf(context).toString();
    double dist((String, Cyclone) m) => distanceKm(r.place.lat, r.place.lon, m.$2.lat, m.$2.lon);
    final groups = groupCyclones(r.cyclones)
        .map((g) => (g, g.map(dist).reduce((a, b) => a < b ? a : b)))
        .where((x) => x.$2 <= 1000)
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    final failed = r.cyclones.where((c) => c.fail != null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (groups.isEmpty) Text(l.noStorm),
      for (final (g, km) in groups)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.cyclone, color: Colors.red),
                const SizedBox(width: 6),
                Expanded(child: Text(g.first.$2.name, style: const TextStyle(fontWeight: FontWeight.bold))),
                Text(l.stormKm(km.round().toString())),
              ]),
              for (final (src, c) in g)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      '${sourceLabel(l, src)} · ${c.lat.abs().toStringAsFixed(1)}°${c.lat >= 0 ? 'N' : 'S'} '
                      '${c.lon.abs().toStringAsFixed(1)}°${c.lon >= 0 ? 'E' : 'W'}'
                      '${c.windKt == null ? '' : ' · ${l.windKt(c.windKt!.round().toString())}'}'
                      ' · ${localTime(c.time, r.offset, loc, 'M/d HH:mm')}',
                      style: const TextStyle(fontSize: 12)),
                ),
            ]),
          ),
        ),
      for (final f in failed)
        Text('${sourceLabel(l, f.source)}: ${failText(l, f.fail!)}',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error)),
    ]);
  }
}
