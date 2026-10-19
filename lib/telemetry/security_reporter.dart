import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import '../security/local_integrity.dart';

abstract interface class SecurityReporter {
  Future<void> finding(IntegrityResult result, String trigger);
  Future<void> event(String category);
  Future<void> nonFatal();
  void crash();
}

/// Reporting is best effort: telemetry must never prevent a block or retry UI.
class CrashlyticsReporter implements SecurityReporter {
  CrashlyticsReporter({required this.enabled});
  final bool enabled;

  Future<void> _safely(
    Future<void> Function(FirebaseCrashlytics) action,
  ) async {
    if (!enabled) return;
    try {
      await action(
        FirebaseCrashlytics.instance,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      debugPrint('Crashlytics reporting unavailable.');
    }
  }

  @override
  Future<void> finding(IntegrityResult result, String trigger) => _safely((
    crashlytics,
  ) async {
    await crashlytics.log(
      'integrity_check trigger=$trigger verdict=${result.verdict.name} simulated=${result.simulated} signals=${result.signals.join(',')}',
    );
    if (result.verdict != IntegrityVerdict.clear) {
      await crashlytics.recordError(
        StateError(
          result.simulated
              ? 'workshop_simulated_integrity_finding'
              : 'device_integrity_finding',
        ),
        StackTrace.current,
        reason: 'Local integrity observation',
        information: [
          'trigger=$trigger',
          'verdict=${result.verdict.name}',
          'simulated=${result.simulated}',
          'signals=${result.signals.join(',')}',
        ],
        fatal: false,
      );
    }
  });

  @override
  Future<void> event(String category) => _safely((c) => c.log(category));
  @override
  Future<void> nonFatal() => _safely(
    (c) => c.recordError(
      StateError('workshop_intentional_non_fatal'),
      StackTrace.current,
      fatal: false,
    ),
  );
  @override
  void crash() {
    if (enabled) FirebaseCrashlytics.instance.crash();
  }
}
