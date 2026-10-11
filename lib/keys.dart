class Keys {
  static const owm = String.fromEnvironment('OWM_KEY');
  static const weatherApi = String.fromEnvironment('WEATHERAPI_KEY');
  static const visualCrossing = String.fromEnvironment('VC_KEY');
  static const openAq = String.fromEnvironment('OPENAQ_KEY');
  static const dataGoKr = String.fromEnvironment('DATA_GO_KR_KEY');
  static const contact =
      String.fromEnvironment('CONTACT', defaultValue: 'dydals5678@gmail.com');
  static String get userAgent => 'WeatherCompare/1.0 ($contact)';
}
