import 'package:flutter/foundation.dart';

/// 아이폰 시뮬레이터 화면 확인용. 이 맥의 시뮬레이터는 탭이 앱에 닿지 않아서
/// `--dart-define=SHOT=<화면>` 으로 열 화면을 정한다(tool/ios_shots.sh).
/// 정식 빌드에선 kDebugMode 가 상수 false 라 통째로 빠진다.
///
/// home(첫 화면) · settings · search · satellite[:레이어 번호]
const String _shot = kDebugMode ? String.fromEnvironment('SHOT') : '';

/// 화면 이름(콜론 앞).
final String debugShot = _shot.split(':').first;

/// 콜론 뒤 숫자(없으면 null).
final int? debugShotArg = _shot.contains(':') ? int.tryParse(_shot.split(':').last) : null;
