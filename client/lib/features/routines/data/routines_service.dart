import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../shared/services/auth_service.dart';

class RoutinesService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _unwrap(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (body['data'] ?? body) as Map<String, dynamic>;
    }
    final error = body['error'] as Map<String, dynamic>?;
    throw RoutinesException(error?['message'] as String? ?? 'Error desconocido');
  }

  /// Devuelve { myRoutines: [...], publicRoutines: [...] }
  Future<Map<String, dynamic>> listRoutines() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.listRoutines}');
    final res = await http.get(uri, headers: await _authHeaders());
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> getRoutine(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.getRoutine(id)}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return data['routine'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> createRoutine({
    required String name,
    required String goal,
    String? description,
    bool isPublic = false,
    required List<Map<String, dynamic>> days,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createRoutine}');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({
        'name': name,
        'goal': goal,
        if (description != null && description.isNotEmpty) 'description': description,
        'isPublic': isPublic,
        'days': days,
      }),
    );
    final data = _unwrap(res);
    return data['routine'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateRoutine({
    required String id,
    required String name,
    required String goal,
    String? description,
    bool isPublic = false,
    required List<Map<String, dynamic>> days,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.updateRoutine(id)}');
    final res = await http.patch(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({
        'name': name,
        'goal': goal,
        'description': description ?? '',
        'isPublic': isPublic,
        'days': days,
      }),
    );
    final data = _unwrap(res);
    return data['routine'] as Map<String, dynamic>;
  }

  Future<void> deleteRoutine(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deleteRoutine(id)}');
    final res = await http.delete(uri, headers: await _authHeaders());
    _unwrap(res);
  }

  Future<void> setDefault(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.setDefaultRoutine(id)}');
    final res = await http.patch(uri, headers: await _authHeaders());
    _unwrap(res);
  }

  Future<Map<String, dynamic>> copyRoutine(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.copyRoutine(id)}');
    final res = await http.post(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return data['routine'] as Map<String, dynamic>;
  }

  /// Devuelve la rutina por defecto completa (con días), o null si no hay.
  Future<Map<String, dynamic>?> getMyDefault() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myDefaultRoutine}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return data['routine'] as Map<String, dynamic>?;
  }
}

class RoutinesException implements Exception {
  final String message;
  const RoutinesException(this.message);
  @override
  String toString() => message;
}
