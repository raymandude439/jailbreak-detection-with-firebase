import 'dart:io';
import 'package:jailbreak_root_detection/jailbreak_root_detection.dart';

enum IntegrityVerdict { clear, compromised, inconclusive }

class IntegrityResult {
  const IntegrityResult(
    this.verdict, {
    this.signals = const [],
    this.simulated = false,
  });
  final IntegrityVerdict verdict;
  final List<String> signals;
  final bool simulated;
  bool get compromised => verdict == IntegrityVerdict.compromised;
  Map<String, Object> toJson() => {
    'verdict': verdict.name,
    'signals': signals,
    'simulated': simulated,
    'platform': Platform.operatingSystem,
  };
}

abstract interface class IntegrityDetector {
  Future<IntegrityResult> check();
}

class LocalIntegrityDetector implements IntegrityDetector {
  @override
  Future<IntegrityResult> check() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return const IntegrityResult(
        IntegrityVerdict.inconclusive,
        signals: ['unsupported_platform'],
      );
    }
    try {
      // Issue-level results avoid calling an iOS proxy alone a jailbreak.
      final issues = await JailbreakRootDetection.instance.checkForIssues
          .timeout(const Duration(seconds: 8));
      const blocking = {
        JailbreakIssue.jailbreak,
        JailbreakIssue.fridaFound,
        JailbreakIssue.cydiaFound,
      };
      return IntegrityResult(
        issues.any(blocking.contains)
            ? IntegrityVerdict.compromised
            : issues.contains(JailbreakIssue.unknown)
            ? IntegrityVerdict.inconclusive
            : IntegrityVerdict.clear,
        signals: issues.map((issue) => issue.name).toList(),
      );
    } catch (_) {
      // A missing plugin, timeout or native error is not evidence of root.
      return const IntegrityResult(
        IntegrityVerdict.inconclusive,
        signals: ['probe_unavailable'],
      );
    }
  }
}
