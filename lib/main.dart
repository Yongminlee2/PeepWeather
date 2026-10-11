import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/app_localizations.dart';

void main() => runApp(const WeatherApp());

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
