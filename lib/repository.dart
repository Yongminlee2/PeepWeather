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
      if (isKorea(p)) Source('airkorea', () => airKorea(f, p)),
    ];

List<Source<List<Cyclone>>> cycloneSources(Fetcher f, Place p) => [
      Source('gdacs', () => gdacs(f)),
      Source('nhc', () => nhc(f)),
      Source('jtwc', () => jtwc(f)),
      if (isKorea(p)) Source('kma_typhoon', () => kmaTyphoon(f)),
    ];

Future<Report> loadReport(Fetcher f, Place p, {bool background = false, Duration? deviceOffset}) async {
  final (fc, air, cy) = await (
    Future.wait(forecastSources(f, p, background: background).map(runSource)),
    Future.wait(airSources(f, p, background: background).map(runSource)),
    Future.wait(cycloneSources(f, p).map(runSource)),
  ).wait;
  final offset = fc.map((r) => r.data?.utcOffset).whereType<Duration>().firstOrNull ??
      deviceOffset ??
      DateTime.now().timeZoneOffset;
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
