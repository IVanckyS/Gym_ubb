import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hiit_models.dart';
import '../data/hiit_service.dart';
import '../engine/hiit_timer_engine.dart';

class HiitSessionScreen extends StatefulWidget {
  final HiitConfig config;

  const HiitSessionScreen({required this.config, super.key});

  @override
  State<HiitSessionScreen> createState() => _HiitSessionScreenState();
}

class _HiitSessionScreenState extends State<HiitSessionScreen> {
  late final HiitTimerEngine _engine;

  // One dedicated AudioPlayer per sound file — avoids shared-state
  // issues that cause silent failures after the first play.
  static const _sfxNames = [
    'prep_beep', 'work_start', 'rest_start', 'round_complete',
    'countdown_beep', 'final', 'workout_finish',
  ];
  late final Map<String, AudioPlayer> _sfx;

  HiitPhase _prevPhase = HiitPhase.idle;
  final Set<int> _beepedSeconds = {};
  bool _saving = false;
  bool _summaryShown = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) WakelockPlus.enable();
    _sfx = {
      for (final name in _sfxNames)
        name: AudioPlayer()..setReleaseMode(ReleaseMode.stop),
    };
    _engine = HiitTimerEngine();
    _engine.addListener(_onStateChange);
    _engine.start(widget.config);
  }

  @override
  void dispose() {
    if (!kIsWeb) WakelockPlus.disable();
    _engine.removeListener(_onStateChange);
    _engine.dispose();
    for (final p in _sfx.values) {
      p.dispose();
    }
    super.dispose();
  }

  void _onStateChange() {
    final state = _engine.state;

    final justChangedPhase = state.phase != _prevPhase;
    if (justChangedPhase) {
      _beepedSeconds.clear();
      switch (state.phase) {
        case HiitPhase.prep:
          break;                          // silence — countdown beeps are enough
        case HiitPhase.work:
          _play('work_start.mp3');        // GO! (simultaneous, different player)
        case HiitPhase.rest:
          _play('rest_start.mp3');        // rest between exercises
        case HiitPhase.restBetweenRounds:
          _play('round_complete.mp3');    // round finished
        case HiitPhase.done:
          _play('workout_finish.mp3');    // workout complete
          if (!_summaryShown) {
            _summaryShown = true;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _showSummary());
          }
        case HiitPhase.idle:
          break;
      }
      _prevPhase = state.phase;
    }

    // 3-2-1 countdown beeps on all phases (alert at end of work, signal before work)
    if (!justChangedPhase &&
        state.phase != HiitPhase.idle &&
        state.phase != HiitPhase.done) {
      final secs = state.remaining.inSeconds;
      if (secs <= 3 && secs >= 0 && !_beepedSeconds.contains(secs)) {
        _beepedSeconds.add(secs);
        _play('countdown_beep.mp3');
      }
    }

    if (mounted) setState(() {});
  }

  void _play(String filename) {
    final key = filename.replaceAll('.mp3', '');
    // AssetSource uses dart:io internally which is unavailable on web.
    // UrlSource loads via HTTP from the Flutter web asset-serving path.
    final src = kIsWeb
        ? UrlSource('assets/sounds/$filename')
        : AssetSource('sounds/$filename');
    _sfx[key]?.play(src);
  }

  Future<void> _showSummary() async {
    if (!mounted) return;
    final state = _engine.state;
    final startedAt = _engine.sessionStartTime ?? DateTime.now();
    final endedAt = DateTime.now();
    final durationSecs = endedAt.difference(startedAt).inSeconds;

    final save = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colorBgSecondary,
        title: const Text('¡Sesión completada!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 48, color: Color(0xFFF9B214)),
            const SizedBox(height: 12),
            _StatRow(label: 'Rondas', value: '${state.roundsCompleted}'),
            _StatRow(label: 'Duración', value: _fmtDuration(durationSecs)),
            _StatRow(label: 'Modo', value: widget.config.mode.label),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentPrimary),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (save == true && mounted) {
      setState(() => _saving = true);
      try {
        await hiitService.saveSession(
          name: '${widget.config.mode.label} ${_fmtDate(startedAt)}',
          config: widget.config,
          totalDurationSeconds: durationSecs,
          roundsCompleted: state.roundsCompleted,
          startedAt: startedAt,
          endedAt: endedAt,
        );
      } catch (_) {}
    }

    if (mounted) context.go('/hiit');
  }

  String _fmtDuration(int secs) {
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  String _fmtDate(DateTime dt) {
    const months = [
      'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  static Color _phaseColor(HiitPhase phase) => switch (phase) {
        HiitPhase.prep => const Color(0xFFF9B214),
        HiitPhase.work => const Color(0xFFEF4444),
        HiitPhase.rest => const Color(0xFF10B981),
        HiitPhase.restBetweenRounds => const Color(0xFF10B981),
        HiitPhase.done => AppColors.accentGreen,
        HiitPhase.idle => AppColors.textMuted,
      };

  static String _phaseLabel(HiitPhase phase) => switch (phase) {
        HiitPhase.prep => 'PREPÁRATE',
        HiitPhase.work => 'TRABAJA',
        HiitPhase.rest => 'DESCANSA',
        HiitPhase.restBetweenRounds => 'DESCANSA',
        HiitPhase.done => 'LISTO',
        HiitPhase.idle => '',
      };

  void _confirmStop() {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colorBgSecondary,
        title: const Text('¿Terminar sesión?'),
        content: const Text('Se perderá el progreso actual.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Continuar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: AppColors.accentSecondary),
            child: const Text('Terminar'),
          ),
        ],
      ),
    ).then((v) {
      if (v == true && mounted) context.go('/hiit');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = _engine.state;
    final config = widget.config;
    final color = _phaseColor(state.phase);
    final label = _phaseLabel(state.phase);
    final isWork = state.phase == HiitPhase.work;

    final currentEx = state.currentExerciseIndex < config.exercises.length
        ? config.exercises[state.currentExerciseIndex]
        : null;

    final totalSecs = state.phaseTotal.inSeconds.clamp(1, 999);
    final elapsedSecs =
        (state.phaseTotal - state.remaining).inSeconds.clamp(0, totalSecs);

    final workImageUrl =
        isWork ? (currentEx?.imageUrl?.isNotEmpty == true ? currentEx!.imageUrl : null) : null;
    final showImage = workImageUrl != null;

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    color: AppColors.textMuted,
                    onPressed: _confirmStop,
                  ),
                  const Spacer(),
                  Text(config.mode.label,
                      style: Theme.of(context).textTheme.titleMedium),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            // ── Round counter ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                config.mode == HiitMode.amrap
                    ? 'Ronda ${state.roundsCompleted + 1}'
                    : 'Ronda ${state.currentRound} / ${state.totalRounds}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.colorTextSecondary,
                    ),
              ),
            ),

            // ── Ring + imagen ejercicio + info ────────────────────────────────
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Imagen del ejercicio (solo en WORK con imagen)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeInOut,
                      height: showImage ? 144 : 0,
                      child: workImageUrl != null
                          ? Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _ExerciseImage(
                                imageUrl: workImageUrl,
                                color: color,
                              ),
                            )
                          : null,
                    ),

                    // Ring con countdown
                    SizedBox(
                      width: 220,
                      height: 220,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _CountdownRing(
                            progress: state.progress,
                            color: color,
                            totalSeconds: totalSecs,
                            elapsedSeconds: elapsedSecs,
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                label,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                style: TextStyle(
                                  color: color,
                                  fontSize: isWork ? 52 : 72,
                                  fontWeight: FontWeight.w700,
                                  height: 1,
                                ),
                                child: Text(
                                    state.remaining.inSeconds.toString()),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Nombre del ejercicio actual
                    if (currentEx != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          currentEx.name,
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),

                    // Dots indicadores de ejercicio
                    if (config.exercises.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children:
                              List.generate(config.exercises.length, (i) {
                            final active = i == state.currentExerciseIndex;
                            return Container(
                              width: 8,
                              height: 8,
                              margin:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? color
                                    : color.withValues(alpha: 0.3),
                              ),
                            );
                          }),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // ── Controls ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (config.mode == HiitMode.forTime &&
                      state.phase == HiitPhase.work)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _engine.advanceManually,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Listo'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                    )
                  else
                    FilledButton.icon(
                      onPressed: state.phase == HiitPhase.done
                          ? null
                          : (state.isPaused
                              ? _engine.resume
                              : _engine.pause),
                      icon: Icon(state.isPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded),
                      label: Text(state.isPaused ? 'Continuar' : 'Pausar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colorBgSecondary,
                        foregroundColor: AppColors.textPrimary,
                        minimumSize: const Size(160, 52),
                      ),
                    ),
                ],
              ),
            ),

            if (_saving)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Imagen del ejercicio (WORK phase) ────────────────────────────────────────

class _ExerciseImage extends StatelessWidget {
  final String imageUrl;
  final Color color;

  const _ExerciseImage({required this.imageUrl, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        color: color.withValues(alpha: 0.08),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: CachedNetworkImage(
          imageUrl: imageUrl,
          fit: BoxFit.cover,
          placeholder: (_, _) => Center(
            child: Icon(Icons.fitness_center_rounded,
                color: color.withValues(alpha: 0.5), size: 36),
          ),
          errorWidget: (_, _, _) => Center(
            child: Icon(Icons.fitness_center_rounded,
                color: color.withValues(alpha: 0.5), size: 36),
          ),
        ),
      ),
    );
  }
}

// ── Stat row for summary dialog ───────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final String label;
  final String value;

  const _StatRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.colorTextSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── Countdown ring ────────────────────────────────────────────────────────────

class _CountdownRing extends StatelessWidget {
  final double progress;
  final Color color;
  final int totalSeconds;
  final int elapsedSeconds;

  const _CountdownRing({
    required this.progress,
    required this.color,
    required this.totalSeconds,
    required this.elapsedSeconds,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingPainter(
        progress: progress,
        color: color,
        totalSeconds: totalSeconds,
        elapsedSeconds: elapsedSeconds,
      ),
      child: const SizedBox(width: 220, height: 220),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final int totalSeconds;
  final int elapsedSeconds;

  const _RingPainter({
    required this.progress,
    required this.color,
    required this.totalSeconds,
    required this.elapsedSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 10.0;

    // Background track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Elapsed arc — fills clockwise from top as time passes
    final elapsed = 1.0 - progress; // progress = remaining/total, elapsed = 1 - that
    if (elapsed > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * elapsed,
        false,
        Paint()
          ..color = color.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Second dots over the ring — use same continuous elapsed as arc to stay in sync
    // ceil: dot lights the instant the arc enters its zone (no perceived lag)
    final n = totalSeconds.clamp(1, 60);
    final litCount = (elapsed * n).ceil().clamp(0, n);
    final smallDots = n > 30;
    final dotR = smallDots ? 4.0 : 6.0;
    final litDotR = smallDots ? 5.5 : 7.5;

    for (int i = 0; i < n; i++) {
      final angle = (i / n) * 2 * pi - pi / 2;
      final x = center.dx + radius * cos(angle);
      final y = center.dy + radius * sin(angle);
      final dotCenter = Offset(x, y);
      final isLit = i < litCount;

      if (isLit) {
        // Glow halo
        canvas.drawCircle(
          dotCenter,
          litDotR + 3,
          Paint()..color = color.withValues(alpha: 0.25),
        );
        canvas.drawCircle(
          dotCenter,
          litDotR,
          Paint()..color = color,
        );
      } else {
        canvas.drawCircle(
          dotCenter,
          dotR,
          Paint()..color = color.withValues(alpha: 0.22),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.totalSeconds != totalSeconds ||
      old.elapsedSeconds != elapsedSeconds;
}
