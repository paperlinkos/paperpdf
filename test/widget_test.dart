import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paperlink_pdf/main.dart';

void main() {
  testWidgets('PaperLink PDF home screen renders branding and Create PDF button', (WidgetTester tester) async {
    await tester.pumpWidget(const PaperLinkApp());
    await tester.pump(const Duration(milliseconds: 500));

    // Verify app title branding
    expect(find.text('PaperLink PDF'), findsWidgets);

    // Verify Create PDF primary button
    expect(find.text('Create PDF'), findsOneWidget);

    // Verify Recent PDFs section title
    expect(find.text('Recent PDFs'), findsOneWidget);
  });
}
