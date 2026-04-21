import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/exercises_service.dart';
import '../data/routines_service.dart';

const _days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const _dayShort = {'Lunes': 'L', 'Martes': 'M', 'Miércoles': 'X', 'Jueves': 'J', 'Viernes': 'V', 'Sábado': 'S', 'Domingo': 'D'};
const _goals = [
  _Goal('fuerza', 'Fuerza', Color(0xFF3B82F6)),
  _Goal('hipertrofia', 'Hipertrofia', AppColors.accentPrimary),
  _Goal('resistencia', 'Resistencia', AppColors.accentGreen),
  _Goal('perdida_de_peso', 'Pérdida de peso', AppColors.accentSecondary),
];

class _Goal {
  const _Goal(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;
}

class CreateRoutineScreen extends StatefulWidget {
  const CreateRoutineScreen({super.key, this.routineId});
  final String? routineId;

  bool get isEditing => routineId != null;

  @override
  State<CreateRoutineScreen> createState() => _CreateRoutineScreenState();
}

class _CreateRoutineScreenState extends State<CreateRoutineScreen> {
  final _routinesService = RoutinesService();
  final _exercisesService = ExercisesService();

  int _step = 1;
  bool _saving = false;
  bool _loadingInitial = false;

  // Step 1
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _goal = 'hipertrofia';
  bool _isPublic = false;

  // Step 2
  final List<String> _selectedDays = [];

  // Step 3: { dayName -> List<exercise map> }
  final Map<String, List<Map<String, dynamic>>> _dayExercises = {};

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadRoutine();
  }

  Future<void> _loadRoutine() async {
    setState(() => _loadingInitial = true);
    try {
      final routine = await _routinesService.getRoutine(widget.routineId!);
      _nameCtrl.text = routine['name'] as String? ?? '';
      _descCtrl.text = routine['description'] as String? ?? '';
      _goal = routine['goal'] as String? ?? 'hipertrofia';
      _isPublic = routine['isPublic'] as bool? ?? false;

      final days = (routine['days'] as List? ?? []).cast<Map<String, dynamic>>();
      _selectedDays.clear();
      _dayExercises.clear();
      for (final day in days) {
        final dayName = day['dayName'] as String? ?? '';
        if (dayName.isEmpty) continue;
        _selectedDays.add(dayName);
        final exercises = (day['exercises'] as List? ?? []).cast<Map<String, dynamic>>();
        _dayExercises[dayName] = exercises
            .where((ex) => ex['exerciseId'] != null)
            .map<Map<String, dynamic>>((ex) => <String, dynamic>{
              'id': ex['exerciseId'].toString(),
              'name': (ex['exerciseName'] ?? '').toString(),
              'muscleGroup': (ex['muscleGroup'] ?? '').toString(),
              'sets': (ex['sets'] as num?)?.toInt() ?? 3,
              'reps': (ex['reps'] ?? '8-12').toString(),
              'restSeconds': (ex['restSeconds'] as num?)?.toInt() ?? 90,
            })
            .toList();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar: $e'), backgroundColor: AppColors.accentSecondary),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _next() => setState(() => _step++);
  void _back() => setState(() => _step--);

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final days = _selectedDays.asMap().entries.map((e) {
        final day = e.value;
        final rawExercises = _dayExercises[day] ?? [];
        final exercises = <Map<String, dynamic>>[];
        for (var j = 0; j < rawExercises.length; j++) {
          final ex = rawExercises[j];
          final exerciseId = ex['id']?.toString() ?? '';
          if (exerciseId.isEmpty) continue;
          exercises.add(<String, dynamic>{
            'exerciseId': exerciseId,
            'sets': (ex['sets'] as num?)?.toInt() ?? 3,
            'reps': (ex['reps'] ?? '8-12').toString(),
            'restSeconds': (ex['restSeconds'] as num?)?.toInt() ?? 90,
            'orderIndex': j,
          });
        }
        return {
          'dayName': day,
          'label': day,
          'orderIndex': e.key,
          'exercises': exercises,
        };
      }).toList();

      if (widget.isEditing) {
        await _routinesService.updateRoutine(
          id: widget.routineId!,
          name: _nameCtrl.text.trim(),
          goal: _goal,
          description: _descCtrl.text.trim(),
          isPublic: _isPublic,
          days: days,
        );
      } else {
        await _routinesService.createRoutine(
          name: _nameCtrl.text.trim(),
          goal: _goal,
          description: _descCtrl.text.trim(),
          isPublic: _isPublic,
          days: days,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.isEditing ? '¡Rutina actualizada!' : '¡Rutina creada exitosamente!'),
            backgroundColor: AppColors.accentGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.accentSecondary),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?['role'] as String? ?? 'student';
    final canPublish = role == 'professor' || role == 'admin';

    if (_loadingInitial) {
      return Scaffold(
        backgroundColor: context.colorBgPrimary,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar rutina' : 'Crear rutina'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(36),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(3, (i) => Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.only(right: i < 2 ? 6 : 0),
                      decoration: BoxDecoration(
                        color: i < _step ? AppColors.accentPrimary : AppColors.bgTertiary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  )),
                ),
                SizedBox(height: 6),
                Text(
                  'Paso $_step de 3 — ${['Información básica', 'Días de entrenamiento', 'Ejercicios por día'][_step - 1]}',
                  style: TextStyle(color: context.colorTextSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: KeyedSubtree(
          key: ValueKey(_step),
          child: _step == 1
              ? _Step1(
                  nameCtrl: _nameCtrl,
                  descCtrl: _descCtrl,
                  goal: _goal,
                  isPublic: _isPublic,
                  canPublish: canPublish,
                  onGoalChanged: (g) => setState(() => _goal = g),
                  onPublicChanged: (v) => setState(() => _isPublic = v),
                  onNext: _nameCtrl.text.trim().isNotEmpty ? _next : null,
                )
              : _step == 2
                  ? _Step2(
                      selectedDays: _selectedDays,
                      onToggle: (day) {
                        setState(() {
                          if (_selectedDays.contains(day)) {
                            _selectedDays.remove(day);
                            _dayExercises.remove(day);
                          } else {
                            _selectedDays.add(day);
                          }
                        });
                      },
                      onBack: _back,
                      onNext: _selectedDays.isNotEmpty ? _next : null,
                    )
                  : _Step3(
                      selectedDays: _selectedDays,
                      dayExercises: _dayExercises,
                      exercisesService: _exercisesService,
                      goal: _goal,
                      onBack: _back,
                      onSave: _saving ? null : _save,
                      saving: _saving,
                    ),
        ),
      ),
    );
  }
}

// ── Paso 1: Información básica ────────────────────────────────────────────────

class _Step1 extends StatefulWidget {
  const _Step1({
    required this.nameCtrl,
    required this.descCtrl,
    required this.goal,
    required this.isPublic,
    required this.canPublish,
    required this.onGoalChanged,
    required this.onPublicChanged,
    required this.onNext,
  });

  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  final String goal;
  final bool isPublic;
  final bool canPublish;
  final void Function(String) onGoalChanged;
  final void Function(bool) onPublicChanged;
  final VoidCallback? onNext;

  @override
  State<_Step1> createState() => _Step1State();
}

class _Step1State extends State<_Step1> {
  @override
  void initState() {
    super.initState();
    widget.nameCtrl.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('Nombre de la rutina *'),
          SizedBox(height: 8),
          TextField(
            controller: widget.nameCtrl,
            autofocus: true,
            style: TextStyle(color: context.colorTextPrimary),
            decoration: InputDecoration(
              hintText: 'Ej: Mi rutina de fuerza',
              hintStyle: TextStyle(color: context.colorTextMuted),
              filled: true,
              fillColor: AppColors.bgSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accentPrimary),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const _Label('Objetivo *'),
          const SizedBox(height: 10),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 3.2,
            children: _goals.map((g) {
              final selected = widget.goal == g.value;
              return GestureDetector(
                onTap: () => widget.onGoalChanged(g.value),
                child: Container(
                  decoration: BoxDecoration(
                    color: selected ? g.color.withAlpha(40) : AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? g.color : AppColors.border, width: selected ? 1.5 : 1),
                  ),
                  child: Center(
                    child: Text(
                      g.label,
                      style: TextStyle(
                        color: selected ? g.color : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _GoalInfoBanner(goal: widget.goal),
          SizedBox(height: 20),
          const _Label('Descripción (opcional)'),
          SizedBox(height: 8),
          TextField(
            controller: widget.descCtrl,
            maxLines: 3,
            style: TextStyle(color: context.colorTextPrimary),
            decoration: InputDecoration(
              hintText: 'Describe el objetivo y características...',
              hintStyle: TextStyle(color: context.colorTextMuted),
              filled: true,
              fillColor: AppColors.bgSecondary,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.accentPrimary),
              ),
            ),
          ),
          if (widget.canPublish) ...[
            SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: context.colorBgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: SwitchListTile(
                title: Text('Rutina pública', style: TextStyle(color: context.colorTextPrimary, fontSize: 14)),
                subtitle: Text('Visible para todos los usuarios', style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                value: widget.isPublic,
                onChanged: widget.onPublicChanged,
                activeThumbColor: AppColors.accentPrimary,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: widget.nameCtrl.text.trim().isNotEmpty ? widget.onNext : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary,
                disabledBackgroundColor: AppColors.bgTertiary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Continuar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Paso 2: Días ──────────────────────────────────────────────────────────────

class _Step2 extends StatelessWidget {
  const _Step2({
    required this.selectedDays,
    required this.onToggle,
    required this.onBack,
    required this.onNext,
  });

  final List<String> selectedDays;
  final void Function(String) onToggle;
  final VoidCallback onBack;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecciona los días en que entrenarás:', style: TextStyle(color: context.colorTextSecondary, fontSize: 14)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _days.map((day) {
              final selected = selectedDays.contains(day);
              return GestureDetector(
                onTap: () => onToggle(day),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.accentPrimary.withAlpha(30) : AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected ? AppColors.accentPrimary : AppColors.border,
                      width: selected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _dayShort[day] ?? day[0],
                        style: TextStyle(
                          color: selected ? AppColors.accentPrimary : AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        day.substring(0, 3),
                        style: TextStyle(
                          color: selected ? AppColors.accentPrimary : AppColors.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (selectedDays.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentPrimary.withAlpha(60)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.accentPrimary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${selectedDays.length} día${selectedDays.length > 1 ? 's' : ''}: ${selectedDays.join(', ')}',
                      style: const TextStyle(color: AppColors.accentPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    disabledBackgroundColor: AppColors.bgTertiary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Continuar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Paso 3: Ejercicios por día ────────────────────────────────────────────────

// defaults de sets/reps/descanso por objetivo
Map<String, dynamic> _defaultsForGoal(String goal) {
  switch (goal) {
    case 'fuerza':       return <String, dynamic>{'sets': 5, 'reps': '3-5',   'restSeconds': 180};
    case 'resistencia':  return <String, dynamic>{'sets': 3, 'reps': '15-20', 'restSeconds': 45};
    case 'perdida_de_peso': return <String, dynamic>{'sets': 3, 'reps': '12-15', 'restSeconds': 60};
    case 'hipertrofia':
    default:             return <String, dynamic>{'sets': 4, 'reps': '8-12',  'restSeconds': 90};
  }
}

class _Step3 extends StatefulWidget {
  const _Step3({
    required this.selectedDays,
    required this.dayExercises,
    required this.exercisesService,
    required this.goal,
    required this.onBack,
    required this.onSave,
    required this.saving,
  });

  final List<String> selectedDays;
  final Map<String, List<Map<String, dynamic>>> dayExercises;
  final ExercisesService exercisesService;
  final String goal;
  final VoidCallback onBack;
  final VoidCallback? onSave;
  final bool saving;

  @override
  State<_Step3> createState() => _Step3State();
}

class _Step3State extends State<_Step3> {
  List<Map<String, dynamic>> _allExercises = [];
  bool _loadingExercises = true;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    try {
      final list = await widget.exercisesService.listExercises();
      setState(() { _allExercises = list; _loadingExercises = false; });
    } catch (e) {
      setState(() => _loadingExercises = false);
    }
  }

  void _addExercise(BuildContext context, String day, Map<String, dynamic> exercise) {
    final exerciseId = '${exercise['id'] ?? ''}';
    if (exerciseId.isEmpty) return;
    final defaults = _defaultsForGoal(widget.goal);
    bool added = false;
    setState(() {
      widget.dayExercises.putIfAbsent(day, () => <Map<String, dynamic>>[]);
      if (!widget.dayExercises[day]!.any((e) => '${e['id']}' == exerciseId)) {
        widget.dayExercises[day]!.add(<String, dynamic>{
          'id': exerciseId,
          'name': '${exercise['name'] ?? ''}',
          'muscleGroup': '${exercise['muscleGroup'] ?? ''}',
          'sets': defaults['sets'],
          'reps': defaults['reps'],
          'restSeconds': defaults['restSeconds'],
        });
        added = true;
      }
    });
    if (added) {
      final screenHeight = MediaQuery.of(context).size.height;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('${exercise['name']} añadido a $day')),
        ]),
        backgroundColor: AppColors.accentPrimary,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: screenHeight - 160,
        ),
        duration: const Duration(seconds: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    }
  }

  void _removeExercise(String day, int index) {
    setState(() => widget.dayExercises[day]?.removeAt(index));
  }

  void _editExercise(BuildContext context, String day, int index) {
    final ex = widget.dayExercises[day]![index];
    showDialog(
      context: context,
      builder: (ctx) => _ExerciseEditDialog(
        exerciseName: '${ex['name']}',
        sets: (ex['sets'] as num?)?.toInt() ?? 3,
        reps: '${ex['reps'] ?? '8-12'}',
        restSeconds: (ex['restSeconds'] as num?)?.toInt() ?? 90,
        goal: widget.goal,
        onSave: (sets, reps, rest) {
          setState(() {
            widget.dayExercises[day]![index] = <String, dynamic>{
              ...ex,
              'sets': sets,
              'reps': reps,
              'restSeconds': rest,
            };
          });
        },
      ),
    );
  }

  void _openPicker(BuildContext context, String day) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExercisePicker(
        day: day,
        exercises: _allExercises,
        loading: _loadingExercises,
        alreadyAdded: (widget.dayExercises[day] ?? [])
            .map((e) => '${e['id'] ?? ''}')
            .where((id) => id.isNotEmpty)
            .toSet(),
        onSelect: (ex) => _addExercise(context, day, ex),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...widget.selectedDays.map((day) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _DayExercisesCard(
                  day: day,
                  exercises: widget.dayExercises[day] ?? [],
                  onAdd: () => _openPicker(context, day),
                  onRemove: (i) => _removeExercise(day, i),
                  onEdit: (i) => _editExercise(context, day, i),
                ),
              )),
              const SizedBox(height: 80),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          color: AppColors.bgPrimary,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onBack,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Atrás'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: widget.onSave,
                  icon: widget.saving
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check, size: 18),
                  label: Text(widget.saving ? 'Guardando...' : 'Guardar rutina'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayExercisesCard extends StatelessWidget {
  const _DayExercisesCard({
    required this.day,
    required this.exercises,
    required this.onAdd,
    required this.onRemove,
    required this.onEdit,
  });

  final String day;
  final List<Map<String, dynamic>> exercises;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final void Function(int) onEdit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      _dayShort[day] ?? day[0],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(day, style: TextStyle(color: context.colorTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                ),
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.accentPrimary.withAlpha(60)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add, size: 14, color: AppColors.accentPrimary),
                        SizedBox(width: 4),
                        Text('Agregar', style: TextStyle(color: AppColors.accentPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (exercises.isEmpty)
            Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Text('Sin ejercicios aún', style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
            )
          else
            ...exercises.asMap().entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  Text('${e.key + 1}', style: const TextStyle(color: AppColors.accentPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${e.value['name'] ?? ''}', style: TextStyle(color: context.colorTextPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
                        Text(
                          '${e.value['sets']} series × ${e.value['reps']} reps · ${e.value['restSeconds']}s',
                          style: TextStyle(color: context.colorTextSecondary, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => onEdit(e.key),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.edit_outlined, size: 14, color: AppColors.accentPrimary),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => onRemove(e.key),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.accentSecondary.withAlpha(25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.close, size: 14, color: AppColors.accentSecondary),
                    ),
                  ),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

// ── Exercise picker overlay ───────────────────────────────────────────────────

class _ExercisePicker extends StatefulWidget {
  const _ExercisePicker({
    required this.day,
    required this.exercises,
    required this.loading,
    required this.alreadyAdded,
    required this.onSelect,
  });

  final String day;
  final List<Map<String, dynamic>> exercises;
  final bool loading;
  final Set<String> alreadyAdded;
  final void Function(Map<String, dynamic>) onSelect;

  @override
  State<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends State<_ExercisePicker> {
  String _search = '';
  String? _muscleFilter; // null=todo, 'tren_superior', 'tren_inferior', o muscle key
  final Set<String> _addedThisSession = {};

  static const _muscleColors = {
    'pecho': Color(0xFF3B82F6),
    'espalda': Color(0xFF8B5CF6),
    'piernas': Color(0xFF22C55E),
    'hombros': Color(0xFFF97316),
    'brazos': Color(0xFFEC4899),
    'core': Color(0xFFEAB308),
    'gluteos': Color(0xFFEF4444),
  };

  static const _trenSuperior = {'pecho', 'espalda', 'hombros', 'brazos'};
  static const _trenInferior = {'piernas', 'gluteos'};

  static const _chips = [
    (label: 'Todo', value: null, icon: null),
    (label: 'Sup.', value: 'tren_superior', icon: Icons.arrow_upward),
    (label: 'Inf.', value: 'tren_inferior', icon: Icons.arrow_downward),
    (label: 'Pecho', value: 'pecho', icon: null),
    (label: 'Espalda', value: 'espalda', icon: null),
    (label: 'Piernas', value: 'piernas', icon: null),
    (label: 'Hombros', value: 'hombros', icon: null),
    (label: 'Brazos', value: 'brazos', icon: null),
    (label: 'Core', value: 'core', icon: null),
    (label: 'Glúteos', value: 'gluteos', icon: null),
  ];

  List<Map<String, dynamic>> get _filtered {
    final q = _search.toLowerCase();
    return widget.exercises.where((e) {
      final muscle = (e['muscleGroup'] as String? ?? '').toLowerCase();
      final name = (e['name'] as String? ?? '').toLowerCase();
      if (q.isNotEmpty && !name.contains(q)) return false;
      if (_muscleFilter == null) return true;
      if (_muscleFilter == 'tren_superior') return _trenSuperior.contains(muscle);
      if (_muscleFilter == 'tren_inferior') return _trenInferior.contains(muscle);
      return muscle == _muscleFilter;
    }).toList()
      ..sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
  }

  Color _chipColor(String? value) {
    if (value == null) return AppColors.accentPrimary;
    if (value == 'tren_superior') return const Color(0xFF3B82F6);
    if (value == 'tren_inferior') return const Color(0xFF22C55E);
    return _muscleColors[value] ?? AppColors.accentPrimary;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // backdrop — solo cierra al tocar afuera
        ModalBarrier(
          color: Colors.black54,
          dismissible: true,
          onDismiss: () => Navigator.pop(context),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: Material(
            color: Colors.transparent,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.78,
              decoration: BoxDecoration(
                color: context.colorBgSecondary,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  SizedBox(height: 8),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Agregar ejercicio — ${widget.day}',
                            style: TextStyle(color: context.colorTextPrimary, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      autofocus: false,
                      style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Buscar ejercicio...',
                        hintStyle: TextStyle(color: context.colorTextMuted),
                        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                        filled: true,
                        fillColor: AppColors.bgTertiary,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                      ),
                      onChanged: (v) => setState(() => _search = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // ── Filtros ──
                  SizedBox(
                    height: 34,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _chips.length,
                      separatorBuilder: (_, i) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final chip = _chips[i];
                        final selected = _muscleFilter == chip.value;
                        final color = _chipColor(chip.value);
                        return GestureDetector(
                          onTap: () => setState(() => _muscleFilter = chip.value),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: selected ? color.withAlpha(40) : AppColors.bgTertiary,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: selected ? color : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (chip.icon != null) ...[
                                  Icon(chip.icon, size: 11, color: selected ? color : AppColors.textMuted),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  chip.label,
                                  style: TextStyle(
                                    color: selected ? color : AppColors.textSecondary,
                                    fontSize: 12,
                                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: widget.loading
                        ? const Center(child: CircularProgressIndicator())
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            itemCount: _filtered.length,
                            itemBuilder: (context, i) {
                              final ex = _filtered[i];
                              final id = '${ex['id'] ?? ''}';
                              final already = widget.alreadyAdded.contains(id) || _addedThisSession.contains(id);
                              final muscle = ex['muscleGroup'] as String? ?? '';
                              final color = _muscleColors[muscle] ?? AppColors.textMuted;
                              return GestureDetector(
                                onTap: already ? null : () {
                                  widget.onSelect(ex);
                                  setState(() => _addedThisSession.add('${ex['id'] ?? ''}'));
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 6),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: already ? AppColors.bgTertiary.withAlpha(80) : AppColors.bgTertiary,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: already ? Colors.transparent : AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 36,
                                        height: 36,
                                        decoration: BoxDecoration(
                                          color: already ? AppColors.accentGreen.withAlpha(30) : color.withAlpha(25),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          already ? Icons.check : Icons.fitness_center,
                                          size: 18,
                                          color: already ? AppColors.accentGreen : color,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              ex['name'] as String? ?? '',
                                              style: TextStyle(
                                                color: already ? AppColors.textMuted : AppColors.textPrimary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: color.withAlpha(25),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(muscle, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Exercise edit dialog ──────────────────────────────────────────────────────

class _ExerciseEditDialog extends StatefulWidget {
  const _ExerciseEditDialog({
    required this.exerciseName,
    required this.sets,
    required this.reps,
    required this.restSeconds,
    required this.goal,
    required this.onSave,
  });

  final String exerciseName;
  final int sets;
  final String reps;
  final int restSeconds;
  final String goal;
  final void Function(int sets, String reps, int restSeconds) onSave;

  @override
  State<_ExerciseEditDialog> createState() => _ExerciseEditDialogState();
}

class _ExerciseEditDialogState extends State<_ExerciseEditDialog> {
  late int _sets;
  late String _reps;
  late int _restSeconds;
  late TextEditingController _repsCtrl;

  // Presets por objetivo: (label, sets, reps, rest)
  static const _presets = {
    'fuerza':        [('Fuerza', 5, '3-5', 180), ('Potencia', 4, '1-3', 240)],
    'hipertrofia':   [('Hipertrofia', 4, '8-12', 90), ('Alto volumen', 5, '10-15', 90)],
    'resistencia':   [('Resistencia', 3, '15-20', 45), ('Circuit', 4, '20-25', 30)],
    'perdida_de_peso': [('Quema grasa', 3, '12-15', 60), ('HIIT', 4, '15-20', 30)],
  };

  @override
  void initState() {
    super.initState();
    _sets = widget.sets;
    _reps = widget.reps;
    _restSeconds = widget.restSeconds;
    _repsCtrl = TextEditingController(text: widget.reps);
  }

  @override
  void dispose() {
    _repsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final presets = _presets[widget.goal] ?? _presets['hipertrofia']!;

    return AlertDialog(
      backgroundColor: AppColors.bgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.exerciseName, style: TextStyle(color: context.colorTextPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
          SizedBox(height: 4),
          Text('Editar series y repeticiones', style: TextStyle(color: context.colorTextSecondary, fontSize: 12, fontWeight: FontWeight.w400)),
        ],
      ),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Presets
            Text('Presets recomendados', style: TextStyle(color: context.colorTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: presets.map((p) {
                final (label, sets, reps, rest) = p;
                final selected = _sets == sets && _reps == reps && _restSeconds == rest;
                return GestureDetector(
                  onTap: () => setState(() {
                    _sets = sets; _reps = reps; _restSeconds = rest;
                    _repsCtrl.text = reps;
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accentPrimary.withAlpha(40) : AppColors.bgTertiary,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? AppColors.accentPrimary : AppColors.border, width: selected ? 1.5 : 1),
                    ),
                    child: Text(label, style: TextStyle(color: selected ? AppColors.accentPrimary : AppColors.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
            _RirHintRow(goal: widget.goal),
            SizedBox(height: 20),
            // Series
            Text('Series', style: TextStyle(color: context.colorTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _CounterButton(icon: Icons.remove, onTap: _sets > 1 ? () => setState(() => _sets--) : null),
                SizedBox(width: 16),
                Text('$_sets', style: TextStyle(color: context.colorTextPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(width: 16),
                _CounterButton(icon: Icons.add, onTap: _sets < 10 ? () => setState(() => _sets++) : null),
              ],
            ),
            SizedBox(height: 16),
            // Repeticiones
            Text('Repeticiones (ej: 8-12 ó 15)', style: TextStyle(color: context.colorTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            TextField(
              controller: _repsCtrl,
              style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
              onChanged: (v) => _reps = v,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bgTertiary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            SizedBox(height: 16),
            // Descanso
            Text('Descanso entre series', style: TextStyle(color: context.colorTextMuted, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                _CounterButton(icon: Icons.remove, onTap: _restSeconds >= 15 ? () => setState(() => _restSeconds -= 15) : null),
                SizedBox(width: 16),
                Text(_restSeconds >= 60
                    ? '${(_restSeconds / 60).floor()}:${(_restSeconds % 60).toString().padLeft(2, '0')} min'
                    : '${_restSeconds}s',
                  style: TextStyle(color: context.colorTextPrimary, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(width: 16),
                _CounterButton(icon: Icons.add, onTap: _restSeconds < 600 ? () => setState(() => _restSeconds += 15) : null),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancelar', style: TextStyle(color: context.colorTextSecondary))),
        FilledButton(
          onPressed: () {
            final reps = _repsCtrl.text.trim().isEmpty ? _reps : _repsCtrl.text.trim();
            widget.onSave(_sets, reps, _restSeconds);
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(backgroundColor: AppColors.accentPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: onTap != null ? AppColors.bgTertiary : AppColors.bgTertiary.withAlpha(80),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(icon, size: 18, color: onTap != null ? AppColors.textPrimary : AppColors.textMuted),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(color: context.colorTextPrimary, fontSize: 14, fontWeight: FontWeight.w600),
  );
}

// ── Goal info banner (Paso 1) ─────────────────────────────────────────────────

class _GoalInfoBanner extends StatelessWidget {
  const _GoalInfoBanner({required this.goal});
  final String goal;

  static const _data = {
    'fuerza': (
      color: Color(0xFF3B82F6),
      reps: '1–6', sets: '3–6', rest: '3–5 min', intensity: '≥85% 1RM', rir: '0–2',
      tip: 'Adaptación neuromuscular. Descansos largos permiten resíntesis completa de ATP-PC (Schoenfeld, 2016).',
    ),
    'hipertrofia': (
      color: AppColors.accentPrimary,
      reps: '6–12', sets: '3–4', rest: '1.5–3 min', intensity: '67–85% 1RM', rir: '1–3',
      tip: '≥10 series semanales por músculo casi duplica la hipertrofia. Principiantes: ~90 s; avanzados: 2–3 min (Singer & Wolf, 2024).',
    ),
    'resistencia': (
      color: AppColors.accentGreen,
      reps: '15–25+', sets: '2–4', rest: '20–90 s', intensity: '40–60% 1RM', rir: '3–5',
      tip: 'ACSM: cargas 40–60% 1RM con descansos <90 s. NSCA: 30 s entre series en circuito.',
    ),
    'perdida_de_peso': (
      color: AppColors.accentSecondary,
      reps: '12–20', sets: '3–4', rest: '30–60 s', intensity: '50–70% 1RM', rir: '2–4',
      tip: 'Descansos cortos mantienen la FC elevada y maximizan el EPOC. El déficit calórico dietético es el factor primario.',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final d = _data[goal];
    if (d == null) return const SizedBox.shrink();
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: d.color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: d.color.withAlpha(70)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Métricas
          Row(
            children: [
              _MetricCell('Reps', d.reps, d.color),
              _MetricCell('Series', d.sets, d.color),
              _MetricCell('Descanso', d.rest, d.color),
              _MetricCell('Intensidad', d.intensity, d.color),
            ],
          ),
          const SizedBox(height: 10),
          // RIR + tip
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: d.color.withAlpha(35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('RIR ${d.rir}',
                    style: TextStyle(color: d.color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(d.tip,
                    style: TextStyle(color: context.colorTextSecondary, fontSize: 11, height: 1.4)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  const _MetricCell(this.label, this.value, this.color);
  final String label, value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center),
          SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: context.colorTextMuted, fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── RIR hint (diálogo de edición) ─────────────────────────────────────────────

class _RirHintRow extends StatelessWidget {
  const _RirHintRow({required this.goal});
  final String goal;

  static const _rir = {
    'fuerza':          ('RIR 0–2', 'Ir cerca del fallo en series de baja rep. con alta carga.'),
    'hipertrofia':     ('RIR 1–3', 'Principiantes: RIR 2–3; avanzados: RIR 1–2 en las últimas series.'),
    'resistencia':     ('RIR 3–5', 'No llegar al fallo; mantener técnica durante toda la serie.'),
    'perdida_de_peso': ('RIR 2–4', 'Descansos cortos priorizan gasto calórico sobre intensidad absoluta.'),
  };

  @override
  Widget build(BuildContext context) {
    final info = _rir[goal];
    if (info == null) return const SizedBox.shrink();
    final (rir, desc) = info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: context.colorBgTertiary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentPrimary.withAlpha(45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withAlpha(30),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(rir,
                style: const TextStyle(color: AppColors.accentPrimary, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(desc,
                style: TextStyle(color: context.colorTextSecondary, fontSize: 11, height: 1.4)),
          ),
        ],
      ),
    );
  }
}






