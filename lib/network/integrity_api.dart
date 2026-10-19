import 'package:dio/dio.dart';
import '../security/firebase_security.dart';
import '../security/local_integrity.dart';

class ApiDecision {
  const ApiDecision({required this.allow, required this.reason});
  final bool allow;
  final String reason;
  factory ApiDecision.fromJson(dynamic data) {
    if (data is! Map || data['allow'] is! bool || data['reason'] is! String) {
      throw const FormatException('Invalid API decision.');
    }
    return ApiDecision(
      allow: data['allow'] as bool,
      reason: data['reason'] as String,
    );
  }
}

abstract interface class IntegrityApi {
  Future<ApiDecision> evaluate(IntegrityResult result);
}

/// One client for one trusted HTTPS origin; tokens never follow redirects.
class AppCheckInterceptor extends Interceptor {
  AppCheckInterceptor({required this.origin, required this.tokens});
  final Uri origin;
  final AppCheckTokens tokens;
  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers.removeWhere(
      (key, _) => key.toLowerCase() == 'x-firebase-appcheck',
    );
    try {
      final uri = options.uri;
      if (uri.scheme != 'https' ||
          uri.host != origin.host ||
          uri.port != origin.port ||
          uri.userInfo.isNotEmpty) {
        throw StateError('Untrusted API origin.');
      }
      options.followRedirects = false;
      options.headers['X-Firebase-AppCheck'] = await tokens.token();
      handler.next(options);
    } catch (_) {
      handler.reject(
        DioException(
          requestOptions: options,
          message: 'Security verification unavailable. Retry the check.',
        ),
      );
    }
  }
}

class DioIntegrityApi implements IntegrityApi {
  DioIntegrityApi({
    required String baseUrl,
    required AppCheckTokens tokens,
    Dio? client,
  }) : dio = client ?? Dio() {
    dio.options = BaseOptions(
      baseUrl: baseUrl.endsWith('/') ? baseUrl : '$baseUrl/',
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      followRedirects: false,
    );
    dio.interceptors.add(
      AppCheckInterceptor(origin: Uri.parse(baseUrl), tokens: tokens),
    );
  }
  final Dio dio;
  @override
  Future<ApiDecision> evaluate(IntegrityResult result) async {
    final response = await dio.post<dynamic>(
      'integrity',
      data: {'local': result.toJson()},
    );
    return ApiDecision.fromJson(response.data);
  }
}
