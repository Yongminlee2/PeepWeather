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

  Future<Fetched> get(Uri url,
      {Duration maxAge = const Duration(minutes: 30), Map<String, String>? headers}) async {
    final file = File('${dir.path}/${_hash(url.toString())}.txt');
    final cached = await _read(file);
    if (cached != null && _now().difference(cached.at) < maxAge) return cached;

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
        final at = _now().toUtc();
        await dir.create(recursive: true);
        await file.writeAsString('${at.toIso8601String()}\n$body');
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

  Future<Fetched?> _read(File f) async {
    if (!await f.exists()) return null;
    final s = await f.readAsString();
    final nl = s.indexOf('\n');
    final at = nl < 0 ? null : DateTime.tryParse(s.substring(0, nl));
    return at == null ? null : Fetched(s.substring(nl + 1), at);
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
