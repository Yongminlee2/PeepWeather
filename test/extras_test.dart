import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/home_widget_sync.dart';
import 'package:weather_compare/l10n/app_localizations.dart';
import 'package:weather_compare/models.dart';
import 'package:weather_compare/more_games.dart';
import 'package:weather_compare/repository.dart';

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
}
