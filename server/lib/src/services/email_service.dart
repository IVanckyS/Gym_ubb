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
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="margin:0;padding:0;background-color:#06060e;font-family:Arial,Helvetica,sans-serif;">
  <table width="100%" cellpadding="0" cellspacing="0">
    <tr>
      <td align="center" style="padding:40px 16px;">
        <table width="480" cellpadding="0" cellspacing="0" style="max-width:480px;border-radius:20px;overflow:hidden;border:1px solid rgba(255,255,255,0.06);">

          <!-- ── BANNER HEADER ── -->
          <tr>
            <td style="background:linear-gradient(135deg,#010c20 0%,#012848 100%);padding:0;position:relative;">
              <table width="100%" cellpadding="0" cellspacing="0">
                <tr>
                  <td style="padding:32px 32px 28px;">
                    <!-- Wordmark row -->
                    <table cellpadding="0" cellspacing="0">
                      <tr>
                        <td style="vertical-align:middle;padding-right:10px;">
                          <!-- Shield icon (inline SVG) -->
                          <svg width="40" height="40" viewBox="0 0 100 100" fill="none" xmlns="http://www.w3.org/2000/svg">
                            <rect width="100" height="100" rx="24" fill="#001428"/>
                            <path d="M50 10L82 22V50C82 68 67 80 50 83C33 80 18 68 18 50V22L50 10Z" fill="rgba(255,255,255,0.08)" stroke="rgba(255,255,255,0.18)" stroke-width="1.5"/>
                            <line x1="6" y1="48" x2="94" y2="48" stroke="#F9B214" stroke-width="4.5" stroke-linecap="round"/>
                            <rect x="4" y="35" width="17" height="26" rx="4" fill="#014898" stroke="#F9B214" stroke-width="2.2"/>
                            <rect x="1" y="39" width="5" height="18" rx="2" fill="#F9B214" opacity="0.75"/>
                            <rect x="79" y="35" width="17" height="26" rx="4" fill="#014898" stroke="#F9B214" stroke-width="2.2"/>
                            <rect x="94" y="39" width="5" height="18" rx="2" fill="#F9B214" opacity="0.75"/>
                            <path d="M20 75C29 71 35 79 44 75C53 71 59 79 68 75C77 71 82 77 80 77" stroke="#F9B214" stroke-width="1.8" fill="none" opacity="0.65" stroke-linecap="round"/>
                          </svg>
                        </td>
                        <td style="vertical-align:middle;">
                          <span style="font-size:26px;font-weight:900;letter-spacing:-1px;line-height:1;">
                            <span style="color:#ffffff;">Gym</span><span style="color:#F9B214;">UBB</span>
                          </span>
                          <div style="font-size:8.5px;color:#4d9fff;letter-spacing:2.5px;text-transform:uppercase;margin-top:3px;font-weight:700;">Universidad del Bío-Bío</div>
                        </td>
                      </tr>
                    </table>
                    <!-- Greeting text -->
                    <div style="margin-top:22px;">
                      <div style="font-size:10px;color:#4d9fff;letter-spacing:2.5px;text-transform:uppercase;font-weight:700;margin-bottom:6px;">VERIFICACIÓN DE CUENTA</div>
                      <div style="font-size:28px;font-weight:900;color:#ffffff;letter-spacing:-1px;line-height:1.1;">Bienvenido al</div>
                      <div style="font-size:28px;font-weight:900;color:#F9B214;letter-spacing:-1px;line-height:1.1;">GymUBB</div>
                    </div>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- ── BODY ── -->
          <tr>
            <td style="background:#0c0c1a;padding:32px 32px 24px;">
              <p style="margin:0 0 8px;color:#eeeef8;font-size:16px;font-weight:700;">Verifica tu correo electrónico</p>
              <p style="margin:0 0 24px;color:#6060a0;font-size:14px;line-height:1.6;">
                Hola, usa el siguiente código para completar tu registro en GymUBB.
                Este código es válido por <strong style="color:#eeeef8;">10 minutos</strong>.
              </p>

              <!-- Code box -->
              <table width="100%" cellpadding="0" cellspacing="0" style="margin-bottom:24px;">
                <tr>
                  <td style="background:#121228;border-radius:14px;border:1px solid rgba(1,72,152,0.4);padding:24px;text-align:center;">
                    <div style="font-size:11px;color:#6060a0;text-transform:uppercase;letter-spacing:2.5px;margin-bottom:10px;">Tu código de verificación</div>
                    <div style="font-size:38px;font-weight:900;color:#F9B214;letter-spacing:12px;font-family:'Courier New',monospace;">$code</div>
                  </td>
                </tr>
              </table>

              <p style="margin:0;color:#3a3a58;font-size:12px;line-height:1.7;">
                Si no solicitaste este registro, ignora este correo.<br>
                No compartas este código con nadie.
              </p>
            </td>
          </tr>

          <!-- ── FOOTER ── -->
          <tr>
            <td style="background:#080816;padding:16px 32px 20px;border-top:1px solid rgba(255,255,255,0.04);">
              <p style="margin:0;color:#2a2a46;font-size:11px;">
                GymUBB · Universidad del Bío-Bío · Concepción &amp; Chillán, Chile
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
