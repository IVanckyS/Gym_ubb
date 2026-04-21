import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:postgres/postgres.dart';
import 'package:uuid/uuid.dart';

import '../database/connection.dart';
import '../database/redis_client.dart';
import '../middleware/auth_middleware.dart';
import '../services/jwt_service.dart';
import '../services/rate_limit_service.dart';
import '../services/email_service.dart';
import '../utils/response.dart';

final _uuid = Uuid();

/// Retorna el router del módulo de autenticación.
/// Se monta en main.dart como: router.mount('/api/v1/auth', authHandler);
Router get authHandler {
  final router = Router();

  router.post('/register', _register);
  router.post('/register/request', _registerRequest);
  router.post('/register/verify', _registerVerify);
  router.post('/login', _login);
  router.post('/logout', _logout);
  router.post('/refresh', _refresh);
  router.get('/me', _me);

  return router;
}

// ── Dominios de email permitidos ─────────────────────────────────────────────

const _allowedDomains = ['alumnos.ubiobio.cl', 'ubiobio.cl'];

bool _isInstitutionalEmail(String email) {
  final lower = email.toLowerCase().trim();
  return _allowedDomains.any((d) => lower.endsWith('@$d'));
}

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Extrae la IP real del request considerando proxy headers.
String _clientIp(Request request) {
  return request.headers['x-forwarded-for']?.split(',').first.trim() ??
      request.headers['x-real-ip'] ??
      'unknown';
}

/// Valida si un string es una IP válida (IPv4 o IPv6).
bool _isValidIp(String ip) {
  return RegExp(r'^(\d{1,3}\.){3}\d{1,3}$').hasMatch(ip) ||
      ip.contains(':'); // IPv6 simplificado
}

/// Hashea la contraseña con bcrypt (cost 12).
String _hashPassword(String password) =>
    BCrypt.hashpw(password, BCrypt.gensalt(logRounds: 12));

/// Verifica contraseña contra el hash almacenado (síncrono).
bool _verifyPassword(String password, String hash) =>
    BCrypt.checkpw(password, hash);

/// Registra una acción en security_audit_log.
Future<void> _audit({
  required String action,
  String? userId,
  required String ip,
  String? userAgent,
  Map<String, dynamic>? details,
}) async {
  try {
    await db.execute(
      Sql.named(
        'INSERT INTO security_audit_log '
        '(id, user_id, action, ip_address, user_agent, details) '
        'VALUES (@id, @userId, @action::audit_action, @ip, @userAgent, @details::jsonb)',
      ),
      parameters: {
        'id': _uuid.v4(),
        'userId': userId,
        'action': action,
        // Si la IP no es válida (ej. 'unknown'), guardar null para no romper el cast ::inet
        'ip': _isValidIp(ip) ? ip : null,
        'userAgent': userAgent,
        'details': details != null ? jsonEncode(details) : null,
      },
    );
  } catch (e) {
    // Nunca fallar por un log de auditoría
    print('[AUDIT] Error registrando acción $action: $e');
  }
}

/// Persiste un refresh token en la BD.
/// Los valores se embeben directamente (no como parámetros) para evitar el bug
/// de OID en postgres ^3.x donde _prepare falla con UUID/timestamptz.
/// Es seguro: id/userId son UUIDs generados por el servidor,
/// tokenHash es un JWT con solo caracteres base64url ([A-Za-z0-9\-_.]).
Future<void> _storeRefreshToken({
  required String id,
  required String userId,
  required String tokenHash,
}) async {
  await db.execute(
    "INSERT INTO refresh_tokens (id, user_id, token_hash, expires_at) "
    "VALUES ('$id'::uuid, '$userId'::uuid, '$tokenHash', "
    "NOW() + INTERVAL '30 days')",
  );
}

/// Construye el objeto de usuario seguro (sin password_hash) para responder al cliente.
Map<String, dynamic> _safeUser(Map<String, dynamic> row) {
  return {
    'id': row['id']?.toString(),
    'email': row['email'],
    'name': row['name'],
    'career': row['career'],
    'faculty': row['faculty'],
    'role': row['role'],
    'weightKg': row['weight_kg'],
    'heightCm': row['height_cm'],
    'bodyFatPct': row['body_fat_pct'],
    'units': row['units'],
    'notificationsEnabled': row['notifications_enabled'],
    'privateProfile': row['private_profile'],
    'memberSince': row['member_since']?.toString(),
    'lastLoginAt': row['last_login_at']?.toString(),
  };
}

// ── POST /api/v1/auth/register ────────────────────────────────────────────────

Future<Response> _register(Request request) async {
  final ip = _clientIp(request);

  // Rate limiting
  if (await isRateLimited(ip)) {
    final ttl = await getBlockTtl(ip);
    return tooManyRequests(
      'Demasiados intentos. Espera ${(ttl / 60).ceil()} minutos.',
    );
  }

  Map<String, dynamic> body;
  try {
    body = await parseBody(request);
  } catch (_) {
    return badRequest('Body JSON inválido');
  }

  // Campos requeridos
  final email = (getField<String>(body, 'email') ?? '').trim().toLowerCase();
  final password = getField<String>(body, 'password') ?? '';
  final name = (getField<String>(body, 'name') ?? '').trim();

  if (email.isEmpty) return badRequest('El campo email es requerido');
  if (password.isEmpty) return badRequest('El campo password es requerido');
  if (name.isEmpty) return badRequest('El campo name es requerido');

  // Validar email institucional
  if (!_isInstitutionalEmail(email)) {
    return badRequest(
      'Solo se permiten emails institucionales (@alumnos.ubiobio.cl o @ubiobio.cl)',
      code: 'EMAIL_NOT_INSTITUTIONAL',
    );
  }

  // Validar longitud del nombre
  if (name.length < 2 || name.length > 255) {
    return badRequest('El nombre debe tener entre 2 y 255 caracteres');
  }

  // Validar contraseña (mínimo 8 caracteres, al menos 1 mayúscula y 1 número)
  if (password.length < 8) {
    return badRequest('La contraseña debe tener al menos 8 caracteres');
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return badRequest('La contraseña debe contener al menos una mayúscula');
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return badRequest('La contraseña debe contener al menos un número');
  }

  // Verificar si ya existe ese email
  final existing = await db.execute(
    Sql.named('SELECT id FROM users WHERE email = @email'),
    parameters: {'email': email},
  );
  if (existing.isNotEmpty) {
    await recordFailedAttempt(ip);
    return conflict('Ya existe una cuenta con ese email', code: 'EMAIL_IN_USE');
  }

  // Determinar rol por dominio del email
  final role = email.endsWith('@alumnos.ubiobio.cl') ? 'student' : 'professor';

  // Crear usuario
  final userId = _uuid.v4();
  final passwordHash = _hashPassword(password);
  final career = getField<String>(body, 'career');

  await db.execute(
    Sql.named(
      'INSERT INTO users (id, email, password_hash, name, career, role) '
      "VALUES (@id, @email, @passwordHash, @name, @career, @role::user_role)",
    ),
    parameters: {
      'id': userId,
      'email': email,
      'passwordHash': passwordHash,
      'name': name,
      'career': career,
      'role': role,
    },
  );

  await _audit(
    action: 'account_created',
    userId: userId,
    ip: ip,
    userAgent: request.headers['user-agent'],
    details: {'email': email, 'role': role},
  );

  // Generar tokens
  final accessToken = generateAccessToken(
    userId: userId,
    email: email,
    role: role,
  );
  final jti = generateJti();
  final refreshToken = generateRefreshToken(userId: userId, jti: jti);

  await _storeRefreshToken(
    id: jti,
    userId: userId,
    tokenHash: refreshToken,
  );

  // Limpiar rate limit al registrarse exitosamente
  await clearAttempts(ip);

  return jsonCreated({
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': {
      'id': userId,
      'email': email,
      'name': name,
      'role': role,
      'career': career,
    },
  });
}

// ── POST /api/v1/auth/login ────────────────────────────────────────────────────

Future<Response> _login(Request request) async {
  final ip = _clientIp(request);

  // Rate limiting
  if (await isRateLimited(ip)) {
    final ttl = await getBlockTtl(ip);
    return tooManyRequests(
      'Demasiados intentos fallidos. Espera ${(ttl / 60).ceil()} minutos.',
    );
  }

  Map<String, dynamic> body;
  try {
    body = await parseBody(request);
  } catch (_) {
    return badRequest('Body JSON inválido');
  }

  final email = (getField<String>(body, 'email') ?? '').trim().toLowerCase();
  final password = getField<String>(body, 'password') ?? '';

  if (email.isEmpty || password.isEmpty) {
    return badRequest('Email y contraseña son requeridos');
  }

  // Buscar usuario activo (role::text porque postgres no decodifica enums customizados)
  final rows = await db.execute(
    Sql.named(
      'SELECT id, email, password_hash, name, career, role::text AS role, is_active '
      'FROM users WHERE email = @email',
    ),
    parameters: {'email': email},
  );

  if (rows.isEmpty) {
    // No revelar si el email existe o no (timing attack mitigation)
    BCrypt.checkpw(password, r'$2b$12$invalidhashfortimingnoop00000000000000000000000000000');
    await recordFailedAttempt(ip);
    await _audit(
      action: 'login_failed',
      ip: ip,
      userAgent: request.headers['user-agent'],
      details: {'email': email, 'reason': 'user_not_found'},
    );
    return unauthorized('Credenciales incorrectas');
  }

  final userRow = rows.first.toColumnMap();
  final isActive = userRow['is_active'] as bool? ?? false;

  if (!isActive) {
    await recordFailedAttempt(ip);
    await _audit(
      action: 'login_failed',
      ip: ip,
      userAgent: request.headers['user-agent'],
      details: {'email': email, 'reason': 'account_inactive'},
    );
    return unauthorized('Cuenta desactivada. Contacta al administrador');
  }

  final passwordHash = userRow['password_hash'] as String;
  final passwordValid = _verifyPassword(password, passwordHash);

  if (!passwordValid) {
    final attempts = await recordFailedAttempt(ip);
    await _audit(
      action: 'login_failed',
      ip: ip,
      userAgent: request.headers['user-agent'],
      details: {'email': email, 'reason': 'wrong_password', 'attempt': attempts},
    );

    final remaining = _maxLoginAttempts - attempts;
    if (remaining <= 0) {
      return tooManyRequests('Demasiados intentos. Cuenta bloqueada por 15 minutos.');
    }
    return unauthorized(
      'Credenciales incorrectas. Intentos restantes: $remaining',
    );
  }

  // Login exitoso
  final userId = userRow['id'].toString();
  final userEmail = userRow['email'] as String;
  final role = userRow['role'] as String;

  // Actualizar last_login_at
  await db.execute(
    Sql.named('UPDATE users SET last_login_at = NOW() WHERE id = @id'),
    parameters: {'id': userId},
  );

  // Generar tokens
  final accessToken = generateAccessToken(
    userId: userId,
    email: userEmail,
    role: role,
  );
  final jti = generateJti();
  final refreshToken = generateRefreshToken(userId: userId, jti: jti);

  await _storeRefreshToken(
    id: jti,
    userId: userId,
    tokenHash: refreshToken,
  );

  await clearAttempts(ip);

  await _audit(
    action: 'login',
    userId: userId,
    ip: ip,
    userAgent: request.headers['user-agent'],
  );

  return jsonOk({
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': _safeUser(userRow),
  });
}

const _maxLoginAttempts = 5;

// ── POST /api/v1/auth/logout ──────────────────────────────────────────────────

Future<Response> _logout(Request request) async {
  Map<String, dynamic> claims;
  try {
    claims = await requireAuth(request);
  } on UnauthorizedException catch (e) {
    return unauthorized(e.message);
  }

  final jti = claims['jti'] as String?;
  final exp = claims['exp'] as int?;

  if (jti != null && exp != null) {
    await blacklistToken(jti, exp);
  }

  // Revocar refresh token si se envió en el body
  Map<String, dynamic> body;
  try {
    body = await parseBody(request);
  } catch (_) {
    body = {};
  }

  final refreshToken = getField<String>(body, 'refreshToken');
  if (refreshToken != null && refreshToken.isNotEmpty) {
    await db.execute(
      Sql.named(
        'UPDATE refresh_tokens SET is_revoked = true '
        'WHERE user_id = @userId AND token_hash = @token AND is_revoked = false',
      ),
      parameters: {
        'userId': claims['sub'],
        'token': refreshToken,
      },
    );
  }

  final ip = _clientIp(request);
  await _audit(
    action: 'logout',
    userId: claims['sub'] as String?,
    ip: ip,
    userAgent: request.headers['user-agent'],
  );

  return jsonOk({'message': 'Sesión cerrada correctamente'});
}

// ── POST /api/v1/auth/refresh ─────────────────────────────────────────────────

Future<Response> _refresh(Request request) async {
  Map<String, dynamic> body;
  try {
    body = await parseBody(request);
  } catch (_) {
    return badRequest('Body JSON inválido');
  }

  final refreshTokenStr = getField<String>(body, 'refreshToken');
  if (refreshTokenStr == null || refreshTokenStr.isEmpty) {
    return badRequest('refreshToken es requerido');
  }

  // Verificar firma y expiración del refresh token
  Map<String, dynamic> claims;
  try {
    claims = verifyToken(refreshTokenStr);
  } catch (_) {
    return unauthorized('Refresh token inválido o expirado');
  }

  if (claims['type'] != 'refresh') {
    return unauthorized('Tipo de token incorrecto');
  }

  final jti = claims['jti'] as String;
  final userId = claims['sub'] as String;

  // Verificar que el token existe en BD y no fue revocado
  final rows = await db.execute(
    Sql.named(
      'SELECT id, user_id, is_revoked, expires_at, replaced_by '
      'FROM refresh_tokens WHERE id = @jti AND token_hash = @token',
    ),
    parameters: {'jti': jti, 'token': refreshTokenStr},
  );

  if (rows.isEmpty) {
    return unauthorized('Refresh token no encontrado');
  }

  final tokenRow = rows.first.toColumnMap();

  if (tokenRow['is_revoked'] as bool) {
    // Token reutilizado — posible robo. Revocar TODA la familia de tokens del usuario.
    await db.execute(
      Sql.named(
        'UPDATE refresh_tokens SET is_revoked = true WHERE user_id = @userId',
      ),
      parameters: {'userId': userId},
    );
    final ip = _clientIp(request);
    await _audit(
      action: 'login_failed',
      userId: userId,
      ip: ip,
      userAgent: request.headers['user-agent'],
      details: {'reason': 'refresh_token_reuse_detected', 'jti': jti},
    );
    return unauthorized(
      'Token de refresco inválido. Por seguridad se cerraron todas tus sesiones.',
    );
  }

  // Buscar datos actualizados del usuario
  final userRows = await db.execute(
    Sql.named(
      'SELECT id, email, name, career, faculty, role::text AS role, is_active, weight_kg, height_cm, '
      'body_fat_pct, units, notifications_enabled, private_profile, member_since, last_login_at '
      'FROM users WHERE id = @userId AND is_active = true',
    ),
    parameters: {'userId': userId},
  );

  if (userRows.isEmpty) {
    return unauthorized('Usuario no encontrado o desactivado');
  }

  final userRow = userRows.first.toColumnMap();
  final email = userRow['email'] as String;
  final role = userRow['role'] as String;

  // Rotación: marcar el token actual como revocado
  final newJti = generateJti();
  await db.execute(
    Sql.named(
      'UPDATE refresh_tokens SET is_revoked = true, replaced_by = @newJti '
      'WHERE id = @jti',
    ),
    parameters: {'newJti': newJti, 'jti': jti},
  );

  // Emitir nuevo par de tokens
  final newAccessToken = generateAccessToken(
    userId: userId,
    email: email,
    role: role,
  );
  final newRefreshToken = generateRefreshToken(userId: userId, jti: newJti);

  await _storeRefreshToken(
    id: newJti,
    userId: userId,
    tokenHash: newRefreshToken,
  );

  return jsonOk({
    'accessToken': newAccessToken,
    'refreshToken': newRefreshToken,
    'user': _safeUser(userRow),
  });
}

// ── GET /api/v1/auth/me ────────────────────────────────────────────────────────

Future<Response> _me(Request request) async {
  Map<String, dynamic> claims;
  try {
    claims = await requireAuth(request);
  } on UnauthorizedException catch (e) {
    return unauthorized(e.message);
  }

  final userId = claims['sub'] as String;

  final rows = await db.execute(
    Sql.named(
      'SELECT id, email, name, career, faculty, role::text AS role, weight_kg, height_cm, '
      'body_fat_pct, units, notifications_enabled, private_profile, '
      'member_since, last_login_at '
      'FROM users WHERE id = @userId AND is_active = true',
    ),
    parameters: {'userId': userId},
  );

  if (rows.isEmpty) {
    return notFound('Usuario no encontrado');
  }

  return jsonOk(_safeUser(rows.first.toColumnMap()));
}

// ── POST /api/v1/auth/register/request ────────────────────────────────────────
// Valida datos, guarda {name, passwordHash, career, code} en Redis (10 min)
// y envía el código de 6 dígitos al correo institucional.

Future<Response> _registerRequest(Request request) async {
  final ip = _clientIp(request);

  if (await isRateLimited(ip)) {
    final ttl = await getBlockTtl(ip);
    return tooManyRequests(
      'Demasiados intentos. Espera ${(ttl / 60).ceil()} minutos.',
    );
  }

  Map<String, dynamic> body;
  try {
    body = await parseBody(request);
  } catch (_) {
    return badRequest('Body JSON inválido');
  }

  final email = (getField<String>(body, 'email') ?? '').trim().toLowerCase();
  final password = getField<String>(body, 'password') ?? '';
  final name = (getField<String>(body, 'name') ?? '').trim();
  final career = getField<String>(body, 'career');

  if (email.isEmpty) return badRequest('El campo email es requerido');
  if (password.isEmpty) return badRequest('El campo password es requerido');
  if (name.isEmpty) return badRequest('El campo name es requerido');

  if (!_isInstitutionalEmail(email)) {
    return badRequest(
      'Solo se permiten emails institucionales (@alumnos.ubiobio.cl o @ubiobio.cl)',
      code: 'EMAIL_NOT_INSTITUTIONAL',
    );
  }

  if (name.length < 2 || name.length > 255) {
    return badRequest('El nombre debe tener entre 2 y 255 caracteres');
  }

  if (password.length < 8) {
    return badRequest('La contraseña debe tener al menos 8 caracteres');
  }
  if (!RegExp(r'[A-Z]').hasMatch(password)) {
    return badRequest('La contraseña debe contener al menos una mayúscula');
  }
  if (!RegExp(r'[0-9]').hasMatch(password)) {
    return badRequest('La contraseña debe contener al menos un número');
  }

  // Verificar que el email no esté ya registrado
  final existing = await db.execute(
    Sql.named('SELECT id FROM users WHERE email = @email'),
    parameters: {'email': email},
  );
  if (existing.isNotEmpty) {
    await recordFailedAttempt(ip);
    return conflict('Ya existe una cuenta con ese email', code: 'EMAIL_IN_USE');
  }

  // Generar código, hashear contraseña y guardar en Redis
  final code = generateVerificationCode();
  final passwordHash = _hashPassword(password);
  final payload = jsonEncode({
    'name': name,
    'passwordHash': passwordHash,
    'career': career,
    'code': code,
  });

  await redisSet('reg:$email', payload, ttlSeconds: 600);
  await redisDel('reg_att:$email'); // reset intentos previos

  // Enviar email (si SMTP no está configurado, imprime en logs)
  try {
    await sendVerificationEmail(to: email, code: code);
  } catch (e) {
    await redisDel('reg:$email');
    return Response.internalServerError(
      body: jsonEncode({
        'data': null,
        'error': {
          'code': 'EMAIL_SEND_FAILED',
          'message': 'No se pudo enviar el correo de verificación. Intenta de nuevo.',
        },
      }),
      headers: {'content-type': 'application/json'},
    );
  }

  return jsonOk({'message': 'Código de verificación enviado a $email'});
}

// ── POST /api/v1/auth/register/verify ─────────────────────────────────────────
// Verifica el código, crea el usuario y retorna tokens de sesión.

Future<Response> _registerVerify(Request request) async {
  final ip = _clientIp(request);

  Map<String, dynamic> body;
  try {
    body = await parseBody(request);
  } catch (_) {
    return badRequest('Body JSON inválido');
  }

  final email = (getField<String>(body, 'email') ?? '').trim().toLowerCase();
  final code = (getField<String>(body, 'code') ?? '').trim();

  if (email.isEmpty) return badRequest('El campo email es requerido');
  if (code.isEmpty) return badRequest('El campo code es requerido');
  if (code.length != 6) return badRequest('El código debe tener 6 dígitos');

  // Recuperar datos pendientes de Redis
  final stored = await redisGet('reg:$email');
  if (stored == null) {
    return badRequest(
      'El código ha expirado o no existe. Solicita un nuevo código.',
      code: 'CODE_EXPIRED',
    );
  }

  final data = jsonDecode(stored) as Map<String, dynamic>;
  final storedCode = data['code'] as String;

  if (code != storedCode) {
    // Contar intentos fallidos — máximo 5
    final attKey = 'reg_att:$email';
    final attempts = await redisIncr(attKey);
    await redisExpire(attKey, 600);

    if (attempts >= 5) {
      await redisDel('reg:$email');
      await redisDel(attKey);
      return badRequest(
        'Demasiados intentos incorrectos. Solicita un nuevo código.',
        code: 'TOO_MANY_ATTEMPTS',
      );
    }

    return badRequest(
      'Código incorrecto. Intentos restantes: ${5 - attempts}',
      code: 'INVALID_CODE',
    );
  }

  // Código correcto — crear usuario
  final name = data['name'] as String;
  final passwordHash = data['passwordHash'] as String;
  final career = data['career'] as String?;
  final role = email.endsWith('@alumnos.ubiobio.cl') ? 'student' : 'professor';

  // Verificar condición de carrera (podría haberse registrado mientras esperaba)
  final doubleCheck = await db.execute(
    Sql.named('SELECT id FROM users WHERE email = @email'),
    parameters: {'email': email},
  );
  if (doubleCheck.isNotEmpty) {
    await redisDel('reg:$email');
    await redisDel('reg_att:$email');
    return conflict('Ya existe una cuenta con ese email', code: 'EMAIL_IN_USE');
  }

  final userId = _uuid.v4();

  await db.execute(
    Sql.named(
      'INSERT INTO users (id, email, password_hash, name, career, role) '
      'VALUES (@id, @email, @passwordHash, @name, @career, @role::user_role)',
    ),
    parameters: {
      'id': userId,
      'email': email,
      'passwordHash': passwordHash,
      'name': name,
      'career': career,
      'role': role,
    },
  );

  // Limpiar Redis
  await redisDel('reg:$email');
  await redisDel('reg_att:$email');
  await clearAttempts(ip);

  await _audit(
    action: 'account_created',
    userId: userId,
    ip: ip,
    userAgent: request.headers['user-agent'],
    details: {'email': email, 'role': role},
  );

  // Generar tokens de sesión
  final accessToken = generateAccessToken(
    userId: userId,
    email: email,
    role: role,
  );
  final jti = generateJti();
  final refreshToken = generateRefreshToken(userId: userId, jti: jti);

  await _storeRefreshToken(id: jti, userId: userId, tokenHash: refreshToken);

  return jsonCreated({
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': {
      'id': userId,
      'email': email,
      'name': name,
      'role': role,
      'career': career,
    },
  });
}
