import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

final _uuid = Uuid();

Router get workoutHandler {
  final router = Router();

  // POST /api/v1/workout/start
  router.post('/start', _startSession);

  // GET /api/v1/workout/active
  router.get('/active', _getActiveSession);

  // POST /api/v1/workout/logSet
  router.post('/logSet', _logSet);

  // PATCH /api/v1/workout/finish/<sessionId>
  router.patch('/finish/<sessionId>', _finishSession);

  // GET /api/v1/workout/week-status?routineId=
  router.get('/week-status', _getWeekStatus);

  // GET /api/v1/workout/history?limit=&offset=
  router.get('/history', _getHistory);

  // GET /api/v1/workout/session/<id>
  router.get('/session/<id>', _getSession);

  // DELETE /api/v1/workout/cancel/<sessionId>
  router.delete('/cancel/<sessionId>', _cancelSession);

  return router;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _sessionToMap(Map<String, dynamic> row) => {
      'id': row['id'],
      'userId': row['user_id'],
      'routineId': row['routine_id'],
      'routineDayId': row['routine_day_id'],
      'routineName': row['routine_name'],
      'dayLabel': row['day_label'],
      'startedAt': row['started_at']?.toString(),
      'endedAt': row['ended_at']?.toString(),
      'durationMinutes': row['duration_minutes'],
      'totalVolumeKg': row['total_volume_kg'] != null
          ? double.tryParse(row['total_volume_kg'].toString())
          : null,
      'notes': row['notes'],
      'status': row['status']?.toString() ?? 'in_progress',
      'earlyFinishReason': row['early_finish_reason'],
    };

Map<String, dynamic> _setToMap(Map<String, dynamic> row) => {
      'id': row['id'],
      'sessionId': row['session_id'],
      'exerciseId': row['exercise_id'],
      'exerciseName': row['exercise_name'],
      'setNumber': row['set_number'],
      'weightKg': row['weight_kg'] != null
          ? double.tryParse(row['weight_kg'].toString())
          : null,
      'reps': row['reps'],
      'durationSeconds': row['duration_seconds'],
      'completed': row['completed'],
      'rpe': row['rpe'],
    };

// ── Handlers ─────────────────────────────────────────────────────────────────

/// POST /start
/// Body: { routineId?, routineDayId? }
/// Inicia una sesión de entrenamiento. Si ya existe una sesión activa, la devuelve.
Future<Response> _startSession(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  // Verificar si ya hay una sesión activa
  final activeCheck = await db.execute(
    'SELECT id FROM workout_sessions '
    "WHERE user_id = '$userId'::uuid AND ended_at IS NULL "
    'ORDER BY started_at DESC LIMIT 1',
  );
  if (activeCheck.isNotEmpty) {
    final sessionId = activeCheck.first.toColumnMap()['id'] as String;
    return _getSession(request.change(path: ''), sessionId);
  }

  final body = await parseBody(request);
  final routineId = body['routineId'] as String?;
  final routineDayId = body['routineDayId'] as String?;

  final sessionId = _uuid.v4();

  if (routineId != null && routineDayId != null) {
    // Verificar que el día pertenece a la rutina
    final check = await db.execute(
      "SELECT id FROM routine_days WHERE id = '$routineDayId'::uuid "
      "AND routine_id = '$routineId'::uuid",
    );
    if (check.isEmpty) return badRequest('Día no pertenece a la rutina indicada');

    await db.execute(
      "INSERT INTO workout_sessions (id, user_id, routine_id, routine_day_id, started_at) "
      "VALUES ('$sessionId'::uuid, '$userId'::uuid, '$routineId'::uuid, '$routineDayId'::uuid, NOW())",
    );
  } else {
    await db.execute(
      "INSERT INTO workout_sessions (id, user_id, started_at) "
      "VALUES ('$sessionId'::uuid, '$userId'::uuid, NOW())",
    );
  }

  return _getSession(request.change(path: ''), sessionId);
}

/// GET /active
/// Devuelve la sesión activa del usuario, con ejercicios y series registradas.
Future<Response> _getActiveSession(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final result = await db.execute(
    'SELECT ws.id FROM workout_sessions ws '
    "WHERE ws.user_id = '$userId'::uuid AND ws.ended_at IS NULL "
    'ORDER BY ws.started_at DESC LIMIT 1',
  );

  if (result.isEmpty) return notFound('No hay sesión activa');

  final sessionId = result.first.toColumnMap()['id'] as String;
  return _getSession(request.change(path: ''), sessionId);
}

/// POST /logSet
/// Body: { sessionId, exerciseId, setNumber, weightKg?, reps?, completed?, rpe? }
Future<Response> _logSet(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final body = await parseBody(request);
  final sessionId = body['sessionId'] as String? ?? '';
  final exerciseId = body['exerciseId'] as String? ?? '';
  final setNumber = body['setNumber'] as int? ?? 1;
  final weightKg = (body['weightKg'] as num?)?.toDouble();
  final reps = body['reps'] as int?;
  final durationSeconds = body['durationSeconds'] as int?;
  final completed = body['completed'] as bool? ?? false;
  final rpe = body['rpe'] as int?;

  if (sessionId.isEmpty) return badRequest('sessionId es requerido');
  if (exerciseId.isEmpty) return badRequest('exerciseId es requerido');

  // Verificar que la sesión pertenece al usuario y está activa
  final sessionCheck = await db.execute(
    "SELECT id FROM workout_sessions WHERE id = '$sessionId'::uuid "
    "AND user_id = '$userId'::uuid AND ended_at IS NULL",
  );
  if (sessionCheck.isEmpty) return notFound('Sesión no encontrada o ya finalizada');

  // Verificar si ya existe ese set (upsert manual)
  final existing = await db.execute(
    "SELECT id FROM workout_sets WHERE session_id = '$sessionId'::uuid "
    "AND exercise_id = '$exerciseId'::uuid AND set_number = $setNumber",
  );

  if (existing.isNotEmpty) {
    final setId = existing.first.toColumnMap()['id'] as String;
    final setClauses = <String>[];
    if (weightKg != null) setClauses.add('weight_kg = $weightKg');
    if (reps != null) setClauses.add('reps = $reps');
    if (durationSeconds != null) setClauses.add('duration_seconds = $durationSeconds');
    setClauses.add('completed = $completed');
    if (rpe != null) setClauses.add('rpe = $rpe');

    if (setClauses.isNotEmpty) {
      await db.execute(
        "UPDATE workout_sets SET ${setClauses.join(', ')} WHERE id = '$setId'::uuid",
      );
    }

    final updated = await db.execute(
      "SELECT ws.id, ws.session_id, ws.exercise_id, e.name AS exercise_name, "
      "ws.set_number, ws.weight_kg, ws.reps, ws.duration_seconds, ws.completed, ws.rpe "
      "FROM workout_sets ws JOIN exercises e ON e.id = ws.exercise_id "
      "WHERE ws.id = '$setId'::uuid",
    );
    return jsonOk({'set': _setToMap(updated.first.toColumnMap())});
  }

  // Insertar nuevo set
  final setId = _uuid.v4();
  final weightVal = weightKg != null ? '$weightKg' : 'NULL';
  final repsVal = reps != null ? '$reps' : 'NULL';
  final durationVal = durationSeconds != null ? '$durationSeconds' : 'NULL';
  final rpeVal = rpe != null ? '$rpe' : 'NULL';

  await db.execute(
    "INSERT INTO workout_sets (id, session_id, exercise_id, set_number, weight_kg, reps, duration_seconds, completed, rpe) "
    "VALUES ('$setId'::uuid, '$sessionId'::uuid, '$exerciseId'::uuid, $setNumber, "
    "$weightVal, $repsVal, $durationVal, $completed, $rpeVal)",
  );

  final inserted = await db.execute(
    "SELECT ws.id, ws.session_id, ws.exercise_id, e.name AS exercise_name, "
    "ws.set_number, ws.weight_kg, ws.reps, ws.duration_seconds, ws.completed, ws.rpe "
    "FROM workout_sets ws JOIN exercises e ON e.id = ws.exercise_id "
    "WHERE ws.id = '$setId'::uuid",
  );

  // Si la serie se completó y hay peso y reps, verificar si es un récord personal
  if (completed && weightKg != null && reps != null && reps > 0) {
    await _checkAndSavePR(userId, exerciseId, weightKg, reps, sessionId);
  }

  return jsonCreated({'set': _setToMap(inserted.first.toColumnMap())});
}

/// PATCH /finish/<sessionId>
/// Body: { notes?, status?, earlyFinishReason? }
/// status: 'completed' | 'partial' (default: 'completed')
/// Finaliza la sesión: calcula duración y volumen total.
Future<Response> _finishSession(Request request, String sessionId) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final sessionCheck = await db.execute(
    "SELECT id, started_at FROM workout_sessions "
    "WHERE id = '$sessionId'::uuid AND user_id = '$userId'::uuid AND ended_at IS NULL",
  );
  if (sessionCheck.isEmpty) return notFound('Sesión no encontrada o ya finalizada');

  final body = await parseBody(request);
  final notes = body['notes'] as String?;
  final rawStatus = body['status'] as String? ?? 'completed';
  final status = rawStatus == 'partial' ? 'partial' : 'completed';
  final earlyFinishReason = body['earlyFinishReason'] as String?;

  // Calcular volumen total (kg × reps de series completadas)
  final volumeResult = await db.execute(
    "SELECT COALESCE(SUM(weight_kg * reps), 0) AS total_volume "
    "FROM workout_sets WHERE session_id = '$sessionId'::uuid AND completed = true "
    "AND weight_kg IS NOT NULL AND reps IS NOT NULL",
  );
  final totalVolume = volumeResult.first.toColumnMap()['total_volume'];
  final totalVolumeKg = double.tryParse(totalVolume?.toString() ?? '0') ?? 0.0;

  final notesClause = notes != null && notes.isNotEmpty
      ? ", notes = '${notes.replaceAll("'", "''")}'"
      : '';
  final reasonClause = earlyFinishReason != null && earlyFinishReason.isNotEmpty
      ? ", early_finish_reason = '${earlyFinishReason.replaceAll("'", "''")}'"
      : '';

  await db.execute(
    "UPDATE workout_sessions SET ended_at = NOW(), "
    "duration_minutes = EXTRACT(EPOCH FROM (NOW() - started_at)) / 60, "
    "total_volume_kg = $totalVolumeKg, "
    "status = '$status'::workout_session_status"
    "$notesClause$reasonClause "
    "WHERE id = '$sessionId'::uuid",
  );

  return _getSession(request.change(path: ''), sessionId);
}

/// GET /history?limit=20&offset=0
/// Devuelve el historial de sesiones finalizadas del usuario.
Future<Response> _getHistory(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final params = request.url.queryParameters;
  final limit = int.tryParse(params['limit'] ?? '20') ?? 20;
  final offset = int.tryParse(params['offset'] ?? '0') ?? 0;

  final result = await db.execute(
    'SELECT ws.id, ws.user_id, ws.routine_id, ws.routine_day_id, '
    'r.name AS routine_name, rd.label AS day_label, '
    'ws.started_at, ws.ended_at, ws.duration_minutes, ws.total_volume_kg, ws.notes '
    'FROM workout_sessions ws '
    'LEFT JOIN routines r ON r.id = ws.routine_id '
    'LEFT JOIN routine_days rd ON rd.id = ws.routine_day_id '
    "WHERE ws.user_id = '$userId'::uuid AND ws.ended_at IS NOT NULL "
    'ORDER BY ws.started_at DESC '
    'LIMIT $limit OFFSET $offset',
  );

  final countResult = await db.execute(
    "SELECT COUNT(*) AS total FROM workout_sessions "
    "WHERE user_id = '$userId'::uuid AND ended_at IS NOT NULL",
  );
  final total = countResult.first.toColumnMap()['total'];

  // Para cada sesión, obtener el conteo de series completadas y ejercicios únicos
  final sessions = <Map<String, dynamic>>[];
  for (final row in result) {
    final session = _sessionToMap(row.toColumnMap());
    final sid = session['id'] as String;

    final statsResult = await db.execute(
      "SELECT COUNT(*) FILTER (WHERE completed = true) AS completed_sets, "
      "COUNT(DISTINCT exercise_id) AS exercise_count "
      "FROM workout_sets WHERE session_id = '$sid'::uuid",
    );
    final stats = statsResult.first.toColumnMap();
    session['completedSets'] = stats['completed_sets'];
    session['exerciseCount'] = stats['exercise_count'];
    sessions.add(session);
  }

  return jsonOk({
    'sessions': sessions,
    'total': total,
    'limit': limit,
    'offset': offset,
  });
}

/// GET /session/<id>
/// Devuelve detalle de la sesión con ejercicios del día y series registradas.
Future<Response> _getSession(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final sessionResult = await db.execute(
    'SELECT ws.id, ws.user_id, ws.routine_id, ws.routine_day_id, '
    'r.name AS routine_name, rd.label AS day_label, '
    'ws.started_at, ws.ended_at, ws.duration_minutes, ws.total_volume_kg, ws.notes '
    'FROM workout_sessions ws '
    'LEFT JOIN routines r ON r.id = ws.routine_id '
    'LEFT JOIN routine_days rd ON rd.id = ws.routine_day_id '
    "WHERE ws.id = '$id'::uuid AND ws.user_id = '$userId'::uuid",
  );

  if (sessionResult.isEmpty) return notFound('Sesión no encontrada');

  final session = _sessionToMap(sessionResult.first.toColumnMap());
  final routineDayId = session['routineDayId'] as String?;

  // Obtener ejercicios del día de la rutina (si aplica)
  List<Map<String, dynamic>> exercises = [];
  if (routineDayId != null) {
    final exResult = await db.execute(
      'SELECT rde.exercise_id, e.name AS exercise_name, '
      'e.muscle_group::text AS muscle_group, e.image_url, e.exercise_type, '
      'rde.sets AS target_sets, rde.reps AS target_reps, '
      'rde.rest_seconds, rde.rir, rde.order_index '
      'FROM routine_day_exercises rde '
      'JOIN exercises e ON e.id = rde.exercise_id '
      "WHERE rde.routine_day_id = '$routineDayId'::uuid "
      'ORDER BY rde.order_index ASC',
    );
    exercises = exResult.map((r) {
      final m = r.toColumnMap();
      return {
        'exerciseId': m['exercise_id'],
        'exerciseName': m['exercise_name'],
        'muscleGroup': m['muscle_group'],
        'imageUrl': m['image_url'],
        'exerciseType': m['exercise_type'] ?? 'dinamico',
        'targetSets': m['target_sets'],
        'targetReps': m['target_reps'],
        'restSeconds': m['rest_seconds'],
        'rir': m['rir'],
        'orderIndex': m['order_index'],
        'sets': <Map<String, dynamic>>[],
      };
    }).toList();
  } else {
    // Sesión libre: obtener ejercicios únicos de los sets registrados
    final exResult = await db.execute(
      'SELECT DISTINCT ON (ws.exercise_id) ws.exercise_id, e.name AS exercise_name, '
      'e.muscle_group::text AS muscle_group, e.image_url, e.exercise_type '
      'FROM workout_sets ws JOIN exercises e ON e.id = ws.exercise_id '
      "WHERE ws.session_id = '$id'::uuid "
      'ORDER BY ws.exercise_id, ws.created_at ASC',
    );
    exercises = exResult.map((r) {
      final m = r.toColumnMap();
      return {
        'exerciseId': m['exercise_id'],
        'exerciseName': m['exercise_name'],
        'muscleGroup': m['muscle_group'],
        'imageUrl': m['image_url'],
        'exerciseType': m['exercise_type'] ?? 'dinamico',
        'targetSets': null,
        'targetReps': null,
        'restSeconds': 90,
        'rir': null,
        'sets': <Map<String, dynamic>>[],
      };
    }).toList();
  }

  // Obtener todas las series de la sesión
  if (exercises.isNotEmpty) {
    final setsResult = await db.execute(
      'SELECT wset.id, wset.session_id, wset.exercise_id, e.name AS exercise_name, '
      'wset.set_number, wset.weight_kg, wset.reps, wset.duration_seconds, wset.completed, wset.rpe '
      'FROM workout_sets wset JOIN exercises e ON e.id = wset.exercise_id '
      "WHERE wset.session_id = '$id'::uuid "
      'ORDER BY wset.exercise_id, wset.set_number ASC',
    );

    // Agrupar series por exerciseId
    final setsByExercise = <String, List<Map<String, dynamic>>>{};
    for (final row in setsResult) {
      final s = _setToMap(row.toColumnMap());
      final eid = s['exerciseId'] as String;
      setsByExercise.putIfAbsent(eid, () => []).add(s);
    }

    // Asignar series a ejercicios
    for (final ex in exercises) {
      final eid = ex['exerciseId'] as String;
      ex['sets'] = setsByExercise[eid] ?? [];
    }

    // Si es sesión libre, añadir ejercicios que están en sets pero no en la lista
    if (routineDayId == null) {
      for (final entry in setsByExercise.entries) {
        final found = exercises.any((e) => e['exerciseId'] == entry.key);
        if (!found) {
          exercises.add({
            'exerciseId': entry.key,
            'exerciseName': entry.value.first['exerciseName'],
            'sets': entry.value,
          });
        }
      }
    }
  }

  session['exercises'] = exercises;
  return jsonOk({'session': session});
}

/// GET /week-status?routineId=<id>
/// Devuelve el estado semanal (lunes–domingo actual) de cada día de una rutina.
/// Respuesta: { "days": { "<routineDayId>": "completed" | "partial" } }
/// Los días sin sesión esta semana no aparecen en el mapa.
Future<Response> _getWeekStatus(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final routineId = request.url.queryParameters['routineId'];
  if (routineId == null || routineId.isEmpty) {
    return badRequest('routineId requerido');
  }

  // Inicio del lunes de la semana actual a medianoche UTC
  final now = DateTime.now().toUtc();
  final monday = now.subtract(Duration(days: now.weekday - 1));
  final weekStart =
      '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')} 00:00:00';

  final result = await db.execute(
    "SELECT routine_day_id, status::text AS status "
    "FROM workout_sessions "
    "WHERE user_id = '$userId'::uuid "
    "AND routine_id = '$routineId'::uuid "
    "AND ended_at IS NOT NULL "
    "AND started_at >= '$weekStart'::timestamp "
    "ORDER BY started_at DESC",
  );

  // Para cada día, tomar solo la sesión más reciente de la semana
  final days = <String, String>{};
  for (final row in result) {
    final m = row.toColumnMap();
    final dayId = m['routine_day_id'] as String?;
    if (dayId != null && !days.containsKey(dayId)) {
      days[dayId] = m['status'] as String? ?? 'completed';
    }
  }

  return jsonOk({'days': days});
}

/// DELETE /cancel/<sessionId>
/// Cancela (elimina) una sesión activa sin finalizar.
Future<Response> _cancelSession(Request request, String sessionId) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final check = await db.execute(
    "SELECT id FROM workout_sessions WHERE id = '$sessionId'::uuid "
    "AND user_id = '$userId'::uuid AND ended_at IS NULL",
  );
  if (check.isEmpty) return notFound('Sesión no encontrada o ya finalizada');

  // Eliminar sets primero (cascade debería cubrirlo, pero por seguridad)
  await db.execute(
    "DELETE FROM workout_sets WHERE session_id = '$sessionId'::uuid",
  );
  await db.execute(
    "DELETE FROM workout_sessions WHERE id = '$sessionId'::uuid",
  );

  return jsonOk({'message': 'Sesión cancelada'});
}

// ── Helpers privados ─────────────────────────────────────────────────────────

/// Verifica si el set completado es un récord personal y lo guarda si aplica.
Future<void> _checkAndSavePR(
  String userId,
  String exerciseId,
  double weightKg,
  int reps,
  String sessionId,
) async {
  try {
    final existing = await db.execute(
      "SELECT id, weight_kg FROM personal_records "
      "WHERE user_id = '$userId'::uuid AND exercise_id = '$exerciseId'::uuid AND reps = $reps",
    );

    if (existing.isEmpty) {
      final prId = _uuid.v4();
      await db.execute(
        "INSERT INTO personal_records (id, user_id, exercise_id, weight_kg, reps, session_id) "
        "VALUES ('$prId'::uuid, '$userId'::uuid, '$exerciseId'::uuid, $weightKg, $reps, '$sessionId'::uuid)",
      );
    } else {
      final currentWeight = double.tryParse(
            existing.first.toColumnMap()['weight_kg']?.toString() ?? '0',
          ) ??
          0;
      if (weightKg > currentWeight) {
        final prId = existing.first.toColumnMap()['id'] as String;
        await db.execute(
          "UPDATE personal_records SET weight_kg = $weightKg, "
          "session_id = '$sessionId'::uuid, achieved_at = NOW(), is_validated = false "
          "WHERE id = '$prId'::uuid",
        );
      }
    }
  } catch (_) {
    // No bloquear el flujo si falla el PR
  }
}
