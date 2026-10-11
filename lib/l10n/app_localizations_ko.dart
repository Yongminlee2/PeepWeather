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
  String get locationNeeded => '지금 위치를 알 수 없어요. 아래에서 도시를 고르거나 검색해 주세요.';

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

  @override
  String get failNoStation => '근처 측정소 없음';

  @override
  String get srcOmEcmwf => 'ECMWF(유럽)';

  @override
  String get srcOmGfs => 'GFS(미국)';

  @override
  String get srcOmIcon => 'ICON(독일)';

  @override
  String get srcOmJma => 'JMA(일본)';

  @override
  String get srcOmKma => 'KMA 모델(한국)';

  @override
  String get srcOmGem => 'GEM(캐나다)';

  @override
  String get srcOmMeteofrance => 'Météo-France(프랑스)';

  @override
  String get srcOmUkmo => 'UKMO(영국)';

  @override
  String get srcOmCma => 'CMA(중국)';

  @override
  String get srcOmBom => 'BOM(호주)';

  @override
  String get srcOmCams => 'CAMS(유럽 코페르니쿠스)';

  @override
  String get satDaily => '하루 한 장 촬영(오늘 낮)';

  @override
  String get satModel => '예측 모델이 계산한 지도';

  @override
  String get satLatest => '가장 최근';

  @override
  String nowRange(Object n, Object range) {
    return '$n곳 예보 범위 $range';
  }

  @override
  String get middleValue => '가운데 값';

  @override
  String get notAvailable => '받지 못한 곳';

  @override
  String get next24 => '앞으로 24시간';

  @override
  String get legendRange => '기관별 범위';

  @override
  String get legendMid => '가운데 값';

  @override
  String rainVotes(Object n, Object wet) {
    return '비 $wet/$n';
  }

  @override
  String get noRainVote => '비 없음';

  @override
  String get tapHint => '칸을 누르면 기관별 값을 볼 수 있어요';

  @override
  String rainPct(Object v) {
    return '비 $v%';
  }

  @override
  String get measured => '실측';

  @override
  String get modelEstimate => '모델 추정';

  @override
  String get detailTable => '기관별 숫자 전부 보기';

  @override
  String sheetAt(Object when) {
    return '$when 기관별 예보';
  }

  @override
  String get today => '오늘';

  @override
  String get airHint => '채운 점은 측정소에서 잰 값, 빈 점은 모델이 계산한 값';

  @override
  String get rainVotesTitle => '비 온다고 한 기관';

  @override
  String rainVotesOf(Object n) {
    return '전체 $n곳 중';
  }

  @override
  String rainCount(Object wet) {
    return '$wet곳';
  }

  @override
  String get noneShort => '없음';

  @override
  String get popLabel => '강수확률';

  @override
  String get pmUnit => '㎍/㎥';

  @override
  String get pmColumns => '미세먼지 / 초미세먼지 (㎍/㎥)';

  @override
  String get infoTitleNow => '가운데 값이란?';

  @override
  String get infoNow =>
      '여러 기관의 지금 기온을 낮은 것부터 줄 세웠을 때 한가운데 있는 값이에요. 한두 곳이 크게 튀어도 덜 흔들려서 평균보다 믿을 만해요.\n\n아래 줄의 점 하나하나가 기관 하나예요. 점이 모여 있으면 기관들이 비슷하게 보고 있다는 뜻이고, 넓게 흩어져 있으면 서로 다르게 보고 있다는 뜻이에요.';

  @override
  String get infoTitleHours => '그래프 읽는 법';

  @override
  String get infoHours =>
      '하늘색 띠: 같은 시각에 가장 낮게 본 기관부터 가장 높게 본 기관까지의 기온 범위예요. 띠가 넓을수록 기관마다 예보가 달라요.\n\n진한 선과 위 숫자: 그 시각 기관 예보의 가운데 값이에요.\n\n아래 파란 막대: 비가 온다고 한 기관의 수예요. 강수확률을 50% 이상으로 봤거나, 비 양을 0.5mm 이상으로 본 기관을 셌어요.\n\n주황 배경: 기관끼리 예보가 크게 갈린 칸이에요. 가운데 절반의 기관끼리 기온이 2.5°C 넘게 다르거나, 비가 온다는 곳과 안 온다는 곳이 반반에 가까울 때 표시해요. 한 곳만 혼자 튀는 건 표시하지 않아요.';

  @override
  String get infoTitlePop => '강수확률(%)이란?';

  @override
  String get infoPop =>
      '그 시간(하루 예보는 그날 중)에 비나 눈이 조금이라도(보통 0.1~1mm 이상) 올 가능성이에요.\n\n예를 들어 70%는 \"비슷한 날씨 상황이 10번 있으면 7번쯤은 비가 왔다\"는 뜻이에요. 비가 얼마나 많이 오는지, 하루 중 몇 시간 동안 오는지를 뜻하지는 않아요.\n\n\"강수확률 1~72%\"처럼 범위로 나오는 건 기관마다 본 값이 달라서예요. 가장 낮게 본 기관이 1%, 가장 높게 본 기관이 72%라는 뜻이에요. 노르웨이 기상청처럼 확률 대신 비의 양(mm)만 주는 곳도 있어요.\n\n막대: 옅은 띠는 모든 기관의 최저~최고 기온, 진한 막대는 가운데 최저~가운데 최고 기온이에요.';

  @override
  String get infoTitleAir => '미세먼지 숫자 읽는 법';

  @override
  String get infoAir =>
      '단위 ㎍/㎥는 공기 1세제곱미터 속에 떠 있는 먼지의 무게(백만분의 1그램)예요.\n\n미세먼지(PM10)는 지름 10㎛ 이하, 초미세먼지(PM2.5)는 2.5㎛ 이하의 더 작은 먼지예요.\n\n등급(환경부 기준)\n미세먼지: 좋음 0~30, 보통 31~80, 나쁨 81~150, 매우나쁨 151 이상\n초미세먼지: 좋음 0~15, 보통 16~35, 나쁨 36~75, 매우나쁨 76 이상\n\n채운 점은 측정소에서 실제로 잰 값(에어코리아, OpenAQ), 빈 점은 예측 모델이 계산한 값이에요. 실측이 더 정확하고, 모델 값은 측정소가 없는 곳도 알려주는 대신 크게 빗나갈 때가 있어요.';

  @override
  String get close => '닫기';

  @override
  String get searchIntro =>
      '도시 이름을 입력하고 키보드의 검색 단추를 누르세요.\n예: 부산, 제주, 도쿄, Paris';

  @override
  String get noPlaces => '아직 없어요. 첫 화면 오른쪽 위 돋보기로 도시를 추가하면 옆으로 넘겨 볼 수 있어요.';

  @override
  String get quickCities => '자주 찾는 도시';

  @override
  String get whereWeather => '어디 날씨를 볼까요?';

  @override
  String get about => '정보';

  @override
  String widgetRange(Object n, Object range) {
    return '$n곳 $range';
  }

  @override
  String get loadingSources => '여러 기관에서 예보를 받아오는 중';

  @override
  String heroAir(Object grade) {
    return '미세먼지 $grade';
  }

  @override
  String get tagMeasured => '측정소';

  @override
  String get tagModel => '모델';

  @override
  String heroRain(Object n, Object wet) {
    return '12시간 안 비 예보 $n곳 중 $wet곳';
  }

  @override
  String get heroNoRain => '12시간 안 비 예보 없음';
}
