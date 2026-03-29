import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class ExercisesService {
  final AuthService _auth = AuthService();

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth.getAccessToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> _handleResponse(http.Response res) async {
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (body['data'] ?? body) as Map<String, dynamic>;
    }
    final error = body['error'] as Map<String, dynamic>?;
    throw ExercisesException(
      error?['message'] as String? ?? 'Error desconocido',
    );
  }

  Future<List<Map<String, dynamic>>> listExercises({
    String muscleGroup = '',
    String difficulty = '',
    String search = '',
  }) async {
    final params = <String, String>{};
    if (muscleGroup.isNotEmpty) params['muscleGroup'] = muscleGroup;
    if (difficulty.isNotEmpty) params['difficulty'] = difficulty;
    if (search.isNotEmpty) params['search'] = search;

    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.listExercises}',
    ).replace(queryParameters: params.isEmpty ? null : params);

    final res = await http.get(uri, headers: await _authHeaders());
    final data = await _handleResponse(res);
    return (data['exercises'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getExercise(String id) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.getExercise(id)}',
    );
    final res = await http.get(uri, headers: await _authHeaders());
    final data = await _handleResponse(res);
    return data['exercise'] as Map<String, dynamic>;
  }

  /// Returns the groups map: { "pecho": [...], "espalda": [...], ... }
  Future<Map<String, dynamic>> byMuscleGroup() async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.byMuscleGroup}',
    );
    final res = await http.get(uri, headers: await _authHeaders());
    final data = await _handleResponse(res);
    return data['groups'] as Map<String, dynamic>;
  }
}

class ExercisesException implements Exception {
  final String message;
  const ExercisesException(this.message);
  @override
  String toString() => message;
}
