import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'fetcher.dart';
import 'models.dart';
import 'repository.dart';
import 'settings.dart';
import 'sources/openweather.dart';

typedef Locator = Future<(double, double)?> Function();

String placeKey(Place p) => '${p.lat.toStringAsFixed(3)},${p.lon.toStringAsFixed(3)}';

/// 대략 위치(COARSE)만. 꺼져 있거나 거절하면 null.
Future<(double, double)?> deviceLocation() async {
  try {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
    final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 15)))
        .catchError((_) async => (await Geolocator.getLastKnownPosition())!);
    return (pos.latitude, pos.longitude);
  } catch (_) {
    return null;
  }
}

class AppState extends ChangeNotifier {
  AppState(this.settings, this.fetcher, {Locator? locator}) : _locator = locator ?? deviceLocation;
  final Settings settings;
  final Fetcher fetcher;
  final Locator _locator;

  Place? current;
  bool locationFailed = false;
  bool locating = false;
  final _reports = <String, Report>{};
  final _loading = <String>{};

  List<Place> get places => [?current, ...settings.places];
  Report? reportFor(Place p) => _reports[placeKey(p)];
  bool isLoading(Place p) => _loading.contains(placeKey(p));

  Future<void> locate(String lang, String fallbackName) async {
    locating = true;
    notifyListeners();
    final pos = await _locator();
    locating = false;
    locationFailed = pos == null;
    if (pos != null) {
      final (lat, lon) = pos;
      try {
        current = await owmReverse(fetcher, lat, lon, lang);
      } catch (_) {
        // 지명을 못 얻어도 한국 안이면 한국 출처는 붙인다.
        final inKorea = lat >= 33 && lat <= 39 && lon >= 124 && lon <= 132;
        current = Place(fallbackName, inKorea ? 'KR' : '', lat, lon);
      }
      await settings.update((s) => s.lastPos = current);
    }
    notifyListeners();
  }

  /// force: 당겨서 새로고침 — 5분보다 오래된 자료는 다시 받는다.
  Future<void> refresh(Place p, {bool force = false}) async {
    final k = placeKey(p);
    if (_loading.contains(k)) return;
    _loading.add(k);
    notifyListeners();
    fetcher.freshCap = force ? const Duration(minutes: 5) : null;
    try {
      _reports[k] = await loadReport(fetcher, p);
    } finally {
      fetcher.freshCap = null;
      _loading.remove(k);
      notifyListeners();
    }
  }
}
