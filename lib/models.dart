/// 하늘 상태. 뒤로 갈수록 "나쁜 날씨"라서 하루 요약은 가장 뒤의 값을 쓴다.
enum Sky { clear, partly, cloudy, fog, rain, snow, thunder }

class Place {
  final String name;
  final String country; // ISO 3166-1 alpha-2, 모르면 ''
  final double lat, lon;
  const Place(this.name, this.country, this.lat, this.lon);

  Map<String, dynamic> toJson() =>
      {'name': name, 'country': country, 'lat': lat, 'lon': lon};
  factory Place.fromJson(Map<String, dynamic> j) => Place(j['name'] as String,
      j['country'] as String, (j['lat'] as num).toDouble(), (j['lon'] as num).toDouble());
}

/// 한 시점 예보. time 은 UTC.
class Hour {
  final DateTime time;
  final double tempC;
  final Sky sky;
  final int? pop; // 강수확률 %
  final double? mm; // 강수량
  const Hour(this.time, this.tempC, this.sky, {this.pop, this.mm});
}

/// 하루 예보. date 는 현지 날짜를 UTC 자정으로 표기한 것.
class Day {
  final DateTime date;
  final double maxC, minC;
  final Sky sky;
  final int? pop;
  final bool partial; // 시간별을 묶었는데 하루 일부만 있음(오늘 저녁만 등) — 엇갈림 판정에서 뺀다
  const Day(this.date, this.maxC, this.minC, this.sky, {this.pop, this.partial = false});
}

class Forecast {
  final Hour? now;
  final List<Hour> hours;
  final List<Day> days;
  final Duration? utcOffset;
  const Forecast({this.now, this.hours = const [], this.days = const [], this.utcOffset});
}

class Air {
  final double? pm10, pm25;
  final String? station;
  final DateTime time;
  const Air({this.pm10, this.pm25, this.station, required this.time});
}

class Cyclone {
  final String name;
  final double lat, lon;
  final double? windKt;
  final DateTime time;
  const Cyclone(this.name, this.lat, this.lon, this.time, {this.windKt});
}

enum Fail { noKey, badKey, quota, network, parse }

/// 출처 하나의 결과: 성공이면 data, 실패면 fail. asOf 는 자료를 받은 시각.
class Result<T> {
  final String source;
  final T? data;
  final Fail? fail;
  final DateTime? asOf;
  const Result(this.source, {this.data, this.fail, this.asOf});
  bool get ok => data != null;
}
