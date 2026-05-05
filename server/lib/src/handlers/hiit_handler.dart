import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

final _uuid = Uuid();

Router get hiitHandler {
  final router = Router();

  router.get('/workouts', _listWorkouts);
  router.post('/workouts', _createWorkout);
  router.get('/workouts/<id>', _getWorkout);
  router.patch('/workouts/<id>', _updateWorkout);
  router.delete('/workouts/<id>', _deleteWorkout);
  router.post('/sessions', _saveSession);
  router.get('/sessions', _listSessions);

  return router;
}

// ── GET /workouts?public=true ─────────────────────────────────────────────────
Future<Response> _listWorkouts(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final onlyPublic = request.url.queryParameters['public'] == 'true';

  final whereClause = onlyPublic
      ? 'is_public = true'
      : "(user_id = '$userId'::uuid OR is_public = true)";

  final result = await db.execute(
    'SELECT id, user_id, name, mode::text AS mode, config, is_public, created_at '
    'FROM hiit_workouts '
    'WHERE is_active = true AND $whereClause '
    'ORDER BY created_at DESC',
  );

  final workouts = result.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'].toString(),
      'userId': m['user_id']?.toString(),
      'name': m['name'],
      'mode': m['mode'],
      'config': m['config'],
      'isPublic': m['is_public'],
      'createdAt': m['created_at']?.toString(),
    };
  }).toList();

  return jsonOk({'workouts': workouts});
}

// ── POST /workouts ────────────────────────────────────────────────────────────
Future<Response> _createWorkout(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

  final name = body['name'] as String?;
  final mode = body['mode'] as String?;
  final config = body['config'] as Map<String, dynamic>? ?? {};
  final isPublic = body['isPublic'] as bool? ?? false;

  if (name == null || name.isEmpty) return badRequest('name requerido');
  if (mode == null) return badRequest('mode requerido');

  const validModes = {'tabata', 'emom', 'amrap', 'for_time', 'mix'};
  if (!validModes.contains(mode)) return badRequest('mode inválido');

  final id = _uuid.v4();
  final configJson = jsonEncode(config);

  await db.execute(
    "INSERT INTO hiit_workouts (id, user_id, name, mode, config, is_public) "
    "VALUES ('$id'::uuid, '$userId'::uuid, \$1, '$mode'::hiit_mode, \$2::jsonb, \$3)",
    parameters: [name, configJson, isPublic],
  );

  return jsonCreated({'id': id, 'name': name, 'mode': mode});
}

// ── GET /workouts/:id ─────────────────────────────────────────────────────────
Future<Response> _getWorkout(Request request, String id) async {
  await requireAuth(request);

  final result = await db.execute(
    'SELECT id, user_id, name, mode::text AS mode, config, is_public, created_at '
    "FROM hiit_workouts WHERE id = '$id'::uuid AND is_active = true",
  );
  if (result.isEmpty) return notFound('Workout no encontrado');

  final m = result.first.toColumnMap();
  return jsonOk({
    'id': m['id'].toString(),
    'userId': m['user_id']?.toString(),
    'name': m['name'],
    'mode': m['mode'],
    'config': m['config'],
    'isPublic': m['is_public'],
    'createdAt': m['created_at']?.toString(),
  });
}

// ── PATCH /workouts/:id ───────────────────────────────────────────────────────
Future<Response> _updateWorkout(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final ownerCheck = await db.execute(
    "SELECT user_id FROM hiit_workouts WHERE id = '$id'::uuid AND is_active = true",
  );
  if (ownerCheck.isEmpty) return notFound('Workout no encontrado');

  final ownerId = ownerCheck.first.toColumnMap()['user_id']?.toString();
  if (ownerId != userId && claims['role'] != 'admin') return forbidden('No autorizado');

  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;
  final sets = <String>[];
  final params = <dynamic>[];
  var i = 1;

  if (body.containsKey('name')) {
    sets.add('name = \$$i'); params.add(body['name']); i++;
  }
  if (body.containsKey('config')) {
    sets.add('config = \$$i::jsonb'); params.add(jsonEncode(body['config'])); i++;
  }
  if (body.containsKey('isPublic')) {
    sets.add('is_public = \$$i'); params.add(body['isPublic']); i++;
  }
  if (sets.isEmpty) return badRequest('Sin campos para actualizar');

  sets.add('updated_at = NOW()');
  await db.execute(
    "UPDATE hiit_workouts SET ${sets.join(', ')} WHERE id = '$id'::uuid",
    parameters: params,
  );

  return jsonOk({'updated': true});
}

// ── DELETE /workouts/:id ──────────────────────────────────────────────────────
Future<Response> _deleteWorkout(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final ownerCheck = await db.execute(
    "SELECT user_id FROM hiit_workouts WHERE id = '$id'::uuid AND is_active = true",
  );
  if (ownerCheck.isEmpty) return notFound('Workout no encontrado');

  final ownerId = ownerCheck.first.toColumnMap()['user_id']?.toString();
  if (ownerId != userId && claims['role'] != 'admin') return forbidden('No autorizado');

  await db.execute(
    "UPDATE hiit_workouts SET is_active = false WHERE id = '$id'::uuid",
  );
  return jsonOk({'deleted': true});
}

// ── POST /sessions ────────────────────────────────────────────────────────────
Future<Response> _saveSession(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final body = jsonDecode(await request.readAsString()) as Map<String, dynamic>;

  final name = body['name'] as String? ?? 'Sesión HIIT';
  final mode = body['mode'] as String?;
  final config = body['config'] as Map<String, dynamic>? ?? {};
  final totalDuration = body['totalDurationSeconds'] as int?;
  final rounds = body['roundsCompleted'] as int? ?? 0;
  final hiitWorkoutId = body['hiitWorkoutId'] as String?;
  final startedAt =
      body['startedAt'] as String? ?? DateTime.now().toUtc().toIso8601String();
  final endedAt =
      body['endedAt'] as String? ?? DateTime.now().toUtc().toIso8601String();

  if (mode == null) return badRequest('mode requerido');

  final id = _uuid.v4();
  final configJson = jsonEncode(config);
  final workoutRef =
      hiitWorkoutId != null ? "'$hiitWorkoutId'::uuid" : 'NULL';

  await db.execute(
    "INSERT INTO hiit_sessions "
    "(id, user_id, hiit_workout_id, name, mode, config, "
    'total_duration_seconds, rounds_completed, started_at, ended_at) '
    "VALUES ('$id'::uuid, '$userId'::uuid, $workoutRef, \$1, '$mode'::hiit_mode, "
    '\$2::jsonb, \$3, \$4, \$5::timestamptz, \$6::timestamptz)',
    parameters: [name, configJson, totalDuration, rounds, startedAt, endedAt],
  );

  return jsonCreated({'id': id});
}

// ── GET /sessions ─────────────────────────────────────────────────────────────
Future<Response> _listSessions(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final limit =
      int.tryParse(request.url.queryParameters['limit'] ?? '20') ?? 20;
  final offset =
      int.tryParse(request.url.queryParameters['offset'] ?? '0') ?? 0;

  final result = await db.execute(
    'SELECT id, hiit_workout_id, name, mode::text AS mode, config, '
    'total_duration_seconds, rounds_completed, started_at, ended_at '
    'FROM hiit_sessions '
    "WHERE user_id = '$userId'::uuid "
    'ORDER BY started_at DESC '
    'LIMIT $limit OFFSET $offset',
  );

  final sessions = result.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'].toString(),
      'hiitWorkoutId': m['hiit_workout_id']?.toString(),
      'name': m['name'],
      'mode': m['mode'],
      'config': m['config'],
      'totalDurationSeconds': m['total_duration_seconds'],
      'roundsCompleted': m['rounds_completed'],
      'startedAt': m['started_at']?.toString(),
      'endedAt': m['ended_at']?.toString(),
    };
  }).toList();

  return jsonOk({'sessions': sessions});
}
