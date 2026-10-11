import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../compare.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../repository.dart';
import 'detail_tables.dart';
import 'format.dart';
import 'theme.dart';

/// 장소 하나의 비교 화면. 한 가지를 보여준다: 기관들이 얼마나 맞는가.
/// 지금(가운데 값과 범위) → 24시간 퍼짐 띠 → 5일 범위 막대 → 미세먼지 눈금 → 태풍 → 위성 → 표 전부 → 출처.
class ReportView extends StatelessWidget {
  const ReportView({super.key, required this.report, required this.fahrenheit, this.now, this.onSatellite});
  final Report report;
  final bool fahrenheit;
  final DateTime? now;
  final VoidCallback? onSatellite;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    final r = report;
    final nowUtc = (now ?? DateTime.now()).toUtc();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _Hero(r, fahrenheit, nowUtc),
        _Section(l.next24, [_Hours(r, fahrenheit, nowUtc)]),
        _Section(l.dailyTitle, [_Days(r, fahrenheit, nowUtc)]),
        _Section(l.airTitle, [_Air(r)]),
        _Section(l.stormTitle, [_Storms(r)]),
        if (onSatellite != null)
          Padding(
            padding: const EdgeInsets.only(top: 20),
            child: OutlinedButton.icon(
              onPressed: onSatellite,
              icon: const Icon(Icons.satellite_alt),
              label: Text(l.satellite),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52), foregroundColor: w.ink, side: BorderSide(color: w.line)),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(l.detailTable, style: TextStyle(color: w.ink, fontWeight: FontWeight.w600)),
              children: [DetailTables(report: r, fahrenheit: fahrenheit, nowUtc: nowUtc)],
            ),
          ),
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
                    child: Text(text, style: TextStyle(fontSize: 12, color: w.muted, decoration: TextDecoration.underline))),
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
        padding: const EdgeInsets.only(top: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: wx(context).ink)),
          const SizedBox(height: 10),
          ...children,
        ]),
      );
}

/// 맨 위: 지명, 기준 시각, 모든 기관 "지금 기온"의 가운데 값(크게)과 범위, 기관별 점.
class _Hero extends StatelessWidget {
  const _Hero(this.r, this.fahrenheit, this.nowUtc);
  final Report r;
  final bool fahrenheit;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    final loc = Localizations.localeOf(context).toString();
    final nows = [
      for (final f in r.forecasts)
        if (f.data?.now case final h?) (f.source, h)
    ];
    final temps = [for (final n in nows) n.$2.tempC];
    final latest = [...r.forecasts, ...r.air].map((x) => x.asOf).whereType<DateTime>().fold<DateTime?>(
        null, (a, b) => a == null || b.isAfter(a) ? b : a);
    // 같은 출처가 예보·미세먼지 둘 다 못 받았으면 한 번만
    final failed = {
      for (final x in [...r.forecasts, ...r.air])
        if (x.fail != null) x.source: x.fail!,
    };
    final mid = temps.isEmpty ? null : median(temps);
    final sky = nows.isEmpty ? null : majoritySky([for (final n in nows) n.$2.sky]);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(color: w.surface, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(r.place.name, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: w.ink)),
        if (latest != null)
          Text(l.asOf(localTime(latest, r.offset, loc, 'M/d HH:mm')), style: TextStyle(fontSize: 13, color: w.muted)),
        const SizedBox(height: 10),
        if (mid != null) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.bottomLeft,
                child: Text(tempText(mid, fahrenheit),
                    style: TextStyle(fontSize: 76, height: 1, color: w.ink, fontFeatures: tabular, letterSpacing: -2)),
              ),
            ),
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (sky != null) Icon(skyIcon(sky), color: skyColor(sky), size: 28),
                Text(l.middleValue, style: TextStyle(fontSize: 13, color: w.muted)),
              ]),
            ),
          ]),
          const SizedBox(height: 8),
          Text(
              l.nowRange(temps.length,
                  '${tempText(temps.reduce(math.min), fahrenheit)} ~ ${tempText(temps.reduce(math.max), fahrenheit)}'),
              style: TextStyle(fontSize: 15, color: w.ink)),
          const SizedBox(height: 10),
          SizedBox(height: 22, child: CustomPaint(size: Size.infinite, painter: _DotStrip(temps, mid, w))),
        ],
        if (failed.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Text(l.notAvailable, style: TextStyle(fontSize: 12, color: w.muted)),
            for (final MapEntry(key: id, value: fail) in failed.entries)
              Text.rich(TextSpan(children: [
                TextSpan(text: '${sourceLabel(l, id)} ', style: TextStyle(fontSize: 12, color: w.ink)),
                TextSpan(text: failText(l, fail), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error)),
              ])),
          ]),
        ],
      ]),
    );
  }
}

/// 기관별 지금 기온을 한 줄 눈금 위의 점으로. 가운데 값은 진한 세로 막대.
class _DotStrip extends CustomPainter {
  _DotStrip(this.values, this.mid, this.w);
  final List<double> values;
  final double mid;
  final Wx w;
  @override
  void paint(Canvas c, Size s) {
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final span = math.max(hi - lo, 1.0);
    double x(double v) => 6 + (v - lo) / span * (s.width - 12);
    final y = s.height / 2;
    c.drawLine(Offset(6, y), Offset(s.width - 6, y), Paint()
      ..color = w.line
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    for (final v in values) {
      c.drawCircle(Offset(x(v), y), 5, Paint()..color = w.band);
    }
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x(mid), y), width: 4, height: s.height), const Radius.circular(2)),
        Paint()..color = w.ink);
  }

  @override
  bool shouldRepaint(_DotStrip o) => o.values != values || o.w != w;
}

void _sheet(BuildContext context, String title, List<Widget> rows) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(c).height * 0.7),
          child: ListView(shrinkWrap: true, padding: const EdgeInsets.fromLTRB(20, 0, 20, 16), children: [
            Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: wx(c).ink)),
            const SizedBox(height: 8),
            ...rows,
          ]),
        ),
      ),
    );

Widget _sourceRow(BuildContext context, String id, Sky sky, String main, String? sub) {
  final w = wx(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Expanded(child: Text(sourceLabel(AppLocalizations.of(context), id), style: TextStyle(color: w.ink))),
      Icon(skyIcon(sky), size: 20, color: skyColor(sky)),
      SizedBox(
          width: 92,
          child: Text(main, textAlign: TextAlign.end, style: TextStyle(color: w.ink, fontFeatures: tabular, fontSize: 15))),
      SizedBox(
          width: 56,
          child: Text(sub ?? '', textAlign: TextAlign.end, style: TextStyle(color: w.rain, fontFeatures: tabular, fontSize: 13))),
    ]),
  );
}

/// 앞으로 24시간(3시간 간격): 기관별 범위 띠 + 가운데 값 선, 아래에 "비 예보한 기관 수".
/// 기관끼리 엇갈린 칸은 호박색 배경.
class _Hours extends StatelessWidget {
  const _Hours(this.r, this.fahrenheit, this.nowUtc);
  final Report r;
  final bool fahrenheit;
  final DateTime nowUtc;

  double _t(double c) => fahrenheit ? c * 9 / 5 + 32 : c;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    final loc = Localizations.localeOf(context).toString();
    final slots = slotTimes(nowUtc, r.offset);
    final sp = [for (final t in slots) hourSpread(r.forecasts, t)];
    if (sp.every((s) => s == null)) return Text('—', style: TextStyle(color: w.muted));
    final idx = [for (var i = 0; i < sp.length; i++) if (sp[i] != null) i];
    final lo = idx.map((i) => _t(sp[i]!.min)).reduce(math.min), hi = idx.map((i) => _t(sp[i]!.max)).reduce(math.max);
    List<FlSpot> line(double Function(HourSpread) f) => [for (final i in idx) FlSpot(i.toDouble(), _t(f(sp[i]!)))];
    final diverging = [for (final i in idx) if (sp[i]!.diverges) i];

    void open(int i) {
      final s = sp[i];
      if (s == null) return;
      _sheet(context, l.sheetAt(localTime(slots[i], r.offset, loc, 'M/d HH:mm')), [
        for (final (id, h) in s.cells)
          _sourceRow(context, id, h.sky, tempText(h.tempC, fahrenheit),
              h.pop != null ? '${h.pop}%' : (h.mm != null && h.mm! > 0 ? '${h.mm!.toStringAsFixed(1)}mm' : null)),
      ]);
    }

    // 짧게: "21시", 첫 칸과 자정 칸만 요일을 붙인다("월 0시")
    String hourLabel(int i) {
      final t = slots[i].add(r.offset);
      final h = loc.startsWith('ko') ? '${t.hour}시' : localTime(slots[i], r.offset, loc, 'ha');
      return i == 0 || t.hour < 3 ? '${localTime(slots[i], r.offset, loc, 'E')} $h' : h;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Wrap(spacing: 14, runSpacing: 4, children: [
        _Legend(color: w.band, label: l.legendRange, square: true),
        _Legend(color: w.ink, label: l.legendMid),
        if (diverging.isNotEmpty) _Legend(color: w.disagree, label: l.diverge, square: true),
      ]),
      const SizedBox(height: 8),
      LayoutBuilder(builder: (context, box) {
        final n = slots.length;
        return GestureDetector(
          onTapUp: (d) => open((d.localPosition.dx / box.maxWidth * n).floor().clamp(0, n - 1)),
          child: SizedBox(
            height: 190,
            child: LineChart(LineChartData(
              minX: -0.5,
              maxX: n - 0.5,
              minY: (lo - 2).floorToDouble(),
              maxY: (hi + 2).ceilToDouble(),
              lineTouchData: const LineTouchData(enabled: false),
              clipData: const FlClipData.all(),
              borderData: FlBorderData(show: false),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: fahrenheit ? 5 : 2,
                getDrawingHorizontalLine: (_) => FlLine(color: w.line, strokeWidth: 1),
              ),
              rangeAnnotations: RangeAnnotations(verticalRangeAnnotations: [
                for (final i in diverging) VerticalRangeAnnotation(x1: i - 0.5, x2: i + 0.5, color: w.disagree.withValues(alpha: 0.16)),
              ]),
              titlesData: FlTitlesData(
                leftTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                topTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.round();
                      if (v != i || i < 0 || i >= n || sp[i] == null) return const SizedBox();
                      return Text(tempText(sp[i]!.median, fahrenheit),
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: w.ink, fontFeatures: tabular));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final i = v.round();
                      if (v != i || i < 0 || i >= n) return const SizedBox();
                      return Text(hourLabel(i), style: TextStyle(fontSize: 11, color: w.muted));
                    },
                  ),
                ),
              ),
              lineBarsData: [
                for (final f in [(HourSpread s) => s.min, (HourSpread s) => s.max])
                  LineChartBarData(
                      spots: line(f),
                      color: Colors.transparent,
                      barWidth: 0,
                      dotData: const FlDotData(show: false)),
                // 곡선이면 가운데 선이 띠 밖으로 삐져나와 보여서 직선으로
                LineChartBarData(
                  spots: line((s) => s.median),
                  color: w.ink,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    getDotPainter: (s, p, b, i) =>
                        FlDotCirclePainter(radius: 3.5, color: w.surface, strokeColor: w.ink, strokeWidth: 2),
                  ),
                ),
              ],
              betweenBarsData: [BetweenBarsData(fromIndex: 0, toIndex: 1, color: w.band.withValues(alpha: 0.6))],
            )),
          ),
        );
      }),
      const SizedBox(height: 6),
      // 비를 예보한 기관 수 — 칸마다 채운 막대
      Row(children: [
        for (var i = 0; i < slots.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => open(i),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                child: Column(children: [
                  Container(
                    height: 26,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(color: w.line.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)),
                    child: FractionallySizedBox(
                      heightFactor: sp[i] == null || sp[i]!.count == 0 ? 0 : sp[i]!.wet / sp[i]!.count,
                      widthFactor: 1,
                      child: DecoratedBox(
                          decoration: BoxDecoration(color: w.rain, borderRadius: BorderRadius.circular(4))),
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      sp[i] == null
                          ? '—'
                          : sp[i]!.wet == 0
                              ? l.noRainVote
                              : l.rainVotes(sp[i]!.count, sp[i]!.wet),
                      maxLines: 1,
                      style: TextStyle(fontSize: 11, color: sp[i] != null && sp[i]!.wet > 0 ? w.rain : w.muted),
                    ),
                  ),
                ]),
              ),
            ),
          ),
      ]),
      const SizedBox(height: 4),
      Text(l.tapHint, style: TextStyle(fontSize: 12, color: w.muted)),
    ]);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.square = false});
  final Color color;
  final String label;
  final bool square;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: square ? 12 : 16,
          height: square ? 12 : 3,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(square ? 3 : 2)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: wx(context).muted)),
      ]);
}

/// 5일: 하루마다 "기관별 최저~최고 전체 범위"(옅은 띠)와 "가운데 최저~가운데 최고"(진한 막대).
class _Days extends StatelessWidget {
  const _Days(this.r, this.fahrenheit, this.nowUtc);
  final Report r;
  final bool fahrenheit;
  final DateTime nowUtc;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    final loc = Localizations.localeOf(context).toString();
    final today = nowUtc.add(r.offset);
    final dates = [for (var i = 0; i < 5; i++) DateTime.utc(today.year, today.month, today.day + i)];
    final ds = [for (final d in dates) daySpread(r.forecasts, d)];
    final have = ds.whereType<DaySpread>();
    if (have.isEmpty) return Text('—', style: TextStyle(color: w.muted));
    final lo = have.map((d) => d.lowMin).reduce(math.min), hi = have.map((d) => d.highMax).reduce(math.max);
    final numStyle = TextStyle(fontSize: 15, color: w.ink, fontFeatures: tabular);
    return Column(children: [
      for (var i = 0; i < dates.length; i++)
        if (ds[i] case final d?)
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _sheet(context, l.sheetAt(localTime(dates[i], Duration.zero, loc, 'M/d E')), [
              for (final (id, day) in d.cells.reversed)
                _sourceRow(context, id, day.sky, '${tempText(day.maxC, fahrenheit)} / ${tempText(day.minC, fahrenheit)}',
                    day.pop == null ? null : '${day.pop}%'),
            ]),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: d.diverges ? w.disagree : Colors.transparent, width: 3),
                  bottom: BorderSide(color: w.line),
                ),
              ),
              child: Row(children: [
                SizedBox(
                  width: 58,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(i == 0 ? l.today : localTime(dates[i], Duration.zero, loc, 'E'),
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: w.ink)),
                    Text(localTime(dates[i], Duration.zero, loc, 'M/d'), style: TextStyle(fontSize: 12, color: w.muted)),
                  ]),
                ),
                Icon(skyIcon(d.sky), size: 24, color: skyColor(d.sky)),
                SizedBox(width: 44, child: Text(tempText(d.medLow, fahrenheit), textAlign: TextAlign.end, style: numStyle)),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                      height: 18, child: CustomPaint(painter: _RangeBar(lo, hi, d.lowMin, d.highMax, d.medLow, d.medHigh, w))),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 44, child: Text(tempText(d.medHigh, fahrenheit), style: numStyle)),
                SizedBox(
                  width: 74,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      d.popMax == null
                          ? ''
                          : l.rainPct(d.popMin == d.popMax ? '${d.popMax}' : '${d.popMin}~${d.popMax}'),
                      style: TextStyle(fontSize: 13, color: d.diverges ? w.disagree : w.rain, fontFeatures: tabular),
                    ),
                  ),
                ),
              ]),
            ),
          ),
    ]);
  }
}

class _RangeBar extends CustomPainter {
  _RangeBar(this.lo, this.hi, this.min, this.max, this.medLow, this.medHigh, this.w);
  final double lo, hi, min, max, medLow, medHigh;
  final Wx w;
  @override
  void paint(Canvas c, Size s) {
    final span = math.max(hi - lo, 1.0);
    double x(double v) => (v - lo) / span * s.width;
    final y = s.height / 2;
    RRect bar(double a, double b, double h) =>
        RRect.fromRectAndRadius(Rect.fromLTRB(x(a), y - h / 2, math.max(x(b), x(a) + h), y + h / 2), Radius.circular(h / 2));
    c.drawRRect(bar(lo, hi, 4), Paint()..color = w.line);
    c.drawRRect(bar(min, max, 10), Paint()..color = w.band.withValues(alpha: 0.7));
    c.drawRRect(bar(medLow, medHigh, 6), Paint()..color = w.ink);
  }

  @override
  bool shouldRepaint(_RangeBar o) => true;
}

/// 미세먼지: 등급 색 띠 위에 기관별 점(채운 점 = 측정소 실측, 빈 점 = 모델 추정), 아래에 기관별 숫자.
class _Air extends StatelessWidget {
  const _Air(this.r);
  final Report r;
  static const _measured = {'airkorea', 'openaq'};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    final ok = [for (final a in r.air) if (a.data != null) a];
    Widget scale(String name, double? Function(Air) v, List<double> cuts, double cap) {
      final pts = [
        for (final a in ok)
          if (v(a.data!) case final x?) (x, _measured.contains(a.source))
      ];
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: TextStyle(fontSize: 13, color: w.muted)),
          const SizedBox(height: 4),
          SizedBox(height: 22, child: CustomPaint(size: Size.infinite, painter: _GradeScale(pts, cuts, cap, w))),
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (ok.isNotEmpty) ...[
        scale(l.pm10, (a) => a.pm10, const [30, 80, 150], 200),
        scale(l.pm25, (a) => a.pm25, const [15, 35, 75], 100),
        Text(l.airHint, style: TextStyle(fontSize: 12, color: w.muted)),
        const SizedBox(height: 8),
      ],
      for (final a in r.air)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sourceLabel(l, a.source), style: TextStyle(color: w.ink)),
                Text(
                  a.fail != null
                      ? failText(l, a.fail!)
                      : [_measured.contains(a.source) ? l.measured : l.modelEstimate, ?a.data!.station].join(' '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: a.fail != null ? Theme.of(context).colorScheme.error : w.muted),
                ),
              ]),
            ),
            if (a.data case final d?) ...[
              Text('${d.pm10?.round() ?? '—'} / ${d.pm25?.round() ?? '—'}',
                  style: TextStyle(fontSize: 15, color: w.ink, fontFeatures: tabular)),
              const SizedBox(width: 8),
              if (worstGrade(d) case final g?)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: gradeColor(g), borderRadius: BorderRadius.circular(10)),
                  child: Text(gradeText(l, g), style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
            ],
          ]),
        ),
    ]);
  }
}

class _GradeScale extends CustomPainter {
  _GradeScale(this.points, this.cuts, this.cap, this.w);
  final List<(double, bool)> points;
  final List<double> cuts;
  final double cap;
  final Wx w;
  @override
  void paint(Canvas c, Size s) {
    double x(double v) => 6 + math.min(v, cap) / cap * (s.width - 12);
    final y = s.height / 2;
    final edges = [0.0, ...cuts, cap];
    for (var i = 0; i < 4; i++) {
      c.drawRect(Rect.fromLTRB(x(edges[i]), y - 3, x(edges[i + 1]), y + 3),
          Paint()..color = gradeColor(Grade.values[i]).withValues(alpha: 0.45));
    }
    for (final (v, measured) in points) {
      final o = Offset(x(v), y);
      c.drawCircle(o, 6.5, Paint()..color = w.surface);
      c.drawCircle(
          o,
          5,
          measured
              ? (Paint()..color = w.ink)
              : (Paint()
                ..color = w.ink
                ..style = PaintingStyle.stroke
                ..strokeWidth = 2));
    }
  }

  @override
  bool shouldRepaint(_GradeScale o) => true;
}

/// 1,000km 안 태풍만, 같은 태풍은 한 덩어리에 기관별로.
class _Storms extends StatelessWidget {
  const _Storms(this.r);
  final Report r;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    final loc = Localizations.localeOf(context).toString();
    double dist((String, Cyclone) m) => distanceKm(r.place.lat, r.place.lon, m.$2.lat, m.$2.lon);
    final groups = groupCyclones(r.cyclones)
        .map((g) => (g, g.map(dist).reduce((a, b) => a < b ? a : b)))
        .where((x) => x.$2 <= 1000)
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    final failed = r.cyclones.where((c) => c.fail != null);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (groups.isEmpty) Text(l.noStorm, style: TextStyle(color: w.muted)),
      for (final (g, km) in groups)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: w.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: w.disagree.withValues(alpha: 0.6)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.cyclone, color: w.disagree),
              const SizedBox(width: 6),
              Expanded(child: Text(g.first.$2.name, style: TextStyle(fontWeight: FontWeight.w600, color: w.ink))),
              Text(l.stormKm(km.round().toString()), style: TextStyle(color: w.ink, fontFeatures: tabular)),
            ]),
            for (final (src, c) in g)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    '${sourceLabel(l, src)}  ${c.lat.abs().toStringAsFixed(1)}°${c.lat >= 0 ? 'N' : 'S'} '
                    '${c.lon.abs().toStringAsFixed(1)}°${c.lon >= 0 ? 'E' : 'W'}'
                    '${c.windKt == null ? '' : '  ${l.windKt(c.windKt!.round().toString())}'}'
                    '  ${localTime(c.time, r.offset, loc, 'M/d HH:mm')}',
                    style: TextStyle(fontSize: 12, color: w.muted, fontFeatures: tabular)),
              ),
          ]),
        ),
      for (final f in failed)
        Text('${sourceLabel(l, f.source)}: ${failText(l, f.fail!)}',
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error)),
    ]);
  }
}
