import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gimie/main.dart';

void main() {
  testWidgets('renders splash screen content', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_seen_v1': false,
    });
    await tester.binding.setSurfaceSize(const Size(1080, 1920));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const GimieApp());
    await tester.pumpAndSettle();

    expect(find.text('Gimie'), findsOneWidget);
    expect(find.text('Conectando pessoas e produtos'), findsOneWidget);
    expect(find.text('Começar'), findsOneWidget);
  });
}
