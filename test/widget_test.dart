import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/main.dart';

void main() {
  testWidgets('YamiLink Onboarding Boot Smoke Test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('YAMILINK'), findsOneWidget);

    expect(
      find.text('A social layer that exists only when you are there.'),
      findsOneWidget,
    );

    expect(find.text('EPHEMERAL ALIAS'), findsOneWidget);
    expect(find.text('INITIALIZE CONNECTION'), findsOneWidget);
  });
}
