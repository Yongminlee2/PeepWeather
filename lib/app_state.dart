import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'fetcher.dart';
import 'models.dart';
import 'repository.dart';
import 'settings.dart';
import 'sources/openweather.dart';
import 'verify.dart';

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
  AppState(this.settings, this.fetcher, {Locator? locator, this.onReport, this.ledgerDir, DateTime Function()? clock})
      : _locator = locator ?? deviceLocation,
        _clock = clock ?? DateTime.now {
    // 섭씨/화씨를 바꾸면 위젯도 바로 다시 그리게
    settings.addListener(() {
      final r = places.isEmpty ? null : reportFor(places.first);
      if (r != null) onReport?.call(r);
    });
  }
  final void Function(Report r)? onReport; // 첫 장(현재 위치)을 새로 받았을 때 — 홈 화면 위젯 갱신
  final Settings settings;
  final Directory? ledgerDir; // 이 동네 정확도 기록 폴더(없으면 기록 안 함)
  final DateTime Function() _clock;
  final Fetcher fetcher;
  final Locator _locator;

  Place? current;
  bool locationFailed = false;
  bool locating = false;
  final _reports = <String, Report>{};
  final _ledgers = <String, Ledger>{};
  final _loading = <String>{};

  List<Place> get places => [?current, ...settings.places];
  Report? reportFor(Place p) => _reports[placeKey(p)];
  Ledger? ledgerFor(Place p) => _ledgers[placeKey(p)];
  bool isLoading(Place p) => _loading.contains(placeKey(p));

  /// 없거나 가장 새 자료가 30분보다 오래됐으면 다시 받을 때.
  bool isStale(Place p, {DateTime? now}) {
    final r = reportFor(p);
    final times = [...?r?.forecasts, ...?r?.air].map((x) => x.asOf).whereType<DateTime>();
    if (times.isEmpty) return true;
    final newest = times.reduce((a, b) => a.isAfter(b) ? a : b);
    return (now ?? DateTime.now()).toUtc().difference(newest) > const Duration(minutes: 30);
  }

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
        final inUs = lat >= 24.5 && lat <= 49.5 && lon >= -125 && lon <= -66.9; // 미국 본토(키 없어도 NWS 는 쓸 수 있다)
        current = Place(fallbackName, inKorea ? 'KR' : inUs ? 'US' : '', lat, lon);
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
    try {
      final r = _reports[k] = await loadReport(force ? fetcher.forced(const Duration(minutes: 5)) : fetcher, p);
      if (ledgerDir case final d?) {
        try {
          _ledgers[k] = await updateLedger(d, r, _clock().toUtc());
        } catch (_) {} // 정확도 기록이 실패해도 날씨는 보여 준다
      }
      if (places.isNotEmpty && placeKey(places.first) == k) onReport?.call(r);
    } finally {
      _loading.remove(k);
      notifyListeners();
    }
  }
}
