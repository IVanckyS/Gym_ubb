import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class NotificationsService {
  final _auth = AuthService();

  Future<Map<String, String>> _headers() async {
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
    final err = body['error'] as Map<String, dynamic>?;
    throw Exception(err?['message'] ?? 'Error desconocido');
  }

  Future<Map<String, dynamic>> list() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.notificationsList}'),
      headers: await _headers(),
    );
    return _unwrap(res);
  }

  Future<int> unreadCount() async {
    final res = await http.get(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.notificationsUnreadCount}'),
      headers: await _headers(),
    );
    final data = _unwrap(res);
    return (data['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> markRead(String id, String type, String referenceId) async {
    await http.patch(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.notificationRead(id)}'),
      headers: await _headers(),
      body: jsonEncode({'type': type, 'referenceId': referenceId}),
    );
  }

  Future<void> markAllRead() async {
    await http.patch(
      Uri.parse('${ApiConstants.baseUrl}${ApiConstants.notificationsReadAll}'),
      headers: await _headers(),
    );
  }
}
