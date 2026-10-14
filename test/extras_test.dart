import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/home_widget_sync.dart';
import 'package:weather_compare/l10n/app_localizations.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/more_games.dart';
import 'package:weather_compare/repository.dart';
import 'package:weather_compare/ui/more_games_screen.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('ko'));
  final t = DateTime.utc(2026, 10, 11);

  Report report(int n) => Report(
        const Place('서울', 'KR', 37.57, 126.98),
        [
          for (final (i, id) in ['met', 'owm', 'weatherapi', 'vc', 'kma'].indexed.take(n))
            Result(id, data: Forecast(now: Hour(t, 20.0 + i, Sky.clear)), asOf: t),
          const Result('nws', fail: Fail.noKey),
        ],
        const [],
        const [],
        const Duration(hours: 9),
      );

  test('widget rows skip failed sources and cap at four', () {
    final rows = widgetRows(report(5), false, l);
    expect(rows, ['노르웨이 기상청 20°', 'OpenWeather 21°', 'WeatherAPI 22°', 'Visual Crossing 23°']);
  });

  test('widget rows follow fahrenheit', () {
    expect(widgetRows(report(1), true, l), ['노르웨이 기상청 68°F']);
  });

  group('more games list', () {
    test('broken json gives empty list', () => expect(MoreGames.parse('{oops'), isEmpty));
    test('bad id, empty name, http icon are filtered; self is marked', () {
      final g = MoreGames.parse('''{"apps":[
        {"id":"not a package","name":"X"},
        {"id":"com.a.b","name":" "},
        {"id":"com.peep.weather","name":"날씨 비교","icon":"http://x/y.png"},
        {"id":"com.peep.push","name":"삐약푸쉬","i18n":{"en":{"name":"Peep Push"}},"icon":"apps/icons/p.jpg"}]}''', lang: 'ja');
      expect(g.map((x) => x.id), ['com.peep.weather', 'com.peep.push']);
      expect(g.first.self, isTrue);
      expect(g.first.icon, '');
      expect(g.last.name, 'Peep Push'); // ja 없음 → en
      expect(g.last.icon, 'https://yongminlee2.github.io/legal/apps/icons/p.jpg');
    });
  });

  test('widget headline: middle value and range across sources', () {
    final (mid, range) = widgetHeadline(report(5), false, l)!;
    expect(mid, '22°'); // 20,21,22,23,24 의 가운데
    expect(range, '5곳 20° ~ 24°');
    expect(widgetHeadline(report(0), false, l), isNull);
  });

  group('more games on iPhone', () {
    const json = '''{"apps":[
      {"id":"com.peep.weather","name":"날씨 비교"},
      {"id":"com.peep.science","name":"삐약과학","ios":"6821341160"},
      {"id":"com.peep.math","name":"삐약수학"}]}''';

    test('only this app and App Store games are listed, opened by App Store number', () {
      final v = MoreGames.visible(MoreGames.parse(json), ios: true);
      expect(v.map((g) => g.id), ['com.peep.weather', 'com.peep.science']);
      expect(MoreGames.storeKey(v[1], ios: true), '6821341160');
      expect(MoreGames.visible(MoreGames.parse(json), ios: false), hasLength(3));
    });

    Future<List<bool>> answers(String? cached, String? fresh, {bool ios = true}) async {
      final out = <bool>[];
      await moreGamesAvailable(out.add, ios: ios, cached: () async => cached, refresh: () async => fresh);
      return out;
    }

    test('settings row: hidden without App Store games, shown once one appears', () async {
      const none = '{"apps":[{"id":"com.peep.weather","name":"날씨 비교"},{"id":"com.peep.math","name":"삐약수학"}]}';
      expect(await answers(null, null), isEmpty); // 목록이 없으면 숨긴 채
      expect(await answers(none, null), [false]);
      expect(await answers(none, json), [false, true]);
      expect(await answers(null, null, ios: false), [true]); // 안드로이드는 늘 보인다
    });
  });
}
