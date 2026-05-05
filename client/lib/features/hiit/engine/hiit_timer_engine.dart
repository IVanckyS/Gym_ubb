import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/hiit_models.dart';

enum HiitPhase { idle, prep, work, rest, restBetweenRounds, done }

class HiitTimerState {
  final HiitPhase phase;
  final int currentRound;
  final int totalRounds;
  final int currentExerciseIndex;
  final Duration remaining;
  final Duration phaseTotal;
  final bool isPaused;
  final int roundsCompleted;

  const HiitTimerState({
    required this.phase,
    required this.currentRound,
    required this.totalRounds,
    required this.currentExerciseIndex,
    required this.remaining,
    required this.phaseTotal,
    required this.isPaused,
    required this.roundsCompleted,
  });

  factory HiitTimerState.initial() => const HiitTimerState(
        phase: HiitPhase.idle,
        currentRound: 1,
        totalRounds: 1,
        currentExerciseIndex: 0,
        remaining: Duration.zero,
        phaseTotal: Duration.zero,
        isPaused: false,
        roundsCompleted: 0,
      );

  double get progress => phaseTotal.inMilliseconds > 0
      ? (remaining.inMilliseconds / phaseTotal.inMilliseconds).clamp(0.0, 1.0)
      : 0.0;

  HiitTimerState copyWith({
    HiitPhase? phase,
    int? currentRound,
    int? totalRounds,
    int? currentExerciseIndex,
    Duration? remaining,
    Duration? phaseTotal,
    bool? isPaused,
    int? roundsCompleted,
  }) =>
      HiitTimerState(
        phase: phase ?? this.phase,
        currentRound: currentRound ?? this.currentRound,
        totalRounds: totalRounds ?? this.totalRounds,
        currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
        remaining: remaining ?? this.remaining,
        phaseTotal: phaseTotal ?? this.phaseTotal,
        isPaused: isPaused ?? this.isPaused,
        roundsCompleted: roundsCompleted ?? this.roundsCompleted,
      );
}

class HiitTimerEngine extends ChangeNotifier {
  HiitConfig? _config;
  HiitTimerState _state = HiitTimerState.initial();

  Timer? _ticker;
  DateTime? _phaseEndTime;
  DateTime? _sessionEndTime; // AMRAP total time limit
  DateTime? _pausedAt;
  DateTime? _sessionStartTime;

  HiitTimerState get state => _state;
  HiitConfig? get config => _config;
  DateTime? get sessionStartTime => _sessionStartTime;

  void start(HiitConfig config) {
    _config = config;
    _sessionStartTime = DateTime.now();

    if (config.mode == HiitMode.amrap) {
      _sessionEndTime = _sessionStartTime!.add(
        Duration(seconds: config.totalSeconds),
      );
    }

    _state = HiitTimerState(
      phase: HiitPhase.idle,
      currentRound: 1,
      totalRounds: _calcTotalRounds(config),
      currentExerciseIndex: 0,
      remaining: Duration.zero,
      phaseTotal: Duration.zero,
      isPaused: false,
      roundsCompleted: 0,
    );

    _ticker = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _tick(),
    );

    _startPhase(HiitPhase.prep, const Duration(seconds: 5));
  }

  int _calcTotalRounds(HiitConfig config) => switch (config.mode) {
        HiitMode.tabata => config.rounds,
        HiitMode.emom => (config.totalSeconds / 60).floor(),
        HiitMode.amrap => 9999,
        HiitMode.forTime => config.rounds,
        HiitMode.mix => config.rounds,
      };

  void pause() {
    if (_state.isPaused || _state.phase == HiitPhase.done) return;
    _pausedAt = DateTime.now();
    _state = _state.copyWith(isPaused: true);
    notifyListeners();
  }

  void resume() {
    if (!_state.isPaused || _pausedAt == null) return;
    final pausedFor = DateTime.now().difference(_pausedAt!);
    _phaseEndTime = _phaseEndTime?.add(pausedFor);
    _sessionEndTime = _sessionEndTime?.add(pausedFor);
    _pausedAt = null;
    _state = _state.copyWith(isPaused: false);
    notifyListeners();
  }

  /// ForTime mode: user taps "Done" to mark the current exercise complete.
  void advanceManually() {
    if (_config?.mode != HiitMode.forTime) return;
    if (_state.phase != HiitPhase.work) return;
    _phaseEndTime = DateTime.now();
  }

  void stop() => _finishSession();

  void _tick() {
    if (_state.isPaused) return;
    final now = DateTime.now();

    // AMRAP: check total time limit
    if (_sessionEndTime != null && now.isAfter(_sessionEndTime!)) {
      _finishSession();
      return;
    }

    final remaining = _phaseEndTime!.difference(now);
    if (remaining <= Duration.zero) {
      _nextStep();
      return;
    }
    _state = _state.copyWith(remaining: remaining);
    notifyListeners();
  }

  void _startPhase(HiitPhase phase, Duration duration) {
    _phaseEndTime = DateTime.now().add(duration);
    _state = _state.copyWith(
      phase: phase,
      remaining: duration,
      phaseTotal: duration,
    );
    notifyListeners();
  }

  void _nextStep() {
    final config = _config!;

    switch (_state.phase) {
      case HiitPhase.prep:
        _startWork();

      case HiitPhase.work:
        _startRest();

      case HiitPhase.rest:
        final nextExIdx = _state.currentExerciseIndex + 1;
        if (nextExIdx < config.exercises.length) {
          _state = _state.copyWith(currentExerciseIndex: nextExIdx);
          _startWork();
        } else {
          final nextRound = _state.currentRound + 1;
          final newCompleted = _state.roundsCompleted + 1;
          final isDone =
              config.mode != HiitMode.amrap && nextRound > _state.totalRounds;

          if (isDone) {
            _finishSession();
            return;
          }

          _state = _state.copyWith(
            currentRound: nextRound,
            currentExerciseIndex: 0,
            roundsCompleted: newCompleted,
          );

          final restBetween = config.restBetweenRounds;
          if (restBetween > 0) {
            _startPhase(
                HiitPhase.restBetweenRounds, Duration(seconds: restBetween));
          } else {
            _startWork();
          }
        }

      case HiitPhase.restBetweenRounds:
        _startWork();

      case HiitPhase.done:
      case HiitPhase.idle:
        break;
    }
  }

  void _startWork() {
    final config = _config!;
    final ex = config.exercises[_state.currentExerciseIndex];
    final workSecs = ex.workSeconds ?? config.workSeconds;
    _startPhase(HiitPhase.work, Duration(seconds: workSecs));
  }

  void _startRest() {
    final config = _config!;
    final ex = config.exercises[_state.currentExerciseIndex];

    int restSecs;
    if (config.mode == HiitMode.emom) {
      final workUsed = ex.workSeconds ?? config.workSeconds;
      restSecs = (60 - workUsed).clamp(0, 60);
    } else {
      restSecs = ex.restSeconds ?? config.restSeconds;
    }

    if (restSecs <= 0) {
      // No rest — advance directly from the rest perspective
      _state = _state.copyWith(phase: HiitPhase.rest);
      _nextStep();
      return;
    }

    _startPhase(HiitPhase.rest, Duration(seconds: restSecs));
  }

  void _finishSession() {
    _ticker?.cancel();
    _ticker = null;
    _state = _state.copyWith(
      phase: HiitPhase.done,
      remaining: Duration.zero,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
