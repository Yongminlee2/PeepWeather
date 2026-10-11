// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => '날씨 비교';

  @override
  String get currentLocation => '현재 위치';

  @override
  String asOf(Object time) {
    return '$time 기준';
  }

  @override
  String get nowTitle => '지금 날씨';

  @override
  String get hourlyTitle => '시간별 비교';

  @override
  String get dailyTitle => '날짜별 비교';

  @override
  String get diverge => '예보가 엇갈려요';

  @override
  String get airTitle => '미세먼지 비교';

  @override
  String get pm10 => '미세먼지';

  @override
  String get pm25 => '초미세먼지';

  @override
  String get gradeGood => '좋음';

  @override
  String get gradeNormal => '보통';

  @override
  String get gradeBad => '나쁨';

  @override
  String get gradeVeryBad => '매우나쁨';

  @override
  String get stormTitle => '태풍';

  @override
  String get noStorm => '근처 태풍 없음 (1,000km 안)';

  @override
  String stormKm(Object km) {
    return '${km}km';
  }

  @override
  String windKt(Object kt) {
    return '최대풍속 ${kt}kt';
  }

  @override
  String get satellite => '위성 구름 지도';

  @override
  String get attribution => '자료 제공';

  @override
  String get failNoKey => '설정 필요';

  @override
  String get failBadKey => '키 오류';

  @override
  String get failQuota => '오늘 한도 초과';

  @override
  String get failNetwork => '인터넷 연결 확인';

  @override
  String get failParse => '못 가져옴';

  @override
  String get search => '도시 검색';

  @override
  String get settings => '설정';

  @override
  String get locationNeeded => '위치를 알 수 없어요. 도시를 검색해서 추가하세요.';

  @override
  String get openLocationSettings => '위치 권한 설정 열기';

  @override
  String get searchHint => '도시 이름';

  @override
  String get noResults => '검색 결과가 없어요';

  @override
  String added(Object name) {
    return '$name 추가됨';
  }

  @override
  String get fahrenheit => '화씨(°F)로 보기';

  @override
  String get alerts => '알림';

  @override
  String get alertRain => '비 소식 (12시간 안 60% 이상)';

  @override
  String get alertAir => '미세먼지 나쁨 이상';

  @override
  String get alertStorm => '태풍 접근 (500km 안)';

  @override
  String get savedPlaces => '저장한 도시';

  @override
  String get privacy => '개인정보처리방침';

  @override
  String get delete => '삭제';

  @override
  String get retry => '다시 시도';

  @override
  String get loading => '불러오는 중';

  @override
  String get srcMet => '노르웨이 기상청';

  @override
  String get srcOwm => 'OpenWeather';

  @override
  String get srcWeatherapi => 'WeatherAPI';

  @override
  String get srcVc => 'Visual Crossing';

  @override
  String get srcNws => '미국 기상청';

  @override
  String get srcKma => '기상청';

  @override
  String get srcAirkorea => '에어코리아';

  @override
  String get srcOpenaq => 'OpenAQ';

  @override
  String get srcGdacs => 'GDACS(UN·EU)';

  @override
  String get srcNhc => '미국 허리케인센터';

  @override
  String get srcJtwc => '미국 합동태풍경보센터';

  @override
  String get srcKmaTyphoon => '기상청 태풍';

  @override
  String get satInfrared => '적외선';

  @override
  String get satVisible => '가시광';

  @override
  String get satTrueColor => '실사(하루)';

  @override
  String get satClouds => '구름(모델)';

  @override
  String get satPrecip => '강수(모델)';

  @override
  String get satKma => '천리안 2A';

  @override
  String get satNight => '밤에는 적외선을 보세요';

  @override
  String get play => '재생';

  @override
  String get pause => '멈춤';

  @override
  String rainSoon(Object place) {
    return '$place에 비 소식';
  }

  @override
  String rainSoonBody(Object pop, Object source, Object time) {
    return '$source: $time 비 확률 $pop%';
  }

  @override
  String airBad(Object grade, Object place) {
    return '$place 미세먼지 $grade';
  }

  @override
  String airBadBody(Object source) {
    return '$source 기준';
  }

  @override
  String stormNear(Object name) {
    return '태풍 $name 접근';
  }

  @override
  String stormNearBody(Object km, Object place) {
    return '$place에서 ${km}km';
  }

  @override
  String get moreGames => '개발자의 다른 게임';

  @override
  String get moreLoading => '불러오는 중…';

  @override
  String get moreOffline => '인터넷에 연결하면 볼 수 있어요';

  @override
  String get moreEmpty => '아직 목록이 없어요';

  @override
  String get moreNow => '지금 앱';

  @override
  String get moreGet => '받기';

  @override
  String get alertsChannel => '날씨 알림';
}
