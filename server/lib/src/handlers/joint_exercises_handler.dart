import 'package:postgres/postgres.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

final _uuid = Uuid();

Router get jointExercisesHandler {
  final router = Router();

  // GET  /api/v1/joint-exercises/list?family=shoulder
  router.get('/list', _list);

  // GET  /api/v1/joint-exercises/get/<id>
  router.get('/get/<id>', _get);

  // POST /api/v1/joint-exercises/create
  router.post('/create', _create);

  // PATCH /api/v1/joint-exercises/update/<id>
  router.patch('/update/<id>', _update);

  // PATCH /api/v1/joint-exercises/deactivate/<id>
  router.patch('/deactivate/<id>', _deactivate);

  return router;
}

const _validFamilies = [
  'shoulder', 'elbow', 'wrist', 'hip', 'knee', 'ankle', 'cervical', 'lumbar',
];

Map<String, dynamic> _toMap(Map<String, dynamic> row) => {
      'id': row['id'],
      'name': row['name'],
      'type': row['type'],
      'jointFamily': row['joint_family'],
      'instructions': (row['instructions'] as List?)?.cast<String>() ?? [],
      'benefits': row['benefits'],
      'whenToUse': row['when_to_use'],
      'isActive': row['is_active'],
      'createdAt': row['created_at']?.toString(),
    };

Future<Response> _list(Request request) async {
  await requireAuth(request);

  final family = request.url.queryParameters['family']?.trim() ?? '';

  final where = family.isNotEmpty
      ? 'WHERE is_active = true AND joint_family = \$1'
      : 'WHERE is_active = true';
  final params = family.isNotEmpty ? [family] : null;

  final result = await db.execute(
    'SELECT id, name, type, joint_family, instructions, benefits, '
    'when_to_use, is_active, created_at '
    'FROM joint_exercises $where ORDER BY joint_family, name ASC',
    parameters: params,
  );

  final items = result.map((r) => _toMap(r.toColumnMap())).toList();
  return jsonOk({'exercises': items, 'total': items.length});
}

Future<Response> _get(Request request, String id) async {
  await requireAuth(request);

  final result = await db.execute(
    'SELECT id, name, type, joint_family, instructions, benefits, '
    "when_to_use, is_active, created_at FROM joint_exercises WHERE id = '$id'::uuid",
  );

  if (result.isEmpty) return notFound('Ejercicio de articulación no encontrado');
  return jsonOk({'exercise': _toMap(result.first.toColumnMap())});
}

Future<Response> _create(Request request) async {
  await requireRole(request, ['admin', 'professor']);

  final body = await parseBody(request);
  final name = (body['name'] as String? ?? '').trim();
  final type = (body['type'] as String? ?? '').trim().toLowerCase();
  final jointFamily = (body['jointFamily'] as String? ?? '').trim().toLowerCase();
  final instructions = (body['instructions'] as List<dynamic>? ?? []).cast<String>();
  final benefits = (body['benefits'] as String? ?? '').trim();
  final whenToUse = (body['whenToUse'] as String? ?? '').trim();

  if (name.isEmpty) return badRequest('El nombre es requerido');
  if (!['movilidad', 'fortalecimiento'].contains(type)) {
    return badRequest('Tipo inválido. Usa: movilidad | fortalecimiento');
  }
  if (!_validFamilies.contains(jointFamily)) {
    return badRequest('Articulación inválida. Válidas: ${_validFamilies.join(', ')}');
  }

  final id = _uuid.v4();

  await db.execute(
    Sql.named(
      "INSERT INTO joint_exercises (id, name, type, joint_family, instructions, "
      "benefits, when_to_use) VALUES "
      "('$id'::uuid, @name, @type, @jointFamily, @instructions, @benefits, @whenToUse)",
    ),
    parameters: {
      'name': name,
      'type': type,
      'jointFamily': jointFamily,
      'instructions': instructions,
      'benefits': benefits.isEmpty ? null : benefits,
      'whenToUse': whenToUse.isEmpty ? null : whenToUse,
    },
  );

  final created = await db.execute(
    'SELECT id, name, type, joint_family, instructions, benefits, '
    "when_to_use, is_active, created_at FROM joint_exercises WHERE id = '$id'::uuid",
  );

  return jsonCreated({'exercise': _toMap(created.first.toColumnMap())});
}

Future<Response> _update(Request request, String id) async {
  await requireRole(request, ['admin', 'professor']);

  final body = await parseBody(request);
  final setClauses = <String>[];
  final params = <Object?>[];
  var idx = 1;

  if (body.containsKey('name')) {
    final name = (body['name'] as String? ?? '').trim();
    if (name.isEmpty) return badRequest('El nombre no puede estar vacío');
    setClauses.add('name = \$$idx'); params.add(name); idx++;
  }
  if (body.containsKey('type')) {
    final type = (body['type'] as String? ?? '').toLowerCase();
    if (!['movilidad', 'fortalecimiento'].contains(type)) {
      return badRequest('Tipo inválido');
    }
    setClauses.add('type = \$$idx'); params.add(type); idx++;
  }
  if (body.containsKey('jointFamily')) {
    final jf = (body['jointFamily'] as String? ?? '').toLowerCase();
    if (!_validFamilies.contains(jf)) return badRequest('Articulación inválida');
    setClauses.add('joint_family = \$$idx'); params.add(jf); idx++;
  }
  if (body.containsKey('instructions')) {
    final ins = (body['instructions'] as List<dynamic>? ?? []).cast<String>();
    setClauses.add('instructions = \$$idx'); params.add(ins); idx++;
  }
  if (body.containsKey('benefits')) {
    setClauses.add('benefits = \$$idx'); params.add(body['benefits']); idx++;
  }
  if (body.containsKey('whenToUse')) {
    setClauses.add('when_to_use = \$$idx'); params.add(body['whenToUse']); idx++;
  }

  if (setClauses.isEmpty) return badRequest('No hay campos para actualizar');

  await db.execute(
    "UPDATE joint_exercises SET ${setClauses.join(', ')} WHERE id = '$id'::uuid",
    parameters: params,
  );

  final updated = await db.execute(
    'SELECT id, name, type, joint_family, instructions, benefits, '
    "when_to_use, is_active, created_at FROM joint_exercises WHERE id = '$id'::uuid",
  );

  if (updated.isEmpty) return notFound('Ejercicio no encontrado');
  return jsonOk({'exercise': _toMap(updated.first.toColumnMap())});
}

Future<Response> _deactivate(Request request, String id) async {
  await requireRole(request, 'admin');

  final body = await parseBody(request);
  final active = body['isActive'] as bool? ?? false;

  await db.execute(
    "UPDATE joint_exercises SET is_active = \$1 WHERE id = '$id'::uuid",
    parameters: [active],
  );

  return jsonOk({
    'message': active ? 'Ejercicio activado' : 'Ejercicio desactivado',
  });
}
