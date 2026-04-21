import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class RankingsException implements Exception {
  final String message;
  RankingsException(this.message);
  @override
  String toString() => message;
}

class RankingsService {
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
    throw RankingsException(error?['message'] as String? ?? 'Error desconocido');
  }

  /// Ejercicios disponibles para ver rankings.
  Future<List<Map<String, dynamic>>> getExercises() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.rankingsExercises}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return (data['exercises'] as List).cast<Map<String, dynamic>>();
  }

  /// Tabla de líderes para un ejercicio y número de reps.
  Future<Map<String, dynamic>> getLeaderboard(
    String exerciseId, {
    int reps = 1,
    int limit = 50,
  }) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.rankingsLeaderboard(exerciseId)}',
    ).replace(queryParameters: {'reps': '$reps', 'limit': '$limit'});
    final res = await http.get(uri, headers: await _authHeaders());
    return _unwrap(res);
  }

  /// PRs pendientes de validación (admin).
  Future<List<Map<String, dynamic>>> getPending() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.rankingsPending}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return (data['records'] as List).cast<Map<String, dynamic>>();
  }

  /// Valida un PR (admin).
  Future<void> validateRecord(String recordId) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.rankingsValidate(recordId)}');
    final res = await http.post(uri, headers: await _authHeaders());
    _unwrap(res);
  }

  /// Rechaza y elimina un PR (admin).
  Future<void> rejectRecord(String recordId) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.rankingsReject(recordId)}');
    final res = await http.delete(uri, headers: await _authHeaders());
    _unwrap(res);
  }

  /// Calcula coeficiente Wilks localmente.
  /// [isMale] true = fórmula masculina, false = femenina.
  static double wilks({
    required double lifted,
    required double bodyWeight,
    required bool isMale,
  }) {
    double a, b, c, d, e, f;

    if (isMale) {
      a = -216.0475144;
      b = 16.2606339;
      c = -0.002388645;
      d = -0.00113732;
      e = 7.01863e-06;
      f = -1.291e-08;
    } else {
      a = 594.31747775582;
      b = -27.23842536447;
      c = 0.82112226871;
      d = -0.00930733913;
      e = 4.731582e-05;
      f = -9.054e-08;
    }

    final bw = bodyWeight;
    final denom = a +
        b * bw +
        c * bw * bw +
        d * bw * bw * bw +
        e * bw * bw * bw * bw +
        f * bw * bw * bw * bw * bw;

    if (denom <= 0) return 0;
    return lifted * 500 / denom;
  }
}
