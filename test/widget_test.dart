import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/main.dart';

void main() {
  testWidgets('YamiLink Onboarding Boot Smoke Test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that the entry screen displays the app title
    expect(find.text('YAMILINK'), findsOneWidget);
    
    // Verify that the tagline is present
    expect(find.text('A social layer that exists only when you are there.'), findsOneWidget);

    // Verify that the entry input field and action button exist
    expect(find.text('EPHEMERAL ALIAS'), findsOneWidget);
    expect(find.text('INITIALIZE LINK'), findsOneWidget);
  });
}
