import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/workout_service.dart';
import '../data/routines_service.dart';

// Mapeo nombre día → weekday (1=lunes … 7=domingo), igual que DateTime.weekday
const _kDayWeekday = {
  'Lunes': 1, 'Martes': 2, 'Miércoles': 3, 'Jueves': 4,
  'Viernes': 5, 'Sábado': 6, 'Domingo': 7,
};

class RoutineDetailScreen extends StatefulWidget {
  const RoutineDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  final _service = RoutinesService();
  final _workoutService = WorkoutService();
  Map<String, dynamic>? _routine;
  // { routineDayId: 'completed' | 'partial' } — días sin sesión esta semana no aparecen
  Map<String, String> _weekStatus = {};
  bool _loading = true;
  String? _error;
  int _expandedDay = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await _service.getRoutine(widget.id);
      final routineId = r['id'] as String?;
      Map<String, String> weekStatus = {};
      if (routineId != null) {
        try {
          weekStatus = await _workoutService.getWeekStatus(routineId);
        } catch (_) {}
      }
      setState(() { _routine = r; _weekStatus = weekStatus; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.accentSecondary, size: 40),
          SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: context.colorTextSecondary)),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final routine = _routine!;
    final days = (routine['days'] as List? ?? []).cast<Map<String, dynamic>>();
    final goal = routine['goal'] as String? ?? 'hipertrofia';
    final creatorName = routine['creatorName'] as String? ?? '';
    final description = routine['description'] as String?;
    final frequency = routine['frequencyDays'] as int? ?? days.length;
    final totalExercises = days.fold<int>(
      0, (sum, d) => sum + ((d['exercises'] as List?)?.length ?? 0),
    );
    final avgExercises = days.isEmpty ? 0 : (totalExercises / days.length).round();

    return CustomScrollView(
      slivers: [
        // ── Hero header ──
        SliverToBoxAdapter(
          child: _Header(
            routine: routine,
            days: days,
            goal: goal,
            creatorName: creatorName,
            description: description,
            expandedDay: _expandedDay,
            onDayTap: (i) => setState(() => _expandedDay = i),
            onBack: () => context.pop(),
          ),
        ),

        // ── Stats ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _StatBox(value: '$frequency', label: 'Días/semana'),
                const SizedBox(width: 10),
                _StatBox(value: '${days.length}', label: 'Total días'),
                const SizedBox(width: 10),
                _StatBox(value: '$avgExercises', label: 'Ejerc./día'),
              ],
            ),
          ),
        ),

        // ── Plan semanal ──
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DayCard(
                  day: days[i],
                  index: i,
                  isExpanded: _expandedDay == i,
                  weekStatus: _weekStatus[days[i]['id'] as String? ?? ''],
                  onTap: () => setState(() => _expandedDay = _expandedDay == i ? -1 : i),
                ),
              ),
              childCount: days.length,
            ),
          ),
        ),

        // ── CTA ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            child: _StartWorkoutButton(routine: routine, days: days, expandedDay: _expandedDay, weekStatus: _weekStatus),
          ),
        ),
      ],
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.routine,
    required this.days,
    required this.goal,
    required this.creatorName,
    required this.description,
    required this.expandedDay,
    required this.onDayTap,
    required this.onBack,
  });

  final Map<String, dynamic> routine;
  final List<Map<String, dynamic>> days;
  final String goal;
  final String creatorName;
  final String? description;
  final int expandedDay;
  final void Function(int) onDayTap;
  final VoidCallback onBack;

  static const _dayShort = {
    'Lunes': 'L', 'Martes': 'M', 'Miércoles': 'X',
    'Jueves': 'J', 'Viernes': 'V', 'Sábado': 'S', 'Domingo': 'D',
  };

  String _goalLabel(String g) {
    switch (g) {
      case 'fuerza': return 'Fuerza';
      case 'hipertrofia': return 'Hipertrofia';
      case 'resistencia': return 'Resistencia';
      case 'perdida_de_peso': return 'Pérdida de peso';
      default: return g;
    }
  }

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
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withAlpha(30),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _goalLabel(goal),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          routine['name'] as String? ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Por $creatorName',
                          style: const TextStyle(color: Color(0xFFD0CDFF), fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  const Text('🏋️', style: TextStyle(fontSize: 32)),
                ],
              ),
              if (description != null && description!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(description!, style: const TextStyle(color: Color(0xFFD0CDFF), fontSize: 13)),
              ],
              if (days.isNotEmpty) ...[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: List.generate(days.length, (i) {
                    final dayName = days[i]['dayName'] as String? ?? '';
                    final short = _dayShort[dayName] ?? (dayName.isNotEmpty ? dayName[0] : '?');
                    final selected = expandedDay == i;
                    return GestureDetector(
                      onTap: () => onDayTap(i),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text(
                            short,
                            style: TextStyle(
                              color: selected ? const Color(0xFF6C63FF) : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  const _StatBox({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: AppColors.accentPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 2),
            Text(label, style: TextStyle(color: context.colorTextSecondary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── Día acordeón ──────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  const _DayCard({
    required this.day,
    required this.index,
    required this.isExpanded,
    required this.onTap,
    this.weekStatus,
  });

  final Map<String, dynamic> day;
  final int index;
  final bool isExpanded;
  final VoidCallback onTap;
  /// 'completed' | 'partial' | null (sin sesión esta semana)
  final String? weekStatus;

  static const _dayShort = {
    'Lunes': 'L', 'Martes': 'M', 'Miércoles': 'X',
    'Jueves': 'J', 'Viernes': 'V', 'Sábado': 'S', 'Domingo': 'D',
  };

  @override
  Widget build(BuildContext context) {
    final dayName = day['dayName'] as String? ?? '';
    final label = day['label'] as String? ?? dayName;
    final exercises = (day['exercises'] as List? ?? []).cast<Map<String, dynamic>>();
    final short = _dayShort[dayName] ?? (dayName.isNotEmpty ? dayName[0] : '?');

    final isCompleted = weekStatus == 'completed';
    final isPartial  = weekStatus == 'partial';

    Color statusDotColor() {
      if (isCompleted) return AppColors.accentGreen;
      if (isPartial)   return const Color(0xFFFFB347);
      return Colors.transparent;
    }

    return Container(
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? AppColors.accentGreen.withAlpha(80)
              : isPartial
                  ? const Color(0xFFFFB347).withAlpha(80)
                  : isExpanded
                      ? AppColors.accentPrimary.withAlpha(80)
                      : AppColors.border,
        ),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isExpanded ? AppColors.accentPrimary : AppColors.accentPrimary.withAlpha(25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        short,
                        style: TextStyle(
                          color: isExpanded ? Colors.white : AppColors.accentPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(dayName, style: TextStyle(color: context.colorTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                        Text(label, style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  // Badge de estado semanal
                  if (weekStatus != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: statusDotColor().withAlpha(25),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: statusDotColor().withAlpha(120)),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(width: 6, height: 6,
                            decoration: BoxDecoration(color: statusDotColor(), shape: BoxShape.circle)),
                        const SizedBox(width: 4),
                        Text(
                          isCompleted ? 'Hecho' : 'Parcial',
                          style: TextStyle(color: statusDotColor(), fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.colorBgTertiary,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${exercises.length} ejerc.',
                      style: TextStyle(color: context.colorTextSecondary, fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.border),
            if (exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Sin ejercicios', style: TextStyle(color: context.colorTextMuted, fontSize: 13)),
              )
            else
              ...List.generate(exercises.length, (i) => _ExerciseRow(exercise: exercises[i], index: i)),
          ],
        ],
      ),
    );
  }
}

// ── Botón iniciar entrenamiento ───────────────────────────────────────────────

class _StartWorkoutButton extends StatelessWidget {
  const _StartWorkoutButton({
    required this.routine,
    required this.days,
    required this.expandedDay,
    required this.weekStatus,
  });

  final Map<String, dynamic> routine;
  final List<Map<String, dynamic>> days;
  final int expandedDay;
  final Map<String, String> weekStatus;

  static const _dayLabels = [
    'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo',
  ];

  void _navigate(BuildContext context, Map<String, dynamic>? selectedDay) {
    context.push('/workout/session', extra: {
      'routineId': routine['id'] as String?,
      'routineDayId': selectedDay?['id'] as String?,
      'routineName': routine['name'] as String?,
      'dayLabel': selectedDay?['label'] as String? ?? selectedDay?['dayName'] as String?,
    });
  }

  void _onPressed(BuildContext context, Map<String, dynamic>? selectedDay) {
    if (selectedDay == null) { _navigate(context, null); return; }

    final dayId     = selectedDay['id'] as String? ?? '';
    final dayName   = selectedDay['dayName'] as String? ?? '';
    final status    = weekStatus[dayId];

    // Día ya completado esta semana → bloqueado
    if (status == 'completed') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$dayName ya fue completado esta semana 💪'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final scheduledWd = _kDayWeekday[dayName];
    final todayWd     = DateTime.now().weekday; // 1=lunes … 7=domingo

    // El día coincide con hoy (o el ejercicio no tiene día asignado) → iniciar directo
    if (scheduledWd == null || scheduledWd == todayWd) {
      _navigate(context, selectedDay);
      return;
    }

    // Día distinto al de hoy → mostrar diálogo
    final isMissed  = scheduledWd < todayWd; // día pasado esta semana
    final todayName = _dayLabels[todayWd - 1];

    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          isMissed ? 'Recuperar entrenamiento' : 'Adelantar entrenamiento',
          style: TextStyle(color: ctx.colorTextPrimary, fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          isMissed
              ? 'La rutina de $dayName no fue completada. ¿Quieres realizarla hoy ($todayName)?'
              : 'La rutina de $dayName está programada para más adelante. ¿Quieres adelantarla y hacerla hoy ($todayName)?',
          style: TextStyle(color: ctx.colorTextSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar', style: TextStyle(color: ctx.colorTextMuted)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentPrimary),
            child: Text(isMissed ? 'Recuperar' : 'Adelantar'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && context.mounted) _navigate(context, selectedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    final dayIndex   = (expandedDay >= 0 && expandedDay < days.length) ? expandedDay : 0;
    final selectedDay = days.isNotEmpty ? days[dayIndex] : null;
    final dayId      = selectedDay?['id'] as String? ?? '';
    final dayName    = selectedDay?['dayName'] as String? ?? '';
    final status     = weekStatus[dayId];
    final isCompleted = status == 'completed';
    final isPartial   = status == 'partial';

    return Column(
      children: [
        FilledButton.icon(
          onPressed: isCompleted ? null : () => _onPressed(context, selectedDay),
          icon: Icon(isCompleted
              ? Icons.check_circle_outline_rounded
              : isPartial
                  ? Icons.replay_rounded
                  : Icons.play_arrow_rounded),
          label: Text(
            isCompleted
                ? '$dayName ya completado esta semana'
                : isPartial
                    ? 'Completar ${dayName.isNotEmpty ? dayName : 'entrenamiento'}'
                    : selectedDay != null
                        ? 'Entrenar $dayName'
                        : 'Comenzar entrenamiento',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: isCompleted
                ? AppColors.accentGreen.withAlpha(120)
                : isPartial
                    ? const Color(0xFFFFB347)
                    : AppColors.accentPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.accentGreen.withAlpha(80),
            disabledForegroundColor: Colors.white70,
            minimumSize: const Size(double.infinity, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        if (isCompleted) ...[
          const SizedBox(height: 8),
          Text(
            'Vuelve la próxima semana o elige otro día',
            style: TextStyle(color: context.colorTextMuted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

// ── Fila de ejercicio ─────────────────────────────────────────────────────────

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({required this.exercise, required this.index});
  final Map<String, dynamic> exercise;
  final int index;

  @override
  Widget build(BuildContext context) {
    final name = exercise['exerciseName'] as String? ?? 'Ejercicio';
    final sets = exercise['sets'] as int? ?? 3;
    final reps = exercise['reps'] as String? ?? '8-12';
    final rest = exercise['restSeconds'] as int? ?? 90;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.border, width: index == 0 ? 0 : 0)),
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withAlpha(25),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '${index + 1}',
                style: const TextStyle(color: AppColors.accentPrimary, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(name, style: TextStyle(color: context.colorTextPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: context.colorBgTertiary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$sets×$reps', style: TextStyle(color: context.colorTextSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              const Icon(Icons.timer_outlined, size: 12, color: AppColors.textMuted),
              SizedBox(width: 3),
              Text('${rest}s', style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}




