# 날씨 비교 (Weather Compare)

내 위치의 예보·미세먼지·태풍·위성 구름을 여러 기관 것으로 나란히 보여주고, 기관끼리 엇갈리는 곳을 표시하는 Flutter 앱.

설계: [docs/설계/2026-10-11-weather-compare-design.md](docs/설계/2026-10-11-weather-compare-design.md)

## 키 설정

`keys.json.example` 을 `keys.json` 으로 복사해 값을 채운다(git 에 올라가지 않음). 비어 있는 키의 출처는 화면에 "설정 필요"로 뜨고 나머지는 정상 동작한다.

| 이름 | 받는 곳 |
|---|---|
| `OWM_KEY` | openweathermap.org 가입 → API keys |
| `WEATHERAPI_KEY` | weatherapi.com 가입 |
| `VC_KEY` | visualcrossing.com 가입 → Account |
| `OPENAQ_KEY` | explore.openaq.org 가입 → API Key |
| `DATA_GO_KR_KEY` | data.go.kr 가입 → 기상청 단기예보, 에어코리아 대기오염정보·측정소정보, 기상청 태풍정보, 기상청 위성영상 조회서비스 활용 신청(일반 인증키, Decoding) |
| `CONTACT` | MET Norway·미국 기상청 요청 머리말에 넣을 연락처(이메일 또는 웹 주소) |

## 실행·빌드

```
flutter run --dart-define-from-file=keys.json
flutter build apk --release --dart-define-from-file=keys.json
flutter test --concurrency=1
```

## 아이폰

같은 Dart 코드로 낸다. 번들 ID 는 안드로이드 패키지와 같은 `com.peep.weather`, 아이폰 전용(아이패드는 호환 모드), 최소 iOS 15.
맥에서 Flutter 는 윈도우와 같은 3.44.9 를 쓴다(다르면 `pubspec.lock` 이 바뀐다). 플러그인은 스위프트 패키지라 CocoaPods 가 필요 없다.

| 무엇 | 어디 |
|---|---|
| 홈 화면 위젯(작게·중간) | `ios/CompareWidget/` — 앱이 `home_widget` 으로 앱 그룹 `group.com.peep.weather` 에 넣은 값을 그린다 |
| 2시간마다 확인(알림·위젯 갱신) | `workmanager` 의 `BGAppRefreshTask`. 이름 `weather-check` 를 `Info.plist`·`AppDelegate.swift`·`lib/background.dart` 에 같게. 실제 시점은 iOS 가 정한다 |
| 알림 권한 | 위치 창 다음에 한 번 묻는다(`askNotificationPermission`). 초기화만으로는 묻지 않게 해 두었다 |
| 홈 화면 이름·위치 문구 | `ios/Runner/{ko,en}.lproj/InfoPlist.strings` |
| 개인정보 매니페스트 | `ios/Runner/PrivacyInfo.xcprivacy`(대략적 위치 → 앱 기능), `ios/CompareWidget/PrivacyInfo.xcprivacy` |
| 설정이 안드로이드와 맞는지 | `test/ios_config_test.dart` (윈도우에서도 돈다) |

```
flutter build ios --simulator --debug --dart-define-from-file=keys.json
python3 tool/ios_shots.py <저장 폴더> <시뮬레이터 UDID> home settings satellite@20   # 화면 확인·스크린샷
flutter build ipa --release --dart-define-from-file=keys.json                         # 앱스토어 업로드용
```

시뮬레이터는 탭이 앱에 안 닿아서 디버그 빌드의 `SHOT` 값으로 열 화면을 정한다(`lib/ui/debug_shot.dart`, 정식 빌드에선 빠진다).
위젯·백그라운드 확인·알림이 실제로 뜨는지는 실기기로 봐야 한다. 앱스토어 입력 내용은 `store/앱스토어-작성내용.md`.
