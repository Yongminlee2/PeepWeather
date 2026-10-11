import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class Settings extends ChangeNotifier {
  Settings._(this._prefs);
  final SharedPreferences _prefs;

  bool fahrenheit = false;
  bool alertRain = true, alertAir = true, alertStorm = true;
  List<Place> places = []; // 저장한 도시
  Place? lastPos; // 앱을 켰을 때 마지막으로 잡은 위치(알림용)

  static Future<Settings> load() async {
    final p = await SharedPreferences.getInstance();
    final s = Settings._(p)
      ..fahrenheit = p.getBool('fahrenheit') ?? false
      ..alertRain = p.getBool('alertRain') ?? true
      ..alertAir = p.getBool('alertAir') ?? true
      ..alertStorm = p.getBool('alertStorm') ?? true;
    s.places = [
      for (final e in jsonDecode(p.getString('places') ?? '[]') as List) Place.fromJson(e as Map<String, dynamic>)
    ];
    final last = p.getString('lastPos');
    s.lastPos = last == null ? null : Place.fromJson(jsonDecode(last) as Map<String, dynamic>);
    return s;
  }

  /// 바꾸고 저장하고 화면에 알린다.
  Future<void> update(void Function(Settings s) change) async {
    change(this);
    await Future.wait([
      _prefs.setBool('fahrenheit', fahrenheit),
      _prefs.setBool('alertRain', alertRain),
      _prefs.setBool('alertAir', alertAir),
      _prefs.setBool('alertStorm', alertStorm),
      _prefs.setString('places', jsonEncode([for (final p in places) p.toJson()])),
      if (lastPos != null) _prefs.setString('lastPos', jsonEncode(lastPos!.toJson())),
    ]);
    notifyListeners();
  }
}
