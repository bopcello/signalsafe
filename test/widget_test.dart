import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:signalsafe/main.dart';
import 'package:signalsafe/scoring/forest.dart';

void main() {
  testWidgets('SignalSafeApp renders dashboard and branding smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final modelFile = File('assets/model.json');
    if (modelFile.existsSync()) {
      ForestEvaluator.fromJsonString(modelFile.readAsStringSync());
    }

    await tester.pumpWidget(const SignalSafeApp());
    await tester.pumpAndSettle();

    // Verifies SignalSafe brand emblem renders
    expect(find.text('SIGNALSAFE'), findsOneWidget);
    // In unauthenticated state, AuthScreen is rendered with Sign In / Account creation
    expect(find.text('Sign In'), findsWidgets);
  });
}
