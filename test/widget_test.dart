import 'package:flutter_test/flutter_test.dart';
import 'package:weather_compare/main.dart';

void main() {
  testWidgets('shows app title', (tester) async {
    await tester.pumpWidget(const WeatherApp());
    await tester.pumpAndSettle();
    expect(find.text('Weather Compare'), findsOneWidget);
  });
}
