import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'api_client.dart';

class AuthService {
  // ── Tokens ──────────────────────────────────────────────────────────────────

  Future<String?> getAccessToken() => ApiClient.instance.getAccessToken();
  Future<String?> getRefreshToken() => ApiClient.instance.getRefreshToken();

  Future<void> _saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await ApiClient.instance.saveTokens(accessToken, refreshToken);
  }

  Future<void> clearTokens() async {
    await ApiClient.instance.clearTokens();
  }

  // ── Login ────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.login}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode == 200) {
      final data = (body['data'] ?? body) as Map<String, dynamic>;
      await _saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return data['user'] as Map<String, dynamic>;
    }

    final error = body['error'] as Map<String, dynamic>?;
    throw AuthException(
      code: error?['code'] as String? ?? 'unknown',
      message: error?['message'] as String? ?? 'Error desconocido',
    );
  }

  // ── Logout ───────────────────────────────────────────────────────────────────

  Future<void> logout() async {
    final token = await getAccessToken();
    if (token != null) {
      await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.logout}'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
    }
    await clearTokens();
    ApiClient.instance.resetSessionExpiredFlag();
  }

  // ── Refresh ──────────────────────────────────────────────────────────────────

  Future<bool> refreshAccessToken() => ApiClient.instance.forceRefresh();

  // ── Me ───────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> getMe() async {
    final res = await ApiClient.instance
        .get('${ApiConstants.baseUrl}${ApiConstants.me}');

    if (res.statusCode == 200) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['data'] as Map<String, dynamic>;
    }

    return null;
  }

  // ── Registro con verificación por email ──────────────────────────────────────

  /// Paso 1: envía el código de verificación al correo.
  Future<void> registerRequest({
    required String email,
    required String password,
    required String name,
    String? career,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.registerRequest}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'name': name,
        if (career != null && career.isNotEmpty) 'career': career,
      }),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) return;

    final error = body['error'] as Map<String, dynamic>?;
    throw AuthException(
      code: error?['code'] as String? ?? 'unknown',
      message: error?['message'] as String? ?? 'Error desconocido',
    );
  }

  /// Paso 2: verifica el código y crea la cuenta. Retorna el user map y guarda tokens.
  Future<Map<String, dynamic>> registerVerify({
    required String email,
    required String code,
  }) async {
    final res = await http.post(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.registerVerify}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'code': code}),
    );

    final body = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = (body['data'] ?? body) as Map<String, dynamic>;
      await _saveTokens(
        accessToken: data['accessToken'] as String,
        refreshToken: data['refreshToken'] as String,
      );
      return data['user'] as Map<String, dynamic>;
    }

    final error = body['error'] as Map<String, dynamic>?;
    throw AuthException(
      code: error?['code'] as String? ?? 'unknown',
      message: error?['message'] as String? ?? 'Error desconocido',
    );
  }

  // ── Validación email UBB ─────────────────────────────────────────────────────

  static bool isValidUbbEmail(String email) {
    final lower = email.toLowerCase().trim();
    return lower.endsWith('@alumnos.ubiobio.cl') ||
        lower.endsWith('@ubiobio.cl');
  }
}

class AuthException implements Exception {
  final String code;
  final String message;

  const AuthException({required this.code, required this.message});

  @override
  String toString() => message;
}
