// 아이폰 설정이 안드로이드·Dart 코드와 어긋나지 않는지 본다. 아이폰 빌드는 맥에서만 되므로,
// 윈도우에서 안드로이드만 고치다가 생긴 차이(번들 ID·앱 이름·백그라운드 이름·위젯 앱 그룹)를 여기서 먼저 잡는다.
// 파일을 직접 읽으니 저장소 루트에서 돈다.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/background.dart';
import 'package:weather_compare/home_widget_sync.dart';

String read(String p) => File(p).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  final plist = read('ios/Runner/Info.plist');
  final pbxproj = read('ios/Runner.xcodeproj/project.pbxproj');

  test('번들 ID가 안드로이드 패키지 이름과 같고, 위젯은 그 아래', () {
    final androidId = RegExp(r'applicationId = "([^"]+)"').firstMatch(read('android/app/build.gradle.kts'))!.group(1)!;
    final ids = RegExp(r'PRODUCT_BUNDLE_IDENTIFIER = ([\w.]+);').allMatches(pbxproj).map((m) => m.group(1)!).toSet();
    expect(ids, {androidId, '$androidId.RunnerTests', '$androidId.CompareWidget'});
  });

  test('홈 화면 이름이 안드로이드 앱 이름과 같다', () {
    String android(String dir) =>
        RegExp(r'name="app_name">([^<]+)<').firstMatch(read('android/app/src/main/res/$dir/strings.xml'))!.group(1)!;
    String ios(String lproj) =>
        RegExp(r'"CFBundleDisplayName" = "([^"]+)";').firstMatch(read('ios/Runner/$lproj.lproj/InfoPlist.strings'))!.group(1)!;
    expect(ios('ko'), android('values-ko'));
    expect(ios('en'), android('values'));
    for (final l in ['en', 'ko']) {
      expect(plist, contains('<string>$l</string>'), reason: 'CFBundleLocalizations');
      expect(read('ios/Runner/$l.lproj/InfoPlist.strings'), contains('NSLocationWhenInUseUsageDescription'));
    }
  });

  test('백그라운드 확인 이름이 Info.plist·AppDelegate 와 같다(다르면 iOS 가 실행하지 않는다)', () {
    expect(plist, contains('<key>BGTaskSchedulerPermittedIdentifiers</key>\n\t<array>\n\t\t<string>$checkTask</string>'));
    expect(plist, contains('<string>fetch</string>'));
    expect(read('ios/Runner/AppDelegate.swift'), contains('withIdentifier: "$checkTask"'));
  });

  test('위젯 앱 그룹이 앱·위젯 entitlements 와 위젯 코드에 같게 들어 있다', () {
    for (final f in ['ios/Runner/Runner.entitlements', 'ios/CompareWidget/CompareWidget.entitlements']) {
      expect(read(f), contains('<string>$appGroup</string>'), reason: f);
    }
    expect(read('ios/CompareWidget/CompareWidget.swift'), contains('"$appGroup"'));
    expect(read('ios/CompareWidget/CompareWidget.swift'), contains('let kind = "CompareWidget"'));
  });

  test('앱 아이콘은 1024 한 장이고 투명 픽셀이 없다(앱 스토어가 거부한다)', () {
    final png = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png').readAsBytesSync();
    int u32(int o) => (png[o] << 24) | (png[o + 1] << 16) | (png[o + 2] << 8) | png[o + 3];
    expect([u32(16), u32(20), png[25]], [1024, 1024, 2]); // 색 형식 2 = 알파 없는 RGB
  });

  test('개인정보 매니페스트가 앱·위젯에 실리고, 추적하지 않는다고 적혀 있다', () {
    for (final f in ['ios/Runner/PrivacyInfo.xcprivacy', 'ios/CompareWidget/PrivacyInfo.xcprivacy']) {
      final m = read(f);
      expect(m, contains('<key>NSPrivacyTracking</key>\n\t<false/>'), reason: f);
      expect(m, contains('NSPrivacyAccessedAPICategoryUserDefaults'), reason: f);
    }
    expect('PrivacyInfo.xcprivacy in Resources'.allMatches(pbxproj).length, 4); // 앱·위젯 각각 파일 줄 + 단계 줄
    expect(plist, contains('<key>ITSAppUsesNonExemptEncryption</key>\n\t<false/>'));
  });
}
