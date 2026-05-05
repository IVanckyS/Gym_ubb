import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  final _authService = AuthService();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await _authService.registerRequest(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
        name: _nameCtrl.text.trim(),
      );

      if (!mounted) return;
      context.push('/register/verify', extra: {
        'email': _emailCtrl.text.trim().toLowerCase(),
        'name': _nameCtrl.text.trim(),
      });
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Error de conexión. Verifica tu red.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildHeader(),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 32),
                        _buildCard(),
                        const SizedBox(height: 20),
                        _buildLoginLink(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF010c20), Color(0xFF012848)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(28, 44, 28, 36),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                'assets/icons/shield_logo.svg',
                width: 56,
                height: 56,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: const TextSpan(
                      children: [
                        TextSpan(
                          text: 'Gym',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.1,
                          ),
                        ),
                        TextSpan(
                          text: 'UBB',
                          style: TextStyle(
                            color: Color(0xFFF9B214),
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1,
                            height: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'UNIVERSIDAD DEL BÍO-BÍO',
                    style: TextStyle(
                      color: Color(0xFF4D9FFF),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'Crea tu cuenta',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Regístrate con tu correo institucional UBB',
            style: TextStyle(
              color: Color(0xFF6060A0),
              fontSize: 14,
            ),
          ),
        ],
      ),
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
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Nombre completo ──────────────────────────────────────────────
            TextFormField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: context.colorTextPrimary),
              decoration: InputDecoration(
                labelText: 'Nombre completo',
                hintText: 'Ej: Juan Pérez',
                prefixIcon:
                    Icon(Icons.person_outline, color: context.colorTextMuted),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
                if (v.trim().length < 2) return 'El nombre es muy corto';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Email ────────────────────────────────────────────────────────
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: context.colorTextPrimary),
              decoration: InputDecoration(
                labelText: 'Correo institucional',
                hintText: 'usuario@alumnos.ubiobio.cl',
                prefixIcon:
                    Icon(Icons.email_outlined, color: context.colorTextMuted),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Ingresa tu correo';
                if (!AuthService.isValidUbbEmail(v.trim())) {
                  return 'Debe ser @alumnos.ubiobio.cl o @ubiobio.cl';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Contraseña ───────────────────────────────────────────────────
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              style: TextStyle(color: context.colorTextPrimary),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                hintText: 'Mín. 8 caracteres, 1 mayúscula y 1 número',
                prefixIcon:
                    Icon(Icons.lock_outline, color: context.colorTextMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: context.colorTextMuted,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa una contraseña';
                if (v.length < 8) return 'Mínimo 8 caracteres';
                if (!RegExp(r'[A-Z]').hasMatch(v)) {
                  return 'Debe tener al menos una mayúscula';
                }
                if (!RegExp(r'[0-9]').hasMatch(v)) {
                  return 'Debe tener al menos un número';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Confirmar contraseña ─────────────────────────────────────────
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscureConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: TextStyle(color: context.colorTextPrimary),
              decoration: InputDecoration(
                labelText: 'Confirmar contraseña',
                hintText: '••••••••',
                prefixIcon:
                    Icon(Icons.lock_outline, color: context.colorTextMuted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: context.colorTextMuted,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Confirma tu contraseña';
                if (v != _passwordCtrl.text) return 'Las contraseñas no coinciden';
                return null;
              },
            ),

            // ── Error ────────────────────────────────────────────────────────
            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.accentSecondary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.accentSecondary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.accentSecondary, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                            color: AppColors.accentSecondary, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Botón registrar ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enviar código de verificación'),
              ),
            ),
            const SizedBox(height: 12),

            // ── Botón cancelar ───────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.colorTextSecondary,
                  side: BorderSide(color: context.colorBorder),
                ),
                onPressed: () => context.pop(),
                child: const Text('Cancelar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          '¿Ya tienes cuenta? ',
          style: TextStyle(color: context.colorTextSecondary, fontSize: 14),
        ),
        GestureDetector(
          onTap: () => context.go('/login'),
          child: const Text(
            'Inicia sesión',
            style: TextStyle(
              color: AppColors.accentPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
