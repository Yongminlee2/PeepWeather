// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Weather Compare';

  @override
  String get currentLocation => 'Current location';

  @override
  String asOf(Object time) {
    return 'as of $time';
  }

  @override
  String get nowTitle => 'Now';

  @override
  String get hourlyTitle => 'Hourly comparison';

  @override
  String get dailyTitle => 'Daily comparison';

  @override
  String get diverge => 'Forecasts disagree';

  @override
  String get airTitle => 'Air quality comparison';

  @override
  String get pm10 => 'PM10';

  @override
  String get pm25 => 'PM2.5';

  @override
  String get gradeGood => 'Good';

  @override
  String get gradeNormal => 'Moderate';

  @override
  String get gradeBad => 'Bad';

  @override
  String get gradeVeryBad => 'Very bad';

  @override
  String get stormTitle => 'Tropical cyclones';

  @override
  String get noStorm => 'No cyclones within 1,000 km';

  @override
  String stormKm(Object km) {
    return '$km km';
  }

  @override
  String windKt(Object kt) {
    return 'Max wind $kt kt';
  }

  @override
  String get satellite => 'Satellite cloud map';

  @override
  String get attribution => 'Data sources';

  @override
  String get failNoKey => 'Not set up';

  @override
  String get failBadKey => 'Key error';

  @override
  String get failQuota => 'Daily limit reached';

  @override
  String get failNetwork => 'Check connection';

  @override
  String get failParse => 'Unavailable';

  @override
  String get search => 'Search city';

  @override
  String get settings => 'Settings';

  @override
  String get locationNeeded => 'Location unavailable. Search and add a city.';

  @override
  String get openLocationSettings => 'Open location settings';

  @override
  String get searchHint => 'City name';

  @override
  String get noResults => 'No results';

  @override
  String added(Object name) {
    return 'Added $name';
  }

  @override
  String get fahrenheit => 'Show °F';

  @override
  String get alerts => 'Alerts';

  @override
  String get alertRain => 'Rain (60%+ within 12 h)';

  @override
  String get alertAir => 'Air quality bad or worse';

  @override
  String get alertStorm => 'Cyclone within 500 km';

  @override
  String get savedPlaces => 'Saved cities';

  @override
  String get privacy => 'Privacy policy';

  @override
  String get delete => 'Delete';

  @override
  String get retry => 'Retry';

  @override
  String get loading => 'Loading';

  @override
  String get srcMet => 'MET Norway';

  @override
  String get srcOwm => 'OpenWeather';

  @override
  String get srcWeatherapi => 'WeatherAPI';

  @override
  String get srcVc => 'Visual Crossing';

  @override
  String get srcNws => 'US NWS';

  @override
  String get srcKma => 'KMA (Korea)';

  @override
  String get srcAirkorea => 'AirKorea';

  @override
  String get srcOpenaq => 'OpenAQ';

  @override
  String get srcGdacs => 'GDACS (UN·EU)';

  @override
  String get srcNhc => 'US NHC';

  @override
  String get srcJtwc => 'US JTWC';

  @override
  String get srcKmaTyphoon => 'KMA Typhoon';

  @override
  String get satInfrared => 'Infrared';

  @override
  String get satVisible => 'Visible';

  @override
  String get satTrueColor => 'True color (daily)';

  @override
  String get satClouds => 'Clouds (model)';

  @override
  String get satPrecip => 'Precip (model)';

  @override
  String get satKma => 'GK-2A';

  @override
  String get satNight => 'It\'s night — try infrared';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String rainSoon(Object place) {
    return 'Rain coming to $place';
  }

  @override
  String rainSoonBody(Object pop, Object source, Object time) {
    return '$source: $pop% at $time';
  }

  @override
  String airBad(Object grade, Object place) {
    return '$place air quality $grade';
  }

  @override
  String airBadBody(Object source) {
    return 'per $source';
  }

  @override
  String stormNear(Object name) {
    return 'Cyclone $name approaching';
  }

  @override
  String stormNearBody(Object km, Object place) {
    return '$km km from $place';
  }

  @override
  String get moreGames => 'More games by the developer';

  @override
  String get moreLoading => 'Loading…';

  @override
  String get moreOffline => 'Connect to the internet to see the list';

  @override
  String get moreEmpty => 'Nothing here yet';

  @override
  String get moreNow => 'This app';

  @override
  String get moreGet => 'Get';

  @override
  String get alertsChannel => 'Weather alerts';

  @override
  String get failNoStation => 'No station nearby';

  @override
  String get srcOmEcmwf => 'ECMWF (Europe)';

  @override
  String get srcOmGfs => 'GFS (US)';

  @override
  String get srcOmIcon => 'ICON (Germany)';

  @override
  String get srcOmJma => 'JMA (Japan)';

  @override
  String get srcOmKma => 'KMA model (Korea)';

  @override
  String get srcOmGem => 'GEM (Canada)';

  @override
  String get srcOmMeteofrance => 'Météo-France';

  @override
  String get srcOmUkmo => 'UKMO (UK)';

  @override
  String get srcOmCma => 'CMA (China)';

  @override
  String get srcOmBom => 'BOM (Australia)';

  @override
  String get srcOmCams => 'CAMS (Copernicus)';

  @override
  String get satDaily => 'One image a day (today)';

  @override
  String get satModel => 'Map computed by a forecast model';

  @override
  String get satLatest => 'Latest';

  @override
  String nowRange(Object n, Object range) {
    return '$n forecasts range $range';
  }

  @override
  String get middleValue => 'Middle value';

  @override
  String get notAvailable => 'Not available';

  @override
  String get next24 => 'Next 24 hours';

  @override
  String get legendRange => 'Range across sources';

  @override
  String get legendMid => 'Middle value';

  @override
  String rainVotes(Object n, Object wet) {
    return 'Rain $wet/$n';
  }

  @override
  String get noRainVote => 'No rain';

  @override
  String get tapHint => 'Tap a column to see each source';

  @override
  String rainPct(Object v) {
    return 'Rain $v%';
  }

  @override
  String get measured => 'Measured';

  @override
  String get modelEstimate => 'Model';

  @override
  String get detailTable => 'All numbers by source';

  @override
  String sheetAt(Object when) {
    return 'Forecasts for $when';
  }

  @override
  String get today => 'Today';

  @override
  String get airHint =>
      'Filled dots are station measurements, hollow dots are model estimates';

  @override
  String get rainVotesTitle => 'Sources expecting rain';

  @override
  String rainVotesOf(Object n) {
    return 'of $n';
  }

  @override
  String rainCount(Object wet) {
    return '$wet';
  }

  @override
  String get noneShort => 'none';

  @override
  String get popLabel => 'Chance of rain';

  @override
  String get pmUnit => 'µg/m³';

  @override
  String get pmColumns => 'PM10 / PM2.5 (µg/m³)';

  @override
  String get infoTitleNow => 'What is the middle value?';

  @override
  String get infoNow =>
      'Line up every source\'s current temperature from low to high; the middle one is shown. It is steadier than an average when one or two sources are far off.\n\nEach dot is one source. Close dots mean the sources agree; spread-out dots mean they don\'t.';

  @override
  String get infoTitleHours => 'Reading the chart';

  @override
  String get infoHours =>
      'Blue band: the range from the lowest to the highest forecast at that time. A wider band means more disagreement.\n\nDark line and numbers: the middle value of all forecasts.\n\nBlue bars: how many sources expect rain (chance 50% or more, or 0.5 mm or more).\n\nOrange background: forecasts clearly split. The middle half differ by more than 2.5 °C, or rain votes are close to half and half. A single outlier is not marked.';

  @override
  String get infoTitlePop => 'What does the % mean?';

  @override
  String get infoPop =>
      'The chance that rain or snow (usually 0.1–1 mm or more) falls during that hour, or during that day for daily forecasts.\n\n70% means that in similar situations it rained about 7 times out of 10. It is not how much rain falls or how many hours it rains.\n\nA range like 1–72% means sources disagree: the lowest says 1%, the highest 72%. Some sources give only amounts (mm), not a chance.\n\nBars: the light band is all sources\' low to high; the dark bar is the middle low to middle high.';

  @override
  String get infoTitleAir => 'Reading air quality numbers';

  @override
  String get infoAir =>
      'µg/m³ is the weight of particles (millionths of a gram) in one cubic metre of air.\n\nPM10 are particles up to 10 µm, PM2.5 up to 2.5 µm.\n\nGrades (Korean standard)\nPM10: good 0–30, moderate 31–80, bad 81–150, very bad 151+\nPM2.5: good 0–15, moderate 16–35, bad 36–75, very bad 76+\n\nFilled dots are station measurements, hollow dots are model estimates. Measurements are more accurate; models cover places without stations but can be far off.';

  @override
  String get close => 'Close';

  @override
  String get searchIntro =>
      'Type a city name and press search on the keyboard.\nFor example: Busan, Tokyo, Paris';

  @override
  String get noPlaces =>
      'None yet. Add a city with the search button on the main screen, then swipe between them.';
}
