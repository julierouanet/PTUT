import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:equipment_management/main.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EquipmentManagementApp());

    // Verify that the dashboard is displayed
    expect(find.text('Tableau de bord'), findsOneWidget);
  });
}
