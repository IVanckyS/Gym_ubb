import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/section_banner.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/providers/default_routine_provider.dart';
import '../data/routines_service.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen>
    with SingleTickerProviderStateMixin {
  final _service = RoutinesService();
  late final TabController _tabs;

  List<Map<String, dynamic>> _myRoutines = [];
  List<Map<String, dynamic>> _publicRoutines = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await _service.listRoutines();
      setState(() {
        _myRoutines = (data['myRoutines'] as List? ?? []).cast<Map<String, dynamic>>();
        _publicRoutines = (data['publicRoutines'] as List? ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _service.deleteRoutine(id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.accentSecondary),
        );
      }
    }
  }

  Future<void> _setDefault(String id, String name) async {
    final provider = context.read<DefaultRoutineProvider>();
    try {
      await _service.setDefault(id);
      await provider.setDefault(id, name);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«$name» establecida como rutina por defecto'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.accentSecondary),
        );
      }
    }
  }

  Future<void> _copyRoutine(String id) async {
    try {
      final copied = await _service.copyRoutine(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('«${copied['name']}» copiada a Mis Rutinas'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      _load();
      _tabs.animateTo(0);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.accentSecondary),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?['role'] as String? ?? 'student';
    final canCreate = role == 'student' || role == 'staff' || role == 'professor' || role == 'admin';

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await context.push<bool>('/routines/create');
                if (created == true) _load();
              },
              backgroundColor: AppColors.accentPrimary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nueva', style: TextStyle(color: Colors.white)),
            )
          : null,
      body: Column(
        children: [
          const SectionBanner(
            title: 'Mis Rutinas',
            subtitle: 'Fuerza · Hipertrofia · Pérdida de peso',
            label: 'Planificación',
            accentColor: Color(0xFF4D9FFF),
            iconName: 'routines',
            gradientColors: [Color(0xFF010e22), Color(0xFF012040)],
          ),
          Container(
            color: context.colorBgSecondary,
            child: TabBar(
              controller: _tabs,
              indicatorColor: AppColors.accentPrimary,
              labelColor: AppColors.accentPrimary,
              unselectedLabelColor: context.colorTextSecondary,
              tabs: const [
                Tab(text: 'Mis Rutinas'),
                Tab(text: 'De Profesores'),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorView(error: _error!, onRetry: _load)
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _RoutineList(
                            routines: _myRoutines,
                            emptyMessage: 'No tienes rutinas aún',
                            emptyAction: canCreate
                                ? () async {
                                    final created = await context.push<bool>('/routines/create');
                                    if (created == true) _load();
                                  }
                                : null,
                            currentUserId: context.read<AuthProvider>().user?['id'] as String?,
                            onDelete: _delete,
                            onEdit: (id) async {
                              final updated = await context.push<bool>('/routines/$id/edit');
                              if (updated == true) _load();
                            },
                            onSetDefault: _setDefault,
                            onCopy: null,
                          ),
                          _RoutineList(
                            routines: _publicRoutines,
                            emptyMessage: 'No hay rutinas de profesores aún',
                            emptyAction: null,
                            currentUserId: null,
                            onDelete: null,
                            onEdit: null,
                            onSetDefault: null,
                            onCopy: _copyRoutine,
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Lista de rutinas ──────────────────────────────────────────────────────────

class _RoutineList extends StatelessWidget {
  const _RoutineList({
    required this.routines,
    required this.emptyMessage,
    required this.emptyAction,
    required this.currentUserId,
    required this.onDelete,
    required this.onEdit,
    required this.onSetDefault,
    required this.onCopy,
  });

  final List<Map<String, dynamic>> routines;
  final String emptyMessage;
  final VoidCallback? emptyAction;
  final String? currentUserId;
  final void Function(String id)? onDelete;
  final void Function(String id)? onEdit;
  final void Function(String id, String name)? onSetDefault;
  final void Function(String id)? onCopy;

  @override
  Widget build(BuildContext context) {
    if (routines.isEmpty) {
      return _EmptyState(message: emptyMessage, onAction: emptyAction);
    }
    return RefreshIndicator(
      color: AppColors.accentPrimary,
      onRefresh: () async {},
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: routines.length,
        separatorBuilder: (context, i) => const SizedBox(height: 10),
        itemBuilder: (context, i) => _RoutineCard(
          routine: routines[i],
          isOwner: currentUserId != null && routines[i]['userId'] == currentUserId,
          onDelete: onDelete,
          onEdit: onEdit,
          onSetDefault: onSetDefault,
          onCopy: onCopy,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onAction});
  final String message;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, size: 48, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(message, style: TextStyle(color: context.colorTextSecondary, fontSize: 15)),
            if (onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: const Text('Crear mi primera rutina'),
                style: FilledButton.styleFrom(backgroundColor: AppColors.accentPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tarjeta de rutina ─────────────────────────────────────────────────────────

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({
    required this.routine,
    required this.isOwner,
    required this.onDelete,
    required this.onEdit,
    required this.onSetDefault,
    required this.onCopy,
  });

  final Map<String, dynamic> routine;
  final bool isOwner;
  final void Function(String id)? onDelete;
  final void Function(String id)? onEdit;
  final void Function(String id, String name)? onSetDefault;
  final void Function(String id)? onCopy;

  static const _dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  Color _goalColor(String goal) {
    switch (goal) {
      case 'fuerza': return const Color(0xFF3B82F6);
      case 'hipertrofia': return AppColors.accentPrimary;
      case 'resistencia': return AppColors.accentGreen;
      case 'perdida_de_peso': return const Color(0xFFFF6B6B);
      default: return AppColors.textMuted;
    }
  }

  String _goalLabel(String goal) {
    switch (goal) {
      case 'fuerza': return 'Fuerza';
      case 'hipertrofia': return 'Hipertrofia';
      case 'resistencia': return 'Resistencia';
      case 'perdida_de_peso': return 'Pérdida de peso';
      default: return goal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final goal = routine['goal'] as String? ?? 'hipertrofia';
    final frequency = routine['frequencyDays'] as int? ?? 0;
    final creatorName = routine['creatorName'] as String? ?? '';
    final description = routine['description'] as String?;
    final goalColor = _goalColor(goal);

    // Días reales que eligió el usuario
    final dayNames = (routine['dayNames'] as List? ?? []).map((e) => '$e').toSet();
    const dayNames7 = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final activeDayIndices = dayNames.isNotEmpty
        ? List.generate(7, (i) => i).where((i) => dayNames.contains(dayNames7[i])).toList()
        : List.generate(frequency.clamp(0, 7), (i) => i); // fallback si no hay datos

    return GestureDetector(
      onTap: () => context.push('/routines/${routine['id']}'),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            routine['isPublic'] == true ? Icons.school_outlined : Icons.person_outline,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          SizedBox(width: 4),
                          Text(creatorName, style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        routine['name'] as String? ?? '',
                        style: TextStyle(color: context.colorTextPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: goalColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: goalColor.withAlpha(80)),
                  ),
                  child: Text(
                    _goalLabel(goal),
                    style: TextStyle(color: goalColor, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            if (description != null && description.isNotEmpty) ...[
              SizedBox(height: 8),
              Text(
                description,
                style: TextStyle(color: context.colorTextSecondary, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            // Indicadores de días
            Row(
              children: List.generate(7, (i) {
                final active = activeDayIndices.contains(i);
                return Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    color: active ? AppColors.accentPrimary : AppColors.bgTertiary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _dayLabels[i],
                      style: TextStyle(
                        color: active ? Colors.white : AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.fitness_center, size: 13, color: AppColors.textMuted),
                SizedBox(width: 4),
                Text('${frequency}x / semana', style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                const Spacer(),
                // Estrella: establecer como predeterminada (solo propias)
                if (isOwner && onSetDefault != null) ...[
                  GestureDetector(
                    onTap: () => onSetDefault!.call(
                      routine['id'] as String,
                      routine['name'] as String? ?? '',
                    ),
                    child: Icon(
                      routine['isDefault'] == true
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 20,
                      color: routine['isDefault'] == true
                          ? const Color(0xFFFFB347)
                          : AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                // Copiar: solo rutinas de profesores (no propias)
                if (!isOwner && onCopy != null) ...[
                  GestureDetector(
                    onTap: () => onCopy!.call(routine['id'] as String),
                    child: const Icon(Icons.copy_outlined, size: 18, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 10),
                ],
                if (isOwner && onEdit != null) ...[
                  GestureDetector(
                    onTap: () => onEdit!.call(routine['id'] as String),
                    child: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 10),
                ],
                if (isOwner && onDelete != null) ...[
                  GestureDetector(
                    onTap: () => _confirmDelete(context),
                    child: const Icon(Icons.delete_outline, size: 18, color: AppColors.textMuted),
                  ),
                  const SizedBox(width: 8),
                ],
                const Icon(Icons.chevron_right, size: 18, color: AppColors.textMuted),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Eliminar rutina', style: TextStyle(color: context.colorTextPrimary)),
        content: Text(
          '¿Eliminar "${routine['name']}"? Esta acción no se puede deshacer.',
          style: TextStyle(color: context.colorTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onDelete?.call(routine['id'] as String);
            },
            child: const Text('Eliminar', style: TextStyle(color: AppColors.accentSecondary)),
          ),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.accentSecondary, size: 40),
            SizedBox(height: 12),
            Text(error, style: TextStyle(color: context.colorTextSecondary), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}




