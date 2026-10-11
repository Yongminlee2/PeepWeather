import '../fetcher.dart';
import '../models.dart';

/// 자료와 그 자료를 받은 시각.
typedef Stamped<T> = (T, DateTime);

void requireKey(String k) {
  if (k.isEmpty) throw const FetchError(Fail.noKey);
}

DateTime oldest(Iterable<DateTime> ts) => ts.reduce((a, b) => a.isBefore(b) ? a : b);

double? toD(Object? v) => v is num ? v.toDouble() : v is String ? double.tryParse(v) : null;

DateTime fromEpoch(Object? s) => DateTime.fromMillisecondsSinceEpoch((s as num).toInt() * 1000, isUtc: true);

/// "2026-10-11" → 그 날짜의 UTC 자정.
DateTime dateOnly(String ymd) {
  final p = ymd.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

String coord(double v) => v.toStringAsFixed(4);
