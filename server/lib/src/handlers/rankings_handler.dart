import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

Router get rankingsHandler {
  final router = Router();

  // GET /api/v1/rankings/exercises
  // Lista de ejercicios que tienen al menos un PR validado (para el selector)
  router.get('/exercises', _getRankingExercises);

  // GET /api/v1/rankings/leaderboard/:exerciseId?reps=1&limit=50
  // Tabla de líderes para un ejercicio y número de reps
  router.get('/leaderboard/<exerciseId>', _getLeaderboard);

  // GET /api/v1/rankings/pending  (admin)
  // PRs pendientes de validación
  router.get('/pending', _getPending);

  // POST /api/v1/rankings/validate/:recordId  (admin)
  // Valida un PR
  router.post('/validate/<recordId>', _validateRecord);

  // POST /api/v1/rankings/reject/:recordId  (admin)
  // Rechaza y elimina un PR
  router.delete('/reject/<recordId>', _rejectRecord);

  return router;
}

// ── Handlers ─────────────────────────────────────────────────────────────────

/// GET /exercises
/// Ejercicios que tienen al menos un PR validado.
Future<Response> _getRankingExercises(Request request) async {
  await requireAuth(request);

  final result = await db.execute(
    'SELECT DISTINCT e.id, e.name, e.muscle_group::text AS muscle_group '
    'FROM personal_records pr '
    'JOIN exercises e ON e.id = pr.exercise_id '
    'WHERE pr.is_validated = true '
    'ORDER BY e.name ASC',
  );

  // Si no hay PRs validados, devolver todos los ejercicios con PRs (validados o no)
  if (result.isEmpty) {
    final all = await db.execute(
      'SELECT DISTINCT e.id, e.name, e.muscle_group::text AS muscle_group '
      'FROM personal_records pr '
      'JOIN exercises e ON e.id = pr.exercise_id '
      'ORDER BY e.name ASC',
    );
    final exercises = all.map((r) {
      final m = r.toColumnMap();
      return {
        'id': m['id'],
        'name': m['name'],
        'muscleGroup': m['muscle_group'],
      };
    }).toList();
    return jsonOk({'exercises': exercises, 'total': exercises.length});
  }

  final exercises = result.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'],
      'name': m['name'],
      'muscleGroup': m['muscle_group'],
    };
  }).toList();

  return jsonOk({'exercises': exercises, 'total': exercises.length});
}

/// GET /leaderboard/:exerciseId?reps=1&limit=50
/// Tabla de líderes para un ejercicio/reps.
/// Incluye todos los PRs (validados y no) — los no validados se marcan.
Future<Response> _getLeaderboard(Request request, String exerciseId) async {
  final claims = await requireAuth(request);
  final currentUserId = claims['sub'] as String;

  final params = request.url.queryParameters;
  final reps = int.tryParse(params['reps'] ?? '1') ?? 1;
  final limit = int.tryParse(params['limit'] ?? '50') ?? 50;

  // Verificar que el ejercicio existe
  final exCheck = await db.execute(
    "SELECT name FROM exercises WHERE id = '$exerciseId'::uuid AND is_active = true",
  );
  if (exCheck.isEmpty) return notFound('Ejercicio no encontrado');
  final exerciseName = exCheck.first.toColumnMap()['name'] as String;

  // Obtener leaderboard — peso más alto por usuario para ese ejercicio y reps
  final result = await db.execute(
    'SELECT pr.id, pr.user_id, u.name AS user_name, u.career, '
    'pr.weight_kg, pr.reps, pr.achieved_at, pr.is_validated, '
    'u.weight_kg AS body_weight '
    'FROM personal_records pr '
    'JOIN users u ON u.id = pr.user_id '
    "WHERE pr.exercise_id = '$exerciseId'::uuid "
    'AND pr.reps = $reps '
    'AND u.is_active = true '
    'ORDER BY pr.weight_kg DESC '
    'LIMIT $limit',
  );

  int? myPosition;
  final entries = <Map<String, dynamic>>[];

  for (int i = 0; i < result.length; i++) {
    final m = result[i].toColumnMap();
    final userId = m['user_id'] as String;
    final weight = double.tryParse(m['weight_kg']?.toString() ?? '0') ?? 0;
    final bodyWeight = m['body_weight'] != null
        ? double.tryParse(m['body_weight'].toString())
        : null;

    // Calcular Wilks si hay peso corporal
    double? wilks;
    if (bodyWeight != null && bodyWeight > 0) {
      wilks = _wilksMale(weight, bodyWeight);
    }

    if (userId == currentUserId) myPosition = i + 1;

    entries.add({
      'position': i + 1,
      'recordId': m['id'],
      'userId': userId,
      'userName': m['user_name'],
      'career': m['career'],
      'weightKg': weight,
      'reps': m['reps'],
      'achievedAt': (m['achieved_at']?.toString() ?? '').split('T').first,
      'isValidated': m['is_validated'],
      'isCurrentUser': userId == currentUserId,
      'wilks': wilks != null ? double.parse(wilks.toStringAsFixed(2)) : null,
    });
  }

  // Si el usuario no está en la lista, buscar su PR para ese ejercicio/reps
  Map<String, dynamic>? myRecord;
  if (myPosition == null) {
    final myResult = await db.execute(
      'SELECT pr.id, pr.weight_kg, pr.reps, pr.achieved_at, pr.is_validated, '
      'u.weight_kg AS body_weight '
      'FROM personal_records pr JOIN users u ON u.id = pr.user_id '
      "WHERE pr.exercise_id = '$exerciseId'::uuid "
      "AND pr.user_id = '$currentUserId'::uuid "
      'AND pr.reps = $reps',
    );
    if (myResult.isNotEmpty) {
      final m = myResult.first.toColumnMap();
      final weight = double.tryParse(m['weight_kg']?.toString() ?? '0') ?? 0;
      final bodyWeight = m['body_weight'] != null
          ? double.tryParse(m['body_weight'].toString())
          : null;
      double? wilks;
      if (bodyWeight != null && bodyWeight > 0) {
        wilks = _wilksMale(weight, bodyWeight);
      }
      myRecord = {
        'weightKg': weight,
        'reps': m['reps'],
        'achievedAt': (m['achieved_at']?.toString() ?? '').split('T').first,
        'isValidated': m['is_validated'],
        'wilks': wilks != null ? double.parse(wilks.toStringAsFixed(2)) : null,
      };
    }
  }

  return jsonOk({
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'reps': reps,
    'entries': entries,
    'total': entries.length,
    'myPosition': myPosition,
    'myRecord': myRecord,
  });
}

/// GET /pending  (solo admin)
/// PRs pendientes de validación.
Future<Response> _getPending(Request request) async {
  await requireRole(request, 'admin');

  final result = await db.execute(
    'SELECT pr.id, pr.user_id, u.name AS user_name, u.career, '
    'e.id AS exercise_id, e.name AS exercise_name, e.muscle_group::text AS muscle_group, '
    'pr.weight_kg, pr.reps, pr.achieved_at, '
    'ws.started_at AS session_date '
    'FROM personal_records pr '
    'JOIN users u ON u.id = pr.user_id '
    'JOIN exercises e ON e.id = pr.exercise_id '
    'LEFT JOIN workout_sessions ws ON ws.id = pr.session_id '
    'WHERE pr.is_validated = false '
    'ORDER BY pr.achieved_at DESC '
    'LIMIT 100',
  );

  final records = result.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'],
      'userId': m['user_id'],
      'userName': m['user_name'],
      'career': m['career'],
      'exerciseId': m['exercise_id'],
      'exerciseName': m['exercise_name'],
      'muscleGroup': m['muscle_group'],
      'weightKg': m['weight_kg'] != null
          ? double.tryParse(m['weight_kg'].toString())
          : null,
      'reps': m['reps'],
      'achievedAt': (m['achieved_at']?.toString() ?? '').split('T').first,
      'sessionDate': (m['session_date']?.toString() ?? '').split('T').first,
    };
  }).toList();

  return jsonOk({'records': records, 'total': records.length});
}

/// POST /validate/:recordId  (solo admin)
Future<Response> _validateRecord(Request request, String recordId) async {
  await requireRole(request, 'admin');

  final check = await db.execute(
    "SELECT id FROM personal_records WHERE id = '$recordId'::uuid",
  );
  if (check.isEmpty) return notFound('Récord no encontrado');

  await db.execute(
    "UPDATE personal_records SET is_validated = true WHERE id = '$recordId'::uuid",
  );

  return jsonOk({'message': 'Récord validado'});
}

/// DELETE /reject/:recordId  (solo admin)
Future<Response> _rejectRecord(Request request, String recordId) async {
  await requireRole(request, 'admin');

  final check = await db.execute(
    "SELECT id FROM personal_records WHERE id = '$recordId'::uuid",
  );
  if (check.isEmpty) return notFound('Récord no encontrado');

  await db.execute(
    "DELETE FROM personal_records WHERE id = '$recordId'::uuid",
  );

  return jsonOk({'message': 'Récord rechazado y eliminado'});
}

// ── Calculadora Wilks ─────────────────────────────────────────────────────────

/// Coeficiente Wilks para hombres (IPF 2020).
/// [lifted] = peso levantado en kg, [bodyWeight] = peso corporal en kg.
double _wilksMale(double lifted, double bodyWeight) {
  const a = -216.0475144;
  const b = 16.2606339;
  const c = -0.002388645;
  const d = -0.00113732;
  const e = 7.01863e-06;
  const f = -1.291e-08;

  final bw = bodyWeight;
  final coeff = 500 /
      (a +
          b * bw +
          c * bw * bw +
          d * bw * bw * bw +
          e * bw * bw * bw * bw +
          f * bw * bw * bw * bw * bw);

  return lifted * coeff;
}
