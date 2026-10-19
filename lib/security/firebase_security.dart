import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

abstract interface class AppCheckTokens {
  Future<String> token({bool forceRefresh = false});
}

class FirebaseSecurity implements AppCheckTokens {
  FirebaseSecurity(this.config);
  final AppConfig config;
  bool ready = false;
  bool crashlyticsReady = false;
  bool _appCheckActivated = false;
  String status = 'Firebase disabled • local workshop mode';

  Future<void> initialize() async {
    if (!config.firebaseEnabled) return;
    try {
      // Uses each attendee's native google-services.json / GoogleService-Info.plist.
      await Firebase.initializeApp().timeout(const Duration(seconds: 20));
      ready = true;
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
        config.crashlyticsEnabled,
      );
      crashlyticsReady = config.crashlyticsEnabled;
      if (crashlyticsReady) {
        FlutterError.onError = (details) {
          FlutterError.presentError(details);
          FirebaseCrashlytics.instance.recordFlutterFatalError(details);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          return true;
        };
      }
      status = 'Firebase ready';
    } catch (_) {
      status = 'Firebase setup unavailable • check your native configuration';
    }
  }

  @override
  Future<String> token({bool forceRefresh = false}) async {
    if (!ready) throw StateError('Firebase is not ready.');
    if (!_appCheckActivated) {
      await FirebaseAppCheck.instance
          .activate(
            providerAndroid: config.debugAppCheck
                ? const AndroidDebugProvider()
                : const AndroidPlayIntegrityProvider(),
            providerApple: config.debugAppCheck
                ? const AppleDebugProvider()
                : const AppleAppAttestWithDeviceCheckFallbackProvider(),
          )
          .timeout(const Duration(seconds: 20));
      await FirebaseAppCheck.instance.setTokenAutoRefreshEnabled(true);
      _appCheckActivated = true;
    }
    final value = await FirebaseAppCheck.instance
        .getToken(forceRefresh)
        .timeout(const Duration(seconds: 20));
    if (value == null || value.trim().isEmpty) {
      throw StateError('App Check token unavailable.');
    }
    return value;
  }
}
