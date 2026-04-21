import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

final _uuid = Uuid();

Router get historyHandler {
  final router = Router();

  // Progreso por ejercicio
  // GET /api/v1/history/progress/:exerciseId?limit=20
  router.get('/progress/<exerciseId>', _getExerciseProgress);

  // Ejercicios entrenados por el usuario (para el selector)
  // GET /api/v1/history/trainedExercises
  router.get('/trainedExercises', _getTrainedExercises);

  // Récords personales
  // GET /api/v1/history/records
  router.get('/records', _getPersonalRecords);

  // Medidas corporales
  // GET /api/v1/history/measurements
  router.get('/measurements', _getMeasurements);

  // POST /api/v1/history/measurements
  router.post('/measurements', _createMeasurement);

  // DELETE /api/v1/history/measurements/:id
  router.delete('/measurements/<id>', _deleteMeasurement);

  return router;
}

// ── Handlers ─────────────────────────────────────────────────────────────────

/// GET /progress/:exerciseId?limit=20
/// Devuelve el historial de un ejercicio: peso máximo y volumen por sesión.
Future<Response> _getExerciseProgress(Request request, String exerciseId) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final limit = int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;

  // Verificar que el ejercicio existe
  final exCheck = await db.execute(
    "SELECT name FROM exercises WHERE id = '$exerciseId'::uuid AND is_active = true",
  );
  if (exCheck.isEmpty) return notFound('Ejercicio no encontrado');
  final exerciseName = exCheck.first.toColumnMap()['name'] as String;

  // Progreso por sesión: fecha, peso máximo del set, volumen total, total sets completados
  final result = await db.execute(
    'SELECT ws.started_at::date AS session_date, '
    'ws.id AS session_id, '
    'MAX(wset.weight_kg) AS max_weight, '
    'SUM(wset.weight_kg * wset.reps) FILTER (WHERE wset.completed = true AND wset.weight_kg IS NOT NULL AND wset.reps IS NOT NULL) AS volume, '
    'COUNT(*) FILTER (WHERE wset.completed = true) AS completed_sets, '
    'MAX(wset.reps) FILTER (WHERE wset.weight_kg = (SELECT MAX(w2.weight_kg) FROM workout_sets w2 WHERE w2.session_id = ws.id AND w2.exercise_id = wset.exercise_id AND w2.completed = true)) AS reps_at_max '
    'FROM workout_sessions ws '
    'JOIN workout_sets wset ON wset.session_id = ws.id '
    "WHERE ws.user_id = '$userId'::uuid "
    "AND wset.exercise_id = '$exerciseId'::uuid "
    'AND ws.ended_at IS NOT NULL '
    'AND wset.completed = true '
    'GROUP BY ws.id, ws.started_at '
    'ORDER BY ws.started_at ASC '
    'LIMIT $limit',
  );

  final points = result.map((r) {
    final m = r.toColumnMap();
    return {
      'sessionId': m['session_id'],
      'date': m['session_date']?.toString(),
      'maxWeight': m['max_weight'] != null
          ? double.tryParse(m['max_weight'].toString())
          : null,
      'volume': m['volume'] != null
          ? double.tryParse(m['volume'].toString())
          : null,
      'completedSets': m['completed_sets'],
      'repsAtMax': m['reps_at_max'],
    };
  }).toList();

  return jsonOk({
    'exerciseId': exerciseId,
    'exerciseName': exerciseName,
    'points': points,
    'total': points.length,
  });
}

/// GET /trainedExercises
/// Lista de ejercicios únicos que el usuario ha registrado en al menos una sesión finalizada.
Future<Response> _getTrainedExercises(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final result = await db.execute(
    'SELECT DISTINCT e.id, e.name, e.muscle_group::text AS muscle_group '
    'FROM workout_sets wset '
    'JOIN exercises e ON e.id = wset.exercise_id '
    'JOIN workout_sessions ws ON ws.id = wset.session_id '
    "WHERE ws.user_id = '$userId'::uuid AND ws.ended_at IS NOT NULL AND wset.completed = true "
    'ORDER BY e.name ASC',
  );

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

/// GET /records
/// Récords personales del usuario.
Future<Response> _getPersonalRecords(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final result = await db.execute(
    'SELECT pr.id, pr.exercise_id, e.name AS exercise_name, '
    'e.muscle_group::text AS muscle_group, '
    'pr.weight_kg, pr.reps, '
    "TO_CHAR(pr.achieved_at AT TIME ZONE 'UTC', 'YYYY-MM-DD\"T\"HH24:MI:SS\"Z\"') AS achieved_at, "
    'pr.is_validated '
    'FROM personal_records pr '
    'JOIN exercises e ON e.id = pr.exercise_id '
    "WHERE pr.user_id = '$userId'::uuid "
    'AND pr.weight_kg > 0 AND pr.reps > 0 '
    'ORDER BY e.name ASC, pr.reps ASC',
  );

  final records = result.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'],
      'exerciseId': m['exercise_id'],
      'exerciseName': m['exercise_name'],
      'muscleGroup': m['muscle_group'],
      'weightKg': m['weight_kg'] != null
          ? double.tryParse(m['weight_kg'].toString())
          : null,
      'reps': m['reps'],
      'achievedAt': m['achieved_at']?.toString(),
      'isValidated': m['is_validated'],
    };
  }).toList();

  return jsonOk({'records': records, 'total': records.length});
}

/// GET /measurements
/// Medidas corporales del usuario, ordenadas por fecha descendente.
Future<Response> _getMeasurements(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final limit = int.tryParse(request.url.queryParameters['limit'] ?? '30') ?? 30;

  final result = await db.execute(
    'SELECT id, user_id, measured_at, weight_kg, body_fat_pct, '
    'chest_cm, waist_cm, hip_cm, arm_cm, leg_cm, notes, created_at '
    "FROM body_measurements WHERE user_id = '$userId'::uuid "
    'ORDER BY measured_at DESC '
    'LIMIT $limit',
  );

  final measurements = result.map((r) {
    final m = r.toColumnMap();
    return _measurementToMap(m);
  }).toList();

  return jsonOk({'measurements': measurements, 'total': measurements.length});
}

/// POST /measurements
/// Body: { measuredAt?, weightKg?, bodyFatPct?, chestCm?, waistCm?, hipCm?, armCm?, legCm?, notes? }
Future<Response> _createMeasurement(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final body = await parseBody(request);

  final measuredAt = (body['measuredAt'] as String?)?.isNotEmpty == true
      ? body['measuredAt'] as String
      : DateTime.now().toIso8601String().split('T').first;

  final weightKg = (body['weightKg'] as num?)?.toDouble();
  final bodyFatPct = (body['bodyFatPct'] as num?)?.toDouble();
  final chestCm = (body['chestCm'] as num?)?.toDouble();
  final waistCm = (body['waistCm'] as num?)?.toDouble();
  final hipCm = (body['hipCm'] as num?)?.toDouble();
  final armCm = (body['armCm'] as num?)?.toDouble();
  final legCm = (body['legCm'] as num?)?.toDouble();
  final notes = body['notes'] as String?;

  if (weightKg == null && bodyFatPct == null && chestCm == null &&
      waistCm == null && hipCm == null && armCm == null && legCm == null) {
    return badRequest('Debe ingresar al menos una medida');
  }

  final id = _uuid.v4();
  final weightVal = weightKg != null ? '$weightKg' : 'NULL';
  final fatVal = bodyFatPct != null ? '$bodyFatPct' : 'NULL';
  final chestVal = chestCm != null ? '$chestCm' : 'NULL';
  final waistVal = waistCm != null ? '$waistCm' : 'NULL';
  final hipVal = hipCm != null ? '$hipCm' : 'NULL';
  final armVal = armCm != null ? '$armCm' : 'NULL';
  final legVal = legCm != null ? '$legCm' : 'NULL';
  final notesVal = notes != null && notes.isNotEmpty
      ? "'${notes.replaceAll("'", "''")}'"
      : 'NULL';

  await db.execute(
    "INSERT INTO body_measurements "
    "(id, user_id, measured_at, weight_kg, body_fat_pct, chest_cm, waist_cm, hip_cm, arm_cm, leg_cm, notes) "
    "VALUES ('$id'::uuid, '$userId'::uuid, '$measuredAt'::date, "
    "$weightVal, $fatVal, $chestVal, $waistVal, $hipVal, $armVal, $legVal, $notesVal)",
  );

  final inserted = await db.execute(
    "SELECT id, user_id, measured_at, weight_kg, body_fat_pct, "
    "chest_cm, waist_cm, hip_cm, arm_cm, leg_cm, notes, created_at "
    "FROM body_measurements WHERE id = '$id'::uuid",
  );

  return jsonCreated({'measurement': _measurementToMap(inserted.first.toColumnMap())});
}

/// DELETE /measurements/:id
Future<Response> _deleteMeasurement(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final check = await db.execute(
    "SELECT id FROM body_measurements WHERE id = '$id'::uuid AND user_id = '$userId'::uuid",
  );
  if (check.isEmpty) return notFound('Medida no encontrada');

  await db.execute("DELETE FROM body_measurements WHERE id = '$id'::uuid");
  return jsonOk({'message': 'Medida eliminada'});
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _measurementToMap(Map<String, dynamic> m) => {
      'id': m['id'],
      'measuredAt': m['measured_at']?.toString(),
      'weightKg': m['weight_kg'] != null
          ? double.tryParse(m['weight_kg'].toString())
          : null,
      'bodyFatPct': m['body_fat_pct'] != null
          ? double.tryParse(m['body_fat_pct'].toString())
          : null,
      'chestCm': m['chest_cm'] != null
          ? double.tryParse(m['chest_cm'].toString())
          : null,
      'waistCm': m['waist_cm'] != null
          ? double.tryParse(m['waist_cm'].toString())
          : null,
      'hipCm': m['hip_cm'] != null
          ? double.tryParse(m['hip_cm'].toString())
          : null,
      'armCm': m['arm_cm'] != null
          ? double.tryParse(m['arm_cm'].toString())
          : null,
      'legCm': m['leg_cm'] != null
          ? double.tryParse(m['leg_cm'].toString())
          : null,
      'notes': m['notes'],
      'createdAt': m['created_at']?.toString(),
    };
