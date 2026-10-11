import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_state.dart';
import 'background.dart';
import 'home_widget_sync.dart';
import 'l10n/app_localizations.dart';
import 'settings.dart';
import 'ui/home_screen.dart';
import 'ui/satellite_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final settings = await Settings.load();
  final state = AppState(settings, await makeFetcher(),
      ledgerDir: await ledgerDirectory(), onReport: (r) => syncWidget(r, settings.fahrenheit, deviceL10n()).ignore());
  scheduleChecks().ignore(); // 알림 등록 실패가 앱 시작을 막지 않게
  runApp(WeatherApp(
      home: HomeScreen(
          state: state,
          afterLocate: () => askNotificationPermission().ignore(),
          onSatellite: (context, p) => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => SatelliteScreen(place: p, fetcher: state.fetcher, offset: state.reportFor(p)?.offset))))));
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key, this.home, this.locale});
  final Widget? home;
  final Locale? locale;

  @override
  Widget build(BuildContext context) => MaterialApp(
        onGenerateTitle: (c) => AppLocalizations.of(c).appTitle,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: locale,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        home: home ??
            Builder(
                builder: (c) => Scaffold(
                    appBar:
                        AppBar(title: Text(AppLocalizations.of(c).appTitle)))),
      );
}
