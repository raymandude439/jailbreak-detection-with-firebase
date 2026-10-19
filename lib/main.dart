import 'package:flutter/material.dart';
import 'config/app_config.dart';
import 'features/workshop/workshop_controller.dart';
import 'features/workshop/workshop_page.dart';
import 'network/integrity_api.dart';
import 'security/firebase_security.dart';
import 'security/local_integrity.dart';
import 'telemetry/security_reporter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = AppConfig.fromEnvironment();
  try {
    config.validate();
  } on FormatException catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Configuration error: ${error.message}'),
            ),
          ),
        ),
      ),
    );
    return;
  }
  final firebase = FirebaseSecurity(config);
  await firebase.initialize();
  final controller = WorkshopController(
    config: config,
    detector: LocalIntegrityDetector(),
    tokens: firebase,
    reporter: CrashlyticsReporter(enabled: firebase.crashlyticsReady),
    api: config.apiBaseUrl.isEmpty
        ? null
        : DioIntegrityApi(baseUrl: config.apiBaseUrl, tokens: firebase),
  );
  runApp(
    WorkshopApp(
      controller: controller,
      firebaseStatus: firebase.status,
      crashlyticsReady: firebase.crashlyticsReady,
    ),
  );
}

class WorkshopApp extends StatelessWidget {
  const WorkshopApp({
    super.key,
    required this.controller,
    required this.firebaseStatus,
    this.crashlyticsReady = false,
  });
  final WorkshopController controller;
  final String firebaseStatus;
  final bool crashlyticsReady;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'App Integrity Lab',
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff176b54)),
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xfff5f7f5),
    ),
    home: WorkshopPage(
      controller: controller,
      firebaseStatus: firebaseStatus,
      crashlyticsReady: crashlyticsReady,
    ),
  );
}
