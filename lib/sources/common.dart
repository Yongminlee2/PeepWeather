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

/// 공공데이터포털(data.go.kr) 응답 오류 확인. 키 오류는 HTTP 200 + XML 로 온다.
void checkDataGoKr(String body) {
  if (body.contains('SERVICE_KEY_IS_NOT_REGISTERED') || body.contains('SERVICE_ACCESS_DENIED')) {
    throw const FetchError(Fail.badKey);
  }
  if (body.contains('LIMITED_NUMBER_OF_SERVICE_REQUESTS')) throw const FetchError(Fail.quota);
  if (body.trimLeft().startsWith('<')) throw const FetchError(Fail.parse);
}

String two(int v) => v.toString().padLeft(2, '0');
String ymd(DateTime d) => '${d.year}${two(d.month)}${two(d.day)}';
