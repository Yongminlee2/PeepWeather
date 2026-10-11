import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../fetcher.dart';
import '../keys.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../sources/satellite.dart';
import 'format.dart';

/// 위성 구름 지도. 정지위성·천리안은 프레임을 모두 미리 받아 겹쳐 두고 보이는 것만 바꿔서
/// 영상처럼 끊김 없이 돈다. 화면을 열면 저절로 재생되고, 지금 보이는 사진의 시각을 늘 보여준다.
class SatelliteScreen extends StatefulWidget {
  const SatelliteScreen({super.key, required this.place, required this.fetcher, this.offset, this.now});
  final Place place;
  final Fetcher fetcher;
  final Duration? offset; // 장소 시간대(없으면 폰 시간대)
  final DateTime? now;

  @override
  State<SatelliteScreen> createState() => _SatelliteScreenState();
}

class _SatelliteScreenState extends State<SatelliteScreen> {
  late final List<SatLayer> _layers = satLayersFor(widget.place);
  late SatLayer _sel = _layers.first;
  Future<List<(DateTime, Uri)>>? _kma;
  List<(DateTime, Uri)> _kmaFrames = const [];
  int _frame = 0;
  Timer? _timer;

  DateTime get _now => (widget.now ?? DateTime.now()).toUtc();
  Duration get _offset => widget.offset ?? DateTime.now().timeZoneOffset;

  /// 지금 고른 레이어의 프레임 시각들(오래된 것 먼저).
  List<DateTime> get _times => _sel.kind == SatKind.kma
      ? [for (final f in _kmaFrames) f.$1]
      : _sel.animated
          ? satFrames(_now, lag: _sel.lag)
          : const [];

  @override
  void initState() {
    super.initState();
    _select(_sel);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _select(SatLayer layer) {
    _timer?.cancel();
    _timer = null;
    _sel = layer;
    if (layer.kind == SatKind.kma) {
      _kma ??= kmaSatFrames(widget.fetcher).then((fs) {
        if (mounted) {
          setState(() {
            _kmaFrames = fs;
            _frame = fs.length - 1;
          });
          if (_sel.kind == SatKind.kma) _play();
        }
        return fs;
      });
      _frame = _kmaFrames.isEmpty ? 0 : _kmaFrames.length - 1;
      if (_kmaFrames.isNotEmpty) _play();
    } else {
      _frame = _times.isEmpty ? 0 : _times.length - 1; // 처음엔 가장 최근 사진
      if (layer.animated) _play();
    }
  }

  /// 마지막(가장 최근) 장면에서 잠깐 멈췄다가 처음부터 다시.
  void _play() {
    _timer?.cancel();
    var hold = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 450), (_) {
      final n = _times.length;
      if (n == 0) return;
      if (_frame == n - 1 && hold < 3) {
        hold++;
        return;
      }
      hold = 0;
      setState(() => _frame = (_frame + 1) % n);
    });
    if (mounted) setState(() {});
  }

  void _toggle() {
    if (_timer != null) {
      _timer!.cancel();
      setState(() => _timer = null);
    } else {
      _play();
    }
  }

  String _label(AppLocalizations l, SatKind k) => switch (k) {
        SatKind.infrared => l.satInfrared,
        SatKind.visible => l.satVisible,
        SatKind.trueColor => l.satTrueColor,
        SatKind.owmClouds => l.satClouds,
        SatKind.owmPrecip => l.satPrecip,
        SatKind.kma => l.satKma,
      };

  /// 태양시 기준 대략 밤인지(경도/15 시간 보정).
  bool get _night {
    final h = _now.add(Duration(minutes: (widget.place.lon * 4).round())).hour;
    return h < 6 || h >= 18;
  }

  /// 지금 보이는 사진이 무엇인지: 시각, 또는 시각이 없는 종류면 그 설명.
  String _when(AppLocalizations l) {
    final ts = _times;
    if (ts.isNotEmpty) return frameLabel(ts[_frame.clamp(0, ts.length - 1)], _offset);
    return switch (_sel.kind) {
      SatKind.trueColor => l.satDaily,
      SatKind.owmClouds || SatKind.owmPrecip => l.satModel,
      _ => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final owm = _sel.kind == SatKind.owmClouds || _sel.kind == SatKind.owmPrecip;
    final credit = _sel.kind == SatKind.kma
        ? '기상청 천리안 2A호 (공공데이터포털)'
        : owm
            ? attributions['owm']!.$1
            : _sel.credit;
    final ts = _times;
    final when = _when(l);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.satellite)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final layer in _layers)
              ChoiceChip(
                label: Text(_label(l, layer.kind)),
                selected: layer == _sel,
                onSelected: (_) => setState(() => _select(layer)),
              ),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            Positioned.fill(child: _body(l, owm)),
            // 지금 보이는 사진의 시각 — 지도 위에 늘 떠 있다
            if (when.isNotEmpty)
              Positioned(
                left: 12,
                top: 12,
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(when,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15, fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ),
              ),
          ]),
        ),
        if (ts.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              IconButton(
                  tooltip: _timer == null ? l.play : l.pause,
                  icon: Icon(_timer == null ? Icons.play_arrow : Icons.pause),
                  onPressed: _toggle),
              Expanded(
                child: Slider(
                  value: _frame.clamp(0, ts.length - 1).toDouble(),
                  max: (ts.length - 1).toDouble(),
                  divisions: ts.length - 1,
                  onChanged: (v) {
                    _timer?.cancel();
                    setState(() {
                      _timer = null;
                      _frame = v.round();
                    });
                  },
                ),
              ),
            ]),
          ),
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: Text(credit, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))),
      ]),
    );
  }

  Widget _body(AppLocalizations l, bool owm) {
    if (_sel.kind == SatKind.kma) {
      return FutureBuilder<List<(DateTime, Uri)>>(
        future: _kma,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(snap.error is FetchError ? failText(l, (snap.error as FetchError).fail) : l.failParse));
          }
          if (_kmaFrames.isEmpty) return const Center(child: CircularProgressIndicator());
          final w = (MediaQuery.sizeOf(context).width * MediaQuery.devicePixelRatioOf(context)).round();
          return InteractiveViewer(
            maxScale: 6,
            child: Stack(fit: StackFit.expand, children: [
              // 모든 장면을 미리 받아 겹쳐 두고 지금 장면만 보이게(깜빡임 없이 넘어간다)
              for (var i = 0; i < _kmaFrames.length; i++)
                Opacity(
                  opacity: i == _frame ? 1 : 0,
                  child: Image.network(_kmaFrames[i].$2.toString(),
                      cacheWidth: w, gaplessPlayback: true, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox()),
                ),
            ]),
          );
        },
      );
    }
    if (owm && Keys.owm.isEmpty) return Center(child: Text(l.failNoKey));
    final ts = _times;
    final frames = ts.isEmpty ? <DateTime?>[null] : ts;
    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(widget.place.lat, widget.place.lon),
          initialZoom: 4,
          minZoom: 1,
          maxZoom: 10,
          backgroundColor: Colors.black,
        ),
        children: [
          // 모든 프레임의 지도 조각을 미리 받아 겹쳐 두고 지금 장면만 보이게
          for (var i = 0; i < frames.length; i++)
            Opacity(opacity: ts.isEmpty || i == _frame ? 1 : 0, child: _tiles(frames[i])),
          TileLayer(urlTemplate: coastlinesUrl, maxNativeZoom: 9, userAgentPackageName: 'com.peep.weather'),
          MarkerLayer(markers: [
            Marker(
                point: LatLng(widget.place.lat, widget.place.lon),
                child: const Icon(Icons.my_location, color: Colors.redAccent, size: 22)),
          ]),
        ],
      ),
      if (_sel.kind == SatKind.visible && _night)
        Positioned(
          bottom: 8,
          left: 8,
          right: 8,
          child: Card(child: Padding(padding: const EdgeInsets.all(8), child: Text(l.satNight, textAlign: TextAlign.center))),
        ),
    ]);
  }

  Widget _tiles(DateTime? t) {
    final wms = _sel.wmsLayer;
    final url = _sel.urlAt(t);
    return TileLayer(
      key: ValueKey('${_sel.kind}|$wms|$url|$t'),
      urlTemplate: wms == null ? url : null,
      wmsOptions: wms == null
          ? null
          : WMSTileLayerOptions(baseUrl: eumetsatWms, layers: [wms], otherParameters: {
              if (t != null) 'time': '${t.toIso8601String().substring(0, 19)}Z',
            }),
      maxNativeZoom: _sel.maxZoom,
      userAgentPackageName: 'com.peep.weather',
      tileDisplay: const TileDisplay.instantaneous(),
    );
  }
}
