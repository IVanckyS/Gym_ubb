import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class HistoryException implements Exception {
  final String message;
  HistoryException(this.message);
  @override
  String toString() => message;
}

class HistoryService {
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
    throw HistoryException(error?['message'] as String? ?? 'Error desconocido');
  }

  /// Ejercicios que el usuario ha entrenado al menos una vez.
  Future<List<Map<String, dynamic>>> getTrainedExercises() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.historyTrainedExercises}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return (data['exercises'] as List).cast<Map<String, dynamic>>();
  }

  /// Progreso de un ejercicio a lo largo del tiempo.
  Future<Map<String, dynamic>> getExerciseProgress(String exerciseId, {int limit = 20}) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.historyProgress(exerciseId)}',
    ).replace(queryParameters: {'limit': '$limit'});
    final res = await http.get(uri, headers: await _authHeaders());
    return _unwrap(res);
  }

  /// Récords personales del usuario.
  Future<List<Map<String, dynamic>>> getPersonalRecords() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.historyRecords}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return (data['records'] as List).cast<Map<String, dynamic>>();
  }

  /// Medidas corporales del usuario.
  Future<List<Map<String, dynamic>>> getMeasurements({int limit = 30}) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.historyMeasurements}',
    ).replace(queryParameters: {'limit': '$limit'});
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return (data['measurements'] as List).cast<Map<String, dynamic>>();
  }

  /// Registra una nueva medida corporal.
  Future<Map<String, dynamic>> createMeasurement({
    String? measuredAt,
    double? weightKg,
    double? bodyFatPct,
    double? chestCm,
    double? waistCm,
    double? hipCm,
    double? armCm,
    double? legCm,
    String? notes,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.historyMeasurements}');
    final res = await http.post(
      uri,
      headers: await _authHeaders(),
      body: jsonEncode({
        if (measuredAt != null) 'measuredAt': measuredAt,
        if (weightKg != null) 'weightKg': weightKg,
        if (bodyFatPct != null) 'bodyFatPct': bodyFatPct,
        if (chestCm != null) 'chestCm': chestCm,
        if (waistCm != null) 'waistCm': waistCm,
        if (hipCm != null) 'hipCm': hipCm,
        if (armCm != null) 'armCm': armCm,
        if (legCm != null) 'legCm': legCm,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      }),
    );
    final data = _unwrap(res);
    return data['measurement'] as Map<String, dynamic>;
  }

  /// Elimina una medida corporal.
  Future<void> deleteMeasurement(String id) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.historyDeleteMeasurement(id)}',
    );
    final res = await http.delete(uri, headers: await _authHeaders());
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final error = body['error'] as Map<String, dynamic>?;
      throw HistoryException(error?['message'] as String? ?? 'Error al eliminar');
    }
  }
}
