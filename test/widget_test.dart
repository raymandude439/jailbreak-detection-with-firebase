import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jailbreak_detection_with_firebase/config/app_config.dart';
import 'package:jailbreak_detection_with_firebase/features/workshop/workshop_controller.dart';
import 'package:jailbreak_detection_with_firebase/main.dart';
import 'workshop_test.dart' show Detector, Tokens, Reporter;

void main() {
  testWidgets(
    'dashboard runs local check at launch without claiming server approval',
    (tester) async {
      final controller = WorkshopController(
        config: const AppConfig(),
        detector: Detector(),
        tokens: Tokens(),
        reporter: Reporter(),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        WorkshopApp(
          controller: controller,
          firebaseStatus: 'Firebase disabled',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('App Integrity Lab'), findsOneWidget);
      expect(find.text('Disabled • no token created'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Simulate root'),
        200,
        scrollable: find.byType(Scrollable),
      );
      expect(find.text('Simulate root'), findsOneWidget);
      expect(controller.phase, WorkshopPhase.localOnly);
      await tester.tap(find.text('Simulate root'));
      await tester.pumpAndSettle();
      expect(find.text('Ooops you are jailbroken/rooted'), findsOneWidget);
      expect(find.text('End simulation and recheck device'), findsOneWidget);
      expect(controller.blocked, true);
    },
  );
}
