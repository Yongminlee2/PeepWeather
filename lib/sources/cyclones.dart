import 'dart:convert';

import '../fetcher.dart';
import '../keys.dart';
import '../models.dart';
import 'common.dart';

/// GDACS: 지금 진행 중인 열대저기압만. severity 는 일생 최대 풍속이라 현재 풍속으로 쓰지 않는다.
List<Cyclone> parseGdacs(String body) => [
      for (final f in (jsonDecode(body)['features'] as List).cast<Map<String, dynamic>>())
        if (f['properties']['iscurrent'] == 'true' && f['properties']['eventtype'] == 'TC')
          Cyclone(f['properties']['eventname'] as String, toD(f['geometry']['coordinates'][1])!,
              toD(f['geometry']['coordinates'][0])!, DateTime.parse('${f['properties']['datemodified']}Z'))
    ];

List<Cyclone> parseNhc(String body) => [
      for (final s in (jsonDecode(body)['activeStorms'] as List).cast<Map<String, dynamic>>())
        Cyclone(s['name'] as String, toD(s['latitudeNumeric'])!, toD(s['longitudeNumeric'])!,
            DateTime.parse(s['lastUpdate'] as String),
            windKt: toD(s['intensity']))
    ];

/// RSS 안의 경보문 주소(…web.txt). abpw·abio 는 해역 요약이라 뺀다.
List<Uri> parseJtwcRss(String body) => [
      for (final m in RegExp(r"https://[^'\x22<\s]+web\.txt").allMatches(body))
        if (!m[0]!.contains('/ab')) Uri.parse(m[0]!)
    ];

double _deg(String v, String hemi) => double.parse(v) * (hemi == 'S' || hemi == 'W' ? -1 : 1);

Cyclone? parseJtwcWarning(String body, DateTime nowUtc) {
  final subj = RegExp(r'SUBJ/[A-Z ]*? (\w+)(?: \((\w[\w-]*)\))? WARNING').firstMatch(body);
  final pos = RegExp(r'(\d{2})(\d{2})(\d{2})Z --- NEAR (\d+\.\d)([NS]) (\d+\.\d)([EW])').firstMatch(body);
  if (subj == null || pos == null) return null;
  final wind = RegExp(r'MAX SUSTAINED WINDS - (\d+) KT').firstMatch(body);
  final day = int.parse(pos[1]!);
  // 경보문엔 일·시·분만 있다. 오늘보다 큰 날이면 지난달.
  final month = day > nowUtc.day ? DateTime.utc(nowUtc.year, nowUtc.month - 1) : nowUtc;
  return Cyclone(subj[2] ?? subj[1]!, _deg(pos[4]!, pos[5]!), _deg(pos[6]!, pos[7]!),
      DateTime.utc(month.year, month.month, day, int.parse(pos[2]!), int.parse(pos[3]!)),
      windKt: wind == null ? null : double.parse(wind[1]!));
}

/// 기상청 태풍정보: 태풍별 가장 최근 위치. 이름은 "한글 영문"으로 합쳐 다른 기관과 이름으로도 묶이게 한다.
List<Cyclone> parseKmaTyphoon(String body) {
  checkDataGoKr(body);
  final items = jsonDecode(body)['response']['body']?['items'];
  if (items is! Map) return const []; // 태풍 없음(NO_DATA)
  final latest = <Object?, Map<String, dynamic>>{};
  for (final it in (items['item'] as List).cast<Map<String, dynamic>>()) {
    final prev = latest[it['typSeq']];
    if (prev == null || '${it['typTm']}'.compareTo('${prev['typTm']}') > 0) latest[it['typSeq']] = it;
  }
  return [
    for (final it in latest.values)
      Cyclone([it['typName'], it['typEn']].whereType<String>().join(' '), toD(it['typLat'])!, toD(it['typLon'])!,
          () {
            final t = '${it['typTm']}';
            return DateTime.utc(int.parse(t.substring(0, 4)), int.parse(t.substring(4, 6)),
                    int.parse(t.substring(6, 8)), int.parse(t.substring(8, 10)), int.parse(t.substring(10, 12)))
                .subtract(const Duration(hours: 9));
          }(),
          windKt: toD(it['typWs']) == null ? null : toD(it['typWs'])! * 1.94384)
  ];
}

Future<Stamped<List<Cyclone>>> gdacs(Fetcher f) async {
  final r = await f.get(Uri.parse('https://www.gdacs.org/gdacsapi/api/events/geteventlist/SEARCH?eventlist=TC'));
  return (parseGdacs(r.body), r.at);
}

Future<Stamped<List<Cyclone>>> nhc(Fetcher f) async {
  final r = await f.get(Uri.parse('https://www.nhc.noaa.gov/CurrentStorms.json'));
  return (parseNhc(r.body), r.at);
}

Future<Stamped<List<Cyclone>>> jtwc(Fetcher f) async {
  final rss = await f.get(Uri.parse('https://www.metoc.navy.mil/jtwc/rss/jtwc.rss'));
  final now = DateTime.now().toUtc();
  final warns = await Future.wait(parseJtwcRss(rss.body).map((u) async {
    try {
      return parseJtwcWarning((await f.get(u)).body, now);
    } on FetchError {
      return null; // 경보문 하나가 실패해도 나머지는 보여준다
    }
  }));
  return (warns.whereType<Cyclone>().toList(), rss.at);
}

Future<Stamped<List<Cyclone>>> kmaTyphoon(Fetcher f) async {
  requireKey(Keys.dataGoKr);
  final kst = DateTime.now().toUtc().add(const Duration(hours: 9));
  final r = await f.get(Uri.https('apis.data.go.kr', '/1360000/TyphoonInfoService/getTyphoonInfo', {
    'serviceKey': Keys.dataGoKr,
    'pageNo': '1',
    'numOfRows': '100',
    'dataType': 'JSON',
    'fromTmFc': ymd(kst.subtract(const Duration(days: 3))),
    'toTmFc': ymd(kst),
  }));
  return (parseKmaTyphoon(r.body), r.at);
}
