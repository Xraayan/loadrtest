import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loadr/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the auth gate while resolving the start screen',
      (tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const LoadRApp());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
