enum HiitMode {
  tabata,
  emom,
  amrap,
  forTime,
  mix;

  String get apiValue => switch (this) {
        HiitMode.forTime => 'for_time',
        _ => name,
      };

  static HiitMode fromApi(String value) => switch (value) {
        'for_time' => HiitMode.forTime,
        'tabata' => HiitMode.tabata,
        'emom' => HiitMode.emom,
        'amrap' => HiitMode.amrap,
        'mix' => HiitMode.mix,
        _ => HiitMode.tabata,
      };

  String get label => switch (this) {
        HiitMode.tabata => 'Tabata',
        HiitMode.emom => 'EMOM',
        HiitMode.amrap => 'AMRAP',
        HiitMode.forTime => 'For Time',
        HiitMode.mix => 'Circuito MIX',
      };

  String get description => switch (this) {
        HiitMode.tabata => '20s trabajo · 10s descanso · 8 rondas',
        HiitMode.emom => 'Cada minuto al minuto',
        HiitMode.amrap => 'Máximas rondas en tiempo fijo',
        HiitMode.forTime => 'Completa el circuito lo más rápido posible',
        HiitMode.mix => 'Configura trabajo/descanso por ejercicio',
      };
}

class HiitExerciseRef {
  final String name;
  final String? exerciseId;
  final String? imageUrl;
  final int? workSeconds;
  final int? restSeconds;

  const HiitExerciseRef({
    required this.name,
    this.exerciseId,
    this.imageUrl,
    this.workSeconds,
    this.restSeconds,
  });

  factory HiitExerciseRef.fromJson(Map<String, dynamic> j) => HiitExerciseRef(
        name: j['name'] as String? ?? '',
        exerciseId: j['exerciseId'] as String?,
        imageUrl: j['imageUrl'] as String?,
        workSeconds: j['workSeconds'] as int?,
        restSeconds: j['restSeconds'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        if (exerciseId != null) 'exerciseId': exerciseId,
        if (imageUrl != null) 'imageUrl': imageUrl,
        if (workSeconds != null) 'workSeconds': workSeconds,
        if (restSeconds != null) 'restSeconds': restSeconds,
      };

  HiitExerciseRef copyWith({
    String? name,
    String? exerciseId,
    String? imageUrl,
    int? workSeconds,
    int? restSeconds,
  }) =>
      HiitExerciseRef(
        name: name ?? this.name,
        exerciseId: exerciseId ?? this.exerciseId,
        imageUrl: imageUrl ?? this.imageUrl,
        workSeconds: workSeconds ?? this.workSeconds,
        restSeconds: restSeconds ?? this.restSeconds,
      );
}

class HiitConfig {
  final HiitMode mode;
  final int workSeconds;
  final int restSeconds;
  final int restBetweenRounds;
  final int rounds;
  final int totalSeconds;
  final List<HiitExerciseRef> exercises;

  const HiitConfig({
    required this.mode,
    this.workSeconds = 20,
    this.restSeconds = 10,
    this.restBetweenRounds = 0,
    this.rounds = 8,
    this.totalSeconds = 600,
    this.exercises = const [],
  });

  factory HiitConfig.defaultFor(HiitMode mode) => switch (mode) {
        HiitMode.tabata => const HiitConfig(
            mode: HiitMode.tabata,
            workSeconds: 20,
            restSeconds: 10,
            rounds: 8,
            exercises: [HiitExerciseRef(name: 'Burpees')],
          ),
        HiitMode.emom => const HiitConfig(
            mode: HiitMode.emom,
            workSeconds: 40,
            restSeconds: 20,
            totalSeconds: 600,
            exercises: [HiitExerciseRef(name: 'Sentadillas')],
          ),
        HiitMode.amrap => const HiitConfig(
            mode: HiitMode.amrap,
            totalSeconds: 720,
            exercises: [
              HiitExerciseRef(name: 'Burpees'),
              HiitExerciseRef(name: 'Saltos'),
              HiitExerciseRef(name: 'Flexiones'),
            ],
          ),
        HiitMode.forTime => const HiitConfig(
            mode: HiitMode.forTime,
            rounds: 5,
            restBetweenRounds: 30,
            exercises: [
              HiitExerciseRef(name: 'Burpees'),
              HiitExerciseRef(name: 'Sentadillas'),
            ],
          ),
        HiitMode.mix => const HiitConfig(
            mode: HiitMode.mix,
            rounds: 3,
            restBetweenRounds: 60,
            exercises: [
              HiitExerciseRef(name: 'Burpees', workSeconds: 30, restSeconds: 15),
              HiitExerciseRef(
                  name: 'Sentadillas', workSeconds: 45, restSeconds: 15),
            ],
          ),
      };

  factory HiitConfig.fromJson(Map<String, dynamic> j) => HiitConfig(
        mode: HiitMode.fromApi(j['mode'] as String? ?? 'tabata'),
        workSeconds: j['workSeconds'] as int? ?? 20,
        restSeconds: j['restSeconds'] as int? ?? 10,
        restBetweenRounds: j['restBetweenRounds'] as int? ?? 0,
        rounds: j['rounds'] as int? ?? 8,
        totalSeconds: j['totalSeconds'] as int? ?? 600,
        exercises: (j['exercises'] as List<dynamic>? ?? [])
            .map((e) => HiitExerciseRef.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'mode': mode.apiValue,
        'workSeconds': workSeconds,
        'restSeconds': restSeconds,
        'restBetweenRounds': restBetweenRounds,
        'rounds': rounds,
        'totalSeconds': totalSeconds,
        'exercises': exercises.map((e) => e.toJson()).toList(),
      };

  HiitConfig copyWith({
    HiitMode? mode,
    int? workSeconds,
    int? restSeconds,
    int? restBetweenRounds,
    int? rounds,
    int? totalSeconds,
    List<HiitExerciseRef>? exercises,
  }) =>
      HiitConfig(
        mode: mode ?? this.mode,
        workSeconds: workSeconds ?? this.workSeconds,
        restSeconds: restSeconds ?? this.restSeconds,
        restBetweenRounds: restBetweenRounds ?? this.restBetweenRounds,
        rounds: rounds ?? this.rounds,
        totalSeconds: totalSeconds ?? this.totalSeconds,
        exercises: exercises ?? this.exercises,
      );
}

class HiitWorkout {
  final String id;
  final String name;
  final HiitMode mode;
  final HiitConfig config;
  final bool isPublic;
  final DateTime createdAt;

  const HiitWorkout({
    required this.id,
    required this.name,
    required this.mode,
    required this.config,
    required this.isPublic,
    required this.createdAt,
  });

  factory HiitWorkout.fromJson(Map<String, dynamic> j) {
    final mode = HiitMode.fromApi(j['mode'] as String? ?? 'tabata');
    final rawConfig = j['config'];
    final configMap = rawConfig is Map<String, dynamic> ? rawConfig : <String, dynamic>{};
    return HiitWorkout(
      id: j['id'] as String,
      name: j['name'] as String,
      mode: mode,
      config: HiitConfig.fromJson({...configMap, 'mode': j['mode']}),
      isPublic: j['isPublic'] as bool? ?? false,
      createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class HiitSession {
  final String id;
  final String? hiitWorkoutId;
  final String name;
  final HiitMode mode;
  final HiitConfig config;
  final int? totalDurationSeconds;
  final int roundsCompleted;
  final DateTime startedAt;
  final DateTime? endedAt;

  const HiitSession({
    required this.id,
    this.hiitWorkoutId,
    required this.name,
    required this.mode,
    required this.config,
    this.totalDurationSeconds,
    required this.roundsCompleted,
    required this.startedAt,
    this.endedAt,
  });

  factory HiitSession.fromJson(Map<String, dynamic> j) {
    final mode = HiitMode.fromApi(j['mode'] as String? ?? 'tabata');
    final rawConfig = j['config'];
    final configMap = rawConfig is Map<String, dynamic> ? rawConfig : <String, dynamic>{};
    return HiitSession(
      id: j['id'] as String,
      hiitWorkoutId: j['hiitWorkoutId'] as String?,
      name: j['name'] as String,
      mode: mode,
      config: HiitConfig.fromJson({...configMap, 'mode': j['mode']}),
      totalDurationSeconds: j['totalDurationSeconds'] as int?,
      roundsCompleted: j['roundsCompleted'] as int? ?? 0,
      startedAt: DateTime.tryParse(j['startedAt'] as String? ?? '') ?? DateTime.now(),
      endedAt: j['endedAt'] != null
          ? DateTime.tryParse(j['endedAt'] as String)
          : null,
    );
  }
}
