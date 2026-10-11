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
List<SatLayer> satLayersFor(Place p) {
  final sat = p.lon < -105
      ? 'GOES-West'
      : p.lon < -30
          ? 'GOES-East'
          : p.lon >= 60
              ? 'Himawari'
              : null;
  return [
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
    _gibsLayer(SatKind.trueColor, 'VIIRS_SNPP_CorrectedReflectance_TrueColor', 9, ext: 'jpg'),
    SatLayer(SatKind.owmClouds, owmTileUrl('clouds_new')),
    SatLayer(SatKind.owmPrecip, owmTileUrl('precipitation_new')),
    if (p.country == 'KR') const SatLayer(SatKind.kma, ''),
  ];
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

Future<List<(DateTime, Uri)>> kmaSatFrames(Fetcher f) async {
  requireKey(Keys.dataGoKr);
  final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
  final r = await f.get(
      Uri.https('apis.data.go.kr', '/1360000/SatlitImgInfoService/getInsightSatlit', {
        'serviceKey': Keys.dataGoKr,
        'pageNo': '1',
        'numOfRows': '10',
        'dataType': 'JSON',
        'sat': 'G2',
        'data': 'ir105',
        'area': 'ko',
        'time': ymd(kst),
      }),
      maxAge: const Duration(minutes: 10),
      check: checkDataGoKr);
  final frames = parseKmaSatFrames(r.body);
  if (frames.isEmpty) throw const FormatException('no image');
  return frames;
}
