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
