import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/api_constants.dart';
import 'auth_service.dart';

class ArticlesException implements Exception {
  final String message;
  ArticlesException(this.message);
  @override
  String toString() => message;
}

class ArticlesService {
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
    throw ArticlesException(error?['message'] as String? ?? 'Error desconocido');
  }

  Future<Map<String, dynamic>> listArticles({
    String category = '',
    String search = '',
    int page = 1,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'limit': '$limit',
      if (category.isNotEmpty) 'category': category,
      if (search.isNotEmpty) 'search': search,
    };
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.listArticles}')
        .replace(queryParameters: params);
    final res = await http.get(uri, headers: await _authHeaders());
    return _unwrap(res);
  }

  Future<Map<String, dynamic>> getArticle(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.getArticle(id)}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return data['article'] as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getFavorites() async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.articleFavorites}');
    final res = await http.get(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return (data['articles'] as List).cast<Map<String, dynamic>>();
  }

  Future<bool> toggleFavorite(String id) async {
    final uri = Uri.parse(
      '${ApiConstants.baseUrl}${ApiConstants.toggleArticleFavorite(id)}',
    );
    final res = await http.post(uri, headers: await _authHeaders());
    final data = _unwrap(res);
    return data['isFavorite'] as bool;
  }

  Future<Map<String, dynamic>> createArticle({
    required String title,
    required String category,
    required String content,
    String excerpt = '',
    List<String> tags = const [],
    String bibliography = '',
    bool publish = false,
  }) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.createArticle}');
    final headers = await _authHeaders();
    final res = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        'title': title,
        'category': category,
        'content': content,
        if (excerpt.isNotEmpty) 'excerpt': excerpt,
        if (tags.isNotEmpty) 'tags': tags,
        if (bibliography.isNotEmpty) 'bibliography': bibliography,
        'publish': publish,
      }),
    );
    final data = _unwrap(res);
    return (data['article'] as Map<String, dynamic>?) ?? data;
  }

  Future<void> deactivateArticle(String id) async {
    final uri = Uri.parse('${ApiConstants.baseUrl}${ApiConstants.deactivateArticle(id)}');
    final res = await http.patch(uri, headers: await _authHeaders());
    _unwrap(res);
  }
}
