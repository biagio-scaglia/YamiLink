import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yamilink/main.dart';

void main() {
  testWidgets('YamiTutorialHelper Boot and Help UI Integration Test', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('YAMILINK'), findsOneWidget);

    final buttonFinder = find.text('INITIALIZE CONNECTION');
    expect(buttonFinder, findsOneWidget);
    await tester.tap(buttonFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    await tester.pump(const Duration(milliseconds: 1000));
    await tester.pump();

    for (int i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('SPACE (RADAR SCANNER)'), findsOneWidget);

    await tester.tap(find.text('SKIP TUTORIAL'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('SPACE (RADAR SCANNER)'), findsNothing);

    final helpFinder = find.byIcon(Icons.help_outline);
    expect(helpFinder, findsOneWidget);
    await tester.tap(helpFinder);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('HELP & RESOURCES'), findsOneWidget);
    expect(find.text('Interactive Walkthrough'), findsOneWidget);
    expect(find.text('Full User Guide'), findsOneWidget);
  });
}
