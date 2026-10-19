import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jailbreak_detection_with_firebase/config/app_config.dart';
import 'package:jailbreak_detection_with_firebase/features/workshop/workshop_controller.dart';
import 'package:jailbreak_detection_with_firebase/network/integrity_api.dart';
import 'package:jailbreak_detection_with_firebase/security/firebase_security.dart';
import 'package:jailbreak_detection_with_firebase/security/local_integrity.dart';
import 'package:jailbreak_detection_with_firebase/telemetry/security_reporter.dart';

class Detector implements IntegrityDetector {
  Detector([this.result = const IntegrityResult(IntegrityVerdict.clear)]);
  IntegrityResult result;
  @override
  Future<IntegrityResult> check() async => result;
}

class Tokens implements AppCheckTokens {
  bool fail = false;
  int calls = 0;
  @override
  Future<String> token({bool forceRefresh = false}) async {
    calls++;
    if (fail) throw StateError('offline');
    return 'test-attestation';
  }
}

class Reporter implements SecurityReporter {
  final findings = <IntegrityResult>[];
  bool fail = false;
  @override
  Future<void> finding(IntegrityResult result, String trigger) async {
    findings.add(result);
    if (fail) throw StateError('telemetry failed');
  }

  @override
  Future<void> event(String category) async {}
  @override
  Future<void> nonFatal() async {}
  @override
  void crash() {}
}

class Api implements IntegrityApi {
  Api({this.allow = true});
  final bool allow;
  bool fail = false;
  IntegrityResult? received;
  Completer<ApiDecision>? pending;
  @override
  Future<ApiDecision> evaluate(IntegrityResult result) async {
    received = result;
    if (fail) throw const FormatException('invalid');
    if (pending != null) return pending!.future;
    return ApiDecision(allow: allow, reason: 'test');
  }
}

class Adapter implements HttpClientAdapter {
  int calls = 0;
  RequestOptions? request;
  String body = '{"allow":true,"reason":"verified"}';
  int status = 200;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    request = options;
    return ResponseBody.fromString(
      body,
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late Detector detector;
  late Tokens tokens;
  late Reporter reporter;
  late Api api;
  WorkshopController controller({
    bool firebase = true,
    bool controls = true,
    bool withApi = true,
  }) => WorkshopController(
    config: AppConfig(firebaseEnabled: firebase, testControls: controls),
    detector: detector,
    tokens: tokens,
    reporter: reporter,
    api: withApi ? api : null,
  );
  setUp(() {
    detector = Detector();
    tokens = Tokens();
    reporter = Reporter();
    api = Api();
  });

  test('only server allow produces allowed state', () async {
    final c = controller();
    await c.run();
    expect(c.phase, WorkshopPhase.allowed);
    expect(api.received!.verdict, IntegrityVerdict.clear);
  });
  test('disabled Firebase and blank API never imply server approval', () async {
    final local = controller(firebase: false);
    await local.run();
    expect(local.phase, WorkshopPhase.localOnly);
    expect(tokens.calls, 0);
    final noApi = controller(withApi: false);
    await noApi.run();
    expect(noApi.phase, WorkshopPhase.localOnly);
  });
  test('root and jailbreak simulation are labelled and reported', () async {
    for (final kind in ['root', 'jailbreak']) {
      final c = controller();
      await c.run(simulation: kind);
      expect(c.phase, WorkshopPhase.blocked);
      expect(reporter.findings.last.simulated, true);
      expect(api.received!.signals, ['simulated_$kind']);
    }
  });
  test(
    'reporter failure cannot erase local block; API still receives finding',
    () async {
      detector.result = const IntegrityResult(
        IntegrityVerdict.compromised,
        signals: ['jailbreak'],
      );
      reporter.fail = true;
      final c = controller();
      await c.run();
      expect(c.blocked, true);
      expect(api.received!.compromised, true);
      await c.resetSimulation();
      expect(c.blocked, true);
    },
  );
  test(
    'token failure causes retry and no API call, not jailbreak accusation',
    () async {
      tokens.fail = true;
      final c = controller();
      await c.run();
      expect(c.phase, WorkshopPhase.retry);
      expect(c.blocked, false);
      expect(api.received, null);
    },
  );
  test('server can block a locally clean device', () async {
    api = Api(allow: false);
    final c = controller();
    await c.run();
    expect(c.blocked, true);
    expect(c.local!.compromised, false);
  });
  test('invalid server response cannot grant access', () async {
    api.fail = true;
    final c = controller();
    await c.run();
    expect(c.phase, WorkshopPhase.retry);
  });
  test(
    'blocked state remains while reporting is pending; no overlapping reset',
    () async {
      api.pending = Completer<ApiDecision>();
      final c = controller();
      final running = c.run(simulation: 'root');
      await Future<void>.delayed(Duration.zero);
      expect(c.blocked, true);
      expect(c.busy, true);
      await c.resetSimulation();
      expect(c.local!.simulated, true);
      api.pending!.complete(const ApiDecision(allow: true, reason: 'test'));
      await running;
      expect(c.blocked, true);
      expect(c.busy, false);
      api.pending = null;
      await c.resetSimulation();
      expect(c.local!.simulated, false);
      expect(c.phase, WorkshopPhase.allowed);
    },
  );
  test('test controls disabled prevents simulated findings', () async {
    final c = controller(controls: false);
    await c.run(simulation: 'root');
    expect(c.phase, WorkshopPhase.idle);
    expect(reporter.findings, isEmpty);
  });
  test('configuration only accepts trusted HTTPS base URLs', () {
    for (final url in [
      'http://api.test',
      'https://user:pass@api.test',
      'https://api.test?token=a',
      'invalid',
    ]) {
      expect(
        () => AppConfig(apiBaseUrl: url).validate(),
        throwsFormatException,
      );
    }
    expect(
      () => const AppConfig(
        apiBaseUrl: 'https://api.test/workshopApi',
      ).validate(),
      returnsNormally,
    );
  });
  test('API attaches token and disables redirects', () async {
    final adapter = Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final client = DioIntegrityApi(
      baseUrl: 'https://api.test/workshopApi',
      tokens: tokens,
      client: dio,
    );
    expect((await client.evaluate(detector.result)).allow, true);
    expect(
      adapter.request!.uri.toString(),
      'https://api.test/workshopApi/integrity',
    );
    expect(adapter.request!.headers['X-Firebase-AppCheck'], 'test-attestation');
    expect(adapter.request!.followRedirects, false);
    expect((adapter.request!.data as Map)['local']['simulated'], false);
  });
  test('API fails closed without token and rejects a foreign origin', () async {
    final adapter = Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    DioIntegrityApi(baseUrl: 'https://api.test', tokens: tokens, client: dio);
    tokens.fail = true;
    await expectLater(
      dio.post<dynamic>('integrity'),
      throwsA(isA<DioException>()),
    );
    tokens.fail = false;
    await expectLater(
      dio.post<dynamic>('https://evil.test/integrity'),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 0);
  });
  test('API refuses redirect and malformed decision', () async {
    final adapter = Adapter();
    final dio = Dio()..httpClientAdapter = adapter;
    final client = DioIntegrityApi(
      baseUrl: 'https://api.test',
      tokens: tokens,
      client: dio,
    );
    adapter.status = 302;
    await expectLater(
      client.evaluate(detector.result),
      throwsA(isA<DioException>()),
    );
    expect(adapter.calls, 1);
    adapter.status = 200;
    adapter.body = '{"allow":"true","reason":"bad"}';
    await expectLater(client.evaluate(detector.result), throwsFormatException);
  });
}
