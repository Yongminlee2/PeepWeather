import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;


import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../fetcher.dart';
import '../keys.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../sources/satellite.dart';
import 'debug_shot.dart';
import 'format.dart';

/// 장면(프레임)마다 화면에 나온 지도 조각이 다 받아졌는지. 다 받은 장면만 재생에 쓴다.
class FrameReadiness {
  final _tiles = <int, Map<Object, bool>>{};

  /// 바뀐 게 있으면 true.
  bool mark(int frame, Object tile, bool loaded) {
    final m = _tiles[frame] ??= {};
    if (m[tile] == loaded) return false;
    m[tile] = loaded;
    return true;
  }

  bool ready(int frame) => _tiles[frame]?.isNotEmpty == true && _tiles[frame]!.values.every((v) => v);

  /// [from] 다음으로 준비된 장면(한 바퀴 돌아도 없으면 그대로).
  int next(int from, int n) {
    for (var k = 1; k <= n; k++) {
      if (ready((from + k) % n)) return (from + k) % n;
    }
    return from;
  }

  /// 지도를 움직이면 보이는 조각이 바뀌니 처음부터 다시 센다(곧바로 다시 채워진다).
  void clear() => _tiles.clear();
}

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
  // 시뮬레이터 화면 확인: SHOT=satellite:N 이면 N번째 레이어로 연다(디버그 빌드만)
  late SatLayer _sel = _layers[(debugShotArg ?? 0).clamp(0, _layers.length - 1)];
  Future<List<(DateTime, Uri)>>? _kma;
  List<(DateTime, Uri)> _kmaFrames = const [];
  int _frame = 0;
  Timer? _timer;
  final _ready = FrameReadiness();
  bool _refresh = false; // 조각 상태가 바뀌어 다음 장면에 다시 그려야 함
  bool _all = false; // 가장 최근 장면을 다 받아서 나머지 장면도 받기 시작했나(지도를 움직여도 유지)
  final _latest = <SatKind, DateTime?>{}; // NASA 에 실제로 올라온 가장 최근 시각(못 알아내면 null → 고정 지연)

  /// NASA 정지위성 레이어: 몇 분 늦게 올라오는지가 그때그때 달라서 실제 최신 시각을 물어본다.
  bool get _askLatest => _sel.animated && _sel.wmsLayer == null && _sel.kind != SatKind.kma;
  bool get _waiting => (_askLatest && !_latest.containsKey(_sel.kind)) || (_sel.kind == SatKind.trueColor && !_dailyDone);

  /// 하루 한 장 실사: 그 장소 위에 실제로 찍힌 위성·날짜(latestDaily). 못 고르면 null 로 두고 예전처럼 default.
  (SatLayer, DateTime)? _daily;
  bool _dailyAsked = false, _dailyDone = false;

  DateTime get _now => (widget.now ?? DateTime.now()).toUtc();
  Duration get _offset => widget.offset ?? DateTime.now().timeZoneOffset;

  /// 지금 고른 레이어의 프레임 시각들(오래된 것 먼저).
  List<DateTime> get _times {
    if (_sel.kind == SatKind.kma) return [for (final f in _kmaFrames) f.$1];
    if (_waiting || !_sel.animated) return const [];
    final t = _latest[_sel.kind];
    return t != null ? satFrames(t, lag: Duration.zero) : satFrames(_now, lag: _sel.lag);
  }

  Timer? _newer;

  @override
  void initState() {
    super.initState();
    _select(_sel);
    // 화면을 열어 둔 동안 새 사진이 올라오면 이어 붙인다
    _newer = Timer.periodic(const Duration(minutes: 5), (_) => _checkNewer());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _newer?.cancel();
    super.dispose();
  }

  /// 새로 올라온 사진이 있나 다시 확인. 있으면 가장 최근 장면으로 옮겨 보여준다.
  Future<void> _checkNewer() async {
    final layer = _sel;
    if (layer.kind == SatKind.kma) {
      final fs = await kmaSatFrames(widget.fetcher.forced(const Duration(minutes: 4))).catchError((_) => _kmaFrames);
      if (!mounted || fs.isEmpty || fs.last.$1 == _kmaFrames.lastOrNull?.$1) return;
      setState(() {
        _kmaFrames = fs;
        if (_sel.kind == SatKind.kma) _frame = fs.length - 1;
      });
    } else if (_askLatest && _latest[layer.kind] != null) {
      final t = await latestPublished(widget.fetcher.client, layer, _now, widget.place);
      if (!mounted || t == null || !t.isAfter(_latest[layer.kind]!)) return;
      setState(() {
        _latest[layer.kind] = t;
        if (_sel.kind == layer.kind) _frame = _times.length - 1;
      });
    }
  }

  void _select(SatLayer layer) {
    _timer?.cancel();
    _timer = null;
    _sel = layer;
    _ready.clear();
    _all = false;
    if (layer.kind == SatKind.trueColor && !_dailyAsked) {
      _dailyAsked = true;
      latestDaily(widget.fetcher.client, widget.place, _now, _offset, jpgBlackShare).then((v) {
        if (mounted) {
          setState(() {
            _daily = v;
            _dailyDone = true;
          });
        }
      });
    }
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
      if (_waiting) {
        final kind = layer.kind;
        latestPublished(widget.fetcher.client, layer, _now, widget.place).then((t) {
          if (!mounted) return;
          setState(() {
            _latest[kind] = t;
            if (_sel.kind == kind) _frame = _times.length - 1;
          });
        });
      }
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
      // 다 받지 못한 장면은 건너뛴다(검은 네모 대신)
      final next = _sel.kind == SatKind.kma ? (_frame + 1) % n : _ready.next(_frame, n);
      if (next != _frame) setState(() => _frame = next);
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
      SatKind.trueColor => _daily == null
          ? l.satDaily
          : l.satDailyOn(localTime(_daily!.$2, Duration.zero, Localizations.localeOf(context).toString(), 'M/d')),
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
            : _sel.kind == SatKind.trueColor && _daily != null
                ? '${_sel.credit} (${dailySatName(_daily!.$1)})'
                : _sel.credit;
    final ts = _times;
    final when = _when(l);
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.satellite)),
      body: SafeArea(
        top: false,
        child: Column(children: [
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
      ),
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
              // 가장 최근 장면을 늘 밑에: 아직 못 받은 장면 자리에 빈 화면 대신 이게 보인다
              for (final i in [_kmaFrames.length - 1, for (var j = 0; j < _kmaFrames.length - 1; j++) j])
                Opacity(
                  opacity: i == _frame || i == _kmaFrames.length - 1 ? 1 : 0,
                  child: Image.network(_kmaFrames[i].$2.toString(),
                      cacheWidth: w, gaplessPlayback: true, fit: BoxFit.contain, errorBuilder: (_, _, _) => const SizedBox()),
                ),
            ]),
          );
        },
      );
    }
    if (owm && Keys.owm.isEmpty) return Center(child: Text(l.failNoKey));
    if (_waiting) {
      return ColoredBox(
          color: const Color(0xFF16202E),
          child: Center(child: Text(l.satLoading, style: const TextStyle(color: Colors.white70))));
    }
    final ts = _times;
    final frames = ts.isEmpty ? <DateTime?>[null] : ts;
    return Stack(children: [
      FlutterMap(
        options: MapOptions(
          initialCenter: LatLng(widget.place.lat, widget.place.lon),
          initialZoom: 4,
          minZoom: 1,
          maxZoom: 10,
          backgroundColor: const Color(0xFF16202E),
          onPositionChanged: (_, _) => _ready.clear(), // 보이는 조각이 바뀐다
        ),
        children: [
          // 가장 최근 장면은 늘 밑에 깔아 둔다: 다른 장면의 조각이 아직 없으면 검은 칸 대신 이게 보인다
          _tiles(frames.last, frames.length - 1),
          // 나머지 장면은 가장 최근 것을 다 받은 뒤에 받는다(한꺼번에 12장을 받으면 다 같이 느려진다).
          // 지금 장면까지를 차례로 겹쳐서, 어느 장면에 빠진 조각(아직 공개 안 된 칸)이 있으면 바로 앞 장면이 보인다
          if (_all || (_all = _ready.ready(frames.length - 1))) ...[
            for (var i = 0; i < frames.length - 1; i++)
              Opacity(opacity: i <= _frame ? 1 : 0, child: _tiles(frames[i], i)),
            Opacity(opacity: _frame == frames.length - 1 ? 1 : 0, child: _tiles(frames.last, frames.length - 1)),
          ],
          // 회색 위성 사진 위에서도 보이게 해안선을 노랗게
          ColorFiltered(
            colorFilter: const ColorFilter.mode(Color(0xFFFFE066), BlendMode.srcIn),
            child: TileLayer(urlTemplate: coastlinesUrl, maxNativeZoom: 9, userAgentPackageName: 'com.peep.weather'),
          ),
          MarkerLayer(markers: [
            Marker(
                point: LatLng(widget.place.lat, widget.place.lon),
                child: const Icon(Icons.my_location, color: Colors.redAccent, size: 22)),
          ]),
        ],
      ),
      if (!_ready.ready(frames.length - 1))
        Positioned(
          top: 12,
          right: 12,
          child: DecoratedBox(
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(8)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                const SizedBox(width: 8),
                Text(l.satLoading, style: const TextStyle(color: Colors.white, fontSize: 13)),
              ]),
            ),
          ),
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

  Widget _tiles(DateTime? t, int frame) {
    final wms = _sel.wmsLayer;
    final daily = _sel.kind == SatKind.trueColor ? _daily : null;
    final url = daily != null ? daily.$1.urlAt(daily.$2) : _sel.urlAt(t);
    return TileLayer(
      tileBuilder: (context, child, tile) {
        // 오류 난 조각도 끝난 것으로 본다(영영 기다리지 않게)
        if (_ready.mark(frame, tile.coordinates, tile.loadFinishedAt != null) && !_refresh) {
          _refresh = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _refresh = false;
            if (mounted) setState(() {});
          });
        }
        return child;
      },
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

/// 받은 위성 조각(JPEG)에서 새까만 칸 비율. GIBS 는 아직 찍지 않은 곳을 검은색으로 채워 준다
/// (바다 사진은 짙은 남색이라 완전한 검정과 다르다).
Future<double> jpgBlackShare(Uint8List jpg) async {
  final codec = await ui.instantiateImageCodec(jpg, targetWidth: 64);
  final img = (await codec.getNextFrame()).image;
  final px = (await img.toByteData())!;
  img.dispose();
  final n = px.lengthInBytes ~/ 4;
  var black = 0;
  for (var i = 0; i < n; i++) {
    if (px.getUint8(i * 4) + px.getUint8(i * 4 + 1) + px.getUint8(i * 4 + 2) < 9) black++;
  }
  return n == 0 ? 1 : black / n;
}
