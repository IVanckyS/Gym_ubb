import 'dart:io';
import 'dart:math';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

/// Genera un código de verificación numérico de 6 dígitos.
String generateVerificationCode() {
  final rnd = Random.secure();
  return (100000 + rnd.nextInt(900000)).toString();
}

/// Envía el código de verificación al correo indicado.
/// Si las variables de entorno SMTP no están configuradas, imprime el código
/// en los logs del servidor (útil en desarrollo).
Future<void> sendVerificationEmail({
  required String to,
  required String code,
}) async {
  final host = Platform.environment['SMTP_HOST'];
  final port = int.tryParse(Platform.environment['SMTP_PORT'] ?? '587') ?? 587;
  final user = Platform.environment['SMTP_USER'];
  final password = Platform.environment['SMTP_PASSWORD'];

  if (host == null || user == null || password == null) {
    // Modo desarrollo: loggear el código en lugar de enviar
    print('');
    print('╔══════════════════════════════════════════════╗');
    print('║  [EMAIL DEV] Código de verificación          ║');
    print('║  Para: $to');
    print('║  Código: $code                               ║');
    print('╚══════════════════════════════════════════════╝');
    print('');
    return;
  }

  final smtpServer = SmtpServer(
    host,
    port: port,
    username: user,
    password: password,
    ssl: port == 465,
    allowInsecure: port != 465,
  );

  final message = Message()
    ..from = Address(user, 'GymUBB')
    ..recipients.add(to)
    ..subject = 'Código de verificación — GymUBB ($code)'
    ..html = _buildEmailHtml(code, to);

  try {
    final sendReport = await send(message, smtpServer);
    print('[EMAIL] Enviado a $to: ${sendReport.mail.subject}');
  } on MailerException catch (e) {
    print('[EMAIL] Error enviando a $to: $e');
    rethrow;
  }
}

String _buildEmailHtml(String code, String to) => '''
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"></head>
<body style="margin:0;padding:0;background-color:#0A0A0F;font-family:Arial,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr>
      <td align="center" style="padding:40px 20px;">
        <table width="420" cellpadding="0" cellspacing="0" style="background:#12121A;border-radius:16px;border:1px solid rgba(255,255,255,0.08);">
          <tr>
            <td style="padding:36px 36px 24px;">
              <!-- Header -->
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td>
                    <div style="display:inline-block;background:linear-gradient(135deg,#6C63FF,#9C8FFF);border-radius:12px;padding:10px 14px;">
                      <span style="font-size:22px;">🏋️</span>
                    </div>
                  </td>
                </tr>
                <tr><td style="height:12px;"></td></tr>
                <tr>
                  <td>
                    <h1 style="margin:0;color:#FFFFFF;font-size:22px;font-weight:bold;">GymUBB</h1>
                    <p style="margin:4px 0 0;color:#8B8B9E;font-size:13px;">Universidad del Bío-Bío</p>
                  </td>
                </tr>
              </table>

              <!-- Divider -->
              <div style="height:1px;background:rgba(255,255,255,0.08);margin:24px 0;"></div>

              <!-- Body -->
              <p style="margin:0 0 8px;color:#FFFFFF;font-size:16px;font-weight:600;">Verifica tu correo electrónico</p>
              <p style="margin:0 0 24px;color:#8B8B9E;font-size:14px;line-height:1.5;">
                Hola, usa el siguiente código para completar tu registro en GymUBB.
                Este código es válido por <strong style="color:#FFFFFF;">10 minutos</strong>.
              </p>

              <!-- Code box -->
              <div style="background:#1A1A24;border-radius:12px;border:1px solid rgba(108,99,255,0.4);padding:24px;text-align:center;margin-bottom:24px;">
                <p style="margin:0 0 8px;color:#8B8B9E;font-size:12px;text-transform:uppercase;letter-spacing:2px;">Tu código</p>
                <p style="margin:0;color:#6C63FF;font-size:36px;font-weight:bold;letter-spacing:10px;">$code</p>
              </div>

              <!-- Warning -->
              <p style="margin:0;color:#4A4A5E;font-size:12px;line-height:1.6;">
                Si no solicitaste este registro, ignora este correo.<br>
                No compartas este código con nadie.
              </p>
            </td>
          </tr>
          <tr>
            <td style="padding:16px 36px 24px;border-top:1px solid rgba(255,255,255,0.05);">
              <p style="margin:0;color:#4A4A5E;font-size:11px;">
                GymUBB · Universidad del Bío-Bío · Concepción, Chile
              </p>
            </td>
          </tr>
        </table>
      </td>
    </tr>
  </table>
</body>
</html>
''';
