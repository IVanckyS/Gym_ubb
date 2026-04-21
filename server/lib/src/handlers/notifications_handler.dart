import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

Router get notificationsHandler {
  final router = Router();

  // GET  /api/v1/notifications/list
  router.get('/list', _list);

  // GET  /api/v1/notifications/unreadCount
  router.get('/unreadCount', _unreadCount);

  // PATCH /api/v1/notifications/read/<id>   — marca notif sistema como leída
  router.patch('/read/<id>', _read);

  // PATCH /api/v1/notifications/readAll    — marca todo como leído
  router.patch('/readAll', _readAll);

  // POST  /api/v1/notifications/create     — admin: crea notif sistema
  router.post('/create', _create);

  return router;
}

// ── Handlers ─────────────────────────────────────────────────────────────────

/// GET /list — combina notificaciones del sistema + eventos nuevos + artículos nuevos
Future<Response> _list(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final notifications = <Map<String, dynamic>>[];

  // 1. Notificaciones del sistema (app_notifications)
  final sysResult = await db.execute(
    'SELECT n.id, n.type, n.title, n.body, n.created_at, '
    '(SELECT 1 FROM notification_reads r WHERE r.user_id = \'$userId\'::uuid '
    ' AND r.notif_type = \'system\' AND r.reference_id = n.id) AS is_read '
    'FROM app_notifications n WHERE n.is_active = true '
    'ORDER BY n.created_at DESC LIMIT 30',
  );
  for (final row in sysResult) {
    final m = row.toColumnMap();
    notifications.add({
      'id': m['id'].toString(),
      'type': 'system',
      'subtype': m['type'],
      'title': m['title'],
      'body': m['body'],
      'referenceId': m['id'].toString(),
      'isRead': m['is_read'] != null,
      'createdAt': m['created_at']?.toString(),
    });
  }

  // 2. Eventos nuevos (últimos 14 días)
  final eventsResult = await db.execute(
    'SELECT e.id, e.title, e.type, e.event_date, e.created_at, '
    '(SELECT 1 FROM notification_reads r WHERE r.user_id = \'$userId\'::uuid '
    ' AND r.notif_type = \'event\' AND r.reference_id = e.id) AS is_read '
    'FROM events e WHERE e.is_active = true '
    'AND e.created_at >= NOW() - INTERVAL \'14 days\' '
    'ORDER BY e.created_at DESC LIMIT 10',
  );
  for (final row in eventsResult) {
    final m = row.toColumnMap();
    notifications.add({
      'id': 'event_${m['id']}',
      'type': 'event',
      'subtype': m['type'],
      'title': 'Nuevo evento: ${m['title']}',
      'body': 'Fecha: ${(m['event_date']?.toString() ?? '').split(' ').first}',
      'referenceId': m['id'].toString(),
      'isRead': m['is_read'] != null,
      'createdAt': m['created_at']?.toString(),
    });
  }

  // 3. Artículos publicados recientemente (últimos 14 días)
  final articlesResult = await db.execute(
    'SELECT a.id, a.title, a.category, a.published_at, '
    '(SELECT 1 FROM notification_reads r WHERE r.user_id = \'$userId\'::uuid '
    ' AND r.notif_type = \'article\' AND r.reference_id = a.id) AS is_read '
    'FROM articles a WHERE a.is_published = true '
    'AND a.published_at >= NOW() - INTERVAL \'14 days\' '
    'ORDER BY a.published_at DESC LIMIT 10',
  );
  for (final row in articlesResult) {
    final m = row.toColumnMap();
    notifications.add({
      'id': 'article_${m['id']}',
      'type': 'article',
      'subtype': m['category'],
      'title': 'Nueva cápsula: ${m['title']}',
      'body': 'Categoría: ${m['category']}',
      'referenceId': m['id'].toString(),
      'isRead': m['is_read'] != null,
      'createdAt': m['published_at']?.toString(),
    });
  }

  // Ordenar por fecha descendente
  notifications.sort((a, b) {
    final da = DateTime.tryParse(a['createdAt'] as String? ?? '') ?? DateTime(2000);
    final db2 = DateTime.tryParse(b['createdAt'] as String? ?? '') ?? DateTime(2000);
    return db2.compareTo(da);
  });

  final unread = notifications.where((n) => !(n['isRead'] as bool)).length;
  return jsonOk({'notifications': notifications, 'unreadCount': unread});
}

/// GET /unreadCount
Future<Response> _unreadCount(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  int count = 0;

  // Sistema
  final sys = await db.execute(
    'SELECT COUNT(*) FROM app_notifications n WHERE n.is_active = true '
    'AND NOT EXISTS (SELECT 1 FROM notification_reads r WHERE r.user_id = \'$userId\'::uuid '
    'AND r.notif_type = \'system\' AND r.reference_id = n.id)',
  );
  count += (sys.first.toColumnMap()['count'] as num?)?.toInt() ?? 0;

  // Eventos últimos 14 días
  final evs = await db.execute(
    'SELECT COUNT(*) FROM events e WHERE e.is_active = true '
    'AND e.created_at >= NOW() - INTERVAL \'14 days\' '
    'AND NOT EXISTS (SELECT 1 FROM notification_reads r WHERE r.user_id = \'$userId\'::uuid '
    'AND r.notif_type = \'event\' AND r.reference_id = e.id)',
  );
  count += (evs.first.toColumnMap()['count'] as num?)?.toInt() ?? 0;

  // Artículos últimos 14 días
  final arts = await db.execute(
    'SELECT COUNT(*) FROM articles a WHERE a.is_published = true '
    'AND a.published_at >= NOW() - INTERVAL \'14 days\' '
    'AND NOT EXISTS (SELECT 1 FROM notification_reads r WHERE r.user_id = \'$userId\'::uuid '
    'AND r.notif_type = \'article\' AND r.reference_id = a.id)',
  );
  count += (arts.first.toColumnMap()['count'] as num?)?.toInt() ?? 0;

  return jsonOk({'count': count});
}

/// PATCH /read/<id> — marca una notificación del sistema como leída
Future<Response> _read(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  // Determinar tipo a partir del body o inferir
  final body = await parseBody(request);
  final type = (body['type'] as String? ?? 'system');
  final refId = (body['referenceId'] as String? ?? id);

  await db.execute(
    'INSERT INTO notification_reads (user_id, notif_type, reference_id) '
    "VALUES ('$userId'::uuid, '$type', '$refId'::uuid) "
    'ON CONFLICT DO NOTHING',
  );

  return jsonOk({'message': 'Marcada como leída'});
}

/// PATCH /readAll — marca todas las notificaciones como leídas
Future<Response> _readAll(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  // Sistema
  final sysResult = await db.execute(
    'SELECT id FROM app_notifications WHERE is_active = true',
  );
  for (final row in sysResult) {
    final id = row.toColumnMap()['id'].toString();
    await db.execute(
      "INSERT INTO notification_reads (user_id, notif_type, reference_id) "
      "VALUES ('$userId'::uuid, 'system', '$id'::uuid) ON CONFLICT DO NOTHING",
    );
  }

  // Eventos últimos 14 días
  final evResult = await db.execute(
    "SELECT id FROM events WHERE is_active = true AND created_at >= NOW() - INTERVAL '14 days'",
  );
  for (final row in evResult) {
    final id = row.toColumnMap()['id'].toString();
    await db.execute(
      "INSERT INTO notification_reads (user_id, notif_type, reference_id) "
      "VALUES ('$userId'::uuid, 'event', '$id'::uuid) ON CONFLICT DO NOTHING",
    );
  }

  // Artículos últimos 14 días
  final artResult = await db.execute(
    "SELECT id FROM articles WHERE is_published = true AND published_at >= NOW() - INTERVAL '14 days'",
  );
  for (final row in artResult) {
    final id = row.toColumnMap()['id'].toString();
    await db.execute(
      "INSERT INTO notification_reads (user_id, notif_type, reference_id) "
      "VALUES ('$userId'::uuid, 'article', '$id'::uuid) ON CONFLICT DO NOTHING",
    );
  }

  return jsonOk({'message': 'Todas marcadas como leídas'});
}

/// POST /create — admin: crea notificación del sistema
Future<Response> _create(Request request) async {
  final claims = await requireAuth(request);
  final role = claims['role'] as String? ?? '';
  if (role != 'admin') return forbidden('Solo admins pueden crear notificaciones');

  final body = await parseBody(request);
  final title = (body['title'] as String? ?? '').trim();
  final bodyText = (body['body'] as String? ?? '').trim();
  final type = (body['type'] as String? ?? 'news').trim();

  if (title.isEmpty || bodyText.isEmpty) return badRequest('title y body son requeridos');

  final validTypes = ['news', 'patch', 'feature', 'reminder'];
  if (!validTypes.contains(type)) return badRequest('Tipo inválido');

  final userId = claims['sub'] as String;
  await db.execute(
    "INSERT INTO app_notifications (type, title, body, created_by) "
    "VALUES ('$type', \$1, \$2, '$userId'::uuid)",
    parameters: [title, bodyText],
  );

  return jsonCreated({'message': 'Notificación creada'});
}
