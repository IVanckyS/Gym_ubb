import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class JointExercisesService {
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
    throw JointExercisesException(
      error?['message'] as String? ?? 'Error desconocido',
    );
  }

  Future<List<Map<String, dynamic>>> list({String family = ''}) async {
    final params = family.isNotEmpty ? '?family=$family' : '';
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.listJointExercises}$params',
    );
    final res = await http.get(uri, headers: await _authHeaders());
    final data = await _handleResponse(res);
    return (data['exercises'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> body) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.createJointExercise}',
    );
    final res = await http.post(uri,
        headers: await _authHeaders(), body: jsonEncode(body));
    final data = await _handleResponse(res);
    return data['exercise'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(
      String id, Map<String, dynamic> body) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.updateJointExercise(id)}',
    );
    final res = await http.patch(uri,
        headers: await _authHeaders(), body: jsonEncode(body));
    final data = await _handleResponse(res);
    return data['exercise'] as Map<String, dynamic>;
  }
}

class JointExercisesException implements Exception {
  final String message;
  const JointExercisesException(this.message);
  @override
  String toString() => message;
}
