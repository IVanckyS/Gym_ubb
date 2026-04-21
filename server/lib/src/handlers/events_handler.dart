import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

final _uuid = Uuid();

Router get eventsHandler {
  final router = Router();

  // GET /api/v1/events/list?type=&upcoming=&page=&limit=
  router.get('/list', _listEvents);

  // GET /api/v1/events/my-interests  — debe ir ANTES de get/:id
  router.get('/my-interests', _myInterests);

  // GET /api/v1/events/get/:id
  router.get('/get/<id>', _getEvent);

  // POST /api/v1/events/create
  router.post('/create', _createEvent);

  // PATCH /api/v1/events/update/:id
  router.patch('/update/<id>', _updateEvent);

  // PATCH /api/v1/events/deactivate/:id
  router.patch('/deactivate/<id>', _deactivateEvent);

  // POST /api/v1/events/:id/interest — toggle interés
  router.post('/<id>/interest', _toggleInterest);

  return router;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _eventToMap(
  Map<String, dynamic> row, {
  bool? isInterested,
  int? interestCount,
}) {
  return {
    'id': row['id']?.toString(),
    'title': row['title'],
    'type': row['type'],
    'eventDate': row['event_date']?.toString(),
    'eventTime': row['event_time']?.toString(),
    'endDate': row['end_date']?.toString(),
    'location': row['location'],
    'description': row['description'],
    'maxParticipants': row['max_participants'],
    'registrationUrl': row['registration_url'],
    'imageUrl': row['image_url'],
    'isActive': row['is_active'],
    'createdAt': row['created_at']?.toString(),
    'createdBy': row['created_by'] != null
        ? {
            'id': row['created_by']?.toString(),
            'name': row['creator_name'],
          }
        : null,
    if (isInterested != null) 'isInterested': isInterested,
    if (interestCount != null) 'interestCount': interestCount,
  };
}

// ── Handlers ──────────────────────────────────────────────────────────────────

Future<Response> _listEvents(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final role = claims['role'] as String;
  final isAdmin = role == 'admin' || role == 'professor';

  final q = request.url.queryParameters;
  final type = q['type']?.trim() ?? '';
  final upcoming = q['upcoming'] != 'false'; // por defecto solo eventos futuros
  final page = int.tryParse(q['page'] ?? '1') ?? 1;
  final limit = (int.tryParse(q['limit'] ?? '20') ?? 20).clamp(1, 100);
  final offset = (page - 1) * limit;

  final conditions = <String>[];
  final params = <Object?>[];
  var idx = 1;

  if (!isAdmin) {
    conditions.add('e.is_active = true');
  }

  if (upcoming) {
    conditions.add('e.event_date >= CURRENT_DATE');
  }

  if (type.isNotEmpty) {
    conditions.add('e.type = \$$idx');
    params.add(type);
    idx++;
  }

  final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

  final rows = await db.execute(
    'SELECT e.id, e.title, e.type, e.event_date, e.event_time, e.end_date, '
    'e.location, e.description, e.max_participants, e.registration_url, '
    'e.image_url, e.is_active, e.created_at, e.created_by, '
    'u.name AS creator_name, '
    '(SELECT COUNT(*) FROM event_interests ei WHERE ei.event_id = e.id) AS interest_count '
    'FROM events e LEFT JOIN users u ON u.id = e.created_by '
    '$where ORDER BY e.event_date ASC, e.event_time ASC '
    'LIMIT $limit OFFSET $offset',
    parameters: params.isEmpty ? null : params,
  );

  // Intereses del usuario actual para marcar cada evento
  final intRows = await db.execute(
    "SELECT event_id FROM event_interests WHERE user_id = '$userId'::uuid",
  );
  final intIds = intRows.map((r) => r.toColumnMap()['event_id']?.toString()).toSet();

  final events = rows.map((row) {
    final map = row.toColumnMap();
    final evId = map['id']?.toString();
    final count = int.tryParse(map['interest_count']?.toString() ?? '0') ?? 0;
    return _eventToMap(map, isInterested: intIds.contains(evId), interestCount: count);
  }).toList();

  return jsonOk({'events': events, 'page': page, 'limit': limit});
}

Future<Response> _getEvent(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final role = claims['role'] as String;
  final isAdmin = role == 'admin' || role == 'professor';

  final rows = await db.execute(
    'SELECT e.*, u.name AS creator_name, '
    '(SELECT COUNT(*) FROM event_interests ei WHERE ei.event_id = e.id) AS interest_count '
    'FROM events e LEFT JOIN users u ON u.id = e.created_by '
    "WHERE e.id = '$id'::uuid",
  );

  if (rows.isEmpty) return notFound('Evento no encontrado');

  final row = rows.first.toColumnMap();

  if (!(row['is_active'] as bool? ?? false) && !isAdmin) {
    return forbidden('Este evento no está disponible');
  }

  final intRows = await db.execute(
    "SELECT 1 FROM event_interests WHERE user_id = '$userId'::uuid AND event_id = '$id'::uuid",
  );

  final count = int.tryParse(row['interest_count']?.toString() ?? '0') ?? 0;

  return jsonOk({
    'event': _eventToMap(row, isInterested: intRows.isNotEmpty, interestCount: count),
  });
}

Future<Response> _createEvent(Request request) async {
  final claims = await requireRole(request, 'professor');
  final creatorId = claims['sub'] as String;

  final body = await parseBody(request);
  final title = (body['title'] as String? ?? '').trim();
  final type = (body['type'] as String? ?? '').trim();
  final eventDate = (body['eventDate'] as String? ?? '').trim();

  if (title.isEmpty) return badRequest('El título es requerido');
  if (type.isEmpty) return badRequest('El tipo es requerido');
  if (eventDate.isEmpty) return badRequest('La fecha del evento es requerida');

  final eventTime = body['eventTime'] as String?;
  final endDate = body['endDate'] as String?;
  final location = (body['location'] as String? ?? '').trim();
  final description = (body['description'] as String? ?? '').trim();
  final maxParticipants = body['maxParticipants'] as int?;
  final registrationUrl = body['registrationUrl'] as String?;
  final imageUrl = body['imageUrl'] as String?;

  final id = _uuid.v4();

  // Build SET list dynamically to avoid nulls in parametrized positions
  final setCols = StringBuffer(
    "id, title, type, event_date, created_by",
  );
  final setVals = StringBuffer(
    "'$id'::uuid, \$1, \$2, \$3::date, '$creatorId'::uuid",
  );
  final params = <Object?>[title, type, eventDate];
  var idx = 4;

  if (eventTime != null && eventTime.isNotEmpty) {
    setCols.write(', event_time');
    setVals.write(', \$$idx::time');
    params.add(eventTime);
    idx++;
  }
  if (endDate != null && endDate.isNotEmpty) {
    setCols.write(', end_date');
    setVals.write(', \$$idx::timestamptz');
    params.add(endDate);
    idx++;
  }
  if (location.isNotEmpty) {
    setCols.write(', location');
    setVals.write(', \$$idx');
    params.add(location);
    idx++;
  }
  if (description.isNotEmpty) {
    setCols.write(', description');
    setVals.write(', \$$idx');
    params.add(description);
    idx++;
  }
  if (maxParticipants != null) {
    setCols.write(', max_participants');
    setVals.write(', \$$idx');
    params.add(maxParticipants);
    idx++;
  }
  if (registrationUrl != null && registrationUrl.isNotEmpty) {
    setCols.write(', registration_url');
    setVals.write(', \$$idx');
    params.add(registrationUrl);
    idx++;
  }
  if (imageUrl != null && imageUrl.isNotEmpty) {
    setCols.write(', image_url');
    setVals.write(', \$$idx');
    params.add(imageUrl);
    idx++;
  }

  await db.execute(
    'INSERT INTO events ($setCols) VALUES ($setVals)',
    parameters: params,
  );

  final created = await db.execute(
    'SELECT e.*, u.name AS creator_name, 0 AS interest_count '
    'FROM events e LEFT JOIN users u ON u.id = e.created_by '
    "WHERE e.id = '$id'::uuid",
  );

  return jsonCreated({
    'event': _eventToMap(created.first.toColumnMap(), isInterested: false, interestCount: 0),
  });
}

Future<Response> _updateEvent(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final role = claims['role'] as String;

  final existing = await db.execute(
    "SELECT created_by FROM events WHERE id = '$id'::uuid",
  );
  if (existing.isEmpty) return notFound('Evento no encontrado');

  final createdBy = existing.first.toColumnMap()['created_by']?.toString();
  if (role != 'admin' && userId != createdBy) {
    return forbidden('Solo el creador o un administrador puede editar este evento');
  }

  final body = await parseBody(request);
  if (body.isEmpty) return badRequest('No hay campos para actualizar');

  final setClauses = <String>[];
  final params = <Object?>[];
  var idx = 1;

  if (body.containsKey('title')) {
    final v = (body['title'] as String? ?? '').trim();
    if (v.isEmpty) return badRequest('El título no puede estar vacío');
    setClauses.add('title = \$$idx'); params.add(v); idx++;
  }
  if (body.containsKey('type')) {
    final v = (body['type'] as String? ?? '').trim();
    if (v.isEmpty) return badRequest('El tipo no puede estar vacío');
    setClauses.add('type = \$$idx'); params.add(v); idx++;
  }
  if (body.containsKey('eventDate')) {
    final v = (body['eventDate'] as String? ?? '').trim();
    if (v.isEmpty) return badRequest('La fecha no puede estar vacía');
    setClauses.add('event_date = \$$idx::date'); params.add(v); idx++;
  }
  if (body.containsKey('eventTime')) {
    final v = body['eventTime'];
    if (v == null) {
      setClauses.add('event_time = NULL');
    } else {
      setClauses.add('event_time = \$$idx::time'); params.add(v.toString()); idx++;
    }
  }
  if (body.containsKey('endDate')) {
    final v = body['endDate'];
    if (v == null) {
      setClauses.add('end_date = NULL');
    } else {
      setClauses.add('end_date = \$$idx::timestamptz'); params.add(v.toString()); idx++;
    }
  }
  if (body.containsKey('location')) {
    setClauses.add('location = \$$idx'); params.add(body['location']); idx++;
  }
  if (body.containsKey('description')) {
    setClauses.add('description = \$$idx'); params.add(body['description']); idx++;
  }
  if (body.containsKey('maxParticipants')) {
    setClauses.add('max_participants = \$$idx'); params.add(body['maxParticipants']); idx++;
  }
  if (body.containsKey('registrationUrl')) {
    setClauses.add('registration_url = \$$idx'); params.add(body['registrationUrl']); idx++;
  }
  if (body.containsKey('imageUrl')) {
    setClauses.add('image_url = \$$idx'); params.add(body['imageUrl']); idx++;
  }

  if (setClauses.isEmpty) return badRequest('No hay campos reconocidos');

  await db.execute(
    "UPDATE events SET ${setClauses.join(', ')}, updated_at = NOW() WHERE id = '$id'::uuid",
    parameters: params.isEmpty ? null : params,
  );

  final updated = await db.execute(
    'SELECT e.*, u.name AS creator_name, '
    '(SELECT COUNT(*) FROM event_interests ei WHERE ei.event_id = e.id) AS interest_count '
    'FROM events e LEFT JOIN users u ON u.id = e.created_by '
    "WHERE e.id = '$id'::uuid",
  );

  final count = int.tryParse(
        updated.first.toColumnMap()['interest_count']?.toString() ?? '0',
      ) ??
      0;

  return jsonOk({'event': _eventToMap(updated.first.toColumnMap(), interestCount: count)});
}

Future<Response> _deactivateEvent(Request request, String id) async {
  await requireRole(request, 'admin');

  final existing = await db.execute(
    "SELECT id FROM events WHERE id = '$id'::uuid",
  );
  if (existing.isEmpty) return notFound('Evento no encontrado');

  await db.execute(
    "UPDATE events SET is_active = false, updated_at = NOW() WHERE id = '$id'::uuid",
  );

  return jsonOk({'message': 'Evento desactivado'});
}

Future<Response> _toggleInterest(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final existing = await db.execute(
    "SELECT id FROM events WHERE id = '$id'::uuid AND is_active = true",
  );
  if (existing.isEmpty) return notFound('Evento no encontrado');

  final interest = await db.execute(
    "SELECT 1 FROM event_interests WHERE user_id = '$userId'::uuid AND event_id = '$id'::uuid",
  );

  final bool isInterested;
  if (interest.isNotEmpty) {
    await db.execute(
      "DELETE FROM event_interests WHERE user_id = '$userId'::uuid AND event_id = '$id'::uuid",
    );
    isInterested = false;
  } else {
    await db.execute(
      "INSERT INTO event_interests (user_id, event_id) VALUES ('$userId'::uuid, '$id'::uuid) ON CONFLICT DO NOTHING",
    );
    isInterested = true;
  }

  final countRows = await db.execute(
    "SELECT COUNT(*) AS total FROM event_interests WHERE event_id = '$id'::uuid",
  );
  final count = int.tryParse(
        countRows.first.toColumnMap()['total']?.toString() ?? '0',
      ) ??
      0;

  return jsonOk({'isInterested': isInterested, 'interestCount': count});
}

Future<Response> _myInterests(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final rows = await db.execute(
    'SELECT e.id, e.title, e.type, e.event_date, e.event_time, e.end_date, '
    'e.location, e.description, e.max_participants, e.registration_url, '
    'e.image_url, e.is_active, e.created_at, e.created_by, '
    'u.name AS creator_name, '
    '(SELECT COUNT(*) FROM event_interests ei WHERE ei.event_id = e.id) AS interest_count '
    'FROM events e '
    "JOIN event_interests eint ON eint.event_id = e.id AND eint.user_id = '$userId'::uuid "
    'LEFT JOIN users u ON u.id = e.created_by '
    'WHERE e.is_active = true '
    'ORDER BY e.event_date ASC, e.event_time ASC',
  );

  final events = rows.map((row) {
    final map = row.toColumnMap();
    final count = int.tryParse(map['interest_count']?.toString() ?? '0') ?? 0;
    return _eventToMap(map, isInterested: true, interestCount: count);
  }).toList();

  return jsonOk({'events': events});
}
