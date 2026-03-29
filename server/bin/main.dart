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

  // Los demás módulos se montan en las siguientes fases:
  // router.mount('/api/v1/routines',  routinesHandler.call);
  // ...

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

Response _healthHandler(Request request) {
  return jsonOk({
    'status': 'ok',
    'service': 'gym-ubb-api',
    'version': '1.0.0',
    'timestamp': DateTime.now().toUtc().toIso8601String(),
    'environment': Platform.environment['RUNMODE'] ?? 'development',
  });
}
