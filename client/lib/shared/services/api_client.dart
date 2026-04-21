import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';

/// Clave global del Navigator para mostrar dialogs fuera del árbol de widgets.
final navigatorKey = GlobalKey<NavigatorState>();

/// Cliente HTTP centralizado con auto-refresh de tokens y logout automático.
///
/// Uso: `ApiClient.instance.get(url, auth: true)`
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  static const _storage = FlutterSecureStorage();
  static const _keyAccess = 'access_token';
  static const _keyRefresh = 'refresh_token';

  bool _refreshing = false;
  bool _sessionExpiredShown = false;

  // ── Token helpers ─────────────────────────────────────────────────────────

  Future<String?> getAccessToken() => _storage.read(key: _keyAccess);
  Future<String?> getRefreshToken() => _storage.read(key: _keyRefresh);

  Future<void> saveTokens(String access, String refresh) async {
    await _storage.write(key: _keyAccess, value: access);
    await _storage.write(key: _keyRefresh, value: refresh);
  }

  Future<void> clearTokens() async {
    await _storage.delete(key: _keyAccess);
    await _storage.delete(key: _keyRefresh);
  }

  // ── Request helpers ───────────────────────────────────────────────────────

  Future<Map<String, String>> _authHeaders() async {
    final token = await getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ── Métodos públicos ──────────────────────────────────────────────────────

  Future<http.Response> get(String url) async =>
      _withRetry(() async => http.get(Uri.parse(url), headers: await _authHeaders()));

  Future<http.Response> post(String url, {Map<String, dynamic>? body}) async =>
      _withRetry(() async => http.post(
            Uri.parse(url),
            headers: await _authHeaders(),
            body: body != null ? jsonEncode(body) : null,
          ));

  Future<http.Response> patch(String url, {Map<String, dynamic>? body}) async =>
      _withRetry(() async => http.patch(
            Uri.parse(url),
            headers: await _authHeaders(),
            body: body != null ? jsonEncode(body) : null,
          ));

  Future<http.Response> delete(String url) async =>
      _withRetry(() async => http.delete(Uri.parse(url), headers: await _authHeaders()));

  // ── Multipart (no necesita retry de auth — manejo manual en quien llame) ─

  Future<http.StreamedResponse> sendMultipart(http.MultipartRequest req) async {
    final token = await getAccessToken();
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    return req.send();
  }

  // ── Core: interceptor 401 → refresh → retry ──────────────────────────────

  Future<http.Response> _withRetry(
    Future<http.Response> Function() call,
  ) async {
    final response = await call();
    if (response.statusCode != 401) return response;

    // Evitar refresh concurrente
    if (_refreshing) {
      // Esperar y reintentar con el nuevo token que ya se está obteniendo
      await Future.delayed(const Duration(milliseconds: 400));
      return call();
    }

    _refreshing = true;
    final refreshed = await _tryRefresh();
    _refreshing = false;

    if (refreshed) return call();

    // Refresh falló → sesión expirada
    await clearTokens();
    _showSessionExpiredDialog();
    return response; // devuelve el 401 original para que el caller lo maneje
  }

  Future<bool> _tryRefresh() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) return false;

    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.refresh}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refreshToken': refreshToken}),
      );
      if (res.statusCode == 200) {
        final data =
            (jsonDecode(res.body) as Map<String, dynamic>)['data'] as Map<String, dynamic>;
        await saveTokens(
          data['accessToken'] as String,
          data['refreshToken'] as String,
        );
        return true;
      }
    } catch (_) {}
    return false;
  }

  void _showSessionExpiredDialog() {
    if (_sessionExpiredShown) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    _sessionExpiredShown = true;

    showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Sesión expirada'),
        content: const Text(
          'Tu sesión ha expirado. Por favor, inicia sesión de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              _sessionExpiredShown = false;
              Navigator.of(ctx, rootNavigator: true).pop();
              Navigator.of(ctx, rootNavigator: true)
                  .pushNamedAndRemoveUntil('/login', (_) => false);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  /// Intenta refrescar el token manualmente (usado por AuthService).
  Future<bool> forceRefresh() => _tryRefresh();

  /// Llama esto al hacer logout manual para resetear el flag.
  void resetSessionExpiredFlag() => _sessionExpiredShown = false;
}
