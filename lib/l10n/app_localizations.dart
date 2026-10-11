import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Weather Compare'**
  String get appTitle;

  /// No description provided for @currentLocation.
  ///
  /// In en, this message translates to:
  /// **'Current location'**
  String get currentLocation;

  /// No description provided for @asOf.
  ///
  /// In en, this message translates to:
  /// **'as of {time}'**
  String asOf(Object time);

  /// No description provided for @nowTitle.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get nowTitle;

  /// No description provided for @hourlyTitle.
  ///
  /// In en, this message translates to:
  /// **'Hourly comparison'**
  String get hourlyTitle;

  /// No description provided for @dailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Daily comparison'**
  String get dailyTitle;

  /// No description provided for @diverge.
  ///
  /// In en, this message translates to:
  /// **'Forecasts disagree'**
  String get diverge;

  /// No description provided for @airTitle.
  ///
  /// In en, this message translates to:
  /// **'Air quality comparison'**
  String get airTitle;

  /// No description provided for @pm10.
  ///
  /// In en, this message translates to:
  /// **'PM10'**
  String get pm10;

  /// No description provided for @pm25.
  ///
  /// In en, this message translates to:
  /// **'PM2.5'**
  String get pm25;

  /// No description provided for @gradeGood.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get gradeGood;

  /// No description provided for @gradeNormal.
  ///
  /// In en, this message translates to:
  /// **'Moderate'**
  String get gradeNormal;

  /// No description provided for @gradeBad.
  ///
  /// In en, this message translates to:
  /// **'Bad'**
  String get gradeBad;

  /// No description provided for @gradeVeryBad.
  ///
  /// In en, this message translates to:
  /// **'Very bad'**
  String get gradeVeryBad;

  /// No description provided for @stormTitle.
  ///
  /// In en, this message translates to:
  /// **'Tropical cyclones'**
  String get stormTitle;

  /// No description provided for @noStorm.
  ///
  /// In en, this message translates to:
  /// **'No cyclones within 1,000 km'**
  String get noStorm;

  /// No description provided for @stormKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String stormKm(Object km);

  /// No description provided for @windKt.
  ///
  /// In en, this message translates to:
  /// **'Max wind {kt} kt'**
  String windKt(Object kt);

  /// No description provided for @satellite.
  ///
  /// In en, this message translates to:
  /// **'Satellite cloud map'**
  String get satellite;

  /// No description provided for @attribution.
  ///
  /// In en, this message translates to:
  /// **'Data sources'**
  String get attribution;

  /// No description provided for @failNoKey.
  ///
  /// In en, this message translates to:
  /// **'Not set up'**
  String get failNoKey;

  /// No description provided for @failBadKey.
  ///
  /// In en, this message translates to:
  /// **'Key error'**
  String get failBadKey;

  /// No description provided for @failQuota.
  ///
  /// In en, this message translates to:
  /// **'Daily limit reached'**
  String get failQuota;

  /// No description provided for @failNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get failNetwork;

  /// No description provided for @failParse.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get failParse;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search city'**
  String get search;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @locationNeeded.
  ///
  /// In en, this message translates to:
  /// **'Location unavailable. Search and add a city.'**
  String get locationNeeded;

  /// No description provided for @openLocationSettings.
  ///
  /// In en, this message translates to:
  /// **'Open location settings'**
  String get openLocationSettings;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'City name'**
  String get searchHint;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @added.
  ///
  /// In en, this message translates to:
  /// **'Added {name}'**
  String added(Object name);

  /// No description provided for @fahrenheit.
  ///
  /// In en, this message translates to:
  /// **'Show °F'**
  String get fahrenheit;

  /// No description provided for @alerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get alerts;

  /// No description provided for @alertRain.
  ///
  /// In en, this message translates to:
  /// **'Rain (60%+ within 12 h)'**
  String get alertRain;

  /// No description provided for @alertAir.
  ///
  /// In en, this message translates to:
  /// **'Air quality bad or worse'**
  String get alertAir;

  /// No description provided for @alertStorm.
  ///
  /// In en, this message translates to:
  /// **'Cyclone within 500 km'**
  String get alertStorm;

  /// No description provided for @savedPlaces.
  ///
  /// In en, this message translates to:
  /// **'Saved cities'**
  String get savedPlaces;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy policy'**
  String get privacy;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @srcMet.
  ///
  /// In en, this message translates to:
  /// **'MET Norway'**
  String get srcMet;

  /// No description provided for @srcOwm.
  ///
  /// In en, this message translates to:
  /// **'OpenWeather'**
  String get srcOwm;

  /// No description provided for @srcWeatherapi.
  ///
  /// In en, this message translates to:
  /// **'WeatherAPI'**
  String get srcWeatherapi;

  /// No description provided for @srcVc.
  ///
  /// In en, this message translates to:
  /// **'Visual Crossing'**
  String get srcVc;

  /// No description provided for @srcNws.
  ///
  /// In en, this message translates to:
  /// **'US NWS'**
  String get srcNws;

  /// No description provided for @srcKma.
  ///
  /// In en, this message translates to:
  /// **'KMA (Korea)'**
  String get srcKma;

  /// No description provided for @srcAirkorea.
  ///
  /// In en, this message translates to:
  /// **'AirKorea'**
  String get srcAirkorea;

  /// No description provided for @srcOpenaq.
  ///
  /// In en, this message translates to:
  /// **'OpenAQ'**
  String get srcOpenaq;

  /// No description provided for @srcGdacs.
  ///
  /// In en, this message translates to:
  /// **'GDACS (UN·EU)'**
  String get srcGdacs;

  /// No description provided for @srcNhc.
  ///
  /// In en, this message translates to:
  /// **'US NHC'**
  String get srcNhc;

  /// No description provided for @srcJtwc.
  ///
  /// In en, this message translates to:
  /// **'US JTWC'**
  String get srcJtwc;

  /// No description provided for @srcKmaTyphoon.
  ///
  /// In en, this message translates to:
  /// **'KMA Typhoon'**
  String get srcKmaTyphoon;

  /// No description provided for @satInfrared.
  ///
  /// In en, this message translates to:
  /// **'Infrared'**
  String get satInfrared;

  /// No description provided for @satVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get satVisible;

  /// No description provided for @satTrueColor.
  ///
  /// In en, this message translates to:
  /// **'True color (daily)'**
  String get satTrueColor;

  /// No description provided for @satClouds.
  ///
  /// In en, this message translates to:
  /// **'Clouds (model)'**
  String get satClouds;

  /// No description provided for @satPrecip.
  ///
  /// In en, this message translates to:
  /// **'Precip (model)'**
  String get satPrecip;

  /// No description provided for @satKma.
  ///
  /// In en, this message translates to:
  /// **'GK-2A'**
  String get satKma;

  /// No description provided for @satNight.
  ///
  /// In en, this message translates to:
  /// **'It\'s night — try infrared'**
  String get satNight;

  /// No description provided for @play.
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @rainSoon.
  ///
  /// In en, this message translates to:
  /// **'Rain coming to {place}'**
  String rainSoon(Object place);

  /// No description provided for @rainSoonBody.
  ///
  /// In en, this message translates to:
  /// **'{source}: {pop}% at {time}'**
  String rainSoonBody(Object pop, Object source, Object time);

  /// No description provided for @airBad.
  ///
  /// In en, this message translates to:
  /// **'{place} air quality {grade}'**
  String airBad(Object grade, Object place);

  /// No description provided for @airBadBody.
  ///
  /// In en, this message translates to:
  /// **'per {source}'**
  String airBadBody(Object source);

  /// No description provided for @stormNear.
  ///
  /// In en, this message translates to:
  /// **'Cyclone {name} approaching'**
  String stormNear(Object name);

  /// No description provided for @stormNearBody.
  ///
  /// In en, this message translates to:
  /// **'{km} km from {place}'**
  String stormNearBody(Object km, Object place);

  /// No description provided for @moreGames.
  ///
  /// In en, this message translates to:
  /// **'More games by the developer'**
  String get moreGames;

  /// No description provided for @moreLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get moreLoading;

  /// No description provided for @moreOffline.
  ///
  /// In en, this message translates to:
  /// **'Connect to the internet to see the list'**
  String get moreOffline;

  /// No description provided for @moreEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get moreEmpty;

  /// No description provided for @moreNow.
  ///
  /// In en, this message translates to:
  /// **'This app'**
  String get moreNow;

  /// No description provided for @moreGet.
  ///
  /// In en, this message translates to:
  /// **'Get'**
  String get moreGet;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
