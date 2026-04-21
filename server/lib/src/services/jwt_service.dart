import 'dart:io';
import 'package:dart_jsonwebtoken/dart_jsonwebtoken.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

String get _jwtSecret {
  final secret = Platform.environment['JWT_SECRET'];
  if (secret == null || secret.isEmpty) {
    throw StateError('[JWT] JWT_SECRET no configurado en variables de entorno');
  }
  return secret;
}

String get _jwtAudience =>
    Platform.environment['JWT_AUDIENCE'] ?? 'gym-ubb-app';

/// Duración del access token: 30 minutos.
const _accessTokenTtl = Duration(minutes: 30);

/// Duración del refresh token: 30 días.
const _refreshTokenTtl = Duration(days: 30);

/// Genera un JWT de acceso (short-lived, 15 min).
///
/// El payload incluye: sub (userId), email, role, jti (único por token).
String generateAccessToken({
  required String userId,
  required String email,
  required String role,
}) {
  final now = DateTime.now().toUtc();
  final jti = _uuid.v4();

  final jwt = JWT(
    {
      'sub': userId,
      'email': email,
      'role': role,
      'jti': jti,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(_accessTokenTtl).millisecondsSinceEpoch ~/ 1000,
      'aud': _jwtAudience,
      'type': 'access',
    },
    jwtId: jti,
    audience: Audience.one(_jwtAudience),
    subject: userId,
    issuer: 'gym-ubb-api',
  );

  return jwt.sign(
    SecretKey(_jwtSecret),
    algorithm: JWTAlgorithm.HS256,
    expiresIn: _accessTokenTtl,
  );
}

/// Genera un JWT de refresco (long-lived, 30 días).
///
/// El jti se persiste en la tabla refresh_tokens para validación y rotación.
String generateRefreshToken({
  required String userId,
  required String jti,
}) {
  final now = DateTime.now().toUtc();

  final jwt = JWT(
    {
      'sub': userId,
      'jti': jti,
      'iat': now.millisecondsSinceEpoch ~/ 1000,
      'exp': now.add(_refreshTokenTtl).millisecondsSinceEpoch ~/ 1000,
      'aud': _jwtAudience,
      'type': 'refresh',
    },
    jwtId: jti,
    audience: Audience.one(_jwtAudience),
    subject: userId,
    issuer: 'gym-ubb-api',
  );

  return jwt.sign(
    SecretKey(_jwtSecret),
    algorithm: JWTAlgorithm.HS256,
    expiresIn: _refreshTokenTtl,
  );
}

/// Verifica un JWT y retorna su payload decodificado.
/// Lanza [JWTException] si es inválido o expirado.
Map<String, dynamic> verifyToken(String token) {
  final jwt = JWT.verify(
    token,
    SecretKey(_jwtSecret),
    audience: Audience.one(_jwtAudience),
    issuer: 'gym-ubb-api',
  );

  return jwt.payload as Map<String, dynamic>;
}

/// Genera un jti único para un nuevo refresh token.
String generateJti() => _uuid.v4();

/// Retorna la fecha de expiración para un refresh token nuevo.
DateTime refreshTokenExpiresAt() =>
    DateTime.now().toUtc().add(_refreshTokenTtl);
