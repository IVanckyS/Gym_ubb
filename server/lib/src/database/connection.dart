import 'dart:io';
import 'package:postgres/postgres.dart';
import 'schema.dart';
import 'seed.dart';

Connection? _db;

/// Retorna la conexión activa a PostgreSQL.
/// Lanza [StateError] si no se llamó [initDb] primero.
Connection get db {
  if (_db == null) {
    throw StateError('Base de datos no inicializada. Llama initDb() primero.');
  }
  return _db!;
}

/// Inicializa la conexión a PostgreSQL y crea el esquema si no existe.
/// Debe llamarse una vez al arrancar el servidor.
Future<void> initDb() async {
  final host = Platform.environment['DB_HOST'] ?? 'localhost';
  final port = int.tryParse(Platform.environment['DB_PORT'] ?? '5432') ?? 5432;
  final database = Platform.environment['DB_NAME'] ?? 'gym_ubb_dev';
  final username = Platform.environment['DB_USER'] ?? 'gym_ubb_user';
  final password = Platform.environment['DB_PASSWORD'] ?? '';
  final isProduction = Platform.environment['RUNMODE'] == 'production';

  _db = await Connection.open(
    Endpoint(
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    ),
    settings: ConnectionSettings(
      sslMode: isProduction ? SslMode.require : SslMode.disable,
      connectTimeout: const Duration(seconds: 10),
    ),
  );

  print('[DB] Conectado a PostgreSQL en $host:$port/$database');

  // Crear tablas, enums e índices si no existen
  await initSchema(_db!);

  // Sembrar datos de desarrollo si es necesario
  await seedAdminUser(_db!);
  await seedDev(_db!);
  await seedJointExercises(_db!);
  await seedArticles(_db!);
  await seedEvents(_db!);
}

/// Cierra la conexión activa. Útil para shutdown graceful y tests.
Future<void> closeDb() async {
  await _db?.close();
  _db = null;
  print('[DB] Conexión cerrada');
}
