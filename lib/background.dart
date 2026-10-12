import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'alerts.dart';
import 'fetcher.dart';
import 'home_widget_sync.dart';
import 'repository.dart';
import 'verify.dart';
import 'settings.dart';

const checkTask = 'weather-check';

Future<Fetcher> makeFetcher() async =>
    Fetcher(http.Client(), Directory('${(await getApplicationSupportDirectory()).path}/responses'));

/// 이 동네 정확도 기록(기관별 하루 전 예보 vs 관측) 폴더.
Future<Directory> ledgerDirectory() async => Directory('${(await getApplicationSupportDirectory()).path}/verify');

final notifications = FlutterLocalNotificationsPlugin();

Future<void> initNotifications() => notifications.initialize(
    settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_weather'), iOS: DarwinInitializationSettings()));

/// 앱 시작 때: 2시간마다 확인 등록.
Future<void> scheduleChecks() async {
  await Workmanager().initialize(callbackDispatcher);
  await Workmanager().registerPeriodicTask(checkTask, checkTask,
      frequency: const Duration(hours: 2),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected));
}

/// 알림 권한(안드로이드 13+, iOS). 위치 권한 창이 닫힌 뒤에 부른다.
Future<void> askNotificationPermission() async {
  await initNotifications();
  await notifications
      .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
      ?.requestNotificationsPermission();
  await notifications
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, sound: true);
}

Future<bool> notificationsEnabled() async {
  await initNotifications();
  return await notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled() ??
      true;
}

/// 권한 창을 한 번 더 띄우고, 이미 두 번 거절해 창이 안 뜨면 휴대폰의 앱 설정 화면을 연다.
Future<void> turnOnNotifications() async {
  await askNotificationPermission();
  if (!await notificationsEnabled()) await Geolocator.openAppSettings();
}

/// 마지막으로 앱에서 잡은 위치(없으면 첫 저장 도시)를 확인해 알림을 보낸다.
Future<bool> runCheck() async {
  final s = await Settings.load();
  final place = s.lastPos ?? s.places.firstOrNull;
  if (place == null) return true;
  final report = await loadReport(await makeFetcher(), place, background: true);
  try {
    await updateLedger(await ledgerDirectory(), report, DateTime.now().toUtc()); // 2시간마다 비교 자료가 쌓인다
  } catch (_) {}
  final prefs = await SharedPreferences.getInstance();
  final sent = pruneSent((jsonDecode(prefs.getString('alertsSent') ?? '{}') as Map).cast<String, String>(), DateTime.now().toUtc());
  final l = deviceL10n();
  await syncWidget(report, s.fahrenheit, l);
  final alerts = decideAlerts(report, s, sent, DateTime.now().toUtc(), l);
  if (alerts.isNotEmpty) {
    await initNotifications();
    for (final a in alerts) {
      await notifications.show(
          id: a.key.hashCode & 0x7fffffff,
          title: a.title,
          body: a.body,
          notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails('alerts', l.alertsChannel, importance: Importance.defaultImportance),
              iOS: const DarwinNotificationDetails()));
      sent[a.key] = a.value;
    }
  }
  await prefs.setString('alertsSent', jsonEncode(sent));
  return true;
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, _) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    try {
      return await runCheck();
    } catch (_) {
      return true; // 다음 주기에 다시
    }
  });
}
