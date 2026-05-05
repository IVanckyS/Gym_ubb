import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

final _uuid = Uuid();

Router get routinesHandler {
  final router = Router();

  // GET  /api/v1/routines/listRoutines?tab=mine|public
  router.get('/listRoutines', _listRoutines);

  // GET  /api/v1/routines/myDefault
  router.get('/myDefault', _myDefault);

  // GET  /api/v1/routines/getRoutine/<id>
  router.get('/getRoutine/<id>', _getRoutine);

  // POST /api/v1/routines/createRoutine
  router.post('/createRoutine', _createRoutine);

  // POST /api/v1/routines/copyRoutine/<id>
  router.post('/copyRoutine/<id>', _copyRoutine);

  // PATCH /api/v1/routines/setDefault/<id>
  router.patch('/setDefault/<id>', _setDefault);

  // PATCH /api/v1/routines/updateRoutine/<id>
  router.patch('/updateRoutine/<id>', _updateRoutine);

  // DELETE /api/v1/routines/deleteRoutine/<id>
  router.delete('/deleteRoutine/<id>', _deleteRoutine);

  return router;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

const _validGoals = ['fuerza', 'hipertrofia', 'resistencia', 'perdida_de_peso'];

Map<String, dynamic> _routineToMap(Map<String, dynamic> row) {
  // day_names viene como List o como String PostgreSQL array "{Lunes,Miércoles,...}"
  final rawDays = row['day_names'];
  List<String> dayNames = [];
  if (rawDays is List) {
    dayNames = rawDays.map((e) => '$e').toList();
  } else if (rawDays is String && rawDays.startsWith('{')) {
    final inner = rawDays.substring(1, rawDays.length - 1);
    dayNames = inner.isEmpty ? [] : inner.split(',').map((s) => s.trim()).toList();
  }
  return {
    'id': row['id'],
    'name': row['name'],
    'description': row['description'],
    'goal': row['goal'],
    'frequencyDays': row['frequency_days'],
    'dayNames': dayNames,
    'isPublic': row['is_public'],
    'isDefault': row['is_default'] ?? false,
    'isActive': row['is_active'],
    'userId': row['user_id'],
    'createdBy': row['created_by'],
    'creatorName': row['creator_name'],
    'createdAt': row['created_at']?.toString(),
    'updatedAt': row['updated_at']?.toString(),
  };
}

Map<String, dynamic> _dayToMap(Map<String, dynamic> row) => {
      'id': row['id'],
      'routineId': row['routine_id'],
      'dayName': row['day_name'],
      'label': row['label'],
      'orderIndex': row['order_index'],
      'exercises': [],
    };

Map<String, dynamic> _dayExerciseToMap(Map<String, dynamic> row) => {
      'id': row['id'],
      'routineDayId': row['routine_day_id'],
      'exerciseId': row['exercise_id'],
      'exerciseName': row['exercise_name'],
      'muscleGroup': row['muscle_group'],
      'exerciseType': row['exercise_type'] ?? 'dinamico',
      'sets': row['sets'],
      'reps': row['reps'],
      'restSeconds': row['rest_seconds'],
      'rir': row['rir'],
      'durationSeconds': row['duration_seconds'],
      'orderIndex': row['order_index'],
    };

// ── Handlers ─────────────────────────────────────────────────────────────────

/// GET /listRoutines?tab=mine|public
/// - mine   → rutinas propias del usuario autenticado (is_active = true)
/// - public → rutinas públicas de profesores (is_public = true, is_active = true)
/// Sin parámetro → devuelve ambas separadas
Future<Response> _listRoutines(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final tab = request.url.queryParameters['tab']?.trim() ?? '';

  if (tab == 'mine' || tab == '') {
    final myResult = await db.execute(
      'SELECT r.id, r.name, r.description, r.goal::text AS goal, '
      'r.frequency_days, r.is_public, r.is_default, r.is_active, r.user_id, r.created_by, '
      'u.name AS creator_name, r.created_at, r.updated_at, '
      'ARRAY(SELECT day_name FROM routine_days WHERE routine_id = r.id ORDER BY order_index) AS day_names '
      'FROM routines r JOIN users u ON u.id = r.created_by '
      "WHERE r.user_id = '$userId'::uuid AND r.is_active = true "
      'ORDER BY r.updated_at DESC',
    );
    final myRoutines = myResult.map((r) => _routineToMap(r.toColumnMap())).toList();

    if (tab == 'mine') {
      return jsonOk({'routines': myRoutines, 'total': myRoutines.length});
    }

    final publicResult = await db.execute(
      'SELECT r.id, r.name, r.description, r.goal::text AS goal, '
      'r.frequency_days, r.is_public, r.is_default, r.is_active, r.user_id, r.created_by, '
      'u.name AS creator_name, r.created_at, r.updated_at, '
      'ARRAY(SELECT day_name FROM routine_days WHERE routine_id = r.id ORDER BY order_index) AS day_names '
      'FROM routines r JOIN users u ON u.id = r.created_by '
      'WHERE r.is_public = true AND r.is_active = true '
      'ORDER BY r.updated_at DESC',
    );
    final publicRoutines = publicResult.map((r) => _routineToMap(r.toColumnMap())).toList();

    return jsonOk({
      'myRoutines': myRoutines,
      'publicRoutines': publicRoutines,
    });
  }

  // tab == 'public'
  final result = await db.execute(
    'SELECT r.id, r.name, r.description, r.goal::text AS goal, '
    'r.frequency_days, r.is_public, r.is_default, r.is_active, r.user_id, r.created_by, '
    'u.name AS creator_name, r.created_at, r.updated_at '
    'FROM routines r JOIN users u ON u.id = r.created_by '
    'WHERE r.is_public = true AND r.is_active = true '
    'ORDER BY r.updated_at DESC',
  );
  final routines = result.map((r) => _routineToMap(r.toColumnMap())).toList();
  return jsonOk({'routines': routines, 'total': routines.length});
}

/// GET /getRoutine/<id>  — devuelve rutina completa con días y ejercicios
Future<Response> _getRoutine(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final routineResult = await db.execute(
    'SELECT r.id, r.name, r.description, r.goal::text AS goal, '
    'r.frequency_days, r.is_public, r.is_default, r.is_active, r.user_id, r.created_by, '
    'u.name AS creator_name, r.created_at, r.updated_at '
    'FROM routines r JOIN users u ON u.id = r.created_by '
    "WHERE r.id = '$id'::uuid AND r.is_active = true",
  );

  if (routineResult.isEmpty) return notFound('Rutina no encontrada');

  final routine = _routineToMap(routineResult.first.toColumnMap());

  // Verificar acceso: es del usuario o es pública
  final isOwner = routine['userId'] == userId;
  final isPublic = routine['isPublic'] as bool? ?? false;
  if (!isOwner && !isPublic) return forbidden('No tienes acceso a esta rutina');

  // Obtener días
  final daysResult = await db.execute(
    'SELECT id, routine_id, day_name, label, order_index '
    "FROM routine_days WHERE routine_id = '$id'::uuid "
    'ORDER BY order_index ASC',
  );

  final days = daysResult.map((r) => _dayToMap(r.toColumnMap())).toList();

  // Obtener ejercicios de todos los días en un solo query
  if (days.isNotEmpty) {
    final dayIds = days.map((d) => "'${d['id']}'::uuid").join(', ');
    final exResult = await db.execute(
      'SELECT rde.id, rde.routine_day_id, rde.exercise_id, '
      'e.name AS exercise_name, e.muscle_group::text AS muscle_group, '
      'e.exercise_type, '
      'rde.sets, rde.reps, rde.rest_seconds, rde.rir, rde.duration_seconds, rde.order_index '
      'FROM routine_day_exercises rde '
      'JOIN exercises e ON e.id = rde.exercise_id '
      'WHERE rde.routine_day_id IN ($dayIds) '
      'ORDER BY rde.routine_day_id, rde.order_index ASC',
    );

    final exByDay = <String, List<Map<String, dynamic>>>{};
    for (final row in exResult) {
      final ex = _dayExerciseToMap(row.toColumnMap());
      final dayId = ex['routineDayId'] as String;
      exByDay.putIfAbsent(dayId, () => []).add(ex);
    }

    for (final day in days) {
      day['exercises'] = exByDay[day['id'] as String] ?? [];
    }
  }

  routine['days'] = days;
  return jsonOk({'routine': routine});
}

/// POST /createRoutine
/// Body: { name, goal, description?, isPublic?, days: [{dayName, label, orderIndex, exercises: [{exerciseId, sets, reps, restSeconds, orderIndex}]}] }
Future<Response> _createRoutine(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final userRole = claims['role'] as String? ?? 'student';

  final body = await parseBody(request);
  final name = (body['name'] as String? ?? '').trim();
  final goal = (body['goal'] as String? ?? '').trim().toLowerCase();
  final description = (body['description'] as String? ?? '').trim();
  final isPublic = body['isPublic'] as bool? ?? false;
  final daysRaw = body['days'] as List<dynamic>? ?? [];

  if (name.isEmpty) return badRequest('El nombre es requerido');
  if (!_validGoals.contains(goal)) {
    return badRequest('Objetivo inválido. Válidos: ${_validGoals.join(', ')}');
  }
  if (daysRaw.isEmpty) return badRequest('Debes agregar al menos un día de entrenamiento');
  // Solo profesores y admins pueden crear rutinas públicas
  if (isPublic && userRole != 'professor' && userRole != 'admin') {
    return forbidden('Solo profesores y admins pueden crear rutinas públicas');
  }

  final frequencyDays = daysRaw.length;
  final routineId = _uuid.v4();

  // Insertar rutina
  await db.execute(
    Sql.named(
      'INSERT INTO routines (id, user_id, name, description, goal, frequency_days, is_public, created_by) '
      "VALUES ('$routineId'::uuid, '$userId'::uuid, @name, @description, "
      "@goal::workout_goal, @frequencyDays, @isPublic, '$userId'::uuid)",
    ),
    parameters: {
      'name': name,
      'description': description.isEmpty ? null : description,
      'goal': goal,
      'frequencyDays': frequencyDays,
      'isPublic': isPublic,
    },
  );

  // Insertar días y ejercicios
  for (final dayRaw in daysRaw) {
    final day = dayRaw as Map<String, dynamic>;
    final dayName = (day['dayName'] as String? ?? '').trim();
    final label = (day['label'] as String? ?? dayName).trim();
    final orderIndex = day['orderIndex'] as int? ?? 0;
    final exercises = day['exercises'] as List<dynamic>? ?? [];

    if (dayName.isEmpty) continue;

    final dayId = _uuid.v4();
    await db.execute(
      Sql.named(
        'INSERT INTO routine_days (id, routine_id, day_name, label, order_index) '
        "VALUES ('$dayId'::uuid, '$routineId'::uuid, @dayName, @label, @orderIndex)",
      ),
      parameters: {
        'dayName': dayName,
        'label': label,
        'orderIndex': orderIndex,
      },
    );

    for (final exRaw in exercises) {
      final ex = exRaw as Map<String, dynamic>;
      final exerciseId = ex['exerciseId'] as String? ?? '';
      if (exerciseId.isEmpty) continue;

      final sets = ex['sets'] as int? ?? 3;
      final reps = (ex['reps'] as String? ?? '8-12').trim();
      final restSeconds = ex['restSeconds'] as int? ?? 90;
      final rir = ex['rir'] as int?;
      final durationSeconds = ex['durationSeconds'] as int?;
      final exOrderIndex = ex['orderIndex'] as int? ?? 0;

      final rdeId = _uuid.v4();
      await db.execute(
        Sql.named(
          'INSERT INTO routine_day_exercises (id, routine_day_id, exercise_id, sets, reps, rest_seconds, rir, duration_seconds, order_index) '
          "VALUES ('$rdeId'::uuid, '$dayId'::uuid, '$exerciseId'::uuid, "
          '@sets, @reps, @restSeconds, @rir, @durationSeconds, @orderIndex)',
        ),
        parameters: {
          'sets': sets,
          'reps': reps,
          'restSeconds': restSeconds,
          'rir': rir,
          'durationSeconds': durationSeconds,
          'orderIndex': exOrderIndex,
        },
      );
    }
  }

  // Leer y devolver la rutina completa
  return _getRoutine(request.change(path: ''), routineId);
}

/// PATCH /updateRoutine/<id>
/// Body: { name?, goal?, description?, isPublic? }
Future<Response> _updateRoutine(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  // Solo el creador o admin puede editar
  final check = await db.execute(
    "SELECT created_by FROM routines WHERE id = '$id'::uuid AND is_active = true",
  );
  if (check.isEmpty) return notFound('Rutina no encontrada');

  final createdBy = check.first.toColumnMap()['created_by'] as String?;
  final role = claims['role'] as String? ?? 'student';
  if (createdBy != userId && role != 'admin') {
    return forbidden('No puedes editar esta rutina');
  }

  final body = await parseBody(request);
  final setClauses = <String>[];
  final params = <Object?>[];
  var idx = 1;

  if (body.containsKey('name')) {
    final name = (body['name'] as String? ?? '').trim();
    if (name.isEmpty) return badRequest('El nombre no puede estar vacío');
    setClauses.add('name = \$$idx');
    params.add(name);
    idx++;
  }

  if (body.containsKey('description')) {
    setClauses.add('description = \$$idx');
    params.add(body['description']);
    idx++;
  }

  if (body.containsKey('goal')) {
    final goal = (body['goal'] as String? ?? '').trim().toLowerCase();
    if (!_validGoals.contains(goal)) return badRequest('Objetivo inválido');
    setClauses.add("goal = '$goal'::workout_goal");
  }

  if (body.containsKey('isPublic')) {
    setClauses.add('is_public = \$$idx');
    params.add(body['isPublic'] as bool? ?? false);
    idx++;
  }

  if (setClauses.isEmpty && !body.containsKey('days')) {
    return badRequest('No hay campos para actualizar');
  }

  if (setClauses.isNotEmpty) {
    setClauses.add('updated_at = NOW()');
    await db.execute(
      "UPDATE routines SET ${setClauses.join(', ')} WHERE id = '$id'::uuid",
      parameters: params.isEmpty ? null : params,
    );
  }

  // Reemplazar días y ejercicios si se envían
  if (body.containsKey('days')) {
    // Desvincular sesiones antes de borrar los días para evitar FK violation
    await db.execute(
      'UPDATE workout_sessions SET routine_day_id = NULL '
      "WHERE routine_day_id IN (SELECT id FROM routine_days WHERE routine_id = '$id'::uuid)",
    );
    await db.execute(
      "DELETE FROM routine_days WHERE routine_id = '$id'::uuid",
    );

    final days = (body['days'] as List? ?? []).cast<Map<String, dynamic>>();
    for (var i = 0; i < days.length; i++) {
      final day = days[i];
      final dayId = _uuid.v4();
      final dayName = (day['dayName'] as String? ?? '').trim();
      final label = (day['label'] as String? ?? dayName).trim();
      final orderIndex = day['orderIndex'] as int? ?? i;

      await db.execute(
        Sql.named(
          'INSERT INTO routine_days (id, routine_id, day_name, label, order_index) '
          "VALUES ('$dayId'::uuid, '$id'::uuid, @dayName, @label, @orderIndex)",
        ),
        parameters: {'dayName': dayName, 'label': label, 'orderIndex': orderIndex},
      );

      final exercises = (day['exercises'] as List? ?? []).cast<Map<String, dynamic>>();
      for (var j = 0; j < exercises.length; j++) {
        final ex = exercises[j];
        final exerciseId = ex['exerciseId'] as String? ?? '';
        if (exerciseId.isEmpty) continue;
        final sets = ex['sets'] as int? ?? 3;
        final reps = ex['reps'] as String? ?? '8-12';
        final restSeconds = ex['restSeconds'] as int? ?? 90;
        final rir = ex['rir'] as int?;
        final durationSeconds = ex['durationSeconds'] as int?;
        final rdeId = _uuid.v4();
        await db.execute(
          Sql.named(
            'INSERT INTO routine_day_exercises (id, routine_day_id, exercise_id, sets, reps, rest_seconds, rir, duration_seconds, order_index) '
            "VALUES ('$rdeId'::uuid, '$dayId'::uuid, '$exerciseId'::uuid, "
            '@sets, @reps, @restSeconds, @rir, @durationSeconds, @orderIndex)',
          ),
          parameters: {'sets': sets, 'reps': reps, 'restSeconds': restSeconds, 'rir': rir, 'durationSeconds': durationSeconds, 'orderIndex': j},
        );
      }
    }
  }

  return _getRoutine(request.change(path: ''), id);
}

/// GET /myDefault — devuelve la rutina por defecto del usuario autenticado (completa con días)
Future<Response> _myDefault(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final result = await db.execute(
    'SELECT r.id, r.name, r.description, r.goal::text AS goal, '
    'r.frequency_days, r.is_public, r.is_default, r.is_active, r.user_id, r.created_by, '
    'u.name AS creator_name, r.created_at, r.updated_at '
    'FROM routines r JOIN users u ON u.id = r.created_by '
    "WHERE r.user_id = '$userId'::uuid AND r.is_default = true AND r.is_active = true "
    'LIMIT 1',
  );

  if (result.isEmpty) return jsonOk({'routine': null});

  final routine = _routineToMap(result.first.toColumnMap());
  final id = routine['id'] as String;

  final daysResult = await db.execute(
    'SELECT id, routine_id, day_name, label, order_index '
    "FROM routine_days WHERE routine_id = '$id'::uuid ORDER BY order_index ASC",
  );
  final days = daysResult.map((r) => _dayToMap(r.toColumnMap())).toList();

  if (days.isNotEmpty) {
    final dayIds = days.map((d) => "'${d['id']}'::uuid").join(', ');
    final exResult = await db.execute(
      'SELECT rde.id, rde.routine_day_id, rde.exercise_id, '
      'e.name AS exercise_name, e.muscle_group::text AS muscle_group, '
      'e.exercise_type, '
      'rde.sets, rde.reps, rde.rest_seconds, rde.rir, rde.duration_seconds, rde.order_index '
      'FROM routine_day_exercises rde '
      'JOIN exercises e ON e.id = rde.exercise_id '
      'WHERE rde.routine_day_id IN ($dayIds) '
      'ORDER BY rde.routine_day_id, rde.order_index ASC',
    );
    final exByDay = <String, List<Map<String, dynamic>>>{};
    for (final row in exResult) {
      final ex = _dayExerciseToMap(row.toColumnMap());
      exByDay.putIfAbsent(ex['routineDayId'] as String, () => []).add(ex);
    }
    for (final day in days) {
      day['exercises'] = exByDay[day['id'] as String] ?? [];
    }
  }

  routine['days'] = days;
  return jsonOk({'routine': routine});
}

/// PATCH /setDefault/<id> — marca esta rutina como por defecto (desactiva las demás)
Future<Response> _setDefault(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final check = await db.execute(
    "SELECT user_id FROM routines WHERE id = '$id'::uuid AND is_active = true",
  );
  if (check.isEmpty) return notFound('Rutina no encontrada');

  final owner = check.first.toColumnMap()['user_id'] as String?;
  if (owner != userId) return forbidden('No puedes establecer esta rutina como predeterminada');

  // Quitar default de todas las rutinas del usuario
  await db.execute(
    "UPDATE routines SET is_default = false WHERE user_id = '$userId'::uuid",
  );
  // Marcar esta como default
  await db.execute(
    "UPDATE routines SET is_default = true, updated_at = NOW() WHERE id = '$id'::uuid",
  );

  return jsonOk({'message': 'Rutina establecida como predeterminada'});
}

/// POST /copyRoutine/<id> — copia una rutina pública como propia
Future<Response> _copyRoutine(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  // Verificar que la rutina existe y es pública (o del usuario)
  final srcResult = await db.execute(
    'SELECT r.id, r.name, r.description, r.goal::text AS goal, r.frequency_days '
    'FROM routines r '
    "WHERE r.id = '$id'::uuid AND r.is_active = true AND (r.is_public = true OR r.user_id = '$userId'::uuid)",
  );
  if (srcResult.isEmpty) return notFound('Rutina no encontrada o sin acceso');

  final src = srcResult.first.toColumnMap();
  final newId = _uuid.v4();
  final name = '${src['name']} (copia)';

  await db.execute(
    Sql.named(
      'INSERT INTO routines (id, user_id, name, description, goal, frequency_days, is_public, created_by) '
      "VALUES ('$newId'::uuid, '$userId'::uuid, @name, @description, "
      "@goal::workout_goal, @freq, false, '$userId'::uuid)",
    ),
    parameters: {
      'name': name,
      'description': src['description'],
      'goal': src['goal'] as String,
      'freq': src['frequency_days'] as int,
    },
  );

  // Copiar días y ejercicios
  final daysResult = await db.execute(
    'SELECT id, day_name, label, order_index FROM routine_days '
    "WHERE routine_id = '$id'::uuid ORDER BY order_index ASC",
  );

  for (final dayRow in daysResult) {
    final day = dayRow.toColumnMap();
    final newDayId = _uuid.v4();
    await db.execute(
      Sql.named(
        'INSERT INTO routine_days (id, routine_id, day_name, label, order_index) '
        "VALUES ('$newDayId'::uuid, '$newId'::uuid, @dayName, @label, @order)",
      ),
      parameters: {
        'dayName': day['day_name'],
        'label': day['label'],
        'order': day['order_index'],
      },
    );

    final exResult = await db.execute(
      'SELECT exercise_id, sets, reps, rest_seconds, rir, duration_seconds, order_index '
      "FROM routine_day_exercises WHERE routine_day_id = '${day['id']}'::uuid "
      'ORDER BY order_index ASC',
    );
    for (final exRow in exResult) {
      final ex = exRow.toColumnMap();
      final newExId = _uuid.v4();
      await db.execute(
        Sql.named(
          'INSERT INTO routine_day_exercises (id, routine_day_id, exercise_id, sets, reps, rest_seconds, rir, duration_seconds, order_index) '
          "VALUES ('$newExId'::uuid, '$newDayId'::uuid, '${ex['exercise_id']}'::uuid, "
          '@sets, @reps, @rest, @rir, @durationSeconds, @order)',
        ),
        parameters: {
          'sets': ex['sets'],
          'reps': ex['reps'],
          'rest': ex['rest_seconds'],
          'rir': ex['rir'],
          'durationSeconds': ex['duration_seconds'],
          'order': ex['order_index'],
        },
      );
    }
  }

  return _getRoutine(request.change(path: ''), newId);
}

/// DELETE /deleteRoutine/<id>  — soft delete
Future<Response> _deleteRoutine(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final role = claims['role'] as String? ?? 'student';

  final check = await db.execute(
    "SELECT created_by FROM routines WHERE id = '$id'::uuid AND is_active = true",
  );
  if (check.isEmpty) return notFound('Rutina no encontrada');

  final createdBy = check.first.toColumnMap()['created_by'] as String?;
  if (createdBy != userId && role != 'admin') {
    return forbidden('No puedes eliminar esta rutina');
  }

  await db.execute(
    "UPDATE routines SET is_active = false, updated_at = NOW() WHERE id = '$id'::uuid",
  );

  return jsonOk({'message': 'Rutina eliminada'});
}
