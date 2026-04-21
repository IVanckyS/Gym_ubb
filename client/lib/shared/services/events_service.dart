import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class EventsException implements Exception {
  final String message;
  EventsException(this.message);
  @override
  String toString() => message;
}

class EventsService {
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
    throw EventsException(error?['message'] as String? ?? 'Error desconocido');
  }

  Future<List<Map<String, dynamic>>> listEvents({
    String type = '',
    bool upcoming = true,
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      'upcoming': '$upcoming',
      if (type.isNotEmpty) 'type': type,
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.listEvents}')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return (data['events'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> getEvent(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.getEvent(id)}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return data['event'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getMyInterests() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.myEventInterests}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return (data['events'] as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> toggleInterest(String id) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.toggleEventInterest(id)}',
    );
    final res = await http.post(uri, headers: await _authHeaders());
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> createEvent({
    required String title,
    required String type,
    required String eventDate,
    String? eventTime,
    String location = '',
    String description = '',
    int? maxParticipants,
    String? registrationUrl,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createEvent}');
    final headers = await _authHeaders();
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'title': title,
        'type': type,
        'eventDate': eventDate,
        if (eventTime != null && eventTime.isNotEmpty) 'eventTime': eventTime,
        if (location.isNotEmpty) 'location': location,
        if (description.isNotEmpty) 'description': description,
        if (maxParticipants != null) 'maxParticipants': maxParticipants,
        if (registrationUrl != null && registrationUrl.isNotEmpty)
          'registrationUrl': registrationUrl,
      }),
    );
    final data = _unwrap(res);
    return (data['event'] as Map<String, dynamic>?) ?? data;
  }

  Future<void> deactivateEvent(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deactivateEvent(id)}');
    final res = await http.patch(uri, headers: await _authHeaders());
    _unwrap(res);
  }
}
