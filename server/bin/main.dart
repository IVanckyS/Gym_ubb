import 'dart:io';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../lib/src/database/connection.dart';
import '../lib/src/database/redis_client.dart';
import '../lib/src/handlers/auth_handler.dart';
import '../lib/src/handlers/users_handler.dart';
import '../lib/src/handlers/careers_handler.dart';
import '../lib/src/handlers/exercises_handler.dart';
import '../lib/src/handlers/routines_handler.dart';
import '../lib/src/handlers/joint_exercises_handler.dart';
import '../lib/src/handlers/workout_handler.dart';
import '../lib/src/handlers/history_handler.dart';
import '../lib/src/handlers/rankings_handler.dart';
import '../lib/src/handlers/articles_handler.dart';
import '../lib/src/handlers/events_handler.dart';
import '../lib/src/handlers/notifications_handler.dart';
import '../lib/src/handlers/lift_submissions_handler.dart';
import '../lib/src/handlers/hiit_handler.dart';
import '../lib/src/middleware/auth_middleware.dart';
import '../lib/src/middleware/cors_middleware.dart';
import '../lib/src/middleware/security_headers_middleware.dart';
import '../lib/src/utils/response.dart';

Future<void> main() async {
  // ── 1. Conectar a bases de datos ──────────────────────────────────────────
  try {
    await initDb();
  } catch (e) {
    print('[FATAL] No se pudo conectar a PostgreSQL: $e');
    exit(1);
  }

  try {
    await initRedis();
  } catch (e) {
    print('[FATAL] No se pudo conectar a Redis: $e');
    exit(1);
  }

  // ── 2. Router base ────────────────────────────────────────────────────────
  final router = Router();

  // Health check (sin autenticación, usado por Docker healthcheck y load balancers)
  router.get('/health', _healthHandler);

  // ── Módulo de autenticación ───────────────────────────────────────────────
  router.mount('/api/v1/auth', authHandler.call);

  router.mount('/api/v1/users', usersHandler.call);
  router.mount('/api/v1/careers', careersHandler.call);
  router.mount('/api/v1/exercises', exercisesHandler.call);
  router.mount('/api/v1/routines', routinesHandler.call);
  router.mount('/api/v1/joint-exercises', jointExercisesHandler.call);
  router.mount('/api/v1/workout', workoutHandler.call);
  router.mount('/api/v1/history', historyHandler.call);
  router.mount('/api/v1/rankings', rankingsHandler.call);
  router.mount('/api/v1/articles', articlesHandler.call);
  router.mount('/api/v1/events', eventsHandler.call);
  router.mount('/api/v1/notifications', notificationsHandler.call);
  router.mount('/api/v1/lift-submissions', liftSubmissionsHandler.call);
  router.mount('/api/v1/hiit', hiitHandler.call);

  // Archivos estáticos (imágenes subidas)
  router.get('/uploads/<path|.*>', _staticFileHandler);

  // Fallback 404
  router.all('/<ignored|.*>', (Request req) => notFound('Ruta no encontrada'));

  // ── 3. Pipeline de middleware ─────────────────────────────────────────────
  final handler = Pipeline()
      .addMiddleware(logRequests())               // Log de cada request
      .addMiddleware(corsMiddleware())             // CORS
      .addMiddleware(securityHeadersMiddleware())  // Headers de seguridad OWASP
      .addMiddleware(authExceptionMiddleware())    // Convierte excepciones auth → 401/403
      .addHandler(router.call);

  // ── 4. Arrancar servidor ──────────────────────────────────────────────────
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = await shelf_io.serve(
    handler,
    InternetAddress.anyIPv4,
    port,
  );

  server.autoCompress = true;
  print('[SERVER] GymUBB API corriendo en http://0.0.0.0:$port');
  print('[SERVER] Modo: ${Platform.environment['RUNMODE'] ?? 'development'}');

  // Shutdown graceful al recibir SIGINT / SIGTERM
  ProcessSignal.sigint.watch().listen((_) async {
    print('\n[SERVER] Deteniendo...');
    await closeDb();
    await closeRedis();
    await server.close(force: false);
    exit(0);
  });
}

// ── Handlers de utilidad ────────────────────────────────────────────────────

Future<Response> _staticFileHandler(Request request, String path) async {
  final file = File('/uploads/$path');
  if (!await file.exists()) {
    return Response.notFound('Archivo no encontrado');
  }
  final ext = path.split('.').last.toLowerCase();
  final mime = switch (ext) {
    'png'  => 'image/png',
    'jpg'  => 'image/jpeg',
    'jpeg' => 'image/jpeg',
    'gif'  => 'image/gif',
    'webp' => 'image/webp',
    _      => 'application/octet-stream',
  };
  return Response.ok(file.openRead(), headers: {'Content-Type': mime});
}

Response _healthHandler(Request request) {
  return jsonOk({
    'status': 'ok',
    'service': 'gym-ubb-api',
    'version': '1.0.0',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'environment': Platform.environment['RUNMODE'] ?? 'development',
  });
}
