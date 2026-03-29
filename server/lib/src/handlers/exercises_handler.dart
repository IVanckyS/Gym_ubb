import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

final _uuid = Uuid();

Router get exercisesHandler {
  final router = Router();

  // GET /api/v1/exercises/listExercises?muscleGroup=&difficulty=&search=
  router.get('/listExercises', _listExercises);

  // GET /api/v1/exercises/getExercise/<id>
  router.get('/getExercise/<id>', _getExercise);

  // GET /api/v1/exercises/byMuscleGroup
  router.get('/byMuscleGroup', _byMuscleGroup);

  // POST /api/v1/exercises/createExercise
  router.post('/createExercise', _createExercise);

  // PATCH /api/v1/exercises/updateExercise/<id>
  router.patch('/updateExercise/<id>', _updateExercise);

  // PATCH /api/v1/exercises/deactivateExercise/<id>
  router.patch('/deactivateExercise/<id>', _deactivateExercise);

  return router;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _exerciseToMap(Map<String, dynamic> row) => {
      'id': row['id'],
      'name': row['name'],
      'muscleGroup': row['muscle_group'],
      'difficulty': row['difficulty'],
      'description': row['description'],
      'muscles': (row['muscles'] as List?)?.cast<String>() ?? [],
      'instructions': (row['instructions'] as List?)?.cast<String>() ?? [],
      'safetyNotes': row['safety_notes'],
      'variations': (row['variations'] as List?)?.cast<String>() ?? [],
      'videoUrl': row['video_url'],
      'equipment': row['equipment'],
      'defaultSets': row['default_sets'],
      'defaultReps': row['default_reps'],
      'defaultRestSeconds': row['default_rest_seconds'],
      'isActive': row['is_active'],
      'createdAt': row['created_at']?.toString(),
    };

const _validMuscleGroups = [
  'pecho',
  'espalda',
  'piernas',
  'hombros',
  'brazos',
  'core',
  'gluteos',
];

const _validDifficulties = ['principiante', 'intermedio', 'avanzado'];

// ── Handlers ─────────────────────────────────────────────────────────────────

Future<Response> _listExercises(Request request) async {
  await requireAuth(request);

  final queryParams = request.url.queryParameters;
  final muscleGroup = queryParams['muscleGroup']?.trim() ?? '';
  final difficulty = queryParams['difficulty']?.trim() ?? '';
  final search = queryParams['search']?.trim() ?? '';

  final conditions = <String>['is_active = true'];
  final params = <Object?>[];
  var paramIdx = 1;

  if (muscleGroup.isNotEmpty) {
    conditions.add('muscle_group::text = \$$paramIdx');
    params.add(muscleGroup);
    paramIdx++;
  }

  if (difficulty.isNotEmpty) {
    conditions.add('difficulty::text = \$$paramIdx');
    params.add(difficulty);
    paramIdx++;
  }

  if (search.isNotEmpty) {
    conditions.add('LOWER(name) LIKE \$$paramIdx');
    params.add('%${search.toLowerCase()}%');
    paramIdx++;
  }

  final where = 'WHERE ${conditions.join(' AND ')}';

  final result = await db.execute(
    'SELECT id, name, muscle_group::text AS muscle_group, '
    'difficulty::text AS difficulty, description, muscles, instructions, '
    'safety_notes, variations, video_url, equipment, '
    'default_sets, default_reps, default_rest_seconds, is_active, created_at '
    'FROM exercises $where ORDER BY name ASC',
    parameters: params.isEmpty ? null : params,
  );

  final exercises = result.map((row) => _exerciseToMap(row.toColumnMap())).toList();
  return jsonOk({'exercises': exercises, 'total': exercises.length});
}

Future<Response> _getExercise(Request request, String id) async {
  await requireAuth(request);

  final result = await db.execute(
    'SELECT id, name, muscle_group::text AS muscle_group, '
    'difficulty::text AS difficulty, description, muscles, instructions, '
    'safety_notes, variations, video_url, equipment, '
    'default_sets, default_reps, default_rest_seconds, is_active, created_at '
    "FROM exercises WHERE id = '$id'::uuid",
  );

  if (result.isEmpty) return notFound('Ejercicio no encontrado');

  return jsonOk({'exercise': _exerciseToMap(result.first.toColumnMap())});
}

Future<Response> _byMuscleGroup(Request request) async {
  await requireAuth(request);

  final result = await db.execute(
    'SELECT id, name, muscle_group::text AS muscle_group, '
    'difficulty::text AS difficulty, description, muscles, instructions, '
    'safety_notes, variations, video_url, equipment, '
    'default_sets, default_reps, default_rest_seconds, is_active, created_at '
    'FROM exercises WHERE is_active = true ORDER BY muscle_group, name ASC',
  );

  final groups = <String, List<Map<String, dynamic>>>{};

  for (final row in result) {
    final exercise = _exerciseToMap(row.toColumnMap());
    final group = exercise['muscleGroup'] as String? ?? 'otro';
    groups.putIfAbsent(group, () => []).add(exercise);
  }

  return jsonOk({'groups': groups});
}

Future<Response> _createExercise(Request request) async {
  await requireRole(request, ['admin', 'professor']);

  final body = await parseBody(request);
  final name = (body['name'] as String? ?? '').trim();
  final muscleGroup = (body['muscleGroup'] as String? ?? '').trim().toLowerCase();
  final difficulty = (body['difficulty'] as String? ?? '').trim().toLowerCase();
  final description = (body['description'] as String? ?? '').trim();
  final safetyNotes = (body['safetyNotes'] as String? ?? '').trim();
  final videoUrl = (body['videoUrl'] as String? ?? '').trim();
  final equipment = (body['equipment'] as String? ?? '').trim();
  final defaultSets = body['defaultSets'] as int? ?? 3;
  final defaultReps = (body['defaultReps'] as String? ?? '8-12').trim();
  final defaultRestSeconds = body['defaultRestSeconds'] as int? ?? 90;

  final muscles = (body['muscles'] as List<dynamic>? ?? []).cast<String>();
  final instructions = (body['instructions'] as List<dynamic>? ?? []).cast<String>();
  final variations = (body['variations'] as List<dynamic>? ?? []).cast<String>();

  if (name.isEmpty) return badRequest('El nombre es requerido');
  if (!_validMuscleGroups.contains(muscleGroup)) {
    return badRequest(
      'Grupo muscular inválido. Válidos: ${_validMuscleGroups.join(', ')}',
    );
  }
  if (!_validDifficulties.contains(difficulty)) {
    return badRequest(
      'Dificultad inválida. Válidas: ${_validDifficulties.join(', ')}',
    );
  }

  final id = _uuid.v4();

  await db.execute(
    Sql.named(
      "INSERT INTO exercises (id, name, muscle_group, difficulty, description, "
      "muscles, instructions, safety_notes, variations, video_url, equipment, "
      "default_sets, default_reps, default_rest_seconds) VALUES "
      "('$id'::uuid, @name, @muscleGroup::muscle_group, @difficulty::difficulty_level, "
      "@description, @muscles, @instructions, @safetyNotes, @variations, "
      "@videoUrl, @equipment, @defaultSets, @defaultReps, @defaultRestSeconds)",
    ),
    parameters: {
      'name': name,
      'muscleGroup': muscleGroup,
      'difficulty': difficulty,
      'description': description.isEmpty ? null : description,
      'muscles': muscles,
      'instructions': instructions,
      'safetyNotes': safetyNotes.isEmpty ? null : safetyNotes,
      'variations': variations,
      'videoUrl': videoUrl.isEmpty ? null : videoUrl,
      'equipment': equipment.isEmpty ? null : equipment,
      'defaultSets': defaultSets,
      'defaultReps': defaultReps,
      'defaultRestSeconds': defaultRestSeconds,
    },
  );

  final created = await db.execute(
    'SELECT id, name, muscle_group::text AS muscle_group, '
    'difficulty::text AS difficulty, description, muscles, instructions, '
    'safety_notes, variations, video_url, equipment, '
    'default_sets, default_reps, default_rest_seconds, is_active, created_at '
    "FROM exercises WHERE id = '$id'::uuid",
  );

  return jsonCreated({'exercise': _exerciseToMap(created.first.toColumnMap())});
}

Future<Response> _updateExercise(Request request, String id) async {
  await requireRole(request, ['admin', 'professor']);

  final body = await parseBody(request);

  final allowedKeys = [
    'name',
    'muscleGroup',
    'difficulty',
    'description',
    'muscles',
    'instructions',
    'safetyNotes',
    'variations',
    'videoUrl',
    'equipment',
    'defaultSets',
    'defaultReps',
    'defaultRestSeconds',
  ];

  final hasUpdate = allowedKeys.any((k) => body.containsKey(k));
  if (!hasUpdate) return badRequest('No hay campos para actualizar');

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

  if (body.containsKey('muscleGroup')) {
    final muscleGroup = (body['muscleGroup'] as String? ?? '').trim().toLowerCase();
    if (!_validMuscleGroups.contains(muscleGroup)) {
      return badRequest('Grupo muscular inválido');
    }
    setClauses.add("muscle_group = '$muscleGroup'::muscle_group");
  }

  if (body.containsKey('difficulty')) {
    final difficulty = (body['difficulty'] as String? ?? '').trim().toLowerCase();
    if (!_validDifficulties.contains(difficulty)) {
      return badRequest('Dificultad inválida');
    }
    setClauses.add("difficulty = '$difficulty'::difficulty_level");
  }

  if (body.containsKey('description')) {
    setClauses.add('description = \$$idx');
    params.add(body['description']);
    idx++;
  }

  if (body.containsKey('muscles')) {
    final muscles = (body['muscles'] as List<dynamic>? ?? []).cast<String>();
    setClauses.add('muscles = \$$idx');
    params.add(muscles);
    idx++;
  }

  if (body.containsKey('instructions')) {
    final instructions = (body['instructions'] as List<dynamic>? ?? []).cast<String>();
    setClauses.add('instructions = \$$idx');
    params.add(instructions);
    idx++;
  }

  if (body.containsKey('safetyNotes')) {
    setClauses.add('safety_notes = \$$idx');
    params.add(body['safetyNotes']);
    idx++;
  }

  if (body.containsKey('variations')) {
    final variations = (body['variations'] as List<dynamic>? ?? []).cast<String>();
    setClauses.add('variations = \$$idx');
    params.add(variations);
    idx++;
  }

  if (body.containsKey('videoUrl')) {
    setClauses.add('video_url = \$$idx');
    params.add(body['videoUrl']);
    idx++;
  }

  if (body.containsKey('equipment')) {
    setClauses.add('equipment = \$$idx');
    params.add(body['equipment']);
    idx++;
  }

  if (body.containsKey('defaultSets')) {
    setClauses.add('default_sets = \$$idx');
    params.add(body['defaultSets'] as int? ?? 3);
    idx++;
  }

  if (body.containsKey('defaultReps')) {
    setClauses.add('default_reps = \$$idx');
    params.add(body['defaultReps'] as String? ?? '8-12');
    idx++;
  }

  if (body.containsKey('defaultRestSeconds')) {
    setClauses.add('default_rest_seconds = \$$idx');
    params.add(body['defaultRestSeconds'] as int? ?? 90);
    idx++;
  }

  await db.execute(
    "UPDATE exercises SET ${setClauses.join(', ')} WHERE id = '$id'::uuid",
    parameters: params.isEmpty ? null : params,
  );

  final updated = await db.execute(
    'SELECT id, name, muscle_group::text AS muscle_group, '
    'difficulty::text AS difficulty, description, muscles, instructions, '
    'safety_notes, variations, video_url, equipment, '
    'default_sets, default_reps, default_rest_seconds, is_active, created_at '
    "FROM exercises WHERE id = '$id'::uuid",
  );

  if (updated.isEmpty) return notFound('Ejercicio no encontrado');
  return jsonOk({'exercise': _exerciseToMap(updated.first.toColumnMap())});
}

Future<Response> _deactivateExercise(Request request, String id) async {
  await requireRole(request, 'admin');

  final body = await parseBody(request);
  final active = body['isActive'] as bool? ?? false;

  await db.execute(
    "UPDATE exercises SET is_active = \$1 WHERE id = '$id'::uuid",
    parameters: [active],
  );

  return jsonOk({'message': active ? 'Ejercicio activado' : 'Ejercicio desactivado'});
}
