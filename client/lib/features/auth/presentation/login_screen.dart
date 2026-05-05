import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _storage = FlutterSecureStorage();
  static const _keySavedEmail = 'saved_email';
  static const _keySavedPassword = 'saved_password';

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _credentialsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final email = await _storage.read(key: _keySavedEmail);
    final password = await _storage.read(key: _keySavedPassword);
    if (email != null && password != null) {
      setState(() {
        _emailCtrl.text = email;
        _passwordCtrl.text = password;
        _rememberMe = true;
        _credentialsLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    final ok = await auth.login(email: email, password: password);
    if (!ok || !mounted) return;

    if (_rememberMe) {
      await _storage.write(key: _keySavedEmail, value: email);
      await _storage.write(key: _keySavedPassword, value: password);
    } else {
      await _storage.delete(key: _keySavedEmail);
      await _storage.delete(key: _keySavedPassword);
    }

    if (!_rememberMe && !_credentialsLoaded && mounted) {
      final save = await _showSaveCredentialsDialog();
      if (save == true && mounted) {
        await _storage.write(key: _keySavedEmail, value: email);
        await _storage.write(key: _keySavedPassword, value: password);
      }
    }

    if (mounted) context.go('/home');
  }

  Future<bool?> _showSaveCredentialsDialog() {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Guardar datos de acceso?'),
        content: const Text('La próxima vez podrás iniciar sesión más rápido.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('No, gracias',
                style: TextStyle(color: context.colorTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, guardar'),
          ),
        ],
      ),
    );
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
                        Text(
                          'Solo para miembros de la comunidad UBB',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        _buildRegisterLink(),
                        const SizedBox(height: 40),
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
            'Bienvenido',
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Inicia sesión con tu correo institucional UBB',
            style: TextStyle(
              color: Color(0xFF6060A0),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterLink() {
    return Container(
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '¿No tienes cuenta? ',
            style: TextStyle(color: context.colorTextSecondary, fontSize: 14),
          ),
          GestureDetector(
            onTap: () => context.push('/register'),
            child: const Text(
              'Regístrate aquí',
              style: TextStyle(
                color: AppColors.accentPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
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
            Text('Iniciar sesión',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Usa tu correo institucional UBB',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),

            // ── Email ──────────────────────────────────────────────────────
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

            // ── Contraseña ────────────────────────────────────────────────
            TextFormField(
              controller: _passwordCtrl,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: TextStyle(color: context.colorTextPrimary),
              decoration: InputDecoration(
                labelText: 'Contraseña',
                hintText: '••••••••',
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
                if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                if (v.length < 6) return 'Mínimo 6 caracteres';
                return null;
              },
            ),

            const SizedBox(height: 8),

            // ── Recordar mis datos ────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _rememberMe,
                    onChanged: (v) => setState(() => _rememberMe = v ?? false),
                    activeColor: AppColors.accentPrimary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Text('Recordar mis datos',
                      style: TextStyle(
                          color: context.colorTextSecondary, fontSize: 13)),
                ),
              ],
            ),

            // ── Error del servidor ────────────────────────────────────────
            Consumer<AuthProvider>(
              builder: (context, auth, _) {
                if (auth.error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
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
                          child: Text(auth.error!,
                              style: const TextStyle(
                                  color: AppColors.accentSecondary,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Botón ingresar ────────────────────────────────────────────
            Consumer<AuthProvider>(
              builder: (context, auth, _) => SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.loading ? null : _submit,
                  child: auth.loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Ingresar'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
