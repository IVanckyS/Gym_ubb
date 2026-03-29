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

  // viewBox: 200 × 338

  static const Map<String, Color> muscleColors = {
    'Pecho': Color(0xFF3b82f6),
    'Espalda': Color(0xFF8b5cf6),
    'Piernas': Color(0xFF22c55e),
    'Hombros': Color(0xFFf97316),
    'Brazos': Color(0xFFec4899),
    'Core': Color(0xFFeab308),
    'Glúteos': Color(0xFFef4444),
  };

  // Mapping from DB enum value to display name
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

  static const List<MuscleZone> zonesFront = [
    MuscleZone(
      id: 'chest_left',
      name: 'Pectoral izquierdo',
      muscleGroup: 'Pecho',
      points: '60,58 100,56 100,97 60,93',
    ),
    MuscleZone(
      id: 'chest_right',
      name: 'Pectoral derecho',
      muscleGroup: 'Pecho',
      points: '100,56 140,58 140,93 100,97',
    ),
    MuscleZone(
      id: 'shoulder_left',
      name: 'Hombro izquierdo',
      muscleGroup: 'Hombros',
      points: '43,50 63,44 65,74 44,76',
    ),
    MuscleZone(
      id: 'shoulder_right',
      name: 'Hombro derecho',
      muscleGroup: 'Hombros',
      points: '137,44 157,50 156,76 135,74',
    ),
    MuscleZone(
      id: 'bicep_left',
      name: 'Bíceps izquierdo',
      muscleGroup: 'Brazos',
      points: '39,73 59,70 62,122 40,125',
    ),
    MuscleZone(
      id: 'bicep_right',
      name: 'Bíceps derecho',
      muscleGroup: 'Brazos',
      points: '141,70 161,73 160,125 138,122',
    ),
    MuscleZone(
      id: 'forearm_left',
      name: 'Antebrazo izquierdo',
      muscleGroup: 'Brazos',
      points: '37,125 61,122 61,168 38,168',
    ),
    MuscleZone(
      id: 'forearm_right',
      name: 'Antebrazo derecho',
      muscleGroup: 'Brazos',
      points: '139,122 163,125 162,168 139,168',
    ),
    MuscleZone(
      id: 'abs',
      name: 'Abdominales',
      muscleGroup: 'Core',
      points: '63,97 137,97 135,160 65,160',
    ),
    MuscleZone(
      id: 'oblique_left',
      name: 'Oblicuo izquierdo',
      muscleGroup: 'Core',
      points: '46,84 63,80 65,160 47,150',
    ),
    MuscleZone(
      id: 'oblique_right',
      name: 'Oblicuo derecho',
      muscleGroup: 'Core',
      points: '137,80 154,84 153,150 135,160',
    ),
    MuscleZone(
      id: 'hipflexor_left',
      name: 'Flexor cadera izquierdo',
      muscleGroup: 'Piernas',
      points: '65,160 100,160 100,183 66,183',
    ),
    MuscleZone(
      id: 'hipflexor_right',
      name: 'Flexor cadera derecho',
      muscleGroup: 'Piernas',
      points: '100,160 135,160 134,183 100,183',
    ),
    MuscleZone(
      id: 'quad_left',
      name: 'Cuádriceps izquierdo',
      muscleGroup: 'Piernas',
      points: '66,183 100,183 100,256 68,256',
    ),
    MuscleZone(
      id: 'quad_right',
      name: 'Cuádriceps derecho',
      muscleGroup: 'Piernas',
      points: '100,183 134,183 132,256 100,256',
    ),
    MuscleZone(
      id: 'tibialis_left',
      name: 'Tibial izquierdo',
      muscleGroup: 'Piernas',
      points: '68,264 96,264 94,318 69,318',
    ),
    MuscleZone(
      id: 'tibialis_right',
      name: 'Tibial derecho',
      muscleGroup: 'Piernas',
      points: '104,264 132,264 131,318 106,318',
    ),
  ];

  // ── Muscle zones — BACK ───────────────────────────────────────────────────

  static const List<MuscleZone> zonesBack = [
    MuscleZone(
      id: 'trapezius',
      name: 'Trapecio',
      muscleGroup: 'Espalda',
      points: '65,52 135,52 128,82 72,82',
    ),
    MuscleZone(
      id: 'lat_left',
      name: 'Dorsal izquierdo',
      muscleGroup: 'Espalda',
      points: '54,78 96,78 98,152 54,138',
    ),
    MuscleZone(
      id: 'lat_right',
      name: 'Dorsal derecho',
      muscleGroup: 'Espalda',
      points: '104,78 146,78 146,138 102,152',
    ),
    MuscleZone(
      id: 'reardelt_left',
      name: 'Deltoides posterior izquierdo',
      muscleGroup: 'Hombros',
      points: '43,50 65,44 66,78 44,76',
    ),
    MuscleZone(
      id: 'reardelt_right',
      name: 'Deltoides posterior derecho',
      muscleGroup: 'Hombros',
      points: '135,44 157,50 156,76 134,78',
    ),
    MuscleZone(
      id: 'tricep_left',
      name: 'Tríceps izquierdo',
      muscleGroup: 'Brazos',
      points: '39,72 59,68 62,120 40,123',
    ),
    MuscleZone(
      id: 'tricep_right',
      name: 'Tríceps derecho',
      muscleGroup: 'Brazos',
      points: '141,68 161,72 160,123 138,120',
    ),
    MuscleZone(
      id: 'forearm_left_back',
      name: 'Antebrazo izquierdo',
      muscleGroup: 'Brazos',
      points: '37,123 61,120 61,165 38,165',
    ),
    MuscleZone(
      id: 'forearm_right_back',
      name: 'Antebrazo derecho',
      muscleGroup: 'Brazos',
      points: '139,120 163,123 162,165 139,165',
    ),
    MuscleZone(
      id: 'erector',
      name: 'Erector espinal',
      muscleGroup: 'Espalda',
      points: '84,96 116,96 116,158 84,158',
    ),
    MuscleZone(
      id: 'glute_left',
      name: 'Glúteo izquierdo',
      muscleGroup: 'Glúteos',
      points: '65,158 100,158 100,196 66,196',
    ),
    MuscleZone(
      id: 'glute_right',
      name: 'Glúteo derecho',
      muscleGroup: 'Glúteos',
      points: '100,158 135,158 134,196 100,196',
    ),
    MuscleZone(
      id: 'hamstring_left',
      name: 'Isquiotibial izquierdo',
      muscleGroup: 'Piernas',
      points: '67,196 100,196 100,256 69,256',
    ),
    MuscleZone(
      id: 'hamstring_right',
      name: 'Isquiotibial derecho',
      muscleGroup: 'Piernas',
      points: '100,196 133,196 131,256 100,256',
    ),
    MuscleZone(
      id: 'calf_left',
      name: 'Gemelo izquierdo',
      muscleGroup: 'Piernas',
      points: '68,264 97,264 95,318 70,318',
    ),
    MuscleZone(
      id: 'calf_right',
      name: 'Gemelo derecho',
      muscleGroup: 'Piernas',
      points: '103,264 132,264 130,318 105,318',
    ),
  ];

  // ── Joint points — FRONT ──────────────────────────────────────────────────

  static const List<JointPoint> jointsFront = [
    JointPoint(
      id: 'shoulder_left',
      name: 'Hombro izquierdo',
      x: 57,
      y: 60,
      family: 'shoulder',
    ),
    JointPoint(
      id: 'shoulder_right',
      name: 'Hombro derecho',
      x: 143,
      y: 60,
      family: 'shoulder',
    ),
    JointPoint(
      id: 'elbow_left',
      name: 'Codo izquierdo',
      x: 40,
      y: 126,
      family: 'elbow',
    ),
    JointPoint(
      id: 'elbow_right',
      name: 'Codo derecho',
      x: 160,
      y: 126,
      family: 'elbow',
    ),
    JointPoint(
      id: 'wrist_left',
      name: 'Muñeca izquierda',
      x: 38,
      y: 168,
      family: 'wrist',
    ),
    JointPoint(
      id: 'wrist_right',
      name: 'Muñeca derecha',
      x: 162,
      y: 168,
      family: 'wrist',
    ),
    JointPoint(
      id: 'hip_left',
      name: 'Cadera izquierda',
      x: 79,
      y: 178,
      family: 'hip',
    ),
    JointPoint(
      id: 'hip_right',
      name: 'Cadera derecha',
      x: 121,
      y: 178,
      family: 'hip',
    ),
    JointPoint(
      id: 'knee_left',
      name: 'Rodilla izquierda',
      x: 77,
      y: 260,
      family: 'knee',
    ),
    JointPoint(
      id: 'knee_right',
      name: 'Rodilla derecha',
      x: 123,
      y: 260,
      family: 'knee',
    ),
    JointPoint(
      id: 'ankle_left',
      name: 'Tobillo izquierdo',
      x: 76,
      y: 318,
      family: 'ankle',
    ),
    JointPoint(
      id: 'ankle_right',
      name: 'Tobillo derecho',
      x: 124,
      y: 318,
      family: 'ankle',
    ),
  ];

  // ── Joint points — BACK ───────────────────────────────────────────────────

  static const List<JointPoint> jointsBack = [
    JointPoint(
      id: 'cervical',
      name: 'Cervical',
      x: 100,
      y: 46,
      family: 'cervical',
    ),
    JointPoint(
      id: 'shoulder_left_back',
      name: 'Hombro izquierdo',
      x: 58,
      y: 62,
      family: 'shoulder',
    ),
    JointPoint(
      id: 'shoulder_right_back',
      name: 'Hombro derecho',
      x: 142,
      y: 62,
      family: 'shoulder',
    ),
    JointPoint(
      id: 'elbow_left_back',
      name: 'Codo izquierdo',
      x: 40,
      y: 123,
      family: 'elbow',
    ),
    JointPoint(
      id: 'elbow_right_back',
      name: 'Codo derecho',
      x: 160,
      y: 123,
      family: 'elbow',
    ),
    JointPoint(
      id: 'wrist_left_back',
      name: 'Muñeca izquierda',
      x: 38,
      y: 165,
      family: 'wrist',
    ),
    JointPoint(
      id: 'wrist_right_back',
      name: 'Muñeca derecha',
      x: 162,
      y: 165,
      family: 'wrist',
    ),
    JointPoint(
      id: 'lumbar',
      name: 'Lumbar',
      x: 100,
      y: 148,
      family: 'lumbar',
    ),
    JointPoint(
      id: 'hip_left_back',
      name: 'Cadera izquierda',
      x: 80,
      y: 180,
      family: 'hip',
    ),
    JointPoint(
      id: 'hip_right_back',
      name: 'Cadera derecha',
      x: 120,
      y: 180,
      family: 'hip',
    ),
    JointPoint(
      id: 'knee_left_back',
      name: 'Rodilla izquierda',
      x: 78,
      y: 258,
      family: 'knee',
    ),
    JointPoint(
      id: 'knee_right_back',
      name: 'Rodilla derecha',
      x: 122,
      y: 258,
      family: 'knee',
    ),
    JointPoint(
      id: 'ankle_left_back',
      name: 'Tobillo izquierdo',
      x: 77,
      y: 318,
      family: 'ankle',
    ),
    JointPoint(
      id: 'ankle_right_back',
      name: 'Tobillo derecho',
      x: 123,
      y: 318,
      family: 'ankle',
    ),
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
