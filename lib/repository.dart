import 'compare.dart';
import 'fetcher.dart';
import 'models.dart';
import 'sources/airkorea.dart';
import 'sources/common.dart';
import 'sources/cyclones.dart';
import 'sources/kma.dart';
import 'sources/met_norway.dart';
import 'sources/nws.dart';
import 'sources/openaq.dart';
import 'sources/openmeteo.dart';
import 'sources/openweather.dart';
import 'sources/visual_crossing.dart';
import 'sources/weatherapi.dart';

class Report {
  final Place place;
  final List<Result<Forecast>> forecasts;
  final List<Result<Air>> air;
  final List<Result<List<Cyclone>>> cyclones;
  final Duration offset; // 장소의 UTC 오프셋
  const Report(this.place, this.forecasts, this.air, this.cyclones, this.offset);
}

class Source<T> {
  final String name;
  final Future<Stamped<T>> Function() run;
  const Source(this.name, this.run);
}

/// 출처 하나를 돌려 결과로 감싼다. 어떤 예외든 그 출처 칸에만 남는다.
Future<Result<T>> runSource<T>(Source<T> s) async {
  try {
    final (data, at) = await s.run();
    return Result(s.name, data: data, asOf: at);
  } on FetchError catch (e) {
    return Result(s.name, fail: e.fail);
  } catch (_) {
    return Result(s.name, fail: Fail.parse);
  }
}

bool isKorea(Place p) => p.country == 'KR';
bool isUs(Place p) => p.country == 'US';

/// background: 알림용 확인이면 무료 한도가 작은 WeatherAPI·Visual Crossing 은 뺀다.
List<Source<Forecast>> forecastSources(Fetcher f, Place p, {bool background = false}) => [
      Source('met', () => metForecast(f, p)),
      Source('owm', () => owmForecast(f, p)),
      if (!background) ...[
        Source('weatherapi', () async {
          final (body, at) = await weatherApiRaw(f, p);
          return (parseWeatherApi(body), at);
        }),
        Source('vc', () => vcForecast(f, p)),
        for (final MapEntry(key: model, value: id) in openMeteoModels.entries)
          Source(id, () async {
            final (body, at) = await openMeteoRaw(f, p); // 모델 10개가 요청 하나를 같이 쓴다
            final fc = parseOpenMeteo(body, model);
            if (fc == null) throw const FetchError(Fail.notCovered);
            return (fc, at);
          }),
      ],
      if (isKorea(p)) Source('kma', () => kmaForecast(f, p)),
      if (isUs(p)) Source('nws', () => nwsForecast(f, p)),
    ];

List<Source<Air>> airSources(Fetcher f, Place p, {bool background = false}) => [
      Source('owm', () => owmAir(f, p)),
      if (!background)
        Source('weatherapi', () async {
          final (body, at) = await weatherApiRaw(f, p); // 예보와 같은 요청 하나를 같이 쓴다
          return (parseWeatherApiAir(body), at);
        }),
      Source('openaq', () => openAq(f, p)),
      Source('om_cams', () => openMeteoAir(f, p)),
      if (isKorea(p)) Source('airkorea', () => airKorea(f, p)),
    ];

List<Source<List<Cyclone>>> cycloneSources(Fetcher f, Place p) => [
      Source('gdacs', () => gdacs(f)),
      Source('nhc', () => nhc(f)),
      Source('jtwc', () => jtwc(f)),
      if (isKorea(p)) Source('kma_typhoon', () => kmaTyphoon(f)),
    ];

/// 시간대를 알려 준 출처가 없을 때: 폰과 가까운 경도면 폰 시간대, 멀면 경도/15 시간.
// ponytail: 경도 추정은 서머타임·국경을 모른다(최대 1~2시간 차이), 정확히 하려면 시간대 경계 자료가 필요
Duration guessOffset(double lon, Duration device) {
  final est = Duration(hours: (lon / 15).round());
  return (est - device).abs() <= const Duration(hours: 1) ? device : est;
}

Future<Report> loadReport(Fetcher f, Place p, {bool background = false, Duration? deviceOffset}) async {
  final (fcAll, air, cy) = await (
    Future.wait(forecastSources(f, p, background: background).map(runSource)),
    Future.wait(airSources(f, p, background: background).map(runSource)),
    Future.wait(cycloneSources(f, p).map(runSource)),
  ).wait;
  final fc = fcAll.where((r) => r.fail != Fail.notCovered).toList();
  final offset = fc.map((r) => r.data?.utcOffset).whereType<Duration>().firstOrNull ??
      guessOffset(p.lon, deviceOffset ?? DateTime.now().timeZoneOffset);
  // 일별을 안 주는 출처(MET·OWM)는 장소 시간대로 시간별을 묶어 채운다.
  final filled = [
    for (final r in fc)
      if (r.data case final d? when d.days.isEmpty && d.hours.isNotEmpty)
        Result(r.source,
            data: Forecast(now: d.now, hours: d.hours, days: daysFromHours(d.hours, offset), utcOffset: d.utcOffset),
            asOf: r.asOf)
      else
        r
  ];
  return Report(p, filled, air, cy, offset);
}
