import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/weight_utils.dart';
import '../../../features/profile/data/user_preferences_service.dart';
import '../../../features/profile/providers/weight_unit_notifier.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/default_routine_provider.dart';
import '../../../shared/services/auth_service.dart';
import '../../../shared/services/notifications_service.dart';
import '../../../features/routines/data/routines_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _monthWorkouts = 0;
  int _currentStreak = 0;
  bool _statsLoaded = false;
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _loadStats();
    _loadUnread();
  }

  Future<void> _loadStats() async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/v1/users/me/stats'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body)['data'] as Map<String, dynamic>?;
        if (data != null) {
          setState(() {
            _monthWorkouts = data['monthWorkouts'] as int? ?? 0;
            _currentStreak = data['currentStreak'] as int? ?? 0;
            _statsLoaded = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadUnread() async {
    try {
      final count = await NotificationsService().unreadCount();
      if (mounted) setState(() => _unreadCount = count);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final auth = context.read<AuthProvider>();
    final role = user?['role'] as String? ?? 'student';
    final isAdmin = role == 'admin';
    final isProfessor = role == 'professor';

    final firstName = _firstName(user?['name'] as String?);
    final now = DateTime.now();
    final dayName = _dayName(now.weekday);
    final dateStr = _formatDate(now);

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              firstName: firstName,
              dayName: dayName,
              dateStr: dateStr,
              monthWorkouts: _statsLoaded ? _monthWorkouts.toString() : '—',
              currentStreak: _statsLoaded ? _currentStreak.toString() : '—',
              unreadCount: _unreadCount,
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _QuickActions(isAdmin: isAdmin, isProfessor: isProfessor),
                const SizedBox(height: 28),
                _TodaySession(),
                const SizedBox(height: 28),
                const _PersonalRecords(),
                const SizedBox(height: 28),
                _NextEvent(),
                const SizedBox(height: 28),
                _DiscoverMore(isAdmin: isAdmin),
                const SizedBox(height: 28),
                _LogoutTile(onLogout: () => auth.logout()),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  String _firstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'Estudiante';
    return fullName.split(' ').first;
  }

  String _dayName(int weekday) {
    const names = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    return names[weekday - 1];
  }

  String _formatDate(DateTime dt) {
    const months = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    return '${dt.day} de ${months[dt.month - 1]}';
  }
}

// ── Header con gradiente ──────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.firstName,
    required this.dayName,
    required this.dateStr,
    required this.monthWorkouts,
    required this.currentStreak,
    required this.unreadCount,
  });

  final String firstName;
  final String dayName;
  final String dateStr;
  final String monthWorkouts;
  final String currentStreak;
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF3D3899), Color(0xFF6C63FF), Color(0xFF8A84FF)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$dayName, $dateStr',
                          style: const TextStyle(
                            color: Color(0xFFD0CDFF),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '¡Hola, $firstName!',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Bienvenido al Gimnasio UBB',
                          style: TextStyle(color: Color(0xFFD0CDFF), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push('/notifications'),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: const Icon(Icons.notifications_outlined,
                              color: Colors.white, size: 20),
                        ),
                        if (unreadCount > 0)
                          Positioned(
                            top: -2,
                            right: -2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: AppColors.accentSecondary,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                              child: Text(
                                unreadCount > 99 ? '99+' : '$unreadCount',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _StatCard(icon: Icons.calendar_month_outlined, label: 'Este mes', value: monthWorkouts, unit: 'entrenamientos')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(icon: Icons.local_fire_department_outlined, label: 'Racha actual', value: currentStreak, unit: 'días seguidos 🔥', iconColor: const Color(0xFFFFB347))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    this.iconColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor ?? const Color(0xFFD0CDFF)),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Color(0xFFD0CDFF), fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
          Text(unit, style: const TextStyle(color: Color(0xFFD0CDFF), fontSize: 11)),
        ],
      ),
    );
  }
}

// ── Acciones rápidas ──────────────────────────────────────────────────────────

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.isAdmin, required this.isProfessor});

  final bool isAdmin;
  final bool isProfessor;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.fitness_center, label: 'Ejercicios', color: const Color(0xFF6C63FF), route: '/exercises'),
      _QuickAction(icon: Icons.emoji_events_outlined, label: 'Rankings', color: const Color(0xFFFFB347), route: '/rankings'),
      _QuickAction(icon: Icons.menu_book_outlined, label: 'Educación', color: const Color(0xFF8B5CF6), route: '/education'),
      _QuickAction(icon: Icons.calendar_today_outlined, label: 'Eventos', color: const Color(0xFFFFB347), route: '/events'),
      if (isAdmin) ...[
        _QuickAction(icon: Icons.manage_accounts, label: 'Usuarios', color: const Color(0xFFFF6B6B), route: '/admin/users'),
        _QuickAction(icon: Icons.school_outlined, label: 'Carreras', color: const Color(0xFF4ECDC4), route: '/admin/careers'),
      ],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Acceso rápido'),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemCount: actions.length,
          itemBuilder: (context, i) => _QuickActionTile(action: actions[i]),
        ),
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({required this.icon, required this.label, required this.color, required this.route});
  final IconData icon;
  final String label;
  final Color color;
  final String? route;
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});
  final _QuickAction action;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (action.route != null) {
          context.go(action.route!);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${action.label} — próximamente'),
              backgroundColor: AppColors.bgTertiary,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: action.color.withAlpha(30),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: action.color.withAlpha(60)),
            ),
            child: Icon(action.icon, color: action.color, size: 24),
          ),
          SizedBox(height: 6),
          Text(
            action.label,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.colorTextSecondary, fontSize: 11, fontWeight: FontWeight.w500),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ── Sesión de hoy ─────────────────────────────────────────────────────────────

class _TodaySession extends StatefulWidget {
  const _TodaySession();

  @override
  State<_TodaySession> createState() => _TodaySessionState();
}

class _TodaySessionState extends State<_TodaySession> {
  final _service = RoutinesService();
  Map<String, dynamic>? _routine;
  Map<String, dynamic>? _todayDay;
  bool _loading = true;

  static const _dayNames7 = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final routine = await _service.getMyDefault();
      if (!mounted) return;
      Map<String, dynamic>? todayDay;
      if (routine != null) {
        final todayName = _dayNames7[DateTime.now().weekday - 1];
        final days = (routine['days'] as List? ?? []).cast<Map<String, dynamic>>();
        todayDay = days.where((d) => d['dayName'] == todayName).firstOrNull;
        todayDay ??= days.isNotEmpty ? days.first : null;
        // Sync provider
        if (mounted) {
          context.read<DefaultRoutineProvider>().setDefault(
            routine['id'] as String,
            routine['name'] as String? ?? '',
          );
        }
      }
      setState(() { _routine = routine; _todayDay = todayDay; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel('Sesión de hoy'),
            if (_routine != null)
              GestureDetector(
                onTap: () => context.push('/routines/${_routine!['id']}'),
                child: const Row(
                  children: [
                    Text('Ver rutina', style: TextStyle(color: AppColors.accentPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                    SizedBox(width: 2),
                    Icon(Icons.chevron_right, color: AppColors.accentPrimary, size: 16),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const SizedBox(
            height: 72,
            child: Center(child: CircularProgressIndicator(color: AppColors.accentPrimary, strokeWidth: 2)),
          )
        else if (_routine == null)
          _NoRoutineCard()
        else
          _RoutineDayCard(routine: _routine!, day: _todayDay),
      ],
    );
  }
}

class _NoRoutineCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorBgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.colorBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.accentPrimary.withAlpha(25),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.fitness_center, color: AppColors.accentPrimary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sin rutina predeterminada',
                        style: TextStyle(color: context.colorTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text('Asigna una rutina desde la sección Rutinas',
                        style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.go('/routines'),
            icon: const Icon(Icons.fitness_center, size: 18),
            label: const Text('Ir a Rutinas'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoutineDayCard extends StatelessWidget {
  const _RoutineDayCard({required this.routine, required this.day});
  final Map<String, dynamic> routine;
  final Map<String, dynamic>? day;

  @override
  Widget build(BuildContext context) {
    final exercises = (day?['exercises'] as List? ?? []).cast<Map<String, dynamic>>();
    final dayLabel = day?['label'] as String? ?? day?['dayName'] as String? ?? 'Hoy';
    final routineName = routine['name'] as String? ?? '';

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.colorBgSecondary,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accentPrimary.withAlpha(60)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withAlpha(25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.fitness_center, color: AppColors.accentPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(routineName,
                            style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
                        Text(dayLabel,
                            style: TextStyle(color: context.colorTextPrimary,
                                fontSize: 15, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${exercises.length} ejercicios',
                        style: const TextStyle(color: AppColors.accentPrimary,
                            fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
              if (exercises.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...exercises.take(3).map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 5, color: AppColors.textMuted),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          e['exerciseName'] as String? ?? '',
                          style: TextStyle(color: context.colorTextSecondary, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text('${e['sets']}×${e['reps']}',
                          style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
                    ],
                  ),
                )),
                if (exercises.length > 3)
                  Text('+ ${exercises.length - 3} más',
                      style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () => context.push('/workout/session', extra: {
              'routineId': routine['id'],
              'routineDayId': day?['id'],
              'routineName': routine['name'],
              'dayLabel': dayLabel,
            }),
            icon: const Icon(Icons.play_arrow_rounded, size: 20),
            label: const Text('Iniciar entrenamiento'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Marcas personales ─────────────────────────────────────────────────────────

class _PersonalRecords extends StatefulWidget {
  const _PersonalRecords();

  @override
  State<_PersonalRecords> createState() => _PersonalRecordsState();
}

class _PersonalRecordsState extends State<_PersonalRecords> {
  List<Map<String, dynamic>> _allRecords = [];
  List<String> _pinnedIds = [];
  bool _loading = true;
  final _prefs = UserPreferencesService();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null) return;
      final results = await Future.wait([
        http.get(Uri.parse('${ApiConstants.baseUrl}/api/v1/history/records'),
            headers: {'Authorization': 'Bearer $token'}),
        _prefs.getPinnedExerciseIds(),
      ]);
      final res = results[0] as http.Response;
      final pinned = results[1] as List<String>;
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body)['data'] as Map<String, dynamic>?;
        final list = (data?['records'] as List? ?? []).cast<Map<String, dynamic>>();
        setState(() {
          _allRecords = list;
          _pinnedIds = pinned;
          _loading = false;
        });
      } else if (mounted) {
        setState(() { _pinnedIds = pinned; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Devuelve hasta 4 registros: primero los fijados, luego rellena con otros (1 por ejercicio).
  List<Map<String, dynamic>> _buildDisplayRecords() {
    final byId = <String, Map<String, dynamic>>{};
    for (final r in _allRecords) {
      final id = r['exerciseId'] as String? ?? '';
      if (id.isNotEmpty) byId.putIfAbsent(id, () => r);
    }

    final result = <Map<String, dynamic>>[];
    for (final id in _pinnedIds) {
      if (byId.containsKey(id)) result.add(byId[id]!);
    }
    if (result.length < 4) {
      for (final r in byId.values) {
        if (result.length >= 4) break;
        if (!_pinnedIds.contains(r['exerciseId'])) result.add(r);
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<WeightUnitNotifier>().unit;
    final unitLabel = unit == WeightUnit.lbs ? 'lbs' : 'kg';
    final records = _buildDisplayRecords();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel('Mis marcas'),
            GestureDetector(
              onTap: () => context.go('/history'),
              child: const Row(
                children: [
                  Text('Ver progreso', style: TextStyle(color: AppColors.accentPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: AppColors.accentPrimary, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const SizedBox(
            height: 60,
            child: Center(child: CircularProgressIndicator(color: AppColors.accentPrimary, strokeWidth: 2)),
          )
        else if (records.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorBorder),
            ),
            child: Center(
              child: Text(
                'Aún no tienes marcas. ¡Registra tu primer entrenamiento!',
                style: TextStyle(color: context.colorTextSecondary, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.4,
            ),
            itemCount: records.length,
            itemBuilder: (context, i) {
              final rec = records[i];
              final name = rec['exerciseName'] as String? ?? '—';
              final rawKg = (rec['weightKg'] as num?)?.toDouble();
              final weightStr = rawKg != null
                  ? '${toDisplayUnit(rawKg, unit).toStringAsFixed(1)} $unitLabel'
                  : '— $unitLabel';
              return _RecordCard(label: name, weight: weightStr);
            },
          ),
      ],
    );
  }
}

class _RecordCard extends StatelessWidget {
  const _RecordCard({required this.label, required this.weight});
  final String label;
  final String weight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, style: TextStyle(color: context.colorTextSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
          SizedBox(height: 2),
          Text(weight, style: TextStyle(color: context.colorTextPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Próximo evento ─────────────────────────────────────────────────────────────

class _NextEvent extends StatefulWidget {
  const _NextEvent();

  @override
  State<_NextEvent> createState() => _NextEventState();
}

class _NextEventState extends State<_NextEvent> {
  Map<String, dynamic>? _event;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final token = await AuthService().getAccessToken();
      if (token == null) return;
      final res = await http.get(
        Uri.parse(
          '${ApiConstants.baseUrl}/api/v1/events/list?upcoming=true&limit=1',
        ),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode == 200 && mounted) {
        final data = jsonDecode(res.body)['data'] as Map<String, dynamic>?;
        final events = (data?['events'] as List?)?.cast<Map<String, dynamic>>();
        setState(() {
          _event = events?.isNotEmpty == true ? events!.first : null;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  String _formatDate(String? dateStr, String? timeStr) {
    if (dateStr == null) return '';
    try {
      final d = DateTime.parse(dateStr);
      const months = [
        '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
        'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
      ];
      final time = timeStr != null ? ' · ${timeStr.substring(0, 5)}' : '';
      return '${d.day} ${months[d.month]}$time';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionLabel('Próximo evento'),
            GestureDetector(
              onTap: () => context.go('/events'),
              child: const Row(
                children: [
                  Text('Ver todos', style: TextStyle(color: AppColors.accentPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right, color: AppColors.accentPrimary, size: 16),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _event != null ? () => context.push('/events/${_event!['id']}') : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB347), Color(0xFFFF8C42)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_rounded, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: !_loaded
                      ? const Text('Cargando...', style: TextStyle(color: Color(0xFFFFE8C0), fontSize: 13))
                      : _event == null
                          ? const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('EVENTO', style: TextStyle(color: Color(0xFFFFE8C0), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
                                SizedBox(height: 2),
                                Text('Sin eventos próximos', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (_event!['type'] as String? ?? 'EVENTO').toUpperCase(),
                                  style: const TextStyle(color: Color(0xFFFFE8C0), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 0.8),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _event!['title'] as String? ?? '',
                                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _formatDate(_event!['eventDate'] as String?, _event!['eventTime'] as String?),
                                  style: const TextStyle(color: Color(0xFFFFE8C0), fontSize: 12),
                                ),
                              ],
                            ),
                ),
                if (_event != null)
                  const Icon(Icons.chevron_right, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Descubre más ──────────────────────────────────────────────────────────────

class _DiscoverMore extends StatelessWidget {
  const _DiscoverMore({required this.isAdmin});
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final items = [
      _DiscoverItem(icon: Icons.menu_book_outlined, label: 'Educación y salud', sub: 'Artículos y consejos', color: const Color(0xFF8B5CF6), route: '/education'),
      _DiscoverItem(icon: Icons.calendar_today_outlined, label: 'Eventos UBB', sub: 'Competencias y talleres', color: const Color(0xFFFFB347), route: '/events'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionLabel('Descubre más'),
        const SizedBox(height: 12),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _DiscoverTile(item: item),
        )),
      ],
    );
  }
}

class _DiscoverItem {
  const _DiscoverItem({required this.icon, required this.label, required this.sub, required this.color, required this.route});
  final IconData icon;
  final String label;
  final String sub;
  final Color color;
  final String? route;
}

class _DiscoverTile extends StatelessWidget {
  const _DiscoverTile({required this.item});
  final _DiscoverItem item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (item.route != null) {
          context.go(item.route!);
        } else {
          _showComingSoon(context, item.label);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: context.colorBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.color.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item.icon, color: item.color, size: 20),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: TextStyle(color: context.colorTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  SizedBox(height: 1),
                  Text(item.sub, style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: context.colorTextMuted, size: 20),
          ],
        ),
      ),
    );
  }
}

// ── Logout ────────────────────────────────────────────────────────────────────

class _LogoutTile extends StatelessWidget {
  const _LogoutTile({required this.onLogout});
  final VoidCallback onLogout;

  Future<void> _confirmLogout(BuildContext context) async {
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
    if (confirmed == true) onLogout();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _confirmLogout(context),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.accentSecondary.withAlpha(60)),
        ),
        child: const Row(
          children: [
            Icon(Icons.logout_rounded, color: AppColors.accentSecondary, size: 20),
            SizedBox(width: 12),
            Text('Cerrar sesión', style: TextStyle(color: AppColors.accentSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        color: context.colorTextSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

void _showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$feature — próximamente'),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ),
  );
}
