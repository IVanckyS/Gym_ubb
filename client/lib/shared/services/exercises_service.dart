import 'dart:convert';
import 'dart:io';
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
    Set<String> muscleGroups = const {},
    Set<String> equipmentList = const {},
    String difficulty = '',
    String search = '',
  }) async {
    final params = <String, String>{};
    if (muscleGroups.isNotEmpty) params['muscleGroup'] = muscleGroups.join(',');
    if (equipmentList.isNotEmpty) params['equipment'] = equipmentList.join(',');
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

  /// Sube una imagen al servidor y retorna la URL pública.
  /// [type] = "main" para imagen principal, "step_N" para el paso N (ej. "step_0")
  Future<String> uploadImage(String exerciseId, File file, {String type = 'main'}) async {
    final token = await _auth.getAccessToken();
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/exercises/uploadImage/$exerciseId');
    final req = http.MultipartRequest('POST', uri);
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields['type'] = type;
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return (body['data']?['url'] ?? body['url']) as String;
    }
    final error = body['error'] as Map<String, dynamic>?;
    throw ExercisesException(error?['message'] as String? ?? 'Error al subir imagen');
  }

  Future<Map<String, dynamic>> updateExercise(String id, Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/exercises/updateExercise/$id');
    final res = await http.patch(uri, headers: await _authHeaders(), body: jsonEncode(body));
    final data = await _handleResponse(res);
    return data['exercise'] as Map<String, dynamic>? ?? data;
  }

  Future<Map<String, dynamic>> createExercise(Map<String, dynamic> body) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}/api/v1/exercises/createExercise');
    final res = await http.post(uri, headers: await _authHeaders(), body: jsonEncode(body));
    final data = await _handleResponse(res);
    return data['exercise'] as Map<String, dynamic>? ?? data;
  }

  /// Búsqueda rápida para el combo de variaciones.
  Future<List<Map<String, dynamic>>> searchExercises(
    String q, {
    String? excludeId,
    int limit = 10,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.searchExercises}')
        .replace(queryParameters: {
      'q': q,
      if (excludeId != null) 'exclude': excludeId,
      'limit': '$limit',
    });
    final res = await http.get(uri, headers: await _authHeaders());
    final data = await _handleResponse(res);
    return (data['exercises'] as List? ?? []).cast<Map<String, dynamic>>();
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
