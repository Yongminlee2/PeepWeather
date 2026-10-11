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

/// 위성 구름 지도: 위쪽 칩으로 출처를 바꾸고, 정지위성은 최근 2시간을 재생한다.
class SatelliteScreen extends StatefulWidget {
  const SatelliteScreen({super.key, required this.place, required this.fetcher, this.offset, this.now});
  final Place place;
  final Duration? offset; // 장소 시간대(없으면 폰 시간대)
  final Fetcher fetcher;
  final DateTime? now;

  @override
  State<SatelliteScreen> createState() => _SatelliteScreenState();
}

class _SatelliteScreenState extends State<SatelliteScreen> {
  late final List<SatLayer> _layers = satLayersFor(widget.place);
  late SatLayer _sel = _layers.first;
  late final List<DateTime> _frames = satFrames((widget.now ?? DateTime.now()).toUtc());
  int? _frame; // null = 가장 최근(default)
  Timer? _timer;
  Future<Uri>? _kma;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggle() {
    if (_timer != null) {
      _timer!.cancel();
      setState(() => _timer = null);
    } else {
      _frame = 0;
      _timer = Timer.periodic(const Duration(milliseconds: 600), (_) => setState(() => _frame = (_frame! + 1) % _frames.length));
      setState(() {});
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
    final h = (widget.now ?? DateTime.now()).toUtc().add(Duration(minutes: (widget.place.lon * 4).round())).hour;
    return h < 6 || h >= 18;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final owm = _sel.kind == SatKind.owmClouds || _sel.kind == SatKind.owmPrecip;
    final credit = _sel.kind == SatKind.kma
        ? '기상청 천리안 2A호 (공공데이터포털)'
        : owm
            ? attributions['owm']!.$1
            : attributions['gibs']!.$1;
    return Scaffold(
      appBar: AppBar(title: Text(l.satellite)),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            for (final layer in _layers)
              ChoiceChip(
                label: Text(_label(l, layer.kind)),
                selected: layer == _sel,
                onSelected: (_) => setState(() {
                  _timer?.cancel();
                  _timer = null;
                  _frame = null;
                  _sel = layer;
                  if (layer.kind == SatKind.kma) _kma ??= kmaSatImage(widget.fetcher);
                }),
              ),
          ]),
        ),
        Expanded(child: _body(l, owm)),
        if (_sel.animated)
          Row(children: [
            IconButton(
                tooltip: _timer == null ? l.play : l.pause,
                icon: Icon(_timer == null ? Icons.play_arrow : Icons.pause),
                onPressed: _toggle),
            Expanded(
              child: Text(_frame == null
                  ? ''
                  : localTime(_frames[_frame!], widget.offset ?? DateTime.now().timeZoneOffset, Localizations.localeOf(context).toString(),
                      'M/d HH:mm')),
            ),
          ]),
        Padding(padding: const EdgeInsets.all(8), child: Text(credit, style: const TextStyle(fontSize: 11))),
      ]),
    );
  }

  Widget _body(AppLocalizations l, bool owm) {
    if (_sel.kind == SatKind.kma) {
      return FutureBuilder<Uri>(
        future: _kma,
        builder: (context, snap) => snap.hasData
            ? InteractiveViewer(maxScale: 6, child: Center(child: Image.network(snap.data.toString(),
                    errorBuilder: (_, _, _) => Text(l.failParse))))
            : snap.hasError
                ? Center(child: Text(snap.error is FetchError ? failText(l, (snap.error as FetchError).fail) : l.failParse))
                : const Center(child: CircularProgressIndicator()),
      );
    }
    if (owm && Keys.owm.isEmpty) return Center(child: Text(l.failNoKey));
    final url = _sel.urlAt(_frame == null ? null : _frames[_frame!]);
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
          TileLayer(
              key: ValueKey(url),
              urlTemplate: url,
              maxNativeZoom: _sel.maxZoom,
              userAgentPackageName: 'com.peep.weather',
              tileDisplay: const TileDisplay.instantaneous()),
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
          top: 8,
          left: 8,
          right: 8,
          child: Card(child: Padding(padding: const EdgeInsets.all(8), child: Text(l.satNight, textAlign: TextAlign.center))),
        ),
    ]);
  }
}
