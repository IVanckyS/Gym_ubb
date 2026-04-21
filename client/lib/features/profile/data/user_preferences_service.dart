import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/services/auth_service.dart';

const _kPinnedExercises = 'pinned_exercise_ids';

/// Persiste preferencias en SharedPrefs Y sincroniza con el backend.
class UserPreferencesService {
  final AuthService _auth = AuthService();

  // ── Sync desde backend al login ──────────────────────────────────────────────

  Future<void> syncPreferences() async {
    try {
      final token = await _auth.getAccessToken();
      if (token == null) return;

      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body)['data'] as Map<String, dynamic>?;
      final user = data?['user'] as Map<String, dynamic>?;
      if (user == null) return;

      final prefs = await SharedPreferences.getInstance();
      if (user['units'] != null) {
        await prefs.setString('weight_unit', user['units'] as String);
      }
      if (user['notificationsEnabled'] != null) {
        await prefs.setBool(
          'notifications_enabled',
          user['notificationsEnabled'] as bool,
        );
      }
    } catch (_) {}
  }

  // ── Ejercicios fijados en Home (solo SharedPrefs) ───────────────────────────

  Future<List<String>> getPinnedExerciseIds() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_kPinnedExercises) ?? [];
  }

  Future<void> setPinnedExerciseIds(List<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kPinnedExercises, ids.take(4).toList());
  }

  // ── Guardar preferencias en backend ──────────────────────────────────────────

  Future<void> savePreferences({
    String? units,
    bool? notificationsEnabled,
    bool? privateProfile,
  }) async {
    try {
      final token = await _auth.getAccessToken();
      if (token == null) return;

      final body = <String, dynamic>{};
      if (units != null) body['units'] = units;
      if (notificationsEnabled != null) {
        body['notificationsEnabled'] = notificationsEnabled;
      }
      if (privateProfile != null) body['privateProfile'] = privateProfile;
      if (body.isEmpty) return;

      await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/preferences'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );
    } catch (_) {}
  }
}
