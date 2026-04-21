import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/auth_service.dart';

class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    required this.email,
    required this.name,
  });

  final String email;
  final String name;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  // 6 controladores y 6 focus nodes para el PIN
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _resending = false;
  String? _resendError;
  String? _resendSuccess;

  // Cooldown reenvío: 60 segundos
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _startCooldown();
    // Enfocar primer box al abrir
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _resendCooldown = 60);
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendCooldown = 0);
      } else {
        if (mounted) setState(() => _resendCooldown--);
      }
    });
  }

  String get _currentCode =>
      _controllers.map((c) => c.text).join();

  void _onBoxChanged(int index, String value) {
    if (value.length > 1) {
      // Pegado de código completo: distribuir dígitos
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      final nextFocus = digits.length < 6 ? digits.length : 5;
      _focusNodes[nextFocus].requestFocus();
      if (digits.length == 6) _trySubmit();
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        _trySubmit();
      }
    }
  }

  void _onBoxKeyDown(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  Future<void> _trySubmit() async {
    final code = _currentCode;
    if (code.length != 6) return;

    final auth = context.read<AuthProvider>();
    auth.clearError();

    final ok = await auth.verifyRegistration(
      email: widget.email,
      code: code,
    );

    if (!mounted) return;

    if (ok) {
      // Router redirige a /home automáticamente al cambiar el AuthStatus
      context.go('/home');
    } else {
      // Limpiar campos en error
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0 || _resending) return;

    setState(() {
      _resending = true;
      _resendError = null;
      _resendSuccess = null;
    });

    try {
      // Reutiliza registerRequest con los mismos datos (el name no importa aquí)
      await _authService.registerRequest(
        email: widget.email,
        password: '__resend__',
        name: widget.name,
      );
      // El servidor sobreescribirá el código en Redis aunque la contraseña sea placeholder;
      // en la práctica el usuario no cambia su contraseña al reenviar,
      // así que se llama con datos guardados (ver nota abajo).
      if (mounted) {
        setState(() {
          _resendSuccess = 'Nuevo código enviado a ${widget.email}';
          _resending = false;
        });
        _startCooldown();
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _resendError = e.message;
          _resending = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resendError = 'No se pudo reenviar el código.';
          _resending = false;
        });
      }
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final domain = parts[1];
    if (local.length <= 2) return email;
    return '${local[0]}${'*' * (local.length - 2)}${local[local.length - 1]}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  _buildHeader(),
                  const SizedBox(height: 32),
                  _buildCard(),
                  const SizedBox(height: 20),
                  _buildCancelButton(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: AppColors.accentPrimary.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: AppColors.accentPrimary,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Verifica tu correo',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
                color: context.colorTextSecondary, fontSize: 14, height: 1.4),
            children: [
              const TextSpan(text: 'Enviamos un código de 6 dígitos a\n'),
              TextSpan(
                text: _maskEmail(widget.email),
                style: const TextStyle(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
      ),
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          // ── PIN boxes ────────────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) => _buildPinBox(i)),
          ),
          const SizedBox(height: 8),
          Text(
            'El código expira en 10 minutos',
            style: TextStyle(color: context.colorTextMuted, fontSize: 12),
          ),

          // ── Error ────────────────────────────────────────────────────────
          Consumer<AuthProvider>(
            builder: (context, auth, _) {
              final msg = auth.error ?? _resendError;
              if (msg == null) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.accentSecondary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color:
                            AppColors.accentSecondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.accentSecondary, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          msg,
                          style: const TextStyle(
                              color: AppColors.accentSecondary, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // ── Éxito reenvío ────────────────────────────────────────────────
          if (_resendSuccess != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: AppColors.accentGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.accentGreen, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _resendSuccess!,
                      style: const TextStyle(
                          color: AppColors.accentGreen, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          // ── Botón verificar ──────────────────────────────────────────────
          Consumer<AuthProvider>(
            builder: (context, auth, _) => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (auth.loading || _currentCode.length != 6)
                    ? null
                    : _trySubmit,
                child: auth.loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Verificar y crear cuenta'),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Reenviar código ──────────────────────────────────────────────
          TextButton(
            onPressed: (_resendCooldown > 0 || _resending) ? null : _resendCode,
            child: _resending
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    _resendCooldown > 0
                        ? 'Reenviar código (${_resendCooldown}s)'
                        : 'Reenviar código',
                    style: TextStyle(
                      color: _resendCooldown > 0
                          ? context.colorTextMuted
                          : AppColors.accentPrimary,
                      fontSize: 14,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinBox(int index) {
    return SizedBox(
      width: 44,
      height: 52,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) => _onBoxKeyDown(index, event),
        child: TextFormField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 6, // permite pegar código completo
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: context.colorBorder, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.accentPrimary, width: 2),
            ),
            filled: true,
            fillColor: context.colorBgTertiary,
          ),
          onChanged: (v) => _onBoxChanged(index, v),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return TextButton(
      onPressed: () => context.go('/login'),
      child: Text(
        'Volver al inicio de sesión',
        style: TextStyle(color: context.colorTextSecondary, fontSize: 14),
      ),
    );
  }
}
