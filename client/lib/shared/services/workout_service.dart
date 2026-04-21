import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class WorkoutException implements Exception {
  final String message;
  WorkoutException(this.message);
  @override
  String toString() => message;
}

class WorkoutService {
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
    throw WorkoutException(error?['message'] as String? ?? 'Error desconocido');
  }

  /// Inicia una sesión (o devuelve la activa si ya existe).
  /// [routineId] y [routineDayId] son opcionales para sesión libre.
  Future<Map<String, dynamic>> startSession({
    String? routineId,
    String? routineDayId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.workoutStart}');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({
        if (routineId != null) 'routineId': routineId,
        if (routineDayId != null) 'routineDayId': routineDayId,
      }),
    );
    final data = _unwrap(res);
    return data['session'] as Map<String, dynamic>;
  }

  /// Devuelve la sesión activa del usuario, o null si no hay ninguna.
  Future<Map<String, dynamic>?> getActiveSession() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.workoutActive}');
    final res = await http.get(uri, headers: await _authHeaders());
    if (res.statusCode == 404) return null;
    final data = _unwrap(res);
    return data['session'] as Map<String, dynamic>;
  }

  /// Obtiene detalle de una sesión por ID.
  Future<Map<String, dynamic>> getSession(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.workoutSession(id)}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return data['session'] as Map<String, dynamic>;
  }

  /// Registra o actualiza un set de un ejercicio.
  Future<Map<String, dynamic>> logSet({
    required String sessionId,
    required String exerciseId,
    required int setNumber,
    double? weightKg,
    int? reps,
    int? durationSeconds,
    bool completed = false,
    int? rpe,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.workoutLogSet}');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({
        'sessionId': sessionId,
        'exerciseId': exerciseId,
        'setNumber': setNumber,
        if (weightKg != null) 'weightKg': weightKg,
        if (reps != null) 'reps': reps,
        if (durationSeconds != null) 'durationSeconds': durationSeconds,
        'completed': completed,
        if (rpe != null) 'rpe': rpe,
      }),
    );
    final data = _unwrap(res);
    return data['set'] as Map<String, dynamic>;
  }

  /// Finaliza la sesión.
  /// [status]: 'completed' (todos los ejercicios) | 'partial' (terminó antes).
  /// [earlyFinishReason]: motivo si status == 'partial'.
  Future<Map<String, dynamic>> finishSession(
    String sessionId, {
    String status = 'completed',
    String? notes,
    String? earlyFinishReason,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.workoutFinish(sessionId)}');
    final res = await http.patch(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({
        'status': status,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (earlyFinishReason != null && earlyFinishReason.isNotEmpty)
          'earlyFinishReason': earlyFinishReason,
      }),
    );
    final data = _unwrap(res);
    return data['session'] as Map<String, dynamic>;
  }

  /// Cancela (elimina) la sesión activa.
  Future<void> cancelSession(String sessionId) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.workoutCancel(sessionId)}');
    final res = await http.delete(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      throw WorkoutException(error?['message'] as String? ?? 'Error al cancelar sesión');
    }
  }

  /// Estado semanal de cada día de una rutina.
  /// Retorna { "<routineDayId>": "completed" | "partial" } — días sin sesión no aparecen.
  Future<Map<String, String>> getWeekStatus(String routineId) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/workout/week-status')
        .replace(queryParameters: {'routineId': routineId});
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    final raw = data['days'] as Map<String, dynamic>? ?? {};
    return raw.map((k, v) => MapEntry(k, v as String));
  }

  /// Devuelve el historial de sesiones finalizadas.
  Future<Map<String, dynamic>> getHistory({int limit = 20, int offset = 0}) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.workoutHistory}',
    ).replace(queryParameters: {
      'limit': '$limit',
      'offset': '$offset',
    });
    final res = await http.get(uri, headers: await _authHeaders());
    return _unwrap(res);
  }
}
