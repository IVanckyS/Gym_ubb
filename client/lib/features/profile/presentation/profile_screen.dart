import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/auth_service.dart';
import '../data/user_preferences_service.dart';
import '../providers/theme_notifier.dart';
import '../providers/weight_unit_notifier.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _authService = AuthService();
  final _prefsService = UserPreferencesService();

  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _records = [];
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    try {
      final token = await _authService.getAccessToken();
      if (token == null) return;

      final statsRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/stats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final recordsRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/history/records'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;
      setState(() {
        if (statsRes.statusCode == 200) {
          _stats = (jsonDecode(statsRes.body)['data'] as Map<String, dynamic>?) ?? {};
        }
        if (recordsRes.statusCode == 200) {
          final data = jsonDecode(recordsRes.body)['data'];
          _records = (data['records'] as List? ?? []).cast<Map<String, dynamic>>();
        }
        _loadingStats = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentSecondary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<AuthProvider>().logout();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user ?? {};
    final name = user['name'] as String? ?? '';
    final email = user['email'] as String? ?? '';
    final career = user['career'] as String? ?? '';
    final role = user['role'] as String? ?? 'student';
    final memberSince = _parseMemberSince(user['memberSince'] as String?);

    final initials = _initials(name);

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: CustomScrollView(
        slivers: [
          _buildHeader(initials, name, email, career, role, memberSince),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildStatsRow(),
                const SizedBox(height: 24),
                _buildPersonalRecords(),
                const SizedBox(height: 24),
                _buildPersonalData(user),
                const SizedBox(height: 24),
                _buildSettings(),
                const SizedBox(height: 24),
                _buildLogoutButton(),
                const SizedBox(height: 24),
                _buildFooter(),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Header con gradiente ────────────────────────────────────────────────────

  Widget _buildHeader(
    String initials,
    String name,
    String email,
    String career,
    String role,
    String memberSince,
  ) {
    return SliverToBoxAdapter(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.accentPrimary.withValues(alpha: 0.3),
              context.colorBgSecondary,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                // Avatar
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentPrimary,
                        AppColors.accentPrimary.withValues(alpha: 0.6),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentPrimary.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  name,
                  style: TextStyle(
                    color: context.colorTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
                ),
                if (career.isNotEmpty) ...[
                  SizedBox(height: 2),
                  Text(
                    career,
                    style: TextStyle(color: context.colorTextMuted, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _Chip(label: _roleLabel(role), color: AppColors.accentPrimary),
                    const SizedBox(width: 8),
                    _Chip(label: 'Miembro desde $memberSince', color: AppColors.accentGreen),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Stats rápidas ──────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    if (_loadingStats) {
      return const Center(
        child: SizedBox(
          height: 80,
          child: CircularProgressIndicator(color: AppColors.accentPrimary, strokeWidth: 2),
        ),
      );
    }
    final totalWorkouts = _stats?['totalWorkouts'] as int? ?? 0;
    final totalRecords = _stats?['totalRecords'] as int? ?? 0;
    final streak = _stats?['currentStreak'] as int? ?? 0;

    return Row(
      children: [
        Expanded(child: _StatCard(value: totalWorkouts.toString(), label: 'Entrenamientos')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: totalRecords.toString(), label: 'Récords')),
        const SizedBox(width: 10),
        Expanded(child: _StatCard(value: '$streak días', label: 'Racha actual')),
      ],
    );
  }

  // ── Mejores marcas ─────────────────────────────────────────────────────────

  Widget _buildPersonalRecords() {
    // Deduplicar: un récord por ejercicio (el de mayor peso)
    final seen = <String>{};
    final highlights = <Map<String, dynamic>>[];
    for (final r in _records) {
      final name = r['exerciseName'] as String? ?? '';
      if (seen.add(name)) highlights.add(r);
      if (highlights.length == 4) break;
    }
    if (highlights.isEmpty) return const SizedBox.shrink();

    final unit = context.watch<WeightUnitNotifier>().unit;
    return _Section(
      title: 'Mejores marcas',
      child: Column(
        children: highlights.map((rec) {
          final exerciseName = rec['exerciseName'] as String? ?? '';
          final rawKg = (rec['weightKg'] as num?)?.toDouble();
          final reps = (rec['reps'] as num?)?.toInt() ?? 0;
          final weight = rawKg != null ? _formatWeight(rawKg, unit) : '—';
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, color: Color(0xFFFFD700), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    exerciseName,
                    style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$weight × $reps reps',
                  style: const TextStyle(
                    color: AppColors.accentPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Datos personales ───────────────────────────────────────────────────────

  Widget _buildPersonalData(Map<String, dynamic> user) {
    return _Section(
      title: 'Datos personales',
      trailing: TextButton.icon(
        onPressed: () => _showEditProfile(user),
        icon: const Icon(Icons.edit_outlined, size: 16),
        label: const Text('Editar'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.accentPrimary,
          textStyle: const TextStyle(fontSize: 13),
        ),
      ),
      child: Column(
        children: [
          _DataRow(label: 'Nombre', value: user['name'] as String? ?? '—'),
          _DataRow(label: 'Email', value: user['email'] as String? ?? '—'),
          _DataRow(label: 'Carrera', value: (user['career'] as String?)?.isNotEmpty == true ? user['career'] as String : '—'),
          _DataRow(label: 'Peso', value: _displayWeight(user['weightKg'])),
          _DataRow(label: 'Altura', value: user['heightCm'] != null ? '${user['heightCm']} cm' : '—'),
        ],
      ),
    );
  }

  // ── Configuración ──────────────────────────────────────────────────────────

  Widget _buildSettings() {
    final themeNotifier = context.watch<ThemeNotifier>();
    final weightNotifier = context.watch<WeightUnitNotifier>();

    return _Section(
      title: 'Configuración',
      child: Column(
        children: [
          // Tema
          _SettingsRow(
            icon: Icons.dark_mode_outlined,
            label: 'Tema',
            trailing: SegmentedButton<ThemeMode>(
              style: SegmentedButton.styleFrom(
                backgroundColor: context.colorBgTertiary,
                selectedBackgroundColor: AppColors.accentPrimary.withValues(alpha: 0.2),
                selectedForegroundColor: AppColors.accentPrimary,
                foregroundColor: context.colorTextSecondary,
                side: BorderSide(color: context.colorBorder),
                textStyle: const TextStyle(fontSize: 12),
              ),
              segments: const [
                ButtonSegment(value: ThemeMode.dark, label: Text('Oscuro')),
                ButtonSegment(value: ThemeMode.light, label: Text('Claro')),
              ],
              selected: {themeNotifier.mode},
              onSelectionChanged: (s) => themeNotifier.setTheme(s.first),
            ),
          ),
          SizedBox(height: 12),

          // Unidades
          _SettingsRow(
            icon: Icons.fitness_center_outlined,
            label: 'Unidades',
            trailing: SegmentedButton<WeightUnit>(
              style: SegmentedButton.styleFrom(
                backgroundColor: context.colorBgTertiary,
                selectedBackgroundColor: AppColors.accentPrimary.withValues(alpha: 0.2),
                selectedForegroundColor: AppColors.accentPrimary,
                foregroundColor: context.colorTextSecondary,
                side: BorderSide(color: context.colorBorder),
                textStyle: const TextStyle(fontSize: 12),
              ),
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ButtonSegment(value: WeightUnit.lbs, label: Text('lbs')),
              ],
              selected: {weightNotifier.unit},
              onSelectionChanged: (s) async {
                await weightNotifier.setUnit(s.first);
                await _prefsService.savePreferences(
                  units: s.first == WeightUnit.lbs ? 'lbs' : 'kg',
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // Notificaciones
          _NotificationsToggle(prefsService: _prefsService),
          const SizedBox(height: 12),

          // Perfil privado
          _PrivateProfileToggle(prefsService: _prefsService),
          const SizedBox(height: 12),

          // Marcas en inicio
          _SettingsRow(
            icon: Icons.push_pin_outlined,
            label: 'Marcas en inicio',
            trailing: TextButton(
              onPressed: () => _showPinnedExercisesPicker(),
              child: const Text('Configurar',
                  style: TextStyle(color: AppColors.accentPrimary, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showPinnedExercisesPicker() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorBgSecondary,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _PinnedExercisesSheet(
        allRecords: _records,
        prefsService: _prefsService,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Cerrar sesión'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.accentSecondary,
          side: BorderSide(color: AppColors.accentSecondary.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'GymUBB v1.0.0 · Universidad del Bío-Bío',
        style: TextStyle(color: context.colorTextMuted, fontSize: 11),
      ),
    );
  }

  // ── Edit Profile BottomSheet ──────────────────────────────────────────────

  Future<void> _showEditProfile(Map<String, dynamic> user) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _EditProfileSheet(user: user),
    );
    if (result == true) {
      // Recargar datos del usuario
      if (mounted) await context.read<AuthProvider>().init();
      if (mounted) _loadStats();
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  String _parseMemberSince(String? raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }

  String _roleLabel(String role) => switch (role) {
    'admin' => 'Admin',
    'professor' => 'Profesor',
    'staff' => 'Staff',
    _ => 'Estudiante',
  };

  String _displayWeight(dynamic rawKg) {
    if (rawKg == null) return '—';
    final unit = context.read<WeightUnitNotifier>().unit;
    return _formatWeight((rawKg as num).toDouble(), unit);
  }

  String _formatWeight(double kg, WeightUnit unit) {
    if (unit == WeightUnit.lbs) {
      return '${(kg * 2.20462).toStringAsFixed(1)} lbs';
    }
    return '${kg.toStringAsFixed(1)} kg';
  }
}

// ── Edit Profile BottomSheet ────────────────────────────────────────────────

class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({required this.user});
  final Map<String, dynamic> user;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _careerCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user['name'] as String? ?? '');
    _careerCtrl = TextEditingController(text: widget.user['career'] as String? ?? '');
    _weightCtrl = TextEditingController(
      text: widget.user['weightKg'] != null ? widget.user['weightKg'].toString() : '',
    );
    _heightCtrl = TextEditingController(
      text: widget.user['heightCm'] != null ? widget.user['heightCm'].toString() : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _careerCtrl.dispose();
    _weightCtrl.dispose();
    _heightCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });

    try {
      final authService = AuthService();
      final token = await authService.getAccessToken();
      if (token == null) throw Exception('No autenticado');

      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'career': _careerCtrl.text.trim().isEmpty ? null : _careerCtrl.text.trim(),
      };
      if (_weightCtrl.text.trim().isNotEmpty) {
        body['weightKg'] = double.tryParse(_weightCtrl.text.trim());
      }
      if (_heightCtrl.text.trim().isNotEmpty) {
        body['heightCm'] = int.tryParse(_heightCtrl.text.trim());
      }

      final res = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(body),
      );

      if (res.statusCode != 200) {
        final msg = jsonDecode(res.body)['error']?['message'] as String?;
        throw Exception(msg ?? 'Error al guardar');
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Editar perfil',
                  style: TextStyle(
                    color: context.colorTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: context.colorTextSecondary),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.accentSecondary.withValues(alpha: 0.3)),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.accentSecondary, fontSize: 13),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _careerCtrl,
              decoration: const InputDecoration(labelText: 'Carrera (opcional)'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightCtrl,
                    decoration: const InputDecoration(labelText: 'Peso (kg)'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (double.tryParse(v) == null) return 'Número inválido';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _heightCtrl,
                    decoration: const InputDecoration(labelText: 'Altura (cm)'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      if (int.tryParse(v) == null) return 'Número inválido';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Guardar cambios', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Notifications Toggle ──────────────────────────────────────────────────────

class _NotificationsToggle extends StatefulWidget {
  const _NotificationsToggle({required this.prefsService});
  final UserPreferencesService prefsService;

  @override
  State<_NotificationsToggle> createState() => _NotificationsToggleState();
}

class _NotificationsToggleState extends State<_NotificationsToggle> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final status = await Permission.notification.status;
    if (mounted) setState(() => _enabled = status.isGranted);
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      final status = await Permission.notification.request();
      if (!status.isGranted && mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permiso denegado'),
            content: const Text(
              'Ve a Ajustes del dispositivo para activar las notificaciones.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.accentPrimary),
                onPressed: () {
                  Navigator.pop(ctx);
                  openAppSettings();
                },
                child: const Text('Ir a Ajustes'),
              ),
            ],
          ),
        );
        return;
      }
      setState(() => _enabled = status.isGranted);
      await widget.prefsService.savePreferences(notificationsEnabled: status.isGranted);
    } else {
      setState(() => _enabled = false);
      await widget.prefsService.savePreferences(notificationsEnabled: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      icon: Icons.notifications_outlined,
      label: 'Notificaciones',
      trailing: Switch(
        value: _enabled,
        onChanged: _toggle,
        activeThumbColor: AppColors.accentPrimary,
      ),
    );
  }
}

// ── Private Profile Toggle ────────────────────────────────────────────────────

class _PrivateProfileToggle extends StatefulWidget {
  const _PrivateProfileToggle({required this.prefsService});
  final UserPreferencesService prefsService;

  @override
  State<_PrivateProfileToggle> createState() => _PrivateProfileToggleState();
}

class _PrivateProfileToggleState extends State<_PrivateProfileToggle> {
  bool _private = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final authService = AuthService();
    final token = await authService.getAccessToken();
    if (token == null || !mounted) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body)['data'] as Map<String, dynamic>?;
        final user = data?['user'] as Map<String, dynamic>?;
        setState(() => _private = user?['privateProfile'] as bool? ?? false);
      }
    } catch (_) {}
  }

  Future<void> _toggle(bool value) async {
    setState(() => _private = value);
    await widget.prefsService.savePreferences(privateProfile: value);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsRow(
      icon: Icons.visibility_off_outlined,
      label: 'Perfil privado en rankings',
      trailing: Switch(
        value: _private,
        onChanged: _toggle,
        activeThumbColor: AppColors.accentPrimary,
      ),
    );
  }
}

// ── Reusable widgets ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: context.colorTextPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (trailing != null) ...[const Spacer(), trailing!],
            ],
          ),
          SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppColors.accentPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colorTextMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  const _DataRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: context.colorTextMuted, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.icon, required this.label, required this.trailing});
  final IconData icon;
  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: context.colorTextSecondary, size: 20),
        SizedBox(width: 12),
        Text(label, style: TextStyle(color: context.colorTextSecondary, fontSize: 14)),
        const Spacer(),
        trailing,
      ],
    );
  }
}

// ── Pinned exercises picker ───────────────────────────────────────────────────

class _PinnedExercisesSheet extends StatefulWidget {
  const _PinnedExercisesSheet({
    required this.allRecords,
    required this.prefsService,
  });
  final List<Map<String, dynamic>> allRecords;
  final UserPreferencesService prefsService;

  @override
  State<_PinnedExercisesSheet> createState() => _PinnedExercisesSheetState();
}

class _PinnedExercisesSheetState extends State<_PinnedExercisesSheet> {
  // Ejercicios únicos del historial (deduplicados por id)
  late List<Map<String, dynamic>> _options;
  // 4 slots: null = sin seleccionar
  late List<Map<String, dynamic>?> _slots;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Deduplicar por exerciseId
    final seen = <String>{};
    _options = [];
    for (final r in widget.allRecords) {
      final id = r['exerciseId'] as String? ?? '';
      if (id.isNotEmpty && seen.add(id)) _options.add(r);
    }
    _slots = List.filled(4, null);
    _loadPinned();
  }

  Future<void> _loadPinned() async {
    final ids = await widget.prefsService.getPinnedExerciseIds();
    if (!mounted) return;
    setState(() {
      for (int i = 0; i < 4; i++) {
        if (i < ids.length) {
          _slots[i] = _options.where((o) => o['exerciseId'] == ids[i]).firstOrNull;
        }
      }
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final ids = _slots
        .whereType<Map<String, dynamic>>()
        .map((s) => s['exerciseId'] as String)
        .toList();
    await widget.prefsService.setPinnedExerciseIds(ids);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Marcas en inicio',
                style: TextStyle(
                    color: context.colorTextPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 17)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Icon(Icons.close, color: context.colorTextSecondary),
            ),
          ]),
          Text('Elige hasta 4 ejercicios para mostrar en la pantalla de inicio.',
              style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
          const SizedBox(height: 16),
          if (_options.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Sin entrenamientos registrados aún.',
                  style: TextStyle(color: context.colorTextSecondary)),
            )
          else
            ...List.generate(4, (i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('${i + 1}',
                        style: const TextStyle(
                            color: AppColors.accentPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: context.colorBgTertiary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: context.colorBorder),
                    ),
                    child: DropdownButton<Map<String, dynamic>>(
                      value: _slots[i],
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      dropdownColor: context.colorBgSecondary,
                      hint: Text('Sin seleccionar',
                          style: TextStyle(color: context.colorTextMuted, fontSize: 13)),
                      style: TextStyle(color: context.colorTextPrimary, fontSize: 13),
                      icon: Icon(Icons.expand_more, color: context.colorTextMuted, size: 18),
                      items: [
                        DropdownMenuItem<Map<String, dynamic>>(
                          value: null,
                          child: Text('— Sin seleccionar',
                              style: TextStyle(color: context.colorTextMuted, fontSize: 13)),
                        ),
                        ..._options.map((o) => DropdownMenuItem(
                          value: o,
                          child: Text(o['exerciseName'] as String? ?? '',
                              overflow: TextOverflow.ellipsis),
                        )),
                      ],
                      onChanged: (v) => setState(() => _slots[i] = v),
                    ),
                  ),
                ),
              ]),
            )),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
