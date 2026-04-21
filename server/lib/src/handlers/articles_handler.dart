import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import '../database/connection.dart';
import '../middleware/auth_middleware.dart';
import '../utils/response.dart';

final _uuid = Uuid();

Router get articlesHandler {
  final router = Router();

  // GET /api/v1/articles/list?category=&search=&page=&limit=
  router.get('/list', _listArticles);

  // GET /api/v1/articles/favorites  — debe ir ANTES de get/:id
  router.get('/favorites', _myFavorites);

  // GET /api/v1/articles/get/:id
  router.get('/get/<id>', _getArticle);

  // POST /api/v1/articles/create
  router.post('/create', _createArticle);

  // PATCH /api/v1/articles/update/:id
  router.patch('/update/<id>', _updateArticle);

  // PATCH /api/v1/articles/deactivate/:id
  router.patch('/deactivate/<id>', _deactivateArticle);

  // POST /api/v1/articles/:id/favorite — toggle favorito
  router.post('/<id>/favorite', _toggleFavorite);

  return router;
}

// ── Helpers ───────────────────────────────────────────────────────────────────

Map<String, dynamic> _articleToMap(Map<String, dynamic> row, {bool? isFavorite}) {
  return {
    'id': row['id']?.toString(),
    'title': row['title'],
    'category': row['category'],
    'excerpt': row['excerpt'],
    'content': row['content'],
    'tags': row['tags'],
    'readTimeMinutes': row['read_time_minutes'],
    'imageUrl': row['image_url'],
    'bibliography': row['bibliography'],
    'resources': row['resources'],
    'isPublished': row['is_published'],
    'publishedAt': row['published_at']?.toString(),
    'createdAt': row['created_at']?.toString(),
    'author': row['author_id'] != null
        ? {
            'id': row['author_id']?.toString(),
            'name': row['author_name'],
            'faculty': row['author_faculty'],
            'email': row['author_email'],
          }
        : null,
    if (isFavorite != null) 'isFavorite': isFavorite,
  };
}

const _validCategories = [
  'biomecanica',
  'nutricion',
  'prevencion',
  'pausas_activas',
  'recuperacion',
  'salud_mental',
];

// ── Handlers ──────────────────────────────────────────────────────────────────

Future<Response> _listArticles(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final role = claims['role'] as String;
  final isAdmin = role == 'admin' || role == 'professor';

  final q = request.url.queryParameters;
  final category = q['category']?.trim() ?? '';
  final search = q['search']?.trim() ?? '';
  final page = int.tryParse(q['page'] ?? '1') ?? 1;
  final limit = (int.tryParse(q['limit'] ?? '20') ?? 20).clamp(1, 100);
  final offset = (page - 1) * limit;

  final conditions = <String>[];
  final params = <Object?>[];
  var idx = 1;

  // Solo admins/professors ven artículos no publicados
  if (!isAdmin) {
    conditions.add('a.is_published = true');
  }

  if (category.isNotEmpty && _validCategories.contains(category)) {
    conditions.add('a.category = \$$idx');
    params.add(category);
    idx++;
  }

  if (search.isNotEmpty) {
    conditions.add(
      '(LOWER(a.title) LIKE \$$idx OR \$$idx = ANY(SELECT LOWER(t) FROM UNNEST(a.tags) AS t))',
    );
    params.add('%${search.toLowerCase()}%');
    idx++;
  }

  final where = conditions.isEmpty ? '' : 'WHERE ${conditions.join(' AND ')}';

  final rows = await db.execute(
    'SELECT a.id, a.title, a.category, a.excerpt, a.read_time_minutes, '
    'a.image_url, a.tags, a.is_published, a.published_at, a.created_at, '
    'a.author_id, u.name AS author_name, u.faculty AS author_faculty, u.email AS author_email '
    'FROM articles a LEFT JOIN users u ON u.id = a.author_id '
    '$where ORDER BY a.published_at DESC NULLS LAST '
    'LIMIT $limit OFFSET $offset',
    parameters: params.isEmpty ? null : params,
  );

  // Favoritos del usuario actual para marcar cada artículo
  final favRows = await db.execute(
    "SELECT article_id FROM article_favorites WHERE user_id = '$userId'::uuid",
  );
  final favIds = favRows.map((r) => r.toColumnMap()['article_id']?.toString()).toSet();

  final articles = rows.map((row) {
    final map = row.toColumnMap();
    final artId = map['id']?.toString();
    // No incluir content en el listado para reducir payload
    return {
      'id': artId,
      'title': map['title'],
      'category': map['category'],
      'excerpt': map['excerpt'],
      'readTimeMinutes': map['read_time_minutes'],
      'imageUrl': map['image_url'],
      'tags': map['tags'],
      'isPublished': map['is_published'],
      'publishedAt': map['published_at']?.toString(),
      'createdAt': map['created_at']?.toString(),
      'isFavorite': favIds.contains(artId),
      'author': map['author_id'] != null
          ? {
              'id': map['author_id']?.toString(),
              'name': map['author_name'],
              'faculty': map['author_faculty'],
              'email': map['author_email'],
            }
          : null,
    };
  }).toList();

  return jsonOk({'articles': articles, 'page': page, 'limit': limit});
}

Future<Response> _getArticle(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final role = claims['role'] as String;
  final isAdmin = role == 'admin' || role == 'professor';

  final rows = await db.execute(
    'SELECT a.*, u.name AS author_name, u.faculty AS author_faculty, u.email AS author_email '
    "FROM articles a LEFT JOIN users u ON u.id = a.author_id WHERE a.id = '$id'::uuid",
  );

  if (rows.isEmpty) return notFound('Artículo no encontrado');

  final row = rows.first.toColumnMap();

  if (!(row['is_published'] as bool? ?? false) && !isAdmin) {
    return forbidden('Este artículo no está publicado');
  }

  final favRows = await db.execute(
    "SELECT 1 FROM article_favorites WHERE user_id = '$userId'::uuid AND article_id = '$id'::uuid",
  );

  return jsonOk({
    'article': _articleToMap(row, isFavorite: favRows.isNotEmpty),
  });
}

Future<Response> _createArticle(Request request) async {
  final claims = await requireRole(request, 'professor');
  final authorId = claims['sub'] as String;

  final body = await parseBody(request);
  final title = (body['title'] as String? ?? '').trim();
  final category = (body['category'] as String? ?? '').trim();
  final content = (body['content'] as String? ?? '').trim();
  final tags = (body['tags'] as List? ?? []).cast<String>();
  final excerpt = (body['excerpt'] as String? ?? '').trim();
  final bibliography = (body['bibliography'] as String? ?? '').trim();
  final imageUrl = body['imageUrl'] as String?;
  final publish = body['publish'] == true;

  if (title.isEmpty) return badRequest('El título es requerido');
  if (content.isEmpty) return badRequest('El contenido es requerido');
  if (!_validCategories.contains(category)) {
    return badRequest('Categoría inválida. Válidas: ${_validCategories.join(', ')}');
  }

  final wordCount = content.split(RegExp(r'\s+')).length;
  final readTime = (wordCount / 200).ceil().clamp(1, 60);
  final id = _uuid.v4();
  final tagsParam = '{${tags.map((t) => '"$t"').join(',')}}';

  await db.execute(
    "INSERT INTO articles (id, title, category, content, excerpt, tags, author_id, "
    'read_time_minutes, bibliography, image_url, is_published, published_at) '
    "VALUES ('$id'::uuid, \$1, \$2, \$3, \$4, '$tagsParam', '$authorId'::uuid, "
    '$readTime, \$5, \$6, ${publish ? 'true' : 'false'}, ${publish ? 'NOW()' : 'NULL'})',
    parameters: [title, category, content, excerpt.isEmpty ? null : excerpt,
        bibliography.isEmpty ? null : bibliography, imageUrl],
  );

  final created = await db.execute(
    'SELECT a.*, u.name AS author_name, u.faculty AS author_faculty, u.email AS author_email '
    "FROM articles a LEFT JOIN users u ON u.id = a.author_id WHERE a.id = '$id'::uuid",
  );

  return jsonCreated({'article': _articleToMap(created.first.toColumnMap(), isFavorite: false)});
}

Future<Response> _updateArticle(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;
  final role = claims['role'] as String;

  // Verificar que existe y que el usuario tiene permiso (admin o autor original)
  final existing = await db.execute(
    "SELECT author_id FROM articles WHERE id = '$id'::uuid",
  );
  if (existing.isEmpty) return notFound('Artículo no encontrado');

  final authorId = existing.first.toColumnMap()['author_id']?.toString();
  if (role != 'admin' && userId != authorId) {
    return forbidden('Solo el autor o un administrador puede editar este artículo');
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
  if (body.containsKey('category')) {
    final v = (body['category'] as String? ?? '').trim();
    if (!_validCategories.contains(v)) return badRequest('Categoría inválida');
    setClauses.add('category = \$$idx'); params.add(v); idx++;
  }
  if (body.containsKey('content')) {
    final v = (body['content'] as String? ?? '').trim();
    if (v.isEmpty) return badRequest('El contenido no puede estar vacío');
    setClauses.add('content = \$$idx'); params.add(v); idx++;
    final wc = v.split(RegExp(r'\s+')).length;
    setClauses.add('read_time_minutes = ${(wc / 200).ceil().clamp(1, 60)}');
  }
  if (body.containsKey('excerpt')) {
    setClauses.add('excerpt = \$$idx'); params.add(body['excerpt']); idx++;
  }
  if (body.containsKey('bibliography')) {
    setClauses.add('bibliography = \$$idx'); params.add(body['bibliography']); idx++;
  }
  if (body.containsKey('imageUrl')) {
    setClauses.add('image_url = \$$idx'); params.add(body['imageUrl']); idx++;
  }
  if (body.containsKey('tags')) {
    final tags = (body['tags'] as List? ?? []).cast<String>();
    final tagsParam = '{${tags.map((t) => '"$t"').join(',')}}';
    setClauses.add("tags = '$tagsParam'");
  }
  if (body.containsKey('publish')) {
    final pub = body['publish'] == true;
    setClauses.add('is_published = $pub');
    if (pub) setClauses.add('published_at = COALESCE(published_at, NOW())');
  }

  if (setClauses.isEmpty) return badRequest('No hay campos reconocidos');

  await db.execute(
    "UPDATE articles SET ${setClauses.join(', ')}, updated_at = NOW() WHERE id = '$id'::uuid",
    parameters: params.isEmpty ? null : params,
  );

  final updated = await db.execute(
    'SELECT a.*, u.name AS author_name, u.faculty AS author_faculty, u.email AS author_email '
    "FROM articles a LEFT JOIN users u ON u.id = a.author_id WHERE a.id = '$id'::uuid",
  );

  return jsonOk({'article': _articleToMap(updated.first.toColumnMap())});
}

Future<Response> _deactivateArticle(Request request, String id) async {
  await requireRole(request, 'admin');

  final existing = await db.execute(
    "SELECT id FROM articles WHERE id = '$id'::uuid",
  );
  if (existing.isEmpty) return notFound('Artículo no encontrado');

  await db.execute(
    "UPDATE articles SET is_published = false, updated_at = NOW() WHERE id = '$id'::uuid",
  );

  return jsonOk({'message': 'Artículo desactivado'});
}

Future<Response> _toggleFavorite(Request request, String id) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final existing = await db.execute(
    "SELECT id FROM articles WHERE id = '$id'::uuid AND is_published = true",
  );
  if (existing.isEmpty) return notFound('Artículo no encontrado');

  final fav = await db.execute(
    "SELECT 1 FROM article_favorites WHERE user_id = '$userId'::uuid AND article_id = '$id'::uuid",
  );

  final bool isFavorite;
  if (fav.isNotEmpty) {
    await db.execute(
      "DELETE FROM article_favorites WHERE user_id = '$userId'::uuid AND article_id = '$id'::uuid",
    );
    isFavorite = false;
  } else {
    await db.execute(
      "INSERT INTO article_favorites (user_id, article_id) VALUES ('$userId'::uuid, '$id'::uuid) ON CONFLICT DO NOTHING",
    );
    isFavorite = true;
  }

  return jsonOk({'isFavorite': isFavorite});
}

Future<Response> _myFavorites(Request request) async {
  final claims = await requireAuth(request);
  final userId = claims['sub'] as String;

  final rows = await db.execute(
    'SELECT a.id, a.title, a.category, a.excerpt, a.read_time_minutes, '
    'a.image_url, a.tags, a.published_at, a.created_at, '
    'a.author_id, u.name AS author_name, u.faculty AS author_faculty, u.email AS author_email '
    'FROM articles a '
    "JOIN article_favorites af ON af.article_id = a.id AND af.user_id = '$userId'::uuid "
    'LEFT JOIN users u ON u.id = a.author_id '
    'WHERE a.is_published = true '
    'ORDER BY af.saved_at DESC',
  );

  final articles = rows.map((row) {
    final map = row.toColumnMap();
    return {
      'id': map['id']?.toString(),
      'title': map['title'],
      'category': map['category'],
      'excerpt': map['excerpt'],
      'readTimeMinutes': map['read_time_minutes'],
      'imageUrl': map['image_url'],
      'tags': map['tags'],
      'publishedAt': map['published_at']?.toString(),
      'isFavorite': true,
      'author': map['author_id'] != null
          ? {
              'id': map['author_id']?.toString(),
              'name': map['author_name'],
              'faculty': map['author_faculty'],
              'email': map['author_email'],
            }
          : null,
    };
  }).toList();

  return jsonOk({'articles': articles});
}
