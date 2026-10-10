import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/app.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('App smoke test loads SpendSmartApp', (WidgetTester tester) async {
    await tester.pumpWidget(const SpendSmartApp());
    expect(find.byType(SpendSmartApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });
}
