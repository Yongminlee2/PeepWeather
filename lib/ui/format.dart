import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../compare.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';

String tempText(double c, bool fahrenheit) => fahrenheit ? '${(c * 9 / 5 + 32).round()}°F' : '${c.round()}°';

String failText(AppLocalizations l, Fail f) => switch (f) {
      Fail.noKey => l.failNoKey,
      Fail.badKey => l.failBadKey,
      Fail.quota => l.failQuota,
      Fail.network => l.failNetwork,
      Fail.parse => l.failParse,
    };

String sourceLabel(AppLocalizations l, String id) => switch (id) {
      'met' => l.srcMet,
      'owm' => l.srcOwm,
      'weatherapi' => l.srcWeatherapi,
      'vc' => l.srcVc,
      'nws' => l.srcNws,
      'kma' => l.srcKma,
      'airkorea' => l.srcAirkorea,
      'openaq' => l.srcOpenaq,
      'gdacs' => l.srcGdacs,
      'nhc' => l.srcNhc,
      'jtwc' => l.srcJtwc,
      'kma_typhoon' => l.srcKmaTyphoon,
      _ => id,
    };

/// 출처별로 요구하는 표기 문구와 주소.
const attributions = <String, (String, String)>{
  'met': ('Data from MET Norway', 'https://api.met.no'),
  'owm': ('Weather data provided by OpenWeather', 'https://openweathermap.org'),
  'weatherapi': ('Powered by WeatherAPI.com', 'https://www.weatherapi.com'),
  'vc': ('Weather data by Visual Crossing', 'https://www.visualcrossing.com'),
  'nws': ('US National Weather Service (NOAA)', 'https://www.weather.gov'),
  'kma': ('기상청 단기예보 (공공데이터포털)', 'https://www.data.go.kr'),
  'airkorea': ('에어코리아 대기오염정보 (한국환경공단)', 'https://www.airkorea.or.kr'),
  'openaq': ('Air quality data from OpenAQ', 'https://openaq.org'),
  'gdacs': ('Global Disaster Alert and Coordination System, GDACS', 'https://www.gdacs.org'),
  'nhc': ('NOAA National Hurricane Center', 'https://www.nhc.noaa.gov'),
  'jtwc': ('Joint Typhoon Warning Center', 'https://www.metoc.navy.mil/jtwc/jtwc.html'),
  'kma_typhoon': ('기상청 태풍정보 (공공데이터포털)', 'https://www.data.go.kr'),
  'gibs': ('Imagery: NASA GIBS / EOSDIS', 'https://earthdata.nasa.gov/gibs'),
};

IconData skyIcon(Sky s) => switch (s) {
      Sky.clear => Icons.wb_sunny,
      Sky.partly => Icons.wb_cloudy_outlined,
      Sky.cloudy => Icons.cloud,
      Sky.fog => Icons.foggy,
      Sky.rain => Icons.water_drop,
      Sky.snow => Icons.ac_unit,
      Sky.thunder => Icons.thunderstorm,
    };

Color skyColor(Sky s) => switch (s) {
      Sky.clear => Colors.orange,
      Sky.partly => Colors.amber.shade700,
      Sky.cloudy || Sky.fog => Colors.blueGrey,
      Sky.rain => Colors.blue,
      Sky.snow => Colors.lightBlue,
      Sky.thunder => Colors.deepPurple,
    };

String gradeText(AppLocalizations l, Grade g) => switch (g) {
      Grade.good => l.gradeGood,
      Grade.normal => l.gradeNormal,
      Grade.bad => l.gradeBad,
      Grade.veryBad => l.gradeVeryBad,
    };

Color gradeColor(Grade g) => switch (g) {
      Grade.good => Colors.blue,
      Grade.normal => Colors.green,
      Grade.bad => Colors.orange,
      Grade.veryBad => Colors.red,
    };

/// 장소 현지 시각 글자(오프셋을 더한 UTC 값을 그대로 포맷).
String localTime(DateTime utc, Duration offset, String locale, String pattern) =>
    DateFormat(pattern, locale).format(utc.add(offset));
