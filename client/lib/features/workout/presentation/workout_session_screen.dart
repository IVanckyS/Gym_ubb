import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/weight_utils.dart';
import '../../../features/profile/providers/weight_unit_notifier.dart';
import '../../../shared/services/workout_service.dart';

class WorkoutSessionScreen extends StatefulWidget {
  const WorkoutSessionScreen({
    super.key,
    this.routineId,
    this.routineDayId,
    this.routineName,
    this.dayLabel,
  });

  final String? routineId;
  final String? routineDayId;
  final String? routineName;
  final String? dayLabel;

  @override
  State<WorkoutSessionScreen> createState() => _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends State<WorkoutSessionScreen> {
  final _service = WorkoutService();

  Map<String, dynamic>? _session;
  bool _loading = true;
  String? _error;

  // Timer general de la sesión
  late Timer _sessionTimer;
  Duration _elapsed = Duration.zero;

  // Timer de descanso
  Timer? _restTimer;
  int _restRemaining = 0;
  bool _restActive = false;
  int _restTotal = 90;

  // Sonidos countdown
  final AudioPlayer _loopPlayer = AudioPlayer();
  final AudioPlayer _finalPlayer = AudioPlayer();

  // Estado de inputs por set: key = "$exerciseId-$setNumber"
  final Map<String, TextEditingController> _weightControllers = {};
  final Map<String, TextEditingController> _repsControllers = {};  // también usado para duración en isométricos
  final Map<String, bool> _setCompleted = {};
  final Map<String, bool> _setLoading = {};

  // Tipo de ejercicio por exerciseId: 'dinamico' | 'isometrico'
  final Map<String, String> _exerciseTypes = {};

  // Unidad de peso del usuario (leída una vez al iniciar)
  WeightUnit _unit = WeightUnit.kg;

  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _unit = context.read<WeightUnitNotifier>().unit;
    _initSession();
  }

  @override
  void dispose() {
    _sessionTimer.cancel();
    _restTimer?.cancel();
    _loopPlayer.dispose();
    _finalPlayer.dispose();
    for (final c in _weightControllers.values) c.dispose();
    for (final c in _repsControllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _initSession() async {
    setState(() { _loading = true; _error = null; });
    try {
      final session = await _service.startSession(
        routineId: widget.routineId,
        routineDayId: widget.routineDayId,
      );
      _loadSession(session);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _loadSession(Map<String, dynamic> session) {
    _session = session;

    // Calcular tiempo transcurrido desde startedAt
    final startedAt = DateTime.tryParse(session['startedAt'] as String? ?? '')?.toLocal();
    if (startedAt != null) {
      _elapsed = DateTime.now().difference(startedAt);
    }

    // Inicializar estado de sets desde los ya registrados
    final exercises = (session['exercises'] as List? ?? []).cast<Map<String, dynamic>>();
    for (final ex in exercises) {
      final exerciseId = ex['exerciseId'] as String;
      final exerciseType = ex['exerciseType'] as String? ?? 'dinamico';
      final isIsometric = exerciseType == 'isometrico';
      _exerciseTypes[exerciseId] = exerciseType;

      final targetSets = ex['targetSets'] as int? ?? 3;
      final sets = (ex['sets'] as List? ?? []).cast<Map<String, dynamic>>();

      for (int i = 1; i <= targetSets; i++) {
        final key = '$exerciseId-$i';
        final existing = sets.where((s) => s['setNumber'] == i).firstOrNull;

        // Peso: convertir de kg a unidad preferida si hay valor existente
        final rawKg = (existing?['weightKg'] as num?)?.toDouble();
        final weightText = rawKg != null
            ? toDisplayUnit(rawKg, _unit).toStringAsFixed(1)
            : '';

        // Segunda columna: reps para dinámicos, duración para isométricos
        final secondText = isIsometric
            ? (existing?['durationSeconds'] != null
                ? existing!['durationSeconds'].toString()
                : '')
            : (existing?['reps'] != null ? existing!['reps'].toString() : '');

        _weightControllers.putIfAbsent(key, () => TextEditingController(text: weightText));
        _repsControllers.putIfAbsent(key, () => TextEditingController(text: secondText));
        _setCompleted[key] = existing?['completed'] as bool? ?? false;
        _setLoading[key] = false;
      }
    }

    // Arrancar timer de sesión
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });

    setState(() { _loading = false; });
  }

  void _startRestTimer(int seconds) {
    _restTimer?.cancel();
    setState(() {
      _restActive = true;
      _restRemaining = seconds;
      _restTotal = seconds;
    });
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        if (_restRemaining > 0) {
          _restRemaining--;
          // Sonido cada segundo cuando quedan 10 o menos
          if (_restRemaining > 0 && _restRemaining <= 10) {
            _playCountdownBeep();
          } else if (_restRemaining == 0) {
            _playFinishSound();
            _restActive = false;
            t.cancel();
          }
        } else {
          _restActive = false;
          t.cancel();
        }
      });
    });
  }

  void _stopRestTimer() {
    _restTimer?.cancel();
    _loopPlayer.stop();
    setState(() { _restActive = false; _restRemaining = 0; });
  }

  Future<void> _playCountdownBeep() async {
    await _loopPlayer.stop();
    await _loopPlayer.play(AssetSource('sounds/loop.mp3'));
  }

  Future<void> _playFinishSound() async {
    await _loopPlayer.stop();
    await _finalPlayer.play(AssetSource('sounds/final.mp3'));
  }

  Future<void> _toggleSet(String exerciseId, int setNumber, int restSeconds) async {
    final key = '$exerciseId-$setNumber';
    if (_setLoading[key] == true) return;

    final sessionId = _session!['id'] as String;
    final weightText = _weightControllers[key]?.text.trim() ?? '';
    final secondText = _repsControllers[key]?.text.trim() ?? '';
    final wasCompleted = _setCompleted[key] ?? false;
    final nowCompleted = !wasCompleted;
    final isIsometric = _exerciseTypes[exerciseId] == 'isometrico';

    // Convertir peso de unidad preferida a kg para la API
    final displayWeight = double.tryParse(weightText);
    final weightKg = displayWeight != null ? fromDisplayUnit(displayWeight, _unit) : null;

    setState(() => _setLoading[key] = true);
    try {
      await _service.logSet(
        sessionId: sessionId,
        exerciseId: exerciseId,
        setNumber: setNumber,
        weightKg: isIsometric ? null : weightKg,
        reps: isIsometric ? null : int.tryParse(secondText),
        durationSeconds: isIsometric ? int.tryParse(secondText) : null,
        completed: nowCompleted,
      );
      setState(() {
        _setCompleted[key] = nowCompleted;
        _setLoading[key] = false;
      });

      if (nowCompleted) {
        _startRestTimer(restSeconds);
      } else if (_restActive) {
        _stopRestTimer();
      }
    } catch (_) {
      setState(() => _setLoading[key] = false);
    }
  }

  bool _isSessionComplete() {
    final exercises = (_session?['exercises'] as List? ?? []).cast<Map<String, dynamic>>();
    if (exercises.isEmpty) return false;
    for (final ex in exercises) {
      final targetSets = ex['targetSets'] as int? ?? 0;
      if (targetSets == 0) continue;
      for (int i = 1; i <= targetSets; i++) {
        final key = '${ex['exerciseId']}-$i';
        if (_setCompleted[key] != true) return false;
      }
    }
    return true;
  }

  Future<void> _finish() async {
    final isComplete = _isSessionComplete();
    if (isComplete) {
      await _doFinish(status: 'completed');
    } else {
      await _showExitDialog();
    }
  }

  Future<void> _doFinish({
    required String status,
    String? earlyFinishReason,
  }) async {
    setState(() => _finishing = true);
    try {
      _sessionTimer.cancel();
      _restTimer?.cancel();
      final sessionId = _session!['id'] as String;
      final finished = await _service.finishSession(
        sessionId,
        status: status,
        earlyFinishReason: earlyFinishReason,
      );
      if (!mounted) return;
      context.pushReplacement('/workout/summary', extra: finished);
    } catch (e) {
      if (!mounted) return;
      setState(() => _finishing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.accentSecondary),
      );
    }
  }

  Future<void> _doCancel() async {
    try {
      final sessionId = _session?['id'] as String?;
      if (sessionId != null) await _service.cancelSession(sessionId);
    } catch (_) {}
    if (!mounted) return;
    context.pop();
  }

  Future<void> _showExitDialog() async {
    if (_session == null) { context.pop(); return; }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ExitSessionDialog(
        onContinue: () => Navigator.of(ctx).pop(),
        onDiscard: () async {
          Navigator.of(ctx).pop();
          await _doCancel();
        },
        onPartial: (reason) async {
          Navigator.of(ctx).pop();
          await _doFinish(status: 'partial', earlyFinishReason: reason);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _session != null && !_finishing) _showExitDialog();
      },
      child: Scaffold(
        backgroundColor: context.colorBgPrimary,
        body: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary))
            : _error != null
                ? _buildError()
                : _buildSession(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.accentSecondary, size: 48),
            SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center,
                style: TextStyle(color: context.colorTextSecondary)),
            const SizedBox(height: 24),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.accentPrimary),
              onPressed: _initSession,
              child: const Text('Reintentar'),
            ),
            SizedBox(height: 12),
            TextButton(
              onPressed: () => context.pop(),
              child: Text('Volver', style: TextStyle(color: context.colorTextSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSession() {
    final session = _session!;
    final exercises = (session['exercises'] as List? ?? []).cast<Map<String, dynamic>>();
    final routineName = widget.routineName ?? session['routineName'] as String?;
    final dayLabel = widget.dayLabel ?? session['dayLabel'] as String?;

    return Column(
      children: [
        // ── Header fijo ──
        _SessionHeader(
          elapsed: _elapsed,
          routineName: routineName,
          dayLabel: dayLabel,
          onFinish: _finishing ? null : _finish,
          onCancel: _finishing ? null : _showExitDialog,
          finishing: _finishing,
        ),

        // ── Banner de descanso ──
        if (_restActive) _RestBanner(
          remaining: _restRemaining,
          total: _restTotal,
          onSkip: _stopRestTimer,
        ),

        // ── Lista de ejercicios ──
        Expanded(
          child: exercises.isEmpty
              ? Center(
                  child: Text(
                    'No hay ejercicios en este día',
                    style: TextStyle(color: context.colorTextSecondary),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 32),
                  itemCount: exercises.length,
                  itemBuilder: (context, i) {
                    final ex = exercises[i];
                    final exId = ex['exerciseId'] as String;
                    final isIsometric = _exerciseTypes[exId] == 'isometrico';
                    return _ExerciseCard(
                      exercise: ex,
                      weightControllers: _weightControllers,
                      repsControllers: _repsControllers,
                      setCompleted: _setCompleted,
                      setLoading: _setLoading,
                      onToggleSet: _toggleSet,
                      isIsometric: isIsometric,
                      weightUnitLabel: _unit == WeightUnit.lbs ? 'LBS' : 'KG',
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Widgets internos ──────────────────────────────────────────────────────────

class _SessionHeader extends StatelessWidget {
  const _SessionHeader({
    required this.elapsed,
    required this.routineName,
    required this.dayLabel,
    required this.onFinish,
    required this.onCancel,
    required this.finishing,
  });

  final Duration elapsed;
  final String? routineName;
  final String? dayLabel;
  final VoidCallback? onFinish;
  final VoidCallback? onCancel;
  final bool finishing;

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colorBgSecondary,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 16,
        right: 16,
        bottom: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
                onPressed: onCancel,
                tooltip: 'Cancelar sesión',
              ),
              const Spacer(),
              // Timer
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: context.colorBgTertiary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.timer_outlined, color: AppColors.accentPrimary, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      _formatDuration(elapsed),
                      style: const TextStyle(
                        color: AppColors.accentPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              finishing
                  ? const SizedBox(
                      width: 36, height: 36,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentPrimary,
                      ),
                    )
                  : FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accentPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: onFinish,
                      child: const Text('Finalizar', style: TextStyle(fontSize: 13)),
                    ),
            ],
          ),
          if (routineName != null || dayLabel != null) ...[
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                [if (routineName != null) routineName, if (dayLabel != null) dayLabel]
                    .join(' · '),
                style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RestBanner extends StatelessWidget {
  const _RestBanner({
    required this.remaining,
    required this.total,
    required this.onSkip,
  });

  final int remaining;
  final int total;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? remaining / total : 0.0;
    final isWarning = remaining <= 10;

    return Container(
      color: context.colorBgTertiary,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(
            Icons.hourglass_bottom_rounded,
            color: isWarning ? AppColors.accentSecondary : AppColors.accentGreen,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Descanso: ${remaining}s',
                      style: TextStyle(
                        color: isWarning ? AppColors.accentSecondary : AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: onSkip,
                      child: const Text(
                        'Omitir',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.bgSecondary,
                  valueColor: AlwaysStoppedAnimation(
                    isWarning ? AppColors.accentSecondary : AppColors.accentGreen,
                  ),
                  borderRadius: BorderRadius.circular(4),
                  minHeight: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseCard extends StatefulWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.weightControllers,
    required this.repsControllers,
    required this.setCompleted,
    required this.setLoading,
    required this.onToggleSet,
    this.isIsometric = false,
    this.weightUnitLabel = 'KG',
  });

  final Map<String, dynamic> exercise;
  final Map<String, TextEditingController> weightControllers;
  final Map<String, TextEditingController> repsControllers;
  final Map<String, bool> setCompleted;
  final Map<String, bool> setLoading;
  final Future<void> Function(String exerciseId, int setNumber, int restSeconds) onToggleSet;
  final bool isIsometric;
  final String weightUnitLabel;

  @override
  State<_ExerciseCard> createState() => _ExerciseCardState();
}

class _ExerciseCardState extends State<_ExerciseCard> {
  bool _expanded = true;

  static const _muscleColors = {
    'pecho': Color(0xFF3b82f6),
    'espalda': Color(0xFF8b5cf6),
    'piernas': Color(0xFF22c55e),
    'hombros': Color(0xFFf97316),
    'brazos': Color(0xFFec4899),
    'core': Color(0xFFeab308),
    'gluteos': Color(0xFFef4444),
  };

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final exerciseId = ex['exerciseId'] as String;
    final name = ex['exerciseName'] as String? ?? '';
    final muscleGroup = ex['muscleGroup'] as String? ?? '';
    final targetSets = ex['targetSets'] as int? ?? 3;
    final targetReps = ex['targetReps'] as String? ?? '8-12';
    final restSeconds = ex['restSeconds'] as int? ?? 90;
    final muscleColor = _muscleColors[muscleGroup] ?? AppColors.accentPrimary;

    final completedSets = List.generate(targetSets, (i) {
      final key = '$exerciseId-${i + 1}';
      return widget.setCompleted[key] ?? false;
    }).where((c) => c).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // ── Encabezado ejercicio ──
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 4,
                    height: 44,
                    decoration: BoxDecoration(
                      color: muscleColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$targetSets series × $targetReps reps · ${restSeconds}s descanso',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Progreso series
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: completedSets == targetSets
                          ? AppColors.accentGreen.withValues(alpha: 0.15)
                          : AppColors.bgTertiary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$completedSets/$targetSets',
                      style: TextStyle(
                        color: completedSets == targetSets
                            ? AppColors.accentGreen
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),

          // ── Sets ──
          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(left: 14, right: 14, bottom: 14),
              child: Column(
                children: [
                  // Cabecera columnas
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        const SizedBox(width: 32),
                        if (!widget.isIsometric) ...[
                          Expanded(
                            child: Text(widget.weightUnitLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            widget.isIsometric ? 'SEG' : 'REPS',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: context.colorTextMuted, fontSize: 11),
                          ),
                        ),
                        const SizedBox(width: 44),
                      ],
                    ),
                  ),
                  ...List.generate(targetSets, (i) {
                    final setNumber = i + 1;
                    final key = '$exerciseId-$setNumber';
                    final completed = widget.setCompleted[key] ?? false;
                    final loading = widget.setLoading[key] ?? false;

                    return _SetRow(
                      setNumber: setNumber,
                      weightController: widget.weightControllers[key]!,
                      repsController: widget.repsControllers[key]!,
                      completed: completed,
                      loading: loading,
                      isIsometric: widget.isIsometric,
                      onToggle: () => widget.onToggleSet(exerciseId, setNumber, restSeconds),
                    );
                  }),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SetRow extends StatelessWidget {
  const _SetRow({
    required this.setNumber,
    required this.weightController,
    required this.repsController,
    required this.completed,
    required this.loading,
    required this.onToggle,
    this.isIsometric = false,
  });

  final int setNumber;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final bool completed;
  final bool loading;
  final VoidCallback onToggle;
  final bool isIsometric;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: completed
            ? AppColors.accentGreen.withValues(alpha: 0.08)
            : AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: completed
              ? AppColors.accentGreen.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
      ),
      child: Row(
        children: [
          // Número de serie
          SizedBox(
            width: 24,
            child: Text(
              '$setNumber',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: completed ? AppColors.accentGreen : AppColors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Campo KG/LBS (oculto en isométricos)
          if (!isIsometric) ...[
            Expanded(
              child: _NumberField(
                controller: weightController,
                hint: '0',
                enabled: !completed,
                decimal: true,
              ),
            ),
            const SizedBox(width: 8),
          ],

          // Campo Reps / Duración
          Expanded(
            child: _NumberField(
              controller: repsController,
              hint: '0',
              enabled: !completed,
              decimal: false,
            ),
          ),
          const SizedBox(width: 8),

          // Botón completar
          SizedBox(
            width: 36,
            height: 36,
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.accentPrimary,
                    ),
                  )
                : InkWell(
                    onTap: onToggle,
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: completed
                            ? AppColors.accentGreen
                            : AppColors.bgSecondary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: completed
                              ? AppColors.accentGreen
                              : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        Icons.check,
                        size: 18,
                        color: completed ? Colors.white : AppColors.textMuted,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.hint,
    required this.enabled,
    required this.decimal,
  });

  final TextEditingController controller;
  final String hint;
  final bool enabled;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      textAlign: TextAlign.center,
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colorTextMuted, fontSize: 14),
        filled: true,
        fillColor: AppColors.bgPrimary,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ── Dialog de salida de sesión ────────────────────────────────────────────────

class _ExitSessionDialog extends StatefulWidget {
  const _ExitSessionDialog({
    required this.onContinue,
    required this.onDiscard,
    required this.onPartial,
  });

  final VoidCallback onContinue;
  final VoidCallback onDiscard;
  final void Function(String reason) onPartial;

  @override
  State<_ExitSessionDialog> createState() => _ExitSessionDialogState();
}

class _ExitSessionDialogState extends State<_ExitSessionDialog> {
  // 0 = pantalla principal, 1 = seleccionar motivo de pausa
  int _step = 0;
  String? _selectedReason;
  final _otherCtrl = TextEditingController();

  static const _reasons = [
    'Poco tiempo',
    'Cansancio / fatiga',
    'Molestia o dolor',
    'Otro',
  ];

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _confirmPartial() {
    final reason = _selectedReason == 'Otro'
        ? _otherCtrl.text.trim()
        : _selectedReason ?? '';
    widget.onPartial(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.colorBgSecondary,
      title: Text(
        _step == 0 ? '¿Qué deseas hacer?' : 'Motivo para terminar',
        style: TextStyle(color: context.colorTextPrimary, fontSize: 17),
      ),
      content: _step == 0 ? _buildMainStep(context) : _buildReasonStep(context),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: _step == 0
          ? [
              TextButton(
                onPressed: widget.onContinue,
                child: Text('Seguir con la rutina',
                    style: TextStyle(color: AppColors.accentPrimary)),
              ),
            ]
          : [
              TextButton(
                onPressed: () => setState(() => _step = 0),
                child: Text('Atrás',
                    style: TextStyle(color: context.colorTextSecondary)),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB347)),
                onPressed: _selectedReason == null
                    ? null
                    : _confirmPartial,
                child: const Text('Terminar aquí',
                    style: TextStyle(color: Colors.black87)),
              ),
            ],
    );
  }

  Widget _buildMainStep(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'No has completado todos los ejercicios de tu rutina.',
          style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
        ),
        const SizedBox(height: 16),
        _OptionTile(
          icon: Icons.fitness_center_rounded,
          iconColor: AppColors.accentPrimary,
          title: 'Seguir con la rutina',
          subtitle: 'Vuelvo a entrenar',
          onTap: widget.onContinue,
        ),
        const SizedBox(height: 8),
        _OptionTile(
          icon: Icons.delete_outline_rounded,
          iconColor: AppColors.accentSecondary,
          title: 'No disputar la rutina',
          subtitle: 'Elimina todo el progreso de esta sesión',
          onTap: widget.onDiscard,
        ),
        const SizedBox(height: 8),
        _OptionTile(
          icon: Icons.flag_outlined,
          iconColor: const Color(0xFFFFB347),
          title: 'Terminar aquí',
          subtitle: 'Guarda el progreso parcial',
          onTap: () => setState(() => _step = 1),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildReasonStep(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _reasons.map((r) {
            final selected = _selectedReason == r;
            return GestureDetector(
              onTap: () => setState(() => _selectedReason = r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accentPrimary.withValues(alpha: 0.15)
                      : context.colorBgTertiary,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected ? AppColors.accentPrimary : context.colorBorder,
                  ),
                ),
                child: Text(r,
                    style: TextStyle(
                      color: selected
                          ? AppColors.accentPrimary
                          : context.colorTextSecondary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    )),
              ),
            );
          }).toList(),
        ),
        if (_selectedReason == 'Otro') ...[
          const SizedBox(height: 8),
          TextField(
            controller: _otherCtrl,
            style: TextStyle(color: context.colorTextPrimary, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Describe el motivo...',
              hintStyle:
                  TextStyle(color: context.colorTextMuted, fontSize: 13),
              isDense: true,
              filled: true,
              fillColor: context.colorBgTertiary,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: context.colorBgTertiary,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.colorBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: context.colorTextPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                  Text(subtitle,
                      style: TextStyle(
                          color: context.colorTextSecondary, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: context.colorTextMuted, size: 18),
          ],
        ),
      ),
    );
  }
}






