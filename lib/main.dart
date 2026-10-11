import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'app_state.dart';
import 'fetcher.dart';
import 'l10n/app_localizations.dart';
import 'settings.dart';
import 'ui/home_screen.dart';
import 'ui/satellite_screen.dart';

Future<Fetcher> makeFetcher() async =>
    Fetcher(http.Client(), Directory('${(await getApplicationSupportDirectory()).path}/responses'));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = AppState(await Settings.load(), await makeFetcher());
  runApp(WeatherApp(
      home: HomeScreen(
          state: state,
          onSatellite: (context, p) => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => SatelliteScreen(place: p, fetcher: state.fetcher))))));
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
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        darkTheme: ThemeData(
            colorSchemeSeed: Colors.indigo,
            brightness: Brightness.dark,
            useMaterial3: true),
        home: home ??
            Builder(
                builder: (c) => Scaffold(
                    appBar:
                        AppBar(title: Text(AppLocalizations.of(c).appTitle)))),
      );
}
