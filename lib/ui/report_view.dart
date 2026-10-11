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
import 'weather_icon.dart';
import '../verdict.dart';
import '../verify.dart';

/// 장소 하나의 비교 화면. 한 가지를 보여준다: 기관들이 얼마나 맞는가.
/// 지금(가운데 값과 범위) → 24시간 퍼짐 띠 → 5일 범위 막대 → 미세먼지 눈금 → 태풍 → 위성 → 표 전부 → 출처.
class ReportView extends StatelessWidget {
  const ReportView(
      {super.key, required this.report, required this.fahrenheit, this.now, this.onSatellite, this.ledger});
  final Report report;
  final bool fahrenheit;
  final DateTime? now;
  final VoidCallback? onSatellite;
  final Ledger? ledger; // 이 동네 정확도 기록(없으면 아직 모으는 중)

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    final r = report;
    final nowUtc = (now ?? DateTime.now()).toUtc();
    final v = verdict(r, ledger, nowUtc);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _Hero(r, fahrenheit, nowUtc, v),
        if (v != null) _Section(l.verdictTitle, [_Verdict(v, r, fahrenheit)], info: (l.infoTitleVerdict, l.infoVerdict)),
        _Section(l.next24, [_Hours(r, fahrenheit, nowUtc)], info: (l.infoTitleHours, l.infoHours)),
        _Section(l.dailyTitle, [_Days(r, fahrenheit, nowUtc)], info: (l.infoTitlePop, l.infoPop)),
        if (ledger case final led? when ranking(led).isNotEmpty)
          _Section(l.accuracyTitle, [_Accuracy(led, isKorea(r.place))], info: (l.infoTitleVerdict, l.infoVerdict)),
        _Section(l.airTitle, [_Air(r)], info: (l.infoTitleAir, l.infoAir)),
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
  const _Section(this.title, this.children, {this.info});
  final String title;
  final List<Widget> children;
  final (String, String)? info; // ⓘ 를 누르면 나오는 설명(제목, 본문)
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 28),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Expanded(child: Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: wx(context).ink))),
            if (info case (final t, final body)) _InfoButton(t, body),
          ]),
          const SizedBox(height: 10),
          ...children,
        ]),
      );
}

/// 설명 단추: 누르면 아래에서 설명이 올라온다.
class _InfoButton extends StatelessWidget {
  const _InfoButton(this.title, this.body, {this.color});
  final String title, body;
  final Color? color;
  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: title,
        visualDensity: VisualDensity.compact,
        icon: Icon(Icons.info_outline, size: 20, color: color ?? wx(context).muted),
        onPressed: () => _sheet(context, title, [
          Text(body, style: TextStyle(fontSize: 15, height: 1.6, color: wx(context).ink)),
        ]),
      );
}

/// 맨 위: 지명, 기준 시각, 모든 기관 "지금 기온"의 가운데 값(크게)과 범위, 기관별 점.
class _Hero extends StatelessWidget {
  const _Hero(this.r, this.fahrenheit, this.nowUtc, this.v);
  final Report r;
  final bool fahrenheit;
  final DateTime nowUtc;
  final Verdict? v; // 있으면 결론과 같은 값(잘 맞춘 곳에 무게)을 크게 보여 준다

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
    final mid = v?.tempNow ?? (temps.isEmpty ? null : median(temps));
    final sky = nows.isEmpty ? Sky.cloudy : majoritySky([for (final n in nows) n.$2.sky]);
    final night = isNightAt(nowUtc, r.offset);
    const fg = Colors.white;
    final soft = Colors.white.withValues(alpha: 0.78);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: heroGradient(sky, night: night)),
        // 어두운 화면에선 밤하늘 카드가 바탕에 묻히지 않게 옅은 테두리
        border: Theme.of(context).brightness == Brightness.dark
            ? Border.all(color: Colors.white.withValues(alpha: 0.12))
            : null,
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.place.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: fg)),
              if (latest != null)
                Text(l.asOf(localTime(latest, r.offset, loc, 'M/d HH:mm')), style: TextStyle(fontSize: 13, color: soft)),
            ]),
          ),
          _InfoButton(l.infoTitleNow, l.infoNow, color: soft),
        ]),
        const SizedBox(height: 6),
        if (mid != null) ...[
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Flexible(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.bottomLeft,
                  child: Text(tempText(mid, fahrenheit),
                      style: const TextStyle(fontSize: 80, height: 1, color: fg, fontFeatures: tabular, letterSpacing: -2)),
                ),
                Text(v?.weighted == true ? l.heroWeighted : l.middleValue, style: TextStyle(fontSize: 13, color: soft)),
              ]),
            ),
            WeatherIcon(sky, night: night, size: 112, animate: true),
          ]),
          const SizedBox(height: 10),
          Text(
              l.nowRange(temps.length,
                  '${tempText(temps.reduce(math.min), fahrenheit)} ~ ${tempText(temps.reduce(math.max), fahrenheit)}'),
              style: const TextStyle(fontSize: 15, color: fg)),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SizedBox(height: 22, child: CustomPaint(size: Size.infinite, painter: _DotStrip(temps, mid))),
          ),
        ],
        // 한눈에: 미세먼지 등급(측정소 우선). 비는 바로 아래 결론 카드에 있다
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          if (airHeadline(r.air) case (final g, final measured))
            _Pill(
              dot: gradeColor(g),
              text: '${l.heroAir(gradeText(l, g))} (${measured ? l.tagMeasured : l.tagModel})',
            ),
        ]),
        if (failed.isNotEmpty) ...[
          const SizedBox(height: 10),
          // 받지 못한 곳은 한 줄로 접고, 누르면 이유를 보여 준다
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => _sheet(context, l.notAvailable, [
              for (final MapEntry(key: id, value: fail) in failed.entries)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    Expanded(child: Text(sourceLabel(l, id), style: TextStyle(color: wx(context).ink))),
                    Text(failText(l, fail), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ]),
                ),
            ]),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(l.notAvailableCount(failed.length), style: TextStyle(fontSize: 13, color: soft)),
                Icon(Icons.chevron_right, size: 18, color: soft),
              ]),
            ),
          ),
        ],
      ]),
    );
  }
}

/// 하늘 카드 위의 작은 알약(반투명 흰 바탕).
class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.dot});
  final String text;
  final Color? dot;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (dot != null)
            Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Flexible(child: Text(text, style: const TextStyle(fontSize: 13, color: Colors.white))),
        ]),
      );
}

/// 기관별 지금 기온을 한 줄 눈금 위의 점으로. 가운데 값은 흰 세로 막대(하늘 배경 위).
class _DotStrip extends CustomPainter {
  _DotStrip(this.values, this.mid);
  final List<double> values;
  final double mid;
  @override
  void paint(Canvas c, Size s) {
    final lo = values.reduce(math.min), hi = values.reduce(math.max);
    final span = math.max(hi - lo, 1.0);
    double x(double v) => 6 + (v - lo) / span * (s.width - 12);
    final y = s.height / 2;
    c.drawLine(Offset(6, y), Offset(s.width - 6, y), Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round);
    for (final v in values) {
      c.drawCircle(Offset(x(v), y), 5, Paint()..color = Colors.white.withValues(alpha: 0.7));
    }
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(x(mid), y), width: 4, height: s.height), const Radius.circular(2)),
        Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_DotStrip o) => o.values != values || o.mid != mid;
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

Widget _sourceRow(BuildContext context, String id, Sky sky, String main, String? sub, {bool night = false}) {
  final w = wx(context);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(children: [
      Expanded(child: Text(sourceLabel(AppLocalizations.of(context), id), style: TextStyle(color: w.ink))),
      WeatherIcon(sky, night: night, size: 30),
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
              h.pop != null ? '${h.pop}%' : (h.mm != null && h.mm! > 0 ? '${h.mm!.toStringAsFixed(1)}mm' : null),
              night: isNightAt(slots[i], r.offset)),
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
      // 칸마다 가장 많은 기관이 고른 하늘
      Row(children: [
        for (var i = 0; i < slots.length; i++)
          Expanded(
            child: Center(
              child: sp[i] == null
                  ? const SizedBox(height: 34)
                  : WeatherIcon(majoritySky([for (final c in sp[i]!.cells) c.$2.sky]),
                      night: isNightAt(slots[i], r.offset), size: 34),
            ),
          ),
      ]),
      LayoutBuilder(builder: (context, box) {
        final n = slots.length;
        // 화면 읽기: 그래프 대신 "21시 21도, 0시 19도 …" 로 읽어 준다
        final spoken = [
          for (var i = 0; i < n; i++)
            if (sp[i] != null) '${hourLabel(i)} ${tempText(sp[i]!.median, fahrenheit)}'
        ].join(', ');
        return Semantics(
          label: '${l.next24}, ${l.middleValue}: $spoken',
          child: GestureDetector(
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
        ),
        );
      }),
      const SizedBox(height: 10),
      // 비를 예보한 기관 수 — 칸마다 채운 막대
      Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.end, children: [
        Text(l.rainVotesTitle, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: w.ink)),
        Text(l.rainVotesOf(sp.whereType<HourSpread>().map((s) => s.count).fold<int>(0, math.max)),
            style: TextStyle(fontSize: 12, color: w.muted)),
      ]),
      const SizedBox(height: 4),
      Row(children: [
        for (var i = 0; i < slots.length; i++)
          Expanded(
            child: InkWell(
              onTap: () => open(i),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 4),
                child: Column(children: [
                  // 바닥선 위로 비 예보 기관 비율만큼 파란 막대가 올라온다
                  SizedBox(
                    height: 26,
                    child: Stack(alignment: Alignment.bottomCenter, children: [
                      Container(height: 2, color: w.line),
                      FractionallySizedBox(
                        heightFactor: sp[i] == null || sp[i]!.count == 0 ? 0 : sp[i]!.wet / sp[i]!.count,
                        widthFactor: 0.55,
                        child: DecoratedBox(
                            decoration: BoxDecoration(
                                color: w.rain, borderRadius: const BorderRadius.vertical(top: Radius.circular(4)))),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      sp[i] == null
                          ? '—'
                          : sp[i]!.wet == 0
                              ? l.noneShort
                              : l.rainCount(sp[i]!.wet),
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
                WeatherIcon(d.sky, size: 42),
                SizedBox(width: 44, child: Text(tempText(d.medLow, fahrenheit), textAlign: TextAlign.end, style: numStyle)),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                      height: 18, child: CustomPaint(painter: _RangeBar(lo, hi, d.lowMin, d.highMax, d.medLow, d.medHigh, w))),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 44, child: Text(tempText(d.medHigh, fahrenheit), style: numStyle)),
                SizedBox(
                  width: 70,
                  child: d.popMax == null
                      ? null
                      : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                          Text(l.popLabel, style: TextStyle(fontSize: 11, color: w.muted)),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(d.popMin == d.popMax ? '${d.popMax}%' : '${d.popMin}~${d.popMax}%',
                                style: TextStyle(
                                    fontSize: 14, color: d.diverges ? w.disagree : w.rain, fontFeatures: tabular)),
                          ),
                        ]),
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
          Text('$name (${l.pmUnit})', style: TextStyle(fontSize: 13, color: w.muted)),
          const SizedBox(height: 4),
          SizedBox(height: 22, child: CustomPaint(size: Size.infinite, painter: _GradeScale(pts, cuts, cap, w))),
        ]),
      );
    }

    final failed = r.air.where((a) => a.fail != null).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (ok.isNotEmpty) ...[
        scale(l.pm10, (a) => a.pm10, const [30, 80, 150], 200),
        scale(l.pm25, (a) => a.pm25, const [15, 35, 75], 100),
        Text(l.airHint, style: TextStyle(fontSize: 12, color: w.muted)),
        const SizedBox(height: 10),
        Align(
            alignment: Alignment.centerRight,
            child: Text(l.pmColumns, style: TextStyle(fontSize: 11, color: w.muted))),
      ],
      for (final a in r.air.where((a) => a.data != null))
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
      if (failed.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${l.notAvailable}: ${[for (final f in failed) '${sourceLabel(l, f.source)} ${failText(l, f.fail!)}'].join(', ')}',
            style: TextStyle(fontSize: 12, color: w.muted),
          ),
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

/// 결론 카드: 문장 몇 줄로 "그래서 어떻다는 건지".
class _Verdict extends StatelessWidget {
  const _Verdict(this.v, this.r, this.fahrenheit);
  final Verdict v;
  final Report r;
  final bool fahrenheit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final w = wx(context);
    final conf = switch (v.tempConfidence) {
      Confidence.high => l.vConfHigh,
      Confidence.medium => l.vConfMedium,
      Confidence.low => l.vConfLow,
    };
    final (wet, n) = v.rainVotes;
    final rows = <(IconData, Color, String, String)>[
      (
        Icons.thermostat,
        v.tempConfidence == Confidence.low ? w.disagree : w.ink,
        conf,
        [
          l.vMidHalf('${tempText(v.midLow, fahrenheit)} ~ ${tempText(v.midHigh, fahrenheit)}'),
          if (v.todayHigh != null) l.vTodayHigh(tempText(v.todayHigh!, fahrenheit)),
        ].join('. '),
      ),
      if (n > 0)
        (
          Icons.umbrella,
          v.rain == RainCall.split ? w.disagree : w.rain,
          switch (v.rain) {
            RainCall.likely => l.vRainLikely,
            RainCall.unlikely => l.vRainUnlikely,
            RainCall.split => l.vRainSplit,
          },
          wet == 0 ? l.vRainNone(n) : l.vRainVotes(n, wet),
        ),
      if (v.tomorrow case final d?)
        (
          Icons.event,
          w.ink,
          () {
            final range = '${tempText(d.medLow, fahrenheit)} ~ ${tempText(d.medHigh, fahrenheit)}';
            final tr = v.tomorrowRain;
            if (tr == null || tr.$2 == 0) return l.vTomorrow(range);
            final ratio = tr.$1 / tr.$2;
            return ratio >= 0.6
                ? l.vTomorrowLikely(range)
                : ratio <= 0.2
                    ? l.vTomorrowDry(range)
                    : l.vTomorrowSplit(range);
          }(),
          v.tomorrowRain == null ? '' : l.vTomorrowRain(v.tomorrowRain!.$1, v.tomorrowRain!.$2),
        ),
      if (v.best case (final id, final sc))
        (Icons.verified, w.rain, l.vBest(sourceLabel(l, id)), l.vBestDetail(sc.mae.toStringAsFixed(1), sc.n))
      else
        (Icons.hourglass_top, w.muted, l.vCollecting, l.vCollectingDetail(v.comparisons)),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(color: w.surface, borderRadius: BorderRadius.circular(18)),
      child: Column(children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) Divider(height: 1, color: w.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(rows[i].$1, color: rows[i].$2, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(rows[i].$3, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: w.ink, fontFeatures: tabular)),
                  if (rows[i].$4.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(rows[i].$4, style: TextStyle(fontSize: 13, height: 1.4, color: w.muted)),
                    ),
                ]),
              ),
            ]),
          ),
        ],
      ]),
    );
  }
}

/// 이 동네 정확도 순위: 평균 오차 막대(짧을수록 잘 맞음)와 비 맞춘 비율.
class _Accuracy extends StatelessWidget {
  const _Accuracy(this.l, this.korea);
  final Ledger l;
  final bool korea;
  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final w = wx(context);
    final rank = ranking(l);
    final worst = rank.map((e) => e.$2.mae).reduce(math.max);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(t.accuracyBasis(korea ? t.obsKma : t.obsOwm), style: TextStyle(fontSize: 12, color: w.muted)),
      const SizedBox(height: 8),
      for (final (i, (id, sc)) in rank.indexed)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            SizedBox(
              width: 22,
              child: Text('${i + 1}', style: TextStyle(fontWeight: FontWeight.w600, color: i == 0 ? w.rain : w.muted)),
            ),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(sourceLabel(t, id), style: TextStyle(color: w.ink)),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, box) => Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 6,
                      width: math.max(6, box.maxWidth * (worst == 0 ? 0 : sc.mae / worst)),
                      decoration: BoxDecoration(
                          color: i == 0 ? w.rain : w.band, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ]),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 96,
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(t.accuracyRow(sc.mae.toStringAsFixed(1)),
                    style: TextStyle(fontSize: 13, color: w.ink, fontFeatures: tabular)),
                Text(t.accuracyRain((sc.rainHitRate * 100).round()),
                    style: TextStyle(fontSize: 11, color: w.muted, fontFeatures: tabular)),
              ]),
            ),
          ]),
        ),
    ]);
  }
}
