import 'package:flutter_test/flutter_test.dart';

import 'package:equipment_management/main.dart';
import 'package:equipment_management/services/auth_service.dart';

void main() {
  testWidgets('App loads correctly', (WidgetTester tester) async {
    // Initialize auth service (normally done in main())
    AuthService().initDemo();

    // Build our app and trigger a frame.
    await tester.pumpWidget(const EquipmentManagementApp());

    // Verify that the dashboard is displayed
    expect(find.text('Tableau de bord'), findsWidgets);
  });
}
