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
  /// **'Your location isn\'t available. Pick a city below or search.'**
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

  /// No description provided for @alertsChannel.
  ///
  /// In en, this message translates to:
  /// **'Weather alerts'**
  String get alertsChannel;

  /// No description provided for @failNoStation.
  ///
  /// In en, this message translates to:
  /// **'No station nearby'**
  String get failNoStation;

  /// No description provided for @srcOmEcmwf.
  ///
  /// In en, this message translates to:
  /// **'ECMWF (Europe)'**
  String get srcOmEcmwf;

  /// No description provided for @srcOmGfs.
  ///
  /// In en, this message translates to:
  /// **'GFS (US)'**
  String get srcOmGfs;

  /// No description provided for @srcOmIcon.
  ///
  /// In en, this message translates to:
  /// **'ICON (Germany)'**
  String get srcOmIcon;

  /// No description provided for @srcOmJma.
  ///
  /// In en, this message translates to:
  /// **'JMA (Japan)'**
  String get srcOmJma;

  /// No description provided for @srcOmKma.
  ///
  /// In en, this message translates to:
  /// **'KMA model (Korea)'**
  String get srcOmKma;

  /// No description provided for @srcOmGem.
  ///
  /// In en, this message translates to:
  /// **'GEM (Canada)'**
  String get srcOmGem;

  /// No description provided for @srcOmMeteofrance.
  ///
  /// In en, this message translates to:
  /// **'Météo-France'**
  String get srcOmMeteofrance;

  /// No description provided for @srcOmUkmo.
  ///
  /// In en, this message translates to:
  /// **'UKMO (UK)'**
  String get srcOmUkmo;

  /// No description provided for @srcOmCma.
  ///
  /// In en, this message translates to:
  /// **'CMA (China)'**
  String get srcOmCma;

  /// No description provided for @srcOmBom.
  ///
  /// In en, this message translates to:
  /// **'BOM (Australia)'**
  String get srcOmBom;

  /// No description provided for @srcOmCams.
  ///
  /// In en, this message translates to:
  /// **'CAMS (Copernicus)'**
  String get srcOmCams;

  /// No description provided for @satDaily.
  ///
  /// In en, this message translates to:
  /// **'One image a day (today)'**
  String get satDaily;

  /// No description provided for @satModel.
  ///
  /// In en, this message translates to:
  /// **'Map computed by a forecast model'**
  String get satModel;

  /// No description provided for @satLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get satLatest;

  /// No description provided for @nowRange.
  ///
  /// In en, this message translates to:
  /// **'{n} forecasts range {range}'**
  String nowRange(Object n, Object range);

  /// No description provided for @middleValue.
  ///
  /// In en, this message translates to:
  /// **'Middle value'**
  String get middleValue;

  /// No description provided for @notAvailable.
  ///
  /// In en, this message translates to:
  /// **'Not available'**
  String get notAvailable;

  /// No description provided for @next24.
  ///
  /// In en, this message translates to:
  /// **'Next 24 hours'**
  String get next24;

  /// No description provided for @legendRange.
  ///
  /// In en, this message translates to:
  /// **'Range across sources'**
  String get legendRange;

  /// No description provided for @legendMid.
  ///
  /// In en, this message translates to:
  /// **'Middle value'**
  String get legendMid;

  /// No description provided for @rainVotes.
  ///
  /// In en, this message translates to:
  /// **'Rain {wet}/{n}'**
  String rainVotes(Object n, Object wet);

  /// No description provided for @noRainVote.
  ///
  /// In en, this message translates to:
  /// **'No rain'**
  String get noRainVote;

  /// No description provided for @tapHint.
  ///
  /// In en, this message translates to:
  /// **'Tap a column to see each source'**
  String get tapHint;

  /// No description provided for @rainPct.
  ///
  /// In en, this message translates to:
  /// **'Rain {v}%'**
  String rainPct(Object v);

  /// No description provided for @measured.
  ///
  /// In en, this message translates to:
  /// **'Measured'**
  String get measured;

  /// No description provided for @modelEstimate.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get modelEstimate;

  /// No description provided for @detailTable.
  ///
  /// In en, this message translates to:
  /// **'All numbers by source'**
  String get detailTable;

  /// No description provided for @sheetAt.
  ///
  /// In en, this message translates to:
  /// **'Forecasts for {when}'**
  String sheetAt(Object when);

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @airHint.
  ///
  /// In en, this message translates to:
  /// **'Filled dots are station measurements, hollow dots are model estimates'**
  String get airHint;

  /// No description provided for @rainVotesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources expecting rain'**
  String get rainVotesTitle;

  /// No description provided for @rainVotesOf.
  ///
  /// In en, this message translates to:
  /// **'of {n}'**
  String rainVotesOf(Object n);

  /// No description provided for @rainCount.
  ///
  /// In en, this message translates to:
  /// **'{wet}'**
  String rainCount(Object wet);

  /// No description provided for @noneShort.
  ///
  /// In en, this message translates to:
  /// **'none'**
  String get noneShort;

  /// No description provided for @popLabel.
  ///
  /// In en, this message translates to:
  /// **'Chance of rain'**
  String get popLabel;

  /// No description provided for @pmUnit.
  ///
  /// In en, this message translates to:
  /// **'µg/m³'**
  String get pmUnit;

  /// No description provided for @pmColumns.
  ///
  /// In en, this message translates to:
  /// **'PM10 / PM2.5 (µg/m³)'**
  String get pmColumns;

  /// No description provided for @infoTitleNow.
  ///
  /// In en, this message translates to:
  /// **'What is the middle value?'**
  String get infoTitleNow;

  /// No description provided for @infoNow.
  ///
  /// In en, this message translates to:
  /// **'Line up every source\'s current temperature from low to high; the middle one is shown. It is steadier than an average when one or two sources are far off.\n\nEach dot is one source. Close dots mean the sources agree; spread-out dots mean they don\'t.'**
  String get infoNow;

  /// No description provided for @infoTitleHours.
  ///
  /// In en, this message translates to:
  /// **'Reading the chart'**
  String get infoTitleHours;

  /// No description provided for @infoHours.
  ///
  /// In en, this message translates to:
  /// **'Blue band: the range from the lowest to the highest forecast at that time. A wider band means more disagreement.\n\nDark line and numbers: the middle value of all forecasts.\n\nBlue bars: how many sources expect rain (chance 50% or more, or 0.5 mm or more).\n\nOrange background: forecasts clearly split. The middle half differ by more than 2.5 °C, or rain votes are close to half and half. A single outlier is not marked.'**
  String get infoHours;

  /// No description provided for @infoTitlePop.
  ///
  /// In en, this message translates to:
  /// **'What does the % mean?'**
  String get infoTitlePop;

  /// No description provided for @infoPop.
  ///
  /// In en, this message translates to:
  /// **'The chance that rain or snow (usually 0.1–1 mm or more) falls during that hour, or during that day for daily forecasts.\n\n70% means that in similar situations it rained about 7 times out of 10. It is not how much rain falls or how many hours it rains.\n\nA range like 1–72% means sources disagree: the lowest says 1%, the highest 72%. Some sources give only amounts (mm), not a chance.\n\nBars: the light band is all sources\' low to high; the dark bar is the middle low to middle high.'**
  String get infoPop;

  /// No description provided for @infoTitleAir.
  ///
  /// In en, this message translates to:
  /// **'Reading air quality numbers'**
  String get infoTitleAir;

  /// No description provided for @infoAir.
  ///
  /// In en, this message translates to:
  /// **'µg/m³ is the weight of particles (millionths of a gram) in one cubic metre of air.\n\nPM10 are particles up to 10 µm, PM2.5 up to 2.5 µm.\n\nGrades (Korean standard)\nPM10: good 0–30, moderate 31–80, bad 81–150, very bad 151+\nPM2.5: good 0–15, moderate 16–35, bad 36–75, very bad 76+\n\nFilled dots are station measurements, hollow dots are model estimates. Measurements are more accurate; models cover places without stations but can be far off.'**
  String get infoAir;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @searchIntro.
  ///
  /// In en, this message translates to:
  /// **'Type a city name and press search on the keyboard.\nFor example: Busan, Tokyo, Paris'**
  String get searchIntro;

  /// No description provided for @noPlaces.
  ///
  /// In en, this message translates to:
  /// **'None yet. Add a city with the search button on the main screen, then swipe between them.'**
  String get noPlaces;

  /// No description provided for @quickCities.
  ///
  /// In en, this message translates to:
  /// **'Popular cities'**
  String get quickCities;

  /// No description provided for @whereWeather.
  ///
  /// In en, this message translates to:
  /// **'Where shall we look?'**
  String get whereWeather;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @widgetRange.
  ///
  /// In en, this message translates to:
  /// **'{n} sources {range}'**
  String widgetRange(Object n, Object range);

  /// No description provided for @loadingSources.
  ///
  /// In en, this message translates to:
  /// **'Collecting forecasts from every source'**
  String get loadingSources;

  /// No description provided for @heroAir.
  ///
  /// In en, this message translates to:
  /// **'Air {grade}'**
  String heroAir(Object grade);

  /// No description provided for @tagMeasured.
  ///
  /// In en, this message translates to:
  /// **'station'**
  String get tagMeasured;

  /// No description provided for @tagModel.
  ///
  /// In en, this message translates to:
  /// **'model'**
  String get tagModel;

  /// No description provided for @heroRain.
  ///
  /// In en, this message translates to:
  /// **'Rain in 12 h: {wet} of {n}'**
  String heroRain(Object n, Object wet);

  /// No description provided for @heroNoRain.
  ///
  /// In en, this message translates to:
  /// **'No rain expected in 12 h'**
  String get heroNoRain;

  /// No description provided for @verdictTitle.
  ///
  /// In en, this message translates to:
  /// **'Bottom line'**
  String get verdictTitle;

  /// No description provided for @vNow.
  ///
  /// In en, this message translates to:
  /// **'Now {t}'**
  String vNow(Object t);

  /// No description provided for @vNowWeighted.
  ///
  /// In en, this message translates to:
  /// **'Now {t} (weighted by local accuracy)'**
  String vNowWeighted(Object t);

  /// No description provided for @vConfHigh.
  ///
  /// In en, this message translates to:
  /// **'Sources agree closely'**
  String get vConfHigh;

  /// No description provided for @vConfMedium.
  ///
  /// In en, this message translates to:
  /// **'Sources differ a little'**
  String get vConfMedium;

  /// No description provided for @vConfLow.
  ///
  /// In en, this message translates to:
  /// **'Sources differ a lot. Check the range below'**
  String get vConfLow;

  /// No description provided for @vTodayHigh.
  ///
  /// In en, this message translates to:
  /// **'High today around {t}'**
  String vTodayHigh(Object t);

  /// No description provided for @vRainLikely.
  ///
  /// In en, this message translates to:
  /// **'Rain is likely within 12 hours'**
  String get vRainLikely;

  /// No description provided for @vRainUnlikely.
  ///
  /// In en, this message translates to:
  /// **'No rain expected within 12 hours'**
  String get vRainUnlikely;

  /// No description provided for @vRainSplit.
  ///
  /// In en, this message translates to:
  /// **'Rain forecasts are split. An umbrella is the safe bet'**
  String get vRainSplit;

  /// No description provided for @vRainVotes.
  ///
  /// In en, this message translates to:
  /// **'{wet} of {n} sources expect rain'**
  String vRainVotes(Object n, Object wet);

  /// No description provided for @vTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow {range}'**
  String vTomorrow(Object range);

  /// No description provided for @vTomorrowRain.
  ///
  /// In en, this message translates to:
  /// **'{k} of {n} sources give 50%+ chance of rain'**
  String vTomorrowRain(Object k, Object n);

  /// No description provided for @vBest.
  ///
  /// In en, this message translates to:
  /// **'Most accurate here: {name}'**
  String vBest(Object name);

  /// No description provided for @vBestDetail.
  ///
  /// In en, this message translates to:
  /// **'off by {err}° on average, {n} checks'**
  String vBestDetail(Object err, Object n);

  /// No description provided for @vCollecting.
  ///
  /// In en, this message translates to:
  /// **'Collecting data on which source is most accurate here'**
  String get vCollecting;

  /// No description provided for @vCollectingDetail.
  ///
  /// In en, this message translates to:
  /// **'A ranking appears after about a day ({n} checks so far)'**
  String vCollectingDetail(Object n);

  /// No description provided for @infoTitleVerdict.
  ///
  /// In en, this message translates to:
  /// **'How is the bottom line made?'**
  String get infoTitleVerdict;

  /// No description provided for @infoVerdict.
  ///
  /// In en, this message translates to:
  /// **'Now: the middle value of all sources. Once enough local checks build up, sources that matched real observations get more weight.\n\nAgreement: the middle half within 1.5 °C means close, within 3 °C a little, otherwise a lot.\n\nRain: the hour in the next 12 with the most sources expecting rain. Over 60% means likely, 20% or less means none expected, otherwise split.\n\nMost accurate: the app saves each source\'s forecast about a day ahead and compares it with the real observation at that time (KMA stations in Korea, OpenWeather current values elsewhere). Checks build up when you open the app and during the 2-hourly alert check. Sources need 5+ checks to be ranked.'**
  String get infoVerdict;

  /// No description provided for @accuracyTitle.
  ///
  /// In en, this message translates to:
  /// **'Local accuracy ranking'**
  String get accuracyTitle;

  /// No description provided for @accuracyRow.
  ///
  /// In en, this message translates to:
  /// **'off by {err}°'**
  String accuracyRow(Object err);

  /// No description provided for @accuracyRain.
  ///
  /// In en, this message translates to:
  /// **'rain right {pct}%'**
  String accuracyRain(Object pct);

  /// No description provided for @accuracyBasis.
  ///
  /// In en, this message translates to:
  /// **'Day-ahead forecasts compared with {obs}'**
  String accuracyBasis(Object obs);

  /// No description provided for @obsKma.
  ///
  /// In en, this message translates to:
  /// **'KMA station observations'**
  String get obsKma;

  /// No description provided for @obsOwm.
  ///
  /// In en, this message translates to:
  /// **'OpenWeather current values'**
  String get obsOwm;
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
