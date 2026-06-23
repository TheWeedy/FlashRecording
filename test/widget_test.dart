import 'package:flutter_test/flutter_test.dart';
import 'package:recordmytime/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the English welcome screen on first launch', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'welcome_seen_v3': false,
      'interface_language_mode': 'english',
    });

    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Record My Time'), findsOneWidget);
    expect(find.text('Start tracking'), findsOneWidget);
  });
}
