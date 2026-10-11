import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'keys.dart';
import 'models.dart';

class FetchError implements Exception {
  final Fail fail;
  const FetchError(this.fail);
  @override
  String toString() => 'FetchError($fail)';
}

class Fetched {
  final String body;
  final DateTime at; // 응답을 받은 시각(저장본이면 저장 시각)
  const Fetched(this.body, this.at);
}

/// HTTP GET + 요청 주소별 파일 캐시. 캐시 파일 첫 줄은 저장 시각, 나머지는 응답 원문.
class Fetcher {
  Fetcher(this.client, this.dir, {DateTime Function()? now}) : _now = now ?? DateTime.now;
  final http.Client client;
  final Directory dir;
  final DateTime Function() _now;
  final _inFlight = <String, Future<Fetched>>{};

  /// 당겨서 새로고침할 때: 30분 이하로 저장하는 자료는 이 시간보다 오래됐으면 다시 받는다.
  /// (측정소 목록처럼 오래 두는 자료는 그대로)
  Duration? freshCap;

  /// 같은 주소를 동시에 부르면 요청 하나를 같이 기다린다.
  /// check: 응답 본문 검사(공공데이터포털은 키 오류도 200 으로 준다). 던지면 저장하지 않는다.
  Future<Fetched> get(Uri url,
      {Duration maxAge = const Duration(minutes: 30), Map<String, String>? headers, void Function(String body)? check}) {
    final key = url.toString();
    // whenComplete 콜백이 Future 를 돌려주면 그걸 기다리므로, 지운 값(자기 자신)을 돌려주지 않게 블록으로.
    return _inFlight.putIfAbsent(key, () => _get(url, maxAge, headers, check).whenComplete(() {
          _inFlight.remove(key);
        }));
  }

  Future<Fetched> _get(Uri url, Duration maxAge, Map<String, String>? headers, void Function(String)? check) async {
    final file = File('${dir.path}/${_hash(url.toString())}.txt');
    final cached = await _read(file);
    final cap = freshCap;
    final age = cap != null && maxAge <= const Duration(minutes: 30) && cap < maxAge ? cap : maxAge;
    if (cached != null && _now().difference(cached.at) < age) return cached;

    final http.Response res;
    try {
      res = await client
          .get(url, headers: {'User-Agent': Keys.userAgent, ...?headers})
          .timeout(const Duration(seconds: 15));
    } on Exception {
      // SocketException·TimeoutException·ClientException 등: 저장본이 있으면 그걸로.
      if (cached != null) return cached;
      throw const FetchError(Fail.network);
    }
    switch (res.statusCode) {
      case 200:
        final body = utf8.decode(res.bodyBytes, allowMalformed: true);
        check?.call(body);
        final at = _now().toUtc();
        await dir.create(recursive: true);
        // 임시 파일에 쓰고 바꿔치기 — 쓰다 죽거나 두 곳(앱·백그라운드)이 동시에 써도 반쪽 파일이 남지 않게
        final tmp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
        await tmp.writeAsString('${at.toIso8601String()}\n$body');
        await tmp.rename(file.path);
        return Fetched(body, at);
      case 401 || 403:
        throw const FetchError(Fail.badKey);
      case 429:
        throw const FetchError(Fail.quota);
      default:
        if (cached != null) return cached;
        throw const FetchError(Fail.network);
    }
  }

  /// 깨진 저장본은 없는 것으로 친다(다시 받으면 덮어쓴다).
  Future<Fetched?> _read(File f) async {
    try {
      if (!await f.exists()) return null;
      final s = utf8.decode(await f.readAsBytes());
      final nl = s.indexOf('\n');
      final at = nl < 0 ? null : DateTime.tryParse(s.substring(0, nl));
      return at == null ? null : Fetched(s.substring(nl + 1), at);
    } catch (_) {
      return null;
    }
  }

  /// FNV-1a 64비트 — 파일 이름용(String.hashCode 는 실행마다 같다는 보장이 없음).
  static String _hash(String s) {
    var h = 0xcbf29ce484222325;
    for (final b in utf8.encode(s)) {
      h ^= b;
      h = (h * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return h.toUnsigned(64).toRadixString(16);
  }
}
