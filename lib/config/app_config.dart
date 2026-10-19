import 'package:flutter/foundation.dart';

/// Compile-time configuration: flutter run --dart-define-from-file=.env
/// Values in a mobile binary are public. Never put server secrets here.
class AppConfig {
  const AppConfig({
    this.firebaseEnabled = false,
    this.debugAppCheck = true,
    this.crashlyticsEnabled = true,
    this.testControls = true,
    this.apiBaseUrl = '',
    this.gifUrl = 'https://media.giphy.com/media/Vuw9m5wXviFIQ/giphy.gif',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    firebaseEnabled: bool.fromEnvironment('FIREBASE_ENABLED'),
    debugAppCheck: bool.fromEnvironment('APP_CHECK_DEBUG', defaultValue: true),
    crashlyticsEnabled: bool.fromEnvironment(
      'CRASHLYTICS_ENABLED',
      defaultValue: true,
    ),
    testControls: bool.fromEnvironment(
      'ENABLE_TEST_CONTROLS',
      defaultValue: kDebugMode,
    ),
    apiBaseUrl: String.fromEnvironment('API_BASE_URL'),
    gifUrl: String.fromEnvironment(
      'RICK_ASTLEY_GIF_URL',
      defaultValue: 'https://media.giphy.com/media/Vuw9m5wXviFIQ/giphy.gif',
    ),
  );

  final bool firebaseEnabled;
  final bool debugAppCheck;
  final bool crashlyticsEnabled;
  final bool testControls;
  final String apiBaseUrl;
  final String gifUrl;

  void validate() {
    if (firebaseEnabled && debugAppCheck && kReleaseMode) {
      throw const FormatException(
        'Set APP_CHECK_DEBUG=false for release builds.',
      );
    }
    if (apiBaseUrl.isNotEmpty) {
      final uri = Uri.tryParse(apiBaseUrl);
      if (uri == null ||
          uri.scheme != 'https' ||
          uri.host.isEmpty ||
          uri.userInfo.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment) {
        throw const FormatException(
          'API_BASE_URL must be an HTTPS URL without credentials, query or fragment.',
        );
      }
    }
  }
}
