import 'dart:io';
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

  // POST /api/v1/exercises/uploadImage/<id>  (multipart/form-data, field: "file")
  router.post('/uploadImage/<id>', _uploadImage);

  // GET /api/v1/exercises/search?q=&exclude=&limit=10
  router.get('/search', _searchExercises);

  return router;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _exerciseToMap(Map<String, dynamic> row) => {
      'id': row['id'],
      'name': row['name'],
      'muscleGroup': row['muscle_group'],
      'difficulty': row['difficulty'],
      'exerciseType': row['exercise_type'] ?? 'dinamico',
      'description': row['description'],
      'muscles': (row['muscles'] as List?)?.cast<String>() ?? [],
      'instructions': (row['instructions'] as List?)?.cast<String>() ?? [],
      'safetyNotes': row['safety_notes'],
      'variations': (row['variations'] as List?)?.cast<String>() ?? [],
      'videoUrl': row['video_url'],
      'imageUrl': row['image_url'],
      'stepImages': (row['step_images'] as List?)?.cast<String>() ?? [],
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
  // muscleGroup y equipment aceptan valores separados por coma: "pecho,espalda"
  final muscleGroups = (queryParams['muscleGroup']?.trim() ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final equipmentList = (queryParams['equipment']?.trim() ?? '')
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  final difficulty = queryParams['difficulty']?.trim() ?? '';
  final search = queryParams['search']?.trim() ?? '';

  final rankeableOnly = queryParams['rankeable'] == 'true';

  final conditions = <String>['is_active = true'];
  if (rankeableOnly) conditions.add('is_rankeable = true');
  final params = <Object?>[];
  var paramIdx = 1;

  // Filtro OR para grupos musculares
  if (muscleGroups.isNotEmpty) {
    final placeholders = muscleGroups.map((_) {
      final p = '\$$paramIdx';
      paramIdx++;
      return p;
    }).join(', ');
    conditions.add('muscle_group::text = ANY(ARRAY[$placeholders])');
    params.addAll(muscleGroups);
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

  // Filtro OR para equipamiento (ILIKE sobre campo equipment)
  if (equipmentList.isNotEmpty) {
    final equips = equipmentList.map((_) {
      final p = '\$$paramIdx';
      paramIdx++;
      return 'LOWER(equipment) LIKE $p';
    }).join(' OR ');
    conditions.add('($equips)');
    params.addAll(equipmentList.map((e) => '%${e.toLowerCase()}%'));
  }

  final where = 'WHERE ${conditions.join(' AND ')}';

  final result = await db.execute(
    'SELECT id, name, muscle_group::text AS muscle_group, '
    'difficulty::text AS difficulty, exercise_type, description, muscles, instructions, '
    'safety_notes, variations, video_url, image_url, step_images, equipment, '
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
    'difficulty::text AS difficulty, exercise_type, description, muscles, instructions, '
    'safety_notes, variations, video_url, image_url, step_images, equipment, '
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
    'difficulty::text AS difficulty, exercise_type, description, muscles, instructions, '
    'safety_notes, variations, video_url, image_url, step_images, equipment, '
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
  final exerciseType = (body['exerciseType'] as String? ?? 'dinamico').trim().toLowerCase();
  final description = (body['description'] as String? ?? '').trim();
  final safetyNotes = (body['safetyNotes'] as String? ?? '').trim();
  final videoUrl = (body['videoUrl'] as String? ?? '').trim();
  final equipment = (body['equipment'] as String? ?? '').trim();
  final defaultSets = body['defaultSets'] as int? ?? 3;
  final defaultReps = (body['defaultReps'] as String? ?? '8-12').trim();
  final defaultRestSeconds = body['defaultRestSeconds'] as int? ?? 90;

  final isRankeable = body['isRankeable'] as bool? ?? false;
  final muscles = (body['muscles'] as List<dynamic>? ?? []).cast<String>();
  final instructions = (body['instructions'] as List<dynamic>? ?? []).cast<String>();
  final variations = (body['variations'] as List<dynamic>? ?? []).cast<String>();
  final stepImages = (body['stepImages'] as List<dynamic>? ?? []).cast<String>();

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
  if (!['dinamico', 'isometrico'].contains(exerciseType)) {
    return badRequest('Tipo de ejercicio inválido. Válidos: dinamico, isometrico');
  }

  final id = _uuid.v4();

  await db.execute(
    Sql.named(
      "INSERT INTO exercises (id, name, muscle_group, difficulty, exercise_type, description, "
      "muscles, instructions, safety_notes, variations, video_url, step_images, equipment, "
      "default_sets, default_reps, default_rest_seconds, is_rankeable) VALUES "
      "('$id'::uuid, @name, @muscleGroup::muscle_group, @difficulty::difficulty_level, "
      "@exerciseType, @description, @muscles, @instructions, @safetyNotes, @variations, "
      "@videoUrl, @stepImages, @equipment, @defaultSets, @defaultReps, @defaultRestSeconds, @isRankeable)",
    ),
    parameters: {
      'name': name,
      'muscleGroup': muscleGroup,
      'difficulty': difficulty,
      'exerciseType': exerciseType,
      'description': description.isEmpty ? null : description,
      'muscles': muscles,
      'instructions': instructions,
      'safetyNotes': safetyNotes.isEmpty ? null : safetyNotes,
      'variations': variations,
      'videoUrl': videoUrl.isEmpty ? null : videoUrl,
      'stepImages': stepImages,
      'equipment': equipment.isEmpty ? null : equipment,
      'defaultSets': defaultSets,
      'defaultReps': defaultReps,
      'defaultRestSeconds': defaultRestSeconds,
      'isRankeable': isRankeable,
    },
  );

  final created = await db.execute(
    'SELECT id, name, muscle_group::text AS muscle_group, '
    'difficulty::text AS difficulty, exercise_type, description, muscles, instructions, '
    'safety_notes, variations, video_url, image_url, step_images, equipment, '
    'default_sets, default_reps, default_rest_seconds, is_active, created_at '
    "FROM exercises WHERE id = '$id'::uuid",
  );

  return jsonCreated({'exercise': _exerciseToMap(created.first.toColumnMap())});
}

Future<Response> _updateExercise(Request request, String id) async {
  await requireRole(request, ['admin', 'professor']);

  final body = await parseBody(request);

  final allowedKeys = [
    'name', 'muscleGroup', 'difficulty', 'exerciseType', 'description', 'muscles',
    'instructions', 'safetyNotes', 'variations', 'videoUrl', 'imageUrl',
    'stepImages', 'equipment', 'defaultSets', 'defaultReps', 'defaultRestSeconds',
    'isRankeable',
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

  if (body.containsKey('exerciseType')) {
    final exerciseType = (body['exerciseType'] as String? ?? 'dinamico').trim().toLowerCase();
    if (!['dinamico', 'isometrico'].contains(exerciseType)) {
      return badRequest('Tipo de ejercicio inválido. Válidos: dinamico, isometrico');
    }
    setClauses.add('exercise_type = \$$idx');
    params.add(exerciseType);
    idx++;
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

  if (body.containsKey('imageUrl')) {
    setClauses.add('image_url = \$$idx');
    params.add(body['imageUrl']);
    idx++;
  }

  if (body.containsKey('stepImages')) {
    final stepImages = (body['stepImages'] as List<dynamic>? ?? []).cast<String>();
    setClauses.add('step_images = \$$idx');
    params.add(stepImages);
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

  if (body.containsKey('isRankeable')) {
    setClauses.add('is_rankeable = \$$idx');
    params.add(body['isRankeable'] as bool? ?? false);
    idx++;
  }

  await db.execute(
    "UPDATE exercises SET ${setClauses.join(', ')} WHERE id = '$id'::uuid",
    parameters: params.isEmpty ? null : params,
  );

  final updated = await db.execute(
    'SELECT id, name, muscle_group::text AS muscle_group, '
    'difficulty::text AS difficulty, exercise_type, description, muscles, instructions, '
    'safety_notes, variations, video_url, image_url, step_images, equipment, '
    'default_sets, default_reps, default_rest_seconds, is_rankeable, is_active, created_at '
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

/// POST /uploadImage/<id>
/// Recibe multipart/form-data con campo "file" (imagen PNG/JPG) y campo opcional "type"
/// type: "main" (imagen principal) | "step_N" (imagen del paso N, ej. "step_0")
/// Guarda el archivo en /uploads/exercises/<id>/ y actualiza image_url o step_images en DB
Future<Response> _uploadImage(Request request, String id) async {
  await requireRole(request, ['admin', 'professor']);

  final contentType = request.headers['content-type'] ?? '';
  if (!contentType.contains('multipart/form-data')) {
    return badRequest('Se esperaba multipart/form-data');
  }

  // Extraer boundary
  final boundaryMatch = RegExp(r'boundary=(.+)').firstMatch(contentType);
  if (boundaryMatch == null) return badRequest('Boundary no encontrado');
  final boundary = boundaryMatch.group(1)!.trim();

  final bodyBytes = await request.read().expand((c) => c).toList();
  final bodyStr = String.fromCharCodes(bodyBytes);

  // Parsear partes del multipart
  final parts = _parseMultipart(bodyStr, bodyBytes, boundary);
  if (parts.isEmpty) return badRequest('No se encontraron partes en el multipart');

  final filePart = parts.firstWhere(
    (p) => p['name'] == 'file',
    orElse: () => {},
  );
  if (filePart.isEmpty) return badRequest('Campo "file" no encontrado');

  final type = parts.firstWhere(
    (p) => p['name'] == 'type',
    orElse: () => {'value': 'main'},
  )['value'] as String? ?? 'main';

  final filename = filePart['filename'] as String? ?? 'image.png';
  final fileBytes = filePart['bytes'] as List<int>? ?? [];
  if (fileBytes.isEmpty) return badRequest('Archivo vacío');

  // Validar extensión
  final ext = filename.split('.').last.toLowerCase();
  if (!['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(ext)) {
    return badRequest('Formato no soportado. Usa PNG, JPG, GIF o WEBP');
  }

  // Crear directorio de uploads
  final uploadDir = Directory('/uploads/exercises/$id');
  await uploadDir.create(recursive: true);

  final fileId = _uuid.v4();
  final savedPath = '${uploadDir.path}/$fileId.$ext';
  await File(savedPath).writeAsBytes(fileBytes);
  final publicUrl = '/uploads/exercises/$id/$fileId.$ext';

  // Actualizar DB según el tipo
  if (type == 'main') {
    await db.execute(
      "UPDATE exercises SET image_url = \$1 WHERE id = '$id'::uuid",
      parameters: [publicUrl],
    );
  } else if (type.startsWith('step_')) {
    final stepIndex = int.tryParse(type.replaceFirst('step_', ''));
    if (stepIndex == null) return badRequest('Tipo inválido: $type');

    // Obtener step_images actuales
    final result = await db.execute(
      "SELECT step_images FROM exercises WHERE id = '$id'::uuid",
    );
    if (result.isEmpty) return notFound('Ejercicio no encontrado');
    final current = (result.first.toColumnMap()['step_images'] as List?)?.cast<String>() ?? [];

    // Expandir la lista si el índice supera el tamaño actual
    final updated = List<String>.from(current);
    while (updated.length <= stepIndex) { updated.add(''); }
    updated[stepIndex] = publicUrl;

    await db.execute(
      "UPDATE exercises SET step_images = \$1 WHERE id = '$id'::uuid",
      parameters: [updated],
    );
  }

  return jsonOk({'url': publicUrl, 'type': type});
}

/// Parsea un multipart/form-data muy básico (campos de texto e imagen)
List<Map<String, dynamic>> _parseMultipart(
    String bodyStr, List<int> bodyBytes, String boundary) {
  final parts = <Map<String, dynamic>>[];
  final delimiter = '--$boundary';
  final sections = bodyStr.split(delimiter);

  for (final section in sections) {
    if (section.trim().isEmpty || section.trim() == '--') continue;

    final headerEnd = section.indexOf('\r\n\r\n');
    if (headerEnd == -1) continue;

    final headers = section.substring(0, headerEnd);
    final nameMatch = RegExp(r'name="([^"]+)"').firstMatch(headers);
    final filenameMatch = RegExp(r'filename="([^"]+)"').firstMatch(headers);

    if (nameMatch == null) continue;
    final name = nameMatch.group(1)!;
    final filename = filenameMatch?.group(1);

    if (filename != null) {
      // Es un archivo binario — buscar los bytes en el buffer original
      final headerMarker = '--$boundary${section.substring(0, headerEnd + 4)}';
      final startIdx = bodyStr.indexOf(headerMarker);
      if (startIdx != -1) {
        final dataStart = startIdx + headerMarker.length;
        final endMarker = '\r\n--$boundary';
        final dataEnd = bodyStr.indexOf(endMarker, dataStart);
        if (dataEnd != -1) {
          final fileBytes = bodyBytes.sublist(dataStart, dataEnd);
          parts.add({'name': name, 'filename': filename, 'bytes': fileBytes});
        }
      }
    } else {
      // Campo de texto
      final value = section.substring(headerEnd + 4).replaceAll(RegExp(r'\r\n$'), '');
      parts.add({'name': name, 'value': value});
    }
  }
  return parts;
}

/// GET /search?q=press&exclude=<id>&limit=10
/// Búsqueda rápida de ejercicios por nombre (para combo de variaciones).
Future<Response> _searchExercises(Request request) async {
  await requireAuth(request);

  final params = request.url.queryParameters;
  final q = params['q']?.trim() ?? '';
  final exclude = params['exclude'] ?? '';
  final limit = int.tryParse(params['limit'] ?? '10') ?? 10;

  if (q.isEmpty) return jsonOk({'exercises': []});

  final excludeClause =
      exclude.isNotEmpty ? "AND e.id <> '$exclude'::uuid" : '';

  final result = await db.execute(
    "SELECT e.id, e.name, e.muscle_group::text AS muscle_group "
    'FROM exercises e '
    "WHERE e.name ILIKE '%$q%' "
    'AND e.is_published = true '
    '$excludeClause '
    'ORDER BY e.name '
    'LIMIT $limit',
  );

  final exercises = result.map((r) {
    final m = r.toColumnMap();
    return {
      'id': m['id'],
      'name': m['name'],
      'muscleGroup': m['muscle_group'],
    };
  }).toList();

  return jsonOk({'exercises': exercises});
}
