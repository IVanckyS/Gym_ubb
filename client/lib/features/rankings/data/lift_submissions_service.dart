import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../shared/services/api_client.dart';

class LiftSubmissionsService {
  Map<String, dynamic> _unwrap(http.Response res) {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (body['data'] ?? body) as Map<String, dynamic>;
    }
    final error = body['error'] as Map<String, dynamic>?;
    throw Exception(error?['message'] as String? ?? 'Error desconocido');
  }

  /// Crea una nueva postulación al ranking.
  Future<Map<String, dynamic>> create(Map<String, dynamic> data) async {
    final res = await ApiClient.instance
        .post('${ApiConstants.baseUrl}${ApiConstants.liftSubmissions}', body: data);
    return _unwrap(res)['submission'] as Map<String, dynamic>;
  }

  /// Lista postulaciones. [status]: pending|approved|rejected. [userId]: filtrar por usuario.
  Future<List<Map<String, dynamic>>> list({
    String? status,
    String? userId,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.liftSubmissions}')
        .replace(queryParameters: {
      if (status != null) 'status': status,
      if (userId != null) 'user_id': userId,
    });
    final res = await ApiClient.instance.get(uri.toString());
    final data = _unwrap(res);
    return (data['submissions'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Detalle de una postulación con imágenes.
  Future<Map<String, dynamic>> getOne(String id) async {
    final res = await ApiClient.instance
        .get('${ApiConstants.baseUrl}${ApiConstants.liftSubmission(id)}');
    return _unwrap(res)['submission'] as Map<String, dynamic>;
  }

  /// Aprobar una postulación (admin/professor/staff).
  Future<Map<String, dynamic>> approve(String id) async {
    final res = await ApiClient.instance
        .post('${ApiConstants.baseUrl}${ApiConstants.liftSubmissionApprove(id)}');
    return _unwrap(res)['submission'] as Map<String, dynamic>;
  }

  /// Rechazar con motivo obligatorio.
  Future<Map<String, dynamic>> reject(String id, String comment) async {
    final res = await ApiClient.instance.post(
      '${ApiConstants.baseUrl}${ApiConstants.liftSubmissionReject(id)}',
      body: {'reviewComment': comment},
    );
    return _unwrap(res)['submission'] as Map<String, dynamic>;
  }

  /// Rankings públicos (levantamientos aprobados).
  Future<List<Map<String, dynamic>>> rankings({
    String? exerciseId,
    int reps = 1,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.liftRankings}')
        .replace(queryParameters: {
      if (exerciseId != null) 'exercise_id': exerciseId,
      'reps': '$reps',
    });
    final res = await ApiClient.instance.get(uri.toString());
    final data = _unwrap(res);
    return (data['rankings'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Récords actuales (el mayor peso aprobado por ejercicio).
  Future<List<Map<String, dynamic>>> records() async {
    final res = await ApiClient.instance
        .get('${ApiConstants.baseUrl}${ApiConstants.liftRecords}');
    final data = _unwrap(res);
    return (data['records'] as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Lista ejercicios rankeables.
  Future<List<Map<String, dynamic>>> rankeableExercises() async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.listExercises}',
    ).replace(queryParameters: {'rankeable': 'true'});
    final res = await ApiClient.instance.get(uri.toString());
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final data = (body['data'] ?? body) as Map<String, dynamic>;
    return (data['exercises'] as List? ?? []).cast<Map<String, dynamic>>();
  }
}
