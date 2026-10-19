import 'package:flutter/foundation.dart';
import '../../config/app_config.dart';
import '../../network/integrity_api.dart';
import '../../security/firebase_security.dart';
import '../../security/local_integrity.dart';
import '../../telemetry/security_reporter.dart';

enum WorkshopPhase { idle, checking, localOnly, allowed, blocked, retry }

class WorkshopController extends ChangeNotifier {
  WorkshopController({
    required this.config,
    required this.detector,
    required this.tokens,
    required this.reporter,
    this.api,
  });
  final AppConfig config;
  final IntegrityDetector detector;
  final AppCheckTokens tokens;
  final SecurityReporter reporter;
  final IntegrityApi? api;
  WorkshopPhase phase = WorkshopPhase.idle;
  IntegrityResult? local;
  String appCheckStatus = 'Not checked';
  String apiStatus = 'Not checked';
  String message = 'Run the security check to begin.';
  bool _running = false;
  bool get busy => _running;
  bool get blocked => phase == WorkshopPhase.blocked;
  bool get canCrash =>
      config.testControls &&
      config.firebaseEnabled &&
      config.crashlyticsEnabled;
  bool _disposed = false;

  void _update() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _report(Future<void> Function() action) async {
    try {
      await action().timeout(const Duration(seconds: 6));
    } catch (_) {
      /* Best effort only. */
    }
  }

  Future<void> run({String trigger = 'manual', String? simulation}) async {
    if (busy || blocked) return;
    if (simulation != null &&
        (!config.testControls || !{'jailbreak', 'root'}.contains(simulation))) {
      return;
    }
    _running = true;
    phase = WorkshopPhase.checking;
    appCheckStatus = 'Waiting for local check';
    apiStatus = 'Not checked';
    message = 'Checking local integrity…';
    _update();
    try {
      local = simulation == null
          ? await detector.check()
          : IntegrityResult(
              IntegrityVerdict.compromised,
              signals: ['simulated_$simulation'],
              simulated: true,
            );
      // Notify immediately; telemetry cannot hold up the block page.
      if (local!.compromised) {
        phase = WorkshopPhase.blocked;
        message = local!.simulated
            ? 'Workshop simulation • $simulation detected'
            : 'Local integrity signals detected';
        _update();
      }
      await _report(() => reporter.finding(local!, trigger));
      // Continue sending findings to the API even if the local guard blocked UI.
      if (!config.firebaseEnabled) {
        appCheckStatus = 'Disabled • no token created';
        apiStatus = 'Not called • Firebase disabled';
        if (!blocked) {
          phase = WorkshopPhase.localOnly;
          message = 'Local check complete. Configure Firebase to continue.';
        }
        return;
      }
      appCheckStatus = 'Acquiring token…';
      _update();
      await tokens.token();
      appCheckStatus = 'Token acquired • server verification still required';
      if (api == null) {
        apiStatus = 'Not configured • API_BASE_URL is blank';
        if (!blocked) {
          phase = WorkshopPhase.localOnly;
          message =
              'App Check ready. Deploy the sample API to get a server decision.';
        }
        return;
      }
      apiStatus = 'Awaiting server decision…';
      _update();
      final decision = await api!.evaluate(local!);
      apiStatus = decision.allow
          ? 'Server allowed request'
          : 'Server blocked request';
      if (!decision.allow) {
        phase = WorkshopPhase.blocked;
        message = 'Server integrity policy rejected this request.';
        await _report(() => reporter.event('server_integrity_rejected'));
      } else if (!blocked) {
        // A clean server decision is required; unknown local state never looks clear.
        phase = WorkshopPhase.allowed;
        message = 'The API allowed this request.';
      }
    } catch (_) {
      if (appCheckStatus.startsWith('Acquiring')) {
        appCheckStatus = 'Unavailable • retry required';
      }
      if (apiStatus.startsWith('Awaiting')) {
        apiStatus = 'Unavailable or invalid response • retry required';
      }
      if (!blocked) {
        phase = WorkshopPhase.retry;
        message =
            'Verification could not complete. Retry; access has not been granted.';
      }
      await _report(() => reporter.event('security_verification_unavailable'));
    } finally {
      _running = false;
      _update();
    }
  }

  /// Workshop reset re-runs the real check; it never clears a native finding.
  Future<void> resetSimulation() async {
    if (busy || local?.simulated != true || !config.testControls) return;
    phase = WorkshopPhase.idle;
    await run(trigger: 'simulation_reset');
  }

  Future<void> nonFatal() async {
    if (!canCrash) return;
    await _report(reporter.nonFatal);
    message =
        'Non-fatal test requested; check Crashlytics after upload.';
    _update();
  }

  Future<void> crash() async {
    if (!canCrash) return;
    await _report(() => reporter.event('workshop_intentional_native_crash'));
    reporter.crash();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
