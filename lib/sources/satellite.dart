import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../fetcher.dart';
import '../keys.dart';
import '../models.dart';
import 'common.dart';

enum SatKind { infrared, visible, trueColor, owmClouds, owmPrecip, kma }

const _gibs = 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best';

/// NASA GIBS 해안선 겹침 레이어(Reference_Features 는 이 축척에서 비어 있어서 Coastlines).
const coastlinesUrl = '$_gibs/Coastlines_15m/default/default/GoogleMapsCompatible_Level13/{z}/{y}/{x}.png';

const _gibsCredit = 'Imagery: NASA GIBS / EOSDIS';
const eumetsatWms = 'https://view.eumetsat.int/geoserver/wms?';

class SatLayer {
  final SatKind kind;
  final String tileUrl; // {time} 자리에 시각 또는 default (WMS 면 비움)
  final String? wmsLayer; // EUMETSAT WMS 레이어 이름
  final bool animated;
  final int maxZoom;
  final Duration lag; // 실시간보다 늦게 올라오는 정도(애니메이션 프레임 계산)
  final String credit;
  const SatLayer(this.kind, this.tileUrl,
      {this.wmsLayer,
      this.animated = false,
      this.maxZoom = 9,
      this.lag = const Duration(minutes: 90),
      this.credit = _gibsCredit});

  String urlAt(DateTime? t) => tileUrl.replaceFirst(
      '{time}', t == null ? 'default' : '${t.toUtc().toIso8601String().substring(0, 19)}Z');
}

SatLayer _gibsLayer(SatKind k, String id, int level, {bool animated = false, String ext = 'png'}) =>
    SatLayer(k, '$_gibs/$id/default/{time}/GoogleMapsCompatible_Level$level/{z}/{y}/{x}.$ext',
        animated: animated, maxZoom: level);

/// EUMETSAT Meteosat-3세대(MTG) 0° 원반 — 유럽·아프리카·중동. 시간별 영상은 무료·제한 없음(EUMETSAT 자료 정책 4절).
SatLayer _eumetsat(SatKind k, String layer) => SatLayer(k, '',
    wmsLayer: layer, animated: true, maxZoom: 8, lag: const Duration(minutes: 30), credit: '© EUMETSAT (Meteosat)');

String owmTileUrl(String layer) => 'https://tile.openweathermap.org/map/$layer/{z}/{x}/{y}.png?appid=${Keys.owm}';

/// 장소 경도에 맞는 정지위성을 고른다. 유럽·아프리카(−30°~60°)는 NASA GIBS 에 정지위성이 없어 EUMETSAT Meteosat.
/// 한국은 천리안(기상청이 몇 분 만에 올림)이 가장 최근 사진이라 키가 있으면 맨 앞에 둔다.
List<SatLayer> satLayersFor(Place p, {bool? kmaFirst}) {
  final kma = p.country == 'KR' && (kmaFirst ?? Keys.dataGoKr.isNotEmpty);
  final sat = p.lon < -105
      ? 'GOES-West'
      : p.lon < -30
          ? 'GOES-East'
          : p.lon >= 60
              ? 'Himawari'
              : null;
  return [
    if (kma) const SatLayer(SatKind.kma, ''),
    if (sat == null) ...[
      _eumetsat(SatKind.infrared, 'mtg_fd:ir105_hrfi'),
      _eumetsat(SatKind.visible, 'mtg_fd:rgb_truecolour'),
    ],
    if (sat != null) ...[
      _gibsLayer(SatKind.infrared, sat == 'Himawari' ? 'Himawari_AHI_Band13_Clean_Infrared' : '${sat}_ABI_Band13_Clean_Infrared', 6,
          animated: true),
      _gibsLayer(SatKind.visible, sat == 'Himawari' ? 'Himawari_AHI_Band3_Red_Visible_1km' : '${sat}_ABI_GeoColor', 7,
          animated: true),
    ],
    dailyTrueColor(dailyTrueColorIds.first), // 실제로 볼 위성·날짜는 화면이 latestDaily 로 고른다
    SatLayer(SatKind.owmClouds, owmTileUrl('clouds_new')),
    SatLayer(SatKind.owmPrecip, owmTileUrl('precipitation_new')),
    if (p.country == 'KR' && !kma) const SatLayer(SatKind.kma, ''),
  ];
}

/// 하루 한 장 실사(극궤도 위성) 후보 — 오후에 지나는 위성(더 최근 사진)부터.
/// Suomi NPP(VIIRS_SNPP)는 2026-10 기준 어느 날짜든 새까만 조각만 준다 — 그래서 이 화면이 늘 검었다. 뺐다.
const dailyTrueColorIds = [
  'VIIRS_NOAA20_CorrectedReflectance_TrueColor',
  'VIIRS_NOAA21_CorrectedReflectance_TrueColor',
  'MODIS_Aqua_CorrectedReflectance_TrueColor',
  'MODIS_Terra_CorrectedReflectance_TrueColor',
];

SatLayer dailyTrueColor(String id) => _gibsLayer(SatKind.trueColor, id, 9, ext: 'jpg');

/// 위성 이름(출처 줄에 붙인다).
String dailySatName(SatLayer l) => l.tileUrl.contains('NOAA20')
    ? 'NOAA-20 VIIRS'
    : l.tileUrl.contains('NOAA21')
        ? 'NOAA-21 VIIRS'
        : l.tileUrl.contains('Aqua')
            ? 'Aqua MODIS'
            : 'Terra MODIS';

/// 장소 위 지도 조각 번호(웹 메르카토르).
(int, int) _tileXY(Place p, int z) {
  final n = 1 << z;
  final lat = p.lat * pi / 180;
  return (((p.lon + 180) / 360 * n).floor(), ((1 - log(tan(lat) + 1 / cos(lat)) / pi) / 2 * n).floor());
}

/// 그 장소 위에 실제로 찍힌 가장 최근 하루 사진(위성, 날짜). 장소 날짜로 오늘 → 어제 → 그제.
/// GIBS 는 아직 처리 안 된 곳·꺼진 위성도 200 으로 새까만 조각을 주므로, 장소 위 조각(5단계) 하나를 받아
/// [blackShare](검은 칸 비율, 화면이 그림을 풀어서 잰다)가 작은 것만 고른다. 모두 비었으면 null.
Future<(SatLayer, DateTime)?> latestDaily(http.Client c, Place p, DateTime nowUtc, Duration offset,
    Future<double> Function(Uint8List jpg) blackShare) async {
  const z = 5;
  final (x, y) = _tileXY(p, z);
  final local = nowUtc.add(offset);
  for (var back = 0; back < 3; back++) {
    final day = DateTime.utc(local.year, local.month, local.day).subtract(Duration(days: back));
    final layers = [for (final id in dailyTrueColorIds) dailyTrueColor(id)];
    final ok = await Future.wait([
      for (final l in layers)
        () async {
          try {
            final url = l.urlAt(day).replaceFirst('{z}', '$z').replaceFirst('{y}', '$y').replaceFirst('{x}', '$x');
            final r = await c.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
            return r.statusCode == 200 && await blackShare(r.bodyBytes) < 0.2;
          } catch (_) {
            return false;
          }
        }(),
    ]);
    for (var i = 0; i < layers.length; i++) {
      if (ok[i]) return (layers[i], day);
    }
  }
  return null;
}

/// 애니메이션 프레임 시각(10분 간격, 오래된 것 먼저). 기본 12장 = 2시간 반복
/// (프레임마다 지도 조각을 미리 받아 겹쳐 두므로 작은 폰 메모리를 생각해 12장).
/// GIBS 정지위성은 1시간 남짓 늦게 올라와서 (지금 − 90분)을 가장 최근으로 본다.
// ponytail: 고정 지연 추정, 빈 프레임이 잦으면 GIBS DescribeDomains 로 실제 최신 시각을 조회할 것
List<DateTime> satFrames(DateTime nowUtc, {int count = 12, Duration lag = const Duration(minutes: 90)}) {
  final latest = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, nowUtc.hour, nowUtc.minute ~/ 10 * 10)
      .subtract(lag);
  return [for (var i = count - 1; i >= 0; i--) latest.subtract(Duration(minutes: 10 * i))];
}

/// GIBS 에 실제로 올라온 가장 최근 사진 시각. 지금부터 10분씩 거슬러 가며 그 장소 위 조각
/// (3단계, 한 장)을 달라고 해 보고 처음 있는 시각을 돌려준다. 3시간 안에 없으면 null.
/// 늦게 올라오는 정도가 그때그때 달라서(25분~1시간 반) 고정값으로 빼면 최근 사진을 버리게 된다.
Future<DateTime?> latestPublished(http.Client c, SatLayer l, DateTime nowUtc, Place p) async {
  const z = 3;
  final (x, y) = _tileXY(p, z);
  var t = DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day, nowUtc.hour, nowUtc.minute ~/ 10 * 10);
  for (var i = 0; i < 18; i++, t = t.subtract(const Duration(minutes: 10))) {
    final url = l.urlAt(t).replaceFirst('{z}', '$z').replaceFirst('{y}', '$y').replaceFirst('{x}', '$x');
    try {
      final r = await c.get(Uri.parse(url)).timeout(const Duration(seconds: 8));
      if (r.statusCode == 200) return t;
    } catch (_) {
      return null; // 연결이 안 되면 더 물어봐도 소용없다
    }
  }
  return null;
}

String _two(int v) => v.toString().padLeft(2, '0');

/// 위성 사진 시각 글자(장소 현지 시각, "10/11 19:30"). intl 없이 — 어디서 불러도 된다.
String frameLabel(DateTime utc, Duration offset) {
  final t = utc.add(offset);
  return '${t.month}/${t.day} ${_two(t.hour)}:${_two(t.minute)}';
}

final _kmaStamp = RegExp(r'_(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})\.(?:thn|srv)\.png');

/// 천리안 영상 목록(2분 간격, 하루치) → [step] 간격으로 최근 [count] 장, 오래된 것 먼저, 원본 크기 https.
List<(DateTime, Uri)> parseKmaSatFrames(String body, {int count = 18, Duration step = const Duration(minutes: 10)}) {
  checkDataGoKr(body);
  final all = <(DateTime, Uri)>[];
  for (final m in RegExp(r'https?://[^\s,\]"]+\.png').allMatches(body)) {
    final st = _kmaStamp.firstMatch(m[0]!);
    if (st == null) continue;
    final t = DateTime.utc(int.parse(st[1]!), int.parse(st[2]!), int.parse(st[3]!), int.parse(st[4]!), int.parse(st[5]!));
    all.add((t, Uri.parse(m[0]!.replaceFirst('.thn.png', '.srv.png')).replace(scheme: 'https')));
  }
  all.sort((a, b) => b.$1.compareTo(a.$1)); // 최근 것부터 골라 담고
  final picked = <(DateTime, Uri)>[];
  for (final f in all) {
    if (picked.isEmpty || picked.last.$1.difference(f.$1) >= step) picked.add(f);
    if (picked.length == count) break;
  }
  return picked.reversed.toList();
}

/// 기상청 위성영상 조회서비스 응답에서 가장 최근 그림 주소.
Uri parseKmaSat(String body) {
  checkDataGoKr(body);
  final urls = RegExp(r'https?://[^\s,\]"]+\.png').allMatches(body).map((m) => m[0]!).toList()..sort();
  if (urls.isEmpty) throw const FormatException('no image');
  // 안드로이드 9+ 는 http 를 막는다 — 기상청 이미지 서버는 https 도 받는다
  // 목록은 썸네일(.thn.png)만 주지만 같은 자리에 원본(.srv.png)이 있다
  return Uri.parse(urls.last.replaceFirst('.thn.png', '.srv.png')).replace(scheme: 'https');
}

/// 천리안 사진 목록은 UTC 날짜로 묶여 있다(한국 날짜로 물으면 0~9시엔 비어 있음).
/// UTC 날이 막 바뀌었을 때도 3시간치가 차도록 전날 목록도 함께 받는다.
List<String> kmaListDays(DateTime nowUtc) => [ymd(nowUtc), ymd(nowUtc.subtract(const Duration(days: 1)))];

Future<List<(DateTime, Uri)>> kmaSatFrames(Fetcher f) async {
  requireKey(Keys.dataGoKr);
  final bodies = <String>[];
  Object? err;
  for (final day in kmaListDays(DateTime.now().toUtc())) {
    try {
      final r = await f.get(
          Uri.https('apis.data.go.kr', '/1360000/SatlitImgInfoService/getInsightSatlit', {
            'serviceKey': Keys.dataGoKr,
            'pageNo': '1',
            'numOfRows': '10',
            'dataType': 'JSON',
            'sat': 'G2',
            'data': 'ir105',
            'area': 'ko',
            'time': day,
          }),
          maxAge: const Duration(minutes: 10),
          check: checkDataGoKr);
      bodies.add(r.body);
    } catch (e) {
      err ??= e; // 하루치가 실패해도 다른 날 것으로 보여 준다
    }
  }
  if (bodies.isEmpty) throw err!;
  final frames = parseKmaSatFrames(bodies.join('\n'));
  if (frames.isEmpty) throw const FormatException('no image');
  return frames;
}
