import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

final _uuid = Uuid();

Router get liftSubmissionsHandler {
  final router = Router();

  // POST   /api/v1/lift-submissions
  router.post('/', _create);
  // GET    /api/v1/lift-submissions?status=&user_id=
  router.get('/', _list);
  // Rutas estáticas ANTES que /<id> para evitar conflicto de ruteo
  // GET    /api/v1/lift-submissions/rankings
  router.get('/rankings', _rankings);
  // GET    /api/v1/lift-submissions/records
  router.get('/records', _records);
  // GET    /api/v1/lift-submissions/<id>
  router.get('/<id>', _getOne);
  // POST   /api/v1/lift-submissions/<id>/approve
  router.post('/<id>/approve', _approve);
  // POST   /api/v1/lift-submissions/<id>/reject
  router.post('/<id>/reject', _reject);

  return router;
}

// ── Helpers ──────────────────────────────────────────────────────────────────

Map<String, dynamic> _submissionToMap(Map<String, dynamic> r) => {
      'id': r['id'],
      'userId': r['user_id'],
      'userName': r['user_name'],
      'exerciseId': r['exercise_id'],
      'exerciseName': r['exercise_name'],
      'weightKg': r['weight_kg'] != null
          ? double.tryParse(r['weight_kg'].toString())
          : null,
      'reps': r['reps'],
      'locationName': r['location_name'],
      'locationLat': r['location_lat'] != null
          ? double.tryParse(r['location_lat'].toString())
          : null,
      'locationLng': r['location_lng'] != null
          ? double.tryParse(r['location_lng'].toString())
          : null,
      'description': r['description'],
      'wasWitnessed': r['was_witnessed'],
      'witnessName': r['witness_name'],
      'videoUrl': r['video_url'],
      'status': r['status']?.toString() ?? 'pending',
      'reviewedBy': r['reviewed_by'],
      'reviewerName': r['reviewer_name'],
      'reviewComment': r['review_comment'],
      'reviewedAt': r['reviewed_at']?.toString(),
      'isRecordBreaking': r['is_record_breaking'] ?? false,
      'createdAt': r['created_at']?.toString(),
    };

// ── Handlers ─────────────────────────────────────────────────────────────────

/// POST /  — Crear solicitud de levantamiento
Future<Response> _create(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final body = await parseBody(request);
  final exerciseId = body['exerciseId'] as String? ?? '';
  final weightKg = (body['weightKg'] as num?)?.toDouble();
  final reps = body['reps'] as int? ?? 1;
  final videoUrl = (body['videoUrl'] as String? ?? '').trim();
  final locationName = body['locationName'] as String?;
  final locationLat = (body['locationLat'] as num?)?.toDouble();
  final locationLng = (body['locationLng'] as num?)?.toDouble();
  final description = body['description'] as String?;
  final wasWitnessed = body['wasWitnessed'] as bool? ?? false;
  final witnessName = body['witnessName'] as String?;

  if (exerciseId.isEmpty) return badRequest('exerciseId es requerido');
  if (weightKg == null || weightKg <= 0) return badRequest('Peso inválido');
  if (reps <= 0) return badRequest('Repeticiones deben ser mayor a 0');
  if (videoUrl.isEmpty) return badRequest('El video es obligatorio');

  // Verificar que el ejercicio existe y es rankeable
  final exCheck = await db.execute(
    "SELECT id, is_rankeable FROM exercises WHERE id = '$exerciseId'::uuid AND is_published = true",
  );
  if (exCheck.isEmpty) return notFound('Ejercicio no encontrado');
  final isRankeable = exCheck.first.toColumnMap()['is_rankeable'] as bool? ?? false;
  if (!isRankeable) {
    return Response(400,
        body: '{"data":null,"error":{"code":"not_rankeable","message":"Este ejercicio no es candidato al ranking"}}',
        headers: {'Content-Type': 'application/json'});
  }

  // Máximo 3 solicitudes pendientes simultáneas
  final pendingCount = await db.execute(
    "SELECT COUNT(*) AS cnt FROM lift_submissions "
    "WHERE user_id = '$userId'::uuid AND status = 'pending'",
  );
  final cnt = (pendingCount.first.toColumnMap()['cnt'] as int?) ?? 0;
  if (cnt >= 3) {
    return Response(429,
        body: '{"data":null,"error":{"code":"too_many_pending","message":"Tienes solicitudes pendientes por revisar. Espera a que sean procesadas"}}',
        headers: {'Content-Type': 'application/json'});
  }

  final id = _uuid.v4();
  final locNameVal = locationName != null ? "'${locationName.replaceAll("'", "''")}'" : 'NULL';
  final locLatVal = locationLat != null ? '$locationLat' : 'NULL';
  final locLngVal = locationLng != null ? '$locationLng' : 'NULL';
  final descVal = description != null ? "'${description.replaceAll("'", "''")}'" : 'NULL';
  final witnessVal = witnessName != null ? "'${witnessName.replaceAll("'", "''")}'" : 'NULL';
  final videoVal = videoUrl.replaceAll("'", "''");

  await db.execute(
    "INSERT INTO lift_submissions "
    "(id, user_id, exercise_id, weight_kg, reps, location_name, location_lat, location_lng, "
    "description, was_witnessed, witness_name, video_url) "
    "VALUES ('$id'::uuid, '$userId'::uuid, '$exerciseId'::uuid, $weightKg, $reps, "
    "$locNameVal, $locLatVal, $locLngVal, $descVal, $wasWitnessed, $witnessVal, '$videoVal')",
  );

  return _fetchOne(id);
}

/// GET /?status=pending&user_id=X
Future<Response> _list(Request request) async {
  final claims = await requireAuth(request);
  final callerId = claims['sub'] as String;
  final callerRole = claims['role'] as String? ?? 'student';

  final params = request.url.queryParameters;
  final status = params['status'];
  final filterUserId = params['user_id'];

  // Admin/profesor/staff ven todas; el usuario solo las suyas
  final isPrivileged = ['admin', 'professor', 'staff'].contains(callerRole);
  final effectiveUserId = isPrivileged ? filterUserId : callerId;

  final conditions = <String>[];
  if (effectiveUserId != null) {
    conditions.add("ls.user_id = '$effectiveUserId'::uuid");
  }
  if (status != null && ['pending', 'approved', 'rejected'].contains(status)) {
    conditions.add("ls.status = '$status'::lift_submission_status");
  }

  final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

  final result = await db.execute(
    'SELECT ls.*, u.name AS user_name, e.name AS exercise_name, '
    'rv.name AS reviewer_name '
    'FROM lift_submissions ls '
    'JOIN users u ON u.id = ls.user_id '
    'JOIN exercises e ON e.id = ls.exercise_id '
    'LEFT JOIN users rv ON rv.id = ls.reviewed_by '
    '$where '
    'ORDER BY ls.created_at DESC '
    'LIMIT 50',
  );

  final submissions = result.map((r) => _submissionToMap(r.toColumnMap())).toList();
  return jsonOk({'submissions': submissions});
}

/// GET /<id>
Future<Response> _getOne(Request request, String id) async {
  await requireAuth(request);
  return _fetchOne(id);
}

Future<Response> _fetchOne(String id) async {
  final result = await db.execute(
    'SELECT ls.*, u.name AS user_name, e.name AS exercise_name, '
    'rv.name AS reviewer_name '
    'FROM lift_submissions ls '
    'JOIN users u ON u.id = ls.user_id '
    'JOIN exercises e ON e.id = ls.exercise_id '
    'LEFT JOIN users rv ON rv.id = ls.reviewed_by '
    "WHERE ls.id = '$id'::uuid",
  );
  if (result.isEmpty) return notFound('Solicitud no encontrada');

  final submission = _submissionToMap(result.first.toColumnMap());

  // Imágenes adicionales
  final imgs = await db.execute(
    'SELECT id, image_url, sort_order FROM lift_submission_images '
    "WHERE submission_id = '$id'::uuid ORDER BY sort_order ASC",
  );
  submission['images'] = imgs.map((r) {
    final m = r.toColumnMap();
    return {'id': m['id'], 'imageUrl': m['image_url'], 'sortOrder': m['sort_order']};
  }).toList();

  return jsonOk({'submission': submission});
}

/// POST /<id>/approve
Future<Response> _approve(Request request, String id) async {
  final claims = await requireAuth(request);
  final reviewerId = claims['sub'] as String;
  final role = claims['role'] as String? ?? 'student';

  if (!['admin', 'professor', 'staff'].contains(role)) {
    return Response(403,
        body: '{"data":null,"error":{"code":"forbidden","message":"Sin permisos"}}',
        headers: {'Content-Type': 'application/json'});
  }

  final check = await db.execute(
    "SELECT ls.id, ls.exercise_id, ls.weight_kg, ls.reps, ls.user_id "
    'FROM lift_submissions ls '
    "WHERE ls.id = '$id'::uuid AND ls.status = 'pending'",
  );
  if (check.isEmpty) return notFound('Solicitud no encontrada o ya revisada');

  final row = check.first.toColumnMap();
  final exerciseId = row['exercise_id'] as String;
  final weightKg = double.tryParse(row['weight_kg'].toString()) ?? 0;
  final reps = row['reps'] as int;

  // ¿Es récord actual?
  final recordCheck = await db.execute(
    "SELECT MAX(weight_kg) AS max_weight FROM lift_submissions "
    "WHERE exercise_id = '$exerciseId'::uuid AND reps = $reps AND status = 'approved'",
  );
  final currentRecord = double.tryParse(
        recordCheck.first.toColumnMap()['max_weight']?.toString() ?? '0',
      ) ??
      0;
  final isRecordBreaking = weightKg > currentRecord;

  await db.execute(
    "UPDATE lift_submissions SET status = 'approved'::lift_submission_status, "
    "reviewed_by = '$reviewerId'::uuid, reviewed_at = NOW(), "
    'is_record_breaking = $isRecordBreaking, updated_at = NOW() '
    "WHERE id = '$id'::uuid",
  );

  // Notificación si rompió récord
  if (isRecordBreaking) {
    final userRow = await db.execute(
      "SELECT u.name, e.name AS ex_name FROM lift_submissions ls "
      'JOIN users u ON u.id = ls.user_id '
      'JOIN exercises e ON e.id = ls.exercise_id '
      "WHERE ls.id = '$id'::uuid",
    );
    if (userRow.isNotEmpty) {
      final m = userRow.first.toColumnMap();
      final userName = m['name'] as String? ?? 'Alguien';
      final exName = m['ex_name'] as String? ?? 'un ejercicio';
      final title = 'Nuevo récord';
      final body = '$userName rompió el récord de $exName con ${weightKg.toStringAsFixed(1)} kg';
      final notifId = _uuid.v4();
      final titleEsc = title.replaceAll("'", "''");
      final bodyEsc = body.replaceAll("'", "''");
      await db.execute(
        "INSERT INTO app_notifications (id, type, title, body) "
        "VALUES ('$notifId'::uuid, 'feature', '$titleEsc', '$bodyEsc')",
      );
    }
  }

  return _fetchOne(id);
}

/// POST /<id>/reject
Future<Response> _reject(Request request, String id) async {
  final claims = await requireAuth(request);
  final reviewerId = claims['sub'] as String;
  final role = claims['role'] as String? ?? 'student';

  if (!['admin', 'professor', 'staff'].contains(role)) {
    return Response(403,
        body: '{"data":null,"error":{"code":"forbidden","message":"Sin permisos"}}',
        headers: {'Content-Type': 'application/json'});
  }

  final body = await parseBody(request);
  final comment = (body['reviewComment'] as String? ?? '').trim();
  if (comment.isEmpty) return badRequest('El motivo de rechazo es obligatorio');

  final check = await db.execute(
    "SELECT id FROM lift_submissions WHERE id = '$id'::uuid AND status = 'pending'",
  );
  if (check.isEmpty) return notFound('Solicitud no encontrada o ya revisada');

  final commentEsc = comment.replaceAll("'", "''");
  await db.execute(
    "UPDATE lift_submissions SET status = 'rejected'::lift_submission_status, "
    "reviewed_by = '$reviewerId'::uuid, reviewed_at = NOW(), "
    "review_comment = '$commentEsc', updated_at = NOW() "
    "WHERE id = '$id'::uuid",
  );

  return _fetchOne(id);
}

/// GET /rankings?exercise_id=X&reps=1
Future<Response> _rankings(Request request) async {
  await requireAuth(request);

  final params = request.url.queryParameters;
  final exerciseId = params['exercise_id'];
  final reps = int.tryParse(params['reps'] ?? '1') ?? 1;

  final whereEx = exerciseId != null ? "AND ls.exercise_id = '$exerciseId'::uuid" : '';

  final result = await db.execute(
    'SELECT ls.id, ls.user_id, u.name AS user_name, ls.exercise_id, '
    'e.name AS exercise_name, ls.weight_kg, ls.reps, '
    'ls.location_name, ls.video_url, ls.is_record_breaking, ls.reviewed_at, '
    'ls.description, ls.was_witnessed, ls.witness_name, '
    'NULL::text AS reviewer_name '
    'FROM lift_submissions ls '
    'JOIN users u ON u.id = ls.user_id '
    'JOIN exercises e ON e.id = ls.exercise_id '
    "WHERE ls.status = 'approved' AND ls.reps = $reps "
    '$whereEx '
    'ORDER BY ls.weight_kg DESC '
    'LIMIT 100',
  );

  final entries = result.map((r) => _submissionToMap(r.toColumnMap())).toList();
  return jsonOk({'rankings': entries, 'reps': reps});
}

/// GET /records — récord actual (mayor peso aprobado) por ejercicio
Future<Response> _records(Request request) async {
  await requireAuth(request);

  final result = await db.execute(
    'SELECT DISTINCT ON (ls.exercise_id, ls.reps) '
    'ls.id, ls.user_id, u.name AS user_name, ls.exercise_id, '
    'e.name AS exercise_name, ls.weight_kg, ls.reps, '
    'ls.location_name, ls.video_url, ls.is_record_breaking, ls.reviewed_at, '
    'ls.description, ls.was_witnessed, ls.witness_name, '
    'NULL::text AS reviewer_name '
    'FROM lift_submissions ls '
    'JOIN users u ON u.id = ls.user_id '
    'JOIN exercises e ON e.id = ls.exercise_id '
    "WHERE ls.status = 'approved' "
    'ORDER BY ls.exercise_id, ls.reps, ls.weight_kg DESC',
  );

  final records = result.map((r) => _submissionToMap(r.toColumnMap())).toList();
  return jsonOk({'records': records});
}
