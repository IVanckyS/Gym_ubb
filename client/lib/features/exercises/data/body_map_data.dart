import 'package:flutter/material.dart';

// ── Data classes ──────────────────────────────────────────────────────────────

class MuscleZone {
  final String id;
  final String name;
  final String muscleGroup;
  final String points; // SVG polygon points "x1,y1 x2,y2 ..."

  const MuscleZone({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.points,
  });
}

class JointPoint {
  final String id;
  final String name;
  final double x;
  final double y;
  final String family;

  const JointPoint({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.family,
  });
}

class JointExercise {
  final String id;
  final String name;
  final String type; // 'movilidad' | 'fortalecimiento'
  final String jointFamily;
  final List<String> instructions;
  final String? benefits;
  final String? whenToUse;
  final String? videoUrl;

  const JointExercise({
    required this.id,
    required this.name,
    required this.type,
    required this.jointFamily,
    required this.instructions,
    this.benefits,
    this.whenToUse,
    this.videoUrl,
  });
}

// ── BodyMapData ───────────────────────────────────────────────────────────────

class BodyMapData {
  BodyMapData._();

  // viewBox: 658 × 1024
  // Key anchors from SVG path data:
  //   Shoulders: left x≈242 y≈192, right x≈403 y≈192
  //   Left arm at elbow: x≈88 y≈511  (arm angles outward-downward)
  //   Right arm at elbow (mirrored): x≈570 y≈511
  //   Body center: x=329

  static const Map<String, Color> muscleColors = {
    'Pecho': Color(0xFF3b82f6),
    'Espalda': Color(0xFF8b5cf6),
    'Piernas': Color(0xFF22c55e),
    'Hombros': Color(0xFFf97316),
    'Brazos': Color(0xFFec4899),
    'Core': Color(0xFFeab308),
    'Glúteos': Color(0xFFef4444),
  };

  static const Map<String, String> muscleGroupDisplayName = {
    'pecho': 'Pecho',
    'espalda': 'Espalda',
    'piernas': 'Piernas',
    'hombros': 'Hombros',
    'brazos': 'Brazos',
    'core': 'Core',
    'gluteos': 'Glúteos',
  };

  static const Map<String, String> muscleEmoji = {
    'Pecho': '💪',
    'Espalda': '🏋️',
    'Piernas': '🦵',
    'Hombros': '🔝',
    'Brazos': '💪',
    'Core': '⚡',
    'Glúteos': '🍑',
  };

  static const Map<String, String> jointFamilyNames = {
    'shoulder': 'Hombro',
    'elbow': 'Codo',
    'wrist': 'Muñeca',
    'hip': 'Cadera',
    'knee': 'Rodilla',
    'ankle': 'Tobillo',
    'cervical': 'Cervical',
    'lumbar': 'Lumbar',
  };

  // ── Muscle zones — FRONT ──────────────────────────────────────────────────
  // Arms angle out from shoulder (x≈242/403, y≈192) to elbow (x≈88/570, y≈511)
  // giving a diagonal slope of ~Δx=-51/+51 per 100px of y.

  static const List<MuscleZone> zonesFront = [
    // Pectorales (entre clavículas y línea submamaria)
    MuscleZone(
      id: 'chest_left',
      name: 'Pectoral izquierdo',
      muscleGroup: 'Pecho',
      points: '222,148 329,143 329,258 222,262',
    ),
    MuscleZone(
      id: 'chest_right',
      name: 'Pectoral derecho',
      muscleGroup: 'Pecho',
      points: '329,143 436,148 436,262 329,258',
    ),
    // Deltoides anterior (cubre la cabeza del hombro, frontal)
    MuscleZone(
      id: 'shoulder_left',
      name: 'Hombro izquierdo',
      muscleGroup: 'Hombros',
      points: '188,128 242,118 252,205 196,215',
    ),
    MuscleZone(
      id: 'shoulder_right',
      name: 'Hombro derecho',
      muscleGroup: 'Hombros',
      points: '416,118 470,128 462,215 406,205',
    ),
    // Bíceps – zona del brazo superior, siguiendo la diagonal del brazo
    MuscleZone(
      id: 'bicep_left',
      name: 'Bíceps izquierdo',
      muscleGroup: 'Brazos',
      points: '196,210 242,200 200,400 155,408',
    ),
    MuscleZone(
      id: 'bicep_right',
      name: 'Bíceps derecho',
      muscleGroup: 'Brazos',
      points: '416,200 462,210 503,408 458,400',
    ),
    // Antebrazo – continuación diagonal hasta la muñeca
    MuscleZone(
      id: 'forearm_left',
      name: 'Antebrazo izquierdo',
      muscleGroup: 'Brazos',
      points: '155,408 200,400 163,538 118,542',
    ),
    MuscleZone(
      id: 'forearm_right',
      name: 'Antebrazo derecho',
      muscleGroup: 'Brazos',
      points: '458,400 503,408 540,542 495,538',
    ),
    // Abdominales (zona central del torso)
    MuscleZone(
      id: 'abs',
      name: 'Abdominales',
      muscleGroup: 'Core',
      points: '228,258 430,258 424,462 234,462',
    ),
    // Oblicuos (laterales del torso)
    MuscleZone(
      id: 'oblique_left',
      name: 'Oblicuo izquierdo',
      muscleGroup: 'Core',
      points: '190,210 232,202 240,462 196,445',
    ),
    MuscleZone(
      id: 'oblique_right',
      name: 'Oblicuo derecho',
      muscleGroup: 'Core',
      points: '426,202 468,210 462,445 418,462',
    ),
    // Flexores de cadera / inguinal
    MuscleZone(
      id: 'hipflexor_left',
      name: 'Flexor cadera izquierdo',
      muscleGroup: 'Piernas',
      points: '234,462 329,462 329,528 237,528',
    ),
    MuscleZone(
      id: 'hipflexor_right',
      name: 'Flexor cadera derecho',
      muscleGroup: 'Piernas',
      points: '329,462 424,462 421,528 329,528',
    ),
    // Cuádriceps
    MuscleZone(
      id: 'quad_left',
      name: 'Cuádriceps izquierdo',
      muscleGroup: 'Piernas',
      points: '237,528 329,528 329,762 242,762',
    ),
    MuscleZone(
      id: 'quad_right',
      name: 'Cuádriceps derecho',
      muscleGroup: 'Piernas',
      points: '329,528 421,528 416,762 329,762',
    ),
    // Tibial anterior / parte frontal de la pierna baja
    MuscleZone(
      id: 'tibialis_left',
      name: 'Tibial izquierdo',
      muscleGroup: 'Piernas',
      points: '244,778 314,778 310,948 248,948',
    ),
    MuscleZone(
      id: 'tibialis_right',
      name: 'Tibial derecho',
      muscleGroup: 'Piernas',
      points: '344,778 414,778 410,948 348,948',
    ),
  ];

  // ── Muscle zones — BACK ───────────────────────────────────────────────────

  static const List<MuscleZone> zonesBack = [
    // Trapecio (parte superior de la espalda, entre hombros)
    MuscleZone(
      id: 'trapezius',
      name: 'Trapecio',
      muscleGroup: 'Espalda',
      points: '228,135 430,135 412,215 246,215',
    ),
    // Dorsal ancho (costado de la espalda – gran superficie)
    MuscleZone(
      id: 'lat_left',
      name: 'Dorsal izquierdo',
      muscleGroup: 'Espalda',
      points: '188,208 320,208 324,445 192,412',
    ),
    MuscleZone(
      id: 'lat_right',
      name: 'Dorsal derecho',
      muscleGroup: 'Espalda',
      points: '338,208 470,208 466,412 334,445',
    ),
    // Deltoides posterior
    MuscleZone(
      id: 'reardelt_left',
      name: 'Deltoides posterior izquierdo',
      muscleGroup: 'Hombros',
      points: '188,120 242,110 252,212 196,220',
    ),
    MuscleZone(
      id: 'reardelt_right',
      name: 'Deltoides posterior derecho',
      muscleGroup: 'Hombros',
      points: '416,110 470,120 462,220 406,212',
    ),
    // Tríceps (brazo posterior, misma diagonal que bíceps)
    MuscleZone(
      id: 'tricep_left',
      name: 'Tríceps izquierdo',
      muscleGroup: 'Brazos',
      points: '196,215 242,205 200,398 155,406',
    ),
    MuscleZone(
      id: 'tricep_right',
      name: 'Tríceps derecho',
      muscleGroup: 'Brazos',
      points: '416,205 462,215 503,406 458,398',
    ),
    // Antebrazo posterior
    MuscleZone(
      id: 'forearm_left_back',
      name: 'Antebrazo izquierdo',
      muscleGroup: 'Brazos',
      points: '155,406 200,398 163,532 118,536',
    ),
    MuscleZone(
      id: 'forearm_right_back',
      name: 'Antebrazo derecho',
      muscleGroup: 'Brazos',
      points: '458,398 503,406 540,536 495,532',
    ),
    // Erector espinal (columna central posterior)
    MuscleZone(
      id: 'erector',
      name: 'Erector espinal',
      muscleGroup: 'Espalda',
      points: '282,248 376,248 376,458 282,458',
    ),
    // Glúteos
    MuscleZone(
      id: 'glute_left',
      name: 'Glúteo izquierdo',
      muscleGroup: 'Glúteos',
      points: '234,458 329,458 329,572 237,572',
    ),
    MuscleZone(
      id: 'glute_right',
      name: 'Glúteo derecho',
      muscleGroup: 'Glúteos',
      points: '329,458 424,458 421,572 329,572',
    ),
    // Isquiotibiales
    MuscleZone(
      id: 'hamstring_left',
      name: 'Isquiotibial izquierdo',
      muscleGroup: 'Piernas',
      points: '237,572 329,572 329,762 242,762',
    ),
    MuscleZone(
      id: 'hamstring_right',
      name: 'Isquiotibial derecho',
      muscleGroup: 'Piernas',
      points: '329,572 421,572 416,762 329,762',
    ),
    // Gemelos
    MuscleZone(
      id: 'calf_left',
      name: 'Gemelo izquierdo',
      muscleGroup: 'Piernas',
      points: '244,778 313,778 309,948 248,948',
    ),
    MuscleZone(
      id: 'calf_right',
      name: 'Gemelo derecho',
      muscleGroup: 'Piernas',
      points: '345,778 414,778 410,948 349,948',
    ),
  ];

  // ── Joint points — FRONT ──────────────────────────────────────────────────

  static const List<JointPoint> jointsFront = [
    JointPoint(id: 'shoulder_left',  name: 'Hombro izquierdo',  x: 225, y: 192, family: 'shoulder'),
    JointPoint(id: 'shoulder_right', name: 'Hombro derecho',    x: 433, y: 192, family: 'shoulder'),
    JointPoint(id: 'elbow_left',     name: 'Codo izquierdo',    x: 168, y: 410, family: 'elbow'),
    JointPoint(id: 'elbow_right',    name: 'Codo derecho',      x: 490, y: 410, family: 'elbow'),
    JointPoint(id: 'wrist_left',     name: 'Muñeca izquierda',  x: 132, y: 542, family: 'wrist'),
    JointPoint(id: 'wrist_right',    name: 'Muñeca derecha',    x: 526, y: 542, family: 'wrist'),
    JointPoint(id: 'hip_left',       name: 'Cadera izquierda',  x: 268, y: 520, family: 'hip'),
    JointPoint(id: 'hip_right',      name: 'Cadera derecha',    x: 390, y: 520, family: 'hip'),
    JointPoint(id: 'knee_left',      name: 'Rodilla izquierda', x: 256, y: 770, family: 'knee'),
    JointPoint(id: 'knee_right',     name: 'Rodilla derecha',   x: 402, y: 770, family: 'knee'),
    JointPoint(id: 'ankle_left',     name: 'Tobillo izquierdo', x: 252, y: 955, family: 'ankle'),
    JointPoint(id: 'ankle_right',    name: 'Tobillo derecho',   x: 406, y: 955, family: 'ankle'),
  ];

  // ── Joint points — BACK ───────────────────────────────────────────────────

  static const List<JointPoint> jointsBack = [
    JointPoint(id: 'cervical',          name: 'Cervical',             x: 329, y: 120, family: 'cervical'),
    JointPoint(id: 'shoulder_left_back',  name: 'Hombro izquierdo',   x: 225, y: 198, family: 'shoulder'),
    JointPoint(id: 'shoulder_right_back', name: 'Hombro derecho',     x: 433, y: 198, family: 'shoulder'),
    JointPoint(id: 'elbow_left_back',   name: 'Codo izquierdo',       x: 168, y: 408, family: 'elbow'),
    JointPoint(id: 'elbow_right_back',  name: 'Codo derecho',         x: 490, y: 408, family: 'elbow'),
    JointPoint(id: 'wrist_left_back',   name: 'Muñeca izquierda',     x: 132, y: 535, family: 'wrist'),
    JointPoint(id: 'wrist_right_back',  name: 'Muñeca derecha',       x: 526, y: 535, family: 'wrist'),
    JointPoint(id: 'lumbar',            name: 'Lumbar',               x: 329, y: 450, family: 'lumbar'),
    JointPoint(id: 'hip_left_back',     name: 'Cadera izquierda',     x: 268, y: 522, family: 'hip'),
    JointPoint(id: 'hip_right_back',    name: 'Cadera derecha',       x: 390, y: 522, family: 'hip'),
    JointPoint(id: 'knee_left_back',    name: 'Rodilla izquierda',    x: 256, y: 770, family: 'knee'),
    JointPoint(id: 'knee_right_back',   name: 'Rodilla derecha',      x: 402, y: 770, family: 'knee'),
    JointPoint(id: 'ankle_left_back',   name: 'Tobillo izquierdo',    x: 252, y: 955, family: 'ankle'),
    JointPoint(id: 'ankle_right_back',  name: 'Tobillo derecho',      x: 406, y: 955, family: 'ankle'),
  ];

  // ── Joint exercises ───────────────────────────────────────────────────────

  static const List<JointExercise> jointExercises = [
    // Shoulder
    JointExercise(
      id: 'sj1',
      name: 'Rotaciones de hombro',
      type: 'movilidad',
      jointFamily: 'shoulder',
      instructions: [
        'Brazos extendidos a los lados.',
        'Realiza círculos pequeños hacia adelante.',
        'Luego hacia atrás.',
      ],
      whenToUse: 'Antes de entrenar pecho, espalda o hombros.',
    ),
    JointExercise(
      id: 'sj2',
      name: 'Band Pull-Aparts',
      type: 'fortalecimiento',
      jointFamily: 'shoulder',
      instructions: [
        'Sostén una banda elástica frente a ti.',
        'Separa los brazos hasta que la banda toque el pecho.',
        'Vuelve controladamente.',
      ],
      benefits: 'Fortalece los rotadores externos y mejora la postura.',
    ),
    JointExercise(
      id: 'sj3',
      name: 'Rotación externa con banda',
      type: 'fortalecimiento',
      jointFamily: 'shoulder',
      instructions: [
        'Codo pegado al cuerpo a 90°.',
        'Rota el brazo hacia afuera contra la resistencia.',
        'Vuelve lentamente.',
      ],
      whenToUse: 'Rehabilitación y prevención de lesiones del manguito rotador.',
    ),
    // Elbow
    JointExercise(
      id: 'ej1',
      name: 'Flexo-extensión de codo',
      type: 'movilidad',
      jointFamily: 'elbow',
      instructions: [
        'Brazo extendido.',
        'Flexiona lentamente el codo.',
        'Extiende completamente.',
        'Repite 10 veces.',
      ],
      whenToUse: 'Calentamiento antes de ejercicios de brazos.',
    ),
    JointExercise(
      id: 'ej2',
      name: 'Supinación/Pronación',
      type: 'movilidad',
      jointFamily: 'elbow',
      instructions: [
        'Codo a 90°, palma mirando arriba.',
        'Gira el antebrazo hacia abajo.',
        'Vuelve a la posición inicial.',
      ],
      benefits: 'Mejora la movilidad del antebrazo.',
    ),
    // Wrist
    JointExercise(
      id: 'wj1',
      name: 'Flexión/Extensión de muñeca',
      type: 'movilidad',
      jointFamily: 'wrist',
      instructions: [
        'Antebrazo apoyado.',
        'Flexiona la muñeca hacia arriba y hacia abajo.',
        '10 repeticiones cada dirección.',
      ],
      whenToUse: 'Antes de ejercicios con barra o mancuernas.',
    ),
    JointExercise(
      id: 'wj2',
      name: 'Círculos de muñeca',
      type: 'movilidad',
      jointFamily: 'wrist',
      instructions: [
        'Realiza círculos lentos con la muñeca.',
        '5 en cada dirección.',
      ],
      benefits: 'Lubrica la articulación de la muñeca.',
    ),
    // Hip
    JointExercise(
      id: 'hj1',
      name: 'Círculos de cadera',
      type: 'movilidad',
      jointFamily: 'hip',
      instructions: [
        'De pie, manos en caderas.',
        'Realiza círculos amplios con la cadera.',
        '5 en cada sentido.',
      ],
      whenToUse: 'Antes de sentadillas, peso muerto o hip thrust.',
    ),
    JointExercise(
      id: 'hj2',
      name: 'Hip Airplane',
      type: 'movilidad',
      jointFamily: 'hip',
      instructions: [
        'De pie en una pierna.',
        'Inclina el torso mientras rotas la cadera.',
        'Mantén el equilibrio 2 seg.',
      ],
      benefits: 'Mejora el control y la estabilidad de cadera.',
    ),
    JointExercise(
      id: 'hj3',
      name: 'Estiramiento 90/90',
      type: 'movilidad',
      jointFamily: 'hip',
      instructions: [
        'Siéntate con ambas rodillas a 90°.',
        'Rota suavemente hacia adelante y atrás.',
        'Mantén 30 seg por lado.',
      ],
      benefits: 'Excelente para la rotación interna y externa de cadera.',
    ),
    // Knee
    JointExercise(
      id: 'kj1',
      name: 'Terminal Knee Extension (TKE)',
      type: 'fortalecimiento',
      jointFamily: 'knee',
      instructions: [
        'Con banda en la parte posterior de la rodilla.',
        'Extiende completamente la rodilla.',
        'Mantén 2 seg y relaja.',
      ],
      whenToUse: 'Rehabilitación y activación del vasto medial.',
    ),
    JointExercise(
      id: 'kj2',
      name: 'Sentadilla con pausa',
      type: 'fortalecimiento',
      jointFamily: 'knee',
      instructions: [
        'Sentadilla normal.',
        'Pausa 3 seg en el punto bajo.',
        'Sube controladamente.',
      ],
      benefits: 'Fortalece los tendones y mejora el control articular.',
    ),
    // Ankle
    JointExercise(
      id: 'aj1',
      name: 'Círculos de tobillo',
      type: 'movilidad',
      jointFamily: 'ankle',
      instructions: [
        'Sentado, levanta un pie.',
        'Realiza círculos amplios con el pie.',
        '5 en cada dirección.',
      ],
      whenToUse: 'Antes de ejercicios de piernas.',
    ),
    JointExercise(
      id: 'aj2',
      name: 'Movilidad de tobillo en pared',
      type: 'movilidad',
      jointFamily: 'ankle',
      instructions: [
        'De pie frente a una pared, pie a ~10cm.',
        'Lleva la rodilla a tocar la pared sin levantar el talón.',
        '10 reps.',
      ],
      benefits: 'Mejora la dorsiflexión esencial para sentadillas.',
    ),
    // Cervical
    JointExercise(
      id: 'cj1',
      name: 'Chin Tucks',
      type: 'fortalecimiento',
      jointFamily: 'cervical',
      instructions: [
        'De pie o sentado.',
        'Lleva la barbilla hacia atrás (doble barbilla).',
        'Mantén 5 seg.',
      ],
      benefits: 'Corrige la postura de la cabeza adelantada.',
    ),
    JointExercise(
      id: 'cj2',
      name: 'Estiramiento lateral cervical',
      type: 'movilidad',
      jointFamily: 'cervical',
      instructions: [
        'Inclina la cabeza hacia un hombro.',
        'Ayuda suavemente con la mano.',
        'Mantén 20 seg por lado.',
      ],
      whenToUse: 'Para aliviar tensión cervical.',
    ),
    // Lumbar
    JointExercise(
      id: 'lj1',
      name: 'Cat-Cow',
      type: 'movilidad',
      jointFamily: 'lumbar',
      instructions: [
        'En cuatro apoyos.',
        'Arquea la espalda hacia arriba (Cat).',
        'Luego hacia abajo (Cow).',
        '10 ciclos lentos.',
      ],
      whenToUse: 'Calentamiento lumbar antes de peso muerto o sentadillas.',
    ),
    JointExercise(
      id: 'lj2',
      name: 'Bird Dog',
      type: 'fortalecimiento',
      jointFamily: 'lumbar',
      instructions: [
        'En cuatro apoyos.',
        'Extiende brazo opuesto y pierna simultáneamente.',
        'Mantén 3 seg, alterna lados.',
      ],
      benefits: 'Estabiliza la columna lumbar y el core.',
    ),
  ];
}
