import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

/// Crea el usuario administrador de desarrollo si no existe.
/// Email: admin@ubiobio.cl — Contraseña: Admin1234
/// Solo se ejecuta cuando RUNMODE != 'production'.
Future<void> seedAdminUser(Connection conn) async {
  if (Platform.environment['RUNMODE'] == 'production') return;

  const adminEmail = 'admin@ubiobio.cl';

  final existing = await conn.execute(
    Sql.named('SELECT id FROM users WHERE email = @email'),
    parameters: {'email': adminEmail},
  );

  if (existing.isNotEmpty) {
    print('[Seed] Admin ya existe, omitiendo.');
    return;
  }

  final passwordHash = BCrypt.hashpw('Admin1234', BCrypt.gensalt(logRounds: 12));

  await conn.execute(
    Sql.named(
      "INSERT INTO users (id, email, password_hash, name, role) "
      "VALUES (@id, @email, @passwordHash, @name, 'admin'::user_role)",
    ),
    parameters: {
      'id': _uuid.v4(),
      'email': adminEmail,
      'passwordHash': passwordHash,
      'name': 'Administrador GymUBB',
    },
  );

  print('[Seed] Usuario admin creado: $adminEmail / Admin1234');
}

/// Siembra datos de desarrollo si la base está vacía.
/// Solo se ejecuta cuando RUNMODE != 'production'.
Future<void> seedDev(Connection conn) async {
  if (Platform.environment['RUNMODE'] == 'production') return;

  // Verificar si ya hay ejercicios
  final result = await conn.execute('SELECT COUNT(*) AS total FROM exercises');
  final count = result.first.toColumnMap()['total'] as int? ?? 0;

  if (count > 0) {
    print('[Seed] Ejercicios ya presentes ($count), omitiendo seed.');
    return;
  }

  print('[Seed] Sembrando ejercicios de desarrollo...');

  for (final exercise in _devExercises) {
    final isRankeable = exercise['is_rankeable'] as bool? ?? false;
    await conn.execute(
      Sql.named('''
        INSERT INTO exercises (
          name, muscle_group, difficulty, description,
          muscles, instructions, safety_notes, variations,
          video_url, equipment, default_sets, default_reps, default_rest_seconds,
          is_rankeable
        ) VALUES (
          @name, @muscle_group::muscle_group, @difficulty::difficulty_level, @description,
          @muscles, @instructions, @safety_notes, @variations,
          @video_url, @equipment, @default_sets, @default_reps, @default_rest_seconds,
          @is_rankeable
        )
      '''),
      parameters: {
        ...exercise,
        'is_rankeable': isRankeable,
      },
    );
  }

  final inserted = _devExercises.length;
  print('[Seed] $inserted ejercicios insertados correctamente.');
}

/// Siembra ejercicios de articulaciones si la tabla está vacía.
/// Solo se ejecuta cuando RUNMODE != 'production'.
Future<void> seedJointExercises(Connection conn) async {
  if (Platform.environment['RUNMODE'] == 'production') return;

  final result = await conn.execute(
    'SELECT COUNT(*) AS total FROM joint_exercises',
  );
  final count = result.first.toColumnMap()['total'] as int? ?? 0;

  if (count > 0) {
    print('[Seed] Ejercicios de articulaciones ya presentes ($count), omitiendo.');
    return;
  }

  print('[Seed] Sembrando ejercicios de articulaciones...');

  for (final exercise in _jointExercises) {
    final id = _uuid.v4();
    await conn.execute(
      Sql.named(
        "INSERT INTO joint_exercises (id, name, type, joint_family, instructions, benefits, when_to_use) "
        "VALUES ('$id'::uuid, @name, @type, @jointFamily, @instructions, @benefits, @whenToUse)",
      ),
      parameters: {
        'name': exercise['name'],
        'type': exercise['type'],
        'jointFamily': exercise['jointFamily'],
        'instructions': (exercise['instructions'] as List).cast<String>(),
        'benefits': exercise['benefits'],
        'whenToUse': exercise['whenToUse'],
      },
    );
  }

  print('[Seed] ${_jointExercises.length} ejercicios de articulaciones insertados.');
}

// ─────────────────────────────────────────────────────────────────────────────
// Datos del mockup (src/data/mockData.js)
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _devExercises = [
  // ── Pecho ─────────────────────────────────────────────────────────────────
  {
    'name': 'Press de Banca',
    'is_rankeable': true,
    'muscle_group': 'pecho',
    'difficulty': 'intermedio',
    'description': 'Ejercicio fundamental para el desarrollo de la musculatura pectoral.',
    'muscles': ['Pectoral mayor', 'Tríceps', 'Deltoides anterior'],
    'instructions': [
      'Túmbate en el banco con los pies apoyados en el suelo.',
      'Agarra la barra con un agarre ligeramente más ancho que los hombros.',
      'Baja la barra controladamente hasta el pecho.',
      'Empuja la barra hacia arriba hasta extender los brazos completamente.',
    ],
    'safety_notes': 'Siempre usa un spotter o barras de seguridad. No arquees excesivamente la espalda.',
    'variations': ['Press inclinado', 'Press declinado', 'Press con mancuernas', 'Press con cables'],
    'video_url': 'https://www.youtube.com/embed/rT7DgCr-3pg',
    'equipment': 'Barra + Banco',
    'default_sets': 3,
    'default_reps': '8-12',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Fondos en Paralelas',
    'muscle_group': 'pecho',
    'difficulty': 'intermedio',
    'description': 'Excelente ejercicio de peso corporal para pecho y tríceps.',
    'muscles': ['Pectoral', 'Tríceps', 'Deltoides anterior'],
    'instructions': [
      'Sujétate en las barras paralelas con los brazos extendidos.',
      'Inclina el torso ligeramente hacia adelante.',
      'Baja el cuerpo flexionando los codos hasta 90°.',
      'Empuja hacia arriba hasta extender los brazos.',
    ],
    'safety_notes': 'No bajes demasiado si tienes problemas de hombros.',
    'variations': ['Fondos con peso', 'Fondos en banco', 'Fondos asistidos'],
    'video_url': null,
    'equipment': 'Barras paralelas',
    'default_sets': 3,
    'default_reps': '8-12',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Aperturas con Mancuernas',
    'muscle_group': 'pecho',
    'difficulty': 'principiante',
    'description': 'Ejercicio de aislamiento para el pecho.',
    'muscles': ['Pectoral mayor', 'Deltoides anterior'],
    'instructions': [
      'Tumbado en banco plano, sujeta mancuernas sobre el pecho.',
      'Abre los brazos en arco amplio hacia los lados.',
      'Cierra los brazos de vuelta a la posición inicial.',
    ],
    'safety_notes': 'Mantén ligera flexión en los codos.',
    'variations': ['Aperturas inclinadas', 'Aperturas en cables', 'Pec-deck'],
    'video_url': null,
    'equipment': 'Mancuernas + Banco',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },

  // ── Espalda ───────────────────────────────────────────────────────────────
  {
    'name': 'Peso Muerto',
    'is_rankeable': true,
    'muscle_group': 'espalda',
    'difficulty': 'avanzado',
    'description': 'Ejercicio compuesto que trabaja toda la cadena posterior del cuerpo.',
    'muscles': ['Isquiotibiales', 'Glúteos', 'Espalda baja', 'Trapecios', 'Core'],
    'instructions': [
      'Párate frente a la barra con los pies a la anchura de caderas.',
      'Agáchate y agarra la barra con ambas manos.',
      'Mantén la espalda recta y el pecho elevado.',
      'Levanta la barra empujando el suelo con los pies.',
      'Extiende completamente caderas y rodillas al llegar arriba.',
    ],
    'safety_notes': 'CRÍTICO: nunca redondees la espalda lumbar.',
    'variations': ['Peso muerto rumano', 'Peso muerto sumo', 'Peso muerto con trampa'],
    'video_url': 'https://www.youtube.com/embed/op9kVnSso6Q',
    'equipment': 'Barra',
    'default_sets': 3,
    'default_reps': '3-6',
    'default_rest_seconds': 180,
  },
  {
    'name': 'Dominadas',
    'muscle_group': 'espalda',
    'difficulty': 'intermedio',
    'description': 'Ejercicio de peso corporal que desarrolla la espalda ancha y los bíceps.',
    'muscles': ['Dorsal ancho', 'Bíceps', 'Romboides', 'Core'],
    'instructions': [
      'Cuelga de la barra con agarre prono.',
      'Activa el core y retrae las escápulas.',
      'Tira hacia arriba hasta que la barbilla supere la barra.',
      'Baja controladamente.',
    ],
    'safety_notes': 'No balancees el cuerpo. Usa banda elástica si no puedes hacer ninguna.',
    'variations': ['Chin-ups', 'Dominadas con peso', 'Dominadas neutras'],
    'video_url': 'https://www.youtube.com/embed/eGo4IYlbE5g',
    'equipment': 'Barra de dominadas',
    'default_sets': 3,
    'default_reps': '6-10',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Remo con Barra',
    'muscle_group': 'espalda',
    'difficulty': 'intermedio',
    'description': 'Ejercicio compuesto para el desarrollo de la espalda media.',
    'muscles': ['Dorsal ancho', 'Romboides', 'Trapecio medio', 'Bíceps'],
    'instructions': [
      'Inclínate hacia adelante manteniendo la espalda recta (45°).',
      'Agarra la barra con agarre prono.',
      'Tira de la barra hacia el abdomen bajo.',
      'Baja controladamente.',
    ],
    'safety_notes': 'Nunca redondees la espalda. Mantén la cabeza en posición neutra.',
    'variations': ['Remo Pendlay', 'Remo con mancuernas', 'Remo en polea baja'],
    'video_url': null,
    'equipment': 'Barra',
    'default_sets': 4,
    'default_reps': '8-12',
    'default_rest_seconds': 90,
  },

  // ── Piernas ───────────────────────────────────────────────────────────────
  {
    'name': 'Sentadilla',
    'is_rankeable': true,
    'muscle_group': 'piernas',
    'difficulty': 'intermedio',
    'description': 'El rey de los ejercicios. Trabaja cuádriceps, isquiotibiales y glúteos.',
    'muscles': ['Cuádriceps', 'Isquiotibiales', 'Glúteos', 'Core'],
    'instructions': [
      'Coloca la barra sobre la parte alta de la espalda.',
      'Pies al ancho de los hombros, ligeramente abiertos.',
      'Baja manteniendo el pecho erguido y las rodillas en línea.',
      'Sube empujando desde los talones.',
    ],
    'safety_notes': 'Nunca redondees la espalda. Mantén las rodillas sin colapsar.',
    'variations': ['Sentadilla goblet', 'Sentadilla frontal', 'Sentadilla búlgara'],
    'video_url': 'https://www.youtube.com/embed/ultWZbUMPL8',
    'equipment': 'Barra + Rack',
    'default_sets': 4,
    'default_reps': '5-8',
    'default_rest_seconds': 120,
  },
  {
    'name': 'Peso Muerto Rumano',
    'muscle_group': 'piernas',
    'difficulty': 'intermedio',
    'description': 'Variante que aísla los isquiotibiales y glúteos.',
    'muscles': ['Isquiotibiales', 'Glúteos', 'Espalda baja'],
    'instructions': [
      'De pie con barra en agarre prono.',
      'Inclina el torso con piernas casi rectas.',
      'Baja hasta sentir estiramiento en isquios.',
      'Vuelve contrayendo glúteos.',
    ],
    'safety_notes': 'Mantén la espalda recta. No bajes más allá de tu flexibilidad.',
    'variations': ['PDM con mancuernas', 'PDM unilateral'],
    'video_url': null,
    'equipment': 'Barra o Mancuernas',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Zancadas',
    'muscle_group': 'piernas',
    'difficulty': 'principiante',
    'description': 'Ejercicio unilateral para cuádriceps y glúteos.',
    'muscles': ['Cuádriceps', 'Glúteos', 'Isquiotibiales'],
    'instructions': [
      'De pie con los pies juntos.',
      'Da un paso hacia adelante.',
      'Baja la rodilla trasera hacia el suelo.',
      'Empuja con el pie delantero para volver.',
    ],
    'safety_notes': 'La rodilla delantera no debe superar la punta del pie.',
    'variations': ['Zancadas en reversa', 'Zancadas caminando'],
    'video_url': null,
    'equipment': 'Peso corporal o Mancuernas',
    'default_sets': 3,
    'default_reps': '10-12 por pierna',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Leg Press',
    'muscle_group': 'piernas',
    'difficulty': 'principiante',
    'description': 'Ejercicio en máquina para cuádriceps con menor riesgo que la sentadilla libre.',
    'muscles': ['Cuádriceps', 'Glúteos', 'Isquiotibiales'],
    'instructions': [
      'Siéntate en la máquina y coloca los pies en la plataforma.',
      'Libera los seguros y baja flexionando rodillas.',
      'Empuja hasta casi extender (sin bloquear rodillas).',
    ],
    'safety_notes': 'No bloquees las rodillas. Mantén la espalda en el respaldo.',
    'variations': ['Leg press unilateral', 'Pies altos', 'Pies bajos'],
    'video_url': null,
    'equipment': 'Máquina Leg Press',
    'default_sets': 4,
    'default_reps': '10-15',
    'default_rest_seconds': 90,
  },

  // ── Hombros ───────────────────────────────────────────────────────────────
  {
    'name': 'Press Militar',
    'is_rankeable': true,
    'muscle_group': 'hombros',
    'difficulty': 'intermedio',
    'description': 'Ejercicio de empuje vertical para deltoides.',
    'muscles': ['Deltoides', 'Tríceps', 'Trapecio superior'],
    'instructions': [
      'De pie o sentado, barra a la altura de los hombros.',
      'Empuja hacia arriba hasta extender los brazos.',
      'Baja controladamente.',
    ],
    'safety_notes': 'Evita arquear excesivamente la zona lumbar.',
    'variations': ['Press Arnold', 'Press con mancuernas', 'Press en máquina'],
    'video_url': 'https://www.youtube.com/embed/2yjwXTZQDDI',
    'equipment': 'Barra o Mancuernas',
    'default_sets': 3,
    'default_reps': '8-12',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Elevaciones Laterales',
    'muscle_group': 'hombros',
    'difficulty': 'principiante',
    'description': 'Aislamiento para deltoides lateral.',
    'muscles': ['Deltoides lateral', 'Deltoides anterior'],
    'instructions': [
      'De pie, mancuernas a los costados.',
      'Eleva hacia los lados hasta la altura de los hombros.',
      'Baja controladamente.',
    ],
    'safety_notes': 'Usa pesos moderados. No balancees el torso.',
    'variations': ['Con cables', 'Elevaciones frontales'],
    'video_url': null,
    'equipment': 'Mancuernas',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },

  // ── Brazos ────────────────────────────────────────────────────────────────
  {
    'name': 'Curl de Bíceps',
    'muscle_group': 'brazos',
    'difficulty': 'principiante',
    'description': 'Aislamiento para bíceps.',
    'muscles': ['Bíceps braquial', 'Braquial', 'Braquiorradial'],
    'instructions': [
      'De pie, mancuernas con agarre supino.',
      'Codos pegados al cuerpo.',
      'Sube contrayendo el bíceps.',
      'Baja controladamente.',
    ],
    'safety_notes': 'No balancees el torso. Codos estáticos.',
    'variations': ['Curl con barra', 'Curl martillo', 'Curl en predicador'],
    'video_url': null,
    'equipment': 'Mancuernas o Barra',
    'default_sets': 3,
    'default_reps': '10-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Extensiones de Tríceps',
    'muscle_group': 'brazos',
    'difficulty': 'principiante',
    'description': 'Aislamiento para tríceps.',
    'muscles': ['Tríceps braquial'],
    'instructions': [
      'De pie, mancuerna con ambas manos sobre la cabeza.',
      'Baja la mancuerna detrás de la cabeza.',
      'Extiende los brazos hacia arriba.',
    ],
    'safety_notes': 'Codos apuntando hacia arriba, no los abras.',
    'variations': ['Press francés', 'Extensiones en polea', 'Kickbacks'],
    'video_url': null,
    'equipment': 'Mancuerna',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },

  // ── Core ──────────────────────────────────────────────────────────────────
  {
    'name': 'Plancha',
    'muscle_group': 'core',
    'difficulty': 'principiante',
    'description': 'Ejercicio isométrico fundamental para el core.',
    'muscles': ['Transverso abdominal', 'Recto abdominal', 'Oblicuos', 'Glúteos'],
    'instructions': [
      'Apoya antebrazos y pies en el suelo.',
      'Cuerpo en línea recta de cabeza a talones.',
      'Contrae abdomen y glúteos.',
      'Mantén la posición.',
    ],
    'safety_notes': 'No dejes caer las caderas. Respira normalmente.',
    'variations': ['Plancha lateral', 'Plancha con elevación', 'Rueda abdominal'],
    'video_url': null,
    'equipment': 'Solo peso corporal',
    'default_sets': 3,
    'default_reps': '30-60 seg',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Crunch Abdominal',
    'muscle_group': 'core',
    'difficulty': 'principiante',
    'description': 'Ejercicio básico para el recto abdominal.',
    'muscles': ['Recto abdominal', 'Oblicuos'],
    'instructions': [
      'Tumbado boca arriba, rodillas flexionadas.',
      'Manos detrás de la cabeza.',
      'Eleva los hombros contrayendo el abdomen.',
      'Vuelve sin apoyar completamente.',
    ],
    'safety_notes': 'No tires del cuello. El movimiento viene del abdomen.',
    'variations': ['Crunch con giro', 'Crunch inverso', 'Sit-up'],
    'video_url': null,
    'equipment': 'Solo peso corporal',
    'default_sets': 3,
    'default_reps': '15-20',
    'default_rest_seconds': 45,
  },

  // ── Hombros (adicional) ───────────────────────────────────────────────────
  {
    'name': 'Face Pull',
    'muscle_group': 'hombros',
    'difficulty': 'principiante',
    'description':
        'Ejercicio preventivo para la salud del hombro. Trabaja la parte posterior del deltoides y los rotadores externos.',
    'muscles': ['Deltoides posterior', 'Rotadores externos', 'Romboides'],
    'instructions': [
      'En polea alta con cuerda, agarra los extremos.',
      'Tira de la cuerda hacia la cara separando los extremos.',
      'Los codos deben quedar por encima de los hombros.',
    ],
    'safety_notes':
        'Usa peso moderado. Ejercicio de salud articular, no de fuerza máxima.',
    'variations': ['Face pull con banda', 'Remo al cuello', 'YWT en banco inclinado'],
    'video_url': null,
    'equipment': 'Polea con cuerda',
    'default_sets': 3,
    'default_reps': '15-20',
    'default_rest_seconds': 45,
  },

  // ── Espalda (adicional) ───────────────────────────────────────────────────
  {
    'name': 'Jalón al Pecho',
    'muscle_group': 'espalda',
    'difficulty': 'principiante',
    'description':
        'Alternativa a las dominadas en máquina de polea. Trabaja el dorsal ancho y permite ajustar el peso.',
    'muscles': ['Dorsal ancho', 'Bíceps', 'Romboides'],
    'instructions': [
      'Siéntate en la máquina y agarra la barra con agarre amplio.',
      'Inclínate ligeramente hacia atrás.',
      'Tira de la barra hacia el pecho superior.',
      'Vuelve arriba controladamente.',
    ],
    'safety_notes':
        'No jalones detrás de la nuca: aumenta el riesgo de lesión cervical.',
    'variations': [
      'Jalón agarre neutro',
      'Jalón agarre cerrado',
      'Jalón con mancuernas en polea',
    ],
    'video_url': null,
    'equipment': 'Máquina de polea',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 75,
  },

  // ── Piernas (adicionales) ─────────────────────────────────────────────────
  {
    'name': 'Sentadilla Búlgara',
    'muscle_group': 'piernas',
    'difficulty': 'avanzado',
    'description':
        'Sentadilla unilateral con pie trasero elevado. Gran desafío de equilibrio y máxima activación de cuádriceps y glúteos.',
    'muscles': ['Cuádriceps', 'Glúteos', 'Isquiotibiales', 'Core'],
    'instructions': [
      'Coloca el pie trasero elevado en un banco.',
      'El pie delantero avanzado un paso.',
      'Baja el cuerpo flexionando la rodilla delantera.',
      'Empuja para subir desde el talón delantero.',
    ],
    'safety_notes':
        'Empieza sin peso hasta dominar el equilibrio. La rodilla delantera no debe sobrepasar los dedos del pie.',
    'variations': ['Con mancuernas', 'Con barra', 'Con peso corporal'],
    'video_url': null,
    'equipment': 'Banco + Mancuernas o Barra',
    'default_sets': 3,
    'default_reps': '8-10 por pierna',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Curl Femoral',
    'muscle_group': 'piernas',
    'difficulty': 'principiante',
    'description': 'Ejercicio de aislamiento para isquiotibiales en máquina.',
    'muscles': ['Isquiotibiales', 'Glúteos'],
    'instructions': [
      'Tumbado en la máquina, coloca el eje a la altura de las rodillas.',
      'Flexiona las rodillas trayendo los pies hacia los glúteos.',
      'Extiende lentamente.',
    ],
    'safety_notes':
        'No uses inercia. Movimiento lento y controlado especialmente en la bajada.',
    'variations': ['Curl nórdico', 'Curl femoral de pie', 'Good morning'],
    'video_url': null,
    'equipment': 'Máquina curl femoral',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },

  // ── Pecho (adicional) ─────────────────────────────────────────────────────
  {
    'name': 'Push Up (Flexiones)',
    'muscle_group': 'pecho',
    'difficulty': 'principiante',
    'description':
        'El ejercicio más accesible para el pecho. No requiere equipamiento y es excelente para principiantes.',
    'muscles': ['Pectoral mayor', 'Tríceps', 'Deltoides anterior', 'Core'],
    'instructions': [
      'Posición de plancha alta con manos algo más ancho que los hombros.',
      'Baja el pecho al suelo manteniendo el cuerpo recto.',
      'Empuja hacia arriba hasta extender los brazos.',
    ],
    'safety_notes': 'Mantén el core activo. No dejes caer las caderas.',
    'variations': [
      'Flexiones inclinadas',
      'Flexiones declinadas',
      'Flexiones diamante',
      'Flexiones en T',
    ],
    'video_url': null,
    'equipment': 'Solo peso corporal',
    'default_sets': 3,
    'default_reps': '10-20',
    'default_rest_seconds': 60,
  },

  // ── Glúteos ───────────────────────────────────────────────────────────────
  {
    'name': 'Hip Thrust',
    'muscle_group': 'gluteos',
    'difficulty': 'principiante',
    'description': 'El mejor ejercicio para el desarrollo de glúteos.',
    'muscles': ['Glúteo mayor', 'Glúteo medio', 'Isquiotibiales'],
    'instructions': [
      'Apoya la espalda alta en un banco.',
      'Barra sobre la cadera con protección.',
      'Empuja caderas hacia arriba alineando el cuerpo.',
      'Aprieta glúteos arriba y baja controladamente.',
    ],
    'safety_notes': 'Usa almohadilla para proteger la cadera.',
    'variations': ['Puente de glúteos', 'Hip thrust con banda', 'Unilateral'],
    'video_url': null,
    'equipment': 'Barra + Banco',
    'default_sets': 3,
    'default_reps': '10-15',
    'default_rest_seconds': 90,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Ejercicios de articulaciones — movilidad y fortalecimiento
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _jointExercises = [
  // ── HOMBRO ────────────────────────────────────────────────────────────────
  {
    'name': 'Rotación interna y externa de hombro con banda',
    'type': 'movilidad',
    'jointFamily': 'shoulder',
    'instructions': [
      'Ancla una banda elástica a la altura del codo.',
      'Mantén el codo flexionado a 90° pegado al costado.',
      'Rota el antebrazo hacia afuera (rotación externa) lentamente.',
      'Vuelve al centro y luego rota hacia adentro (rotación interna).',
      'Realiza 10 repeticiones en cada dirección.',
    ],
    'benefits': 'Mejora el rango de movimiento glenohumeral, previene el síndrome de impingement y equilibra los rotadores del manguito.',
    'whenToUse': 'Ideal como calentamiento previo a entrenamientos de empuje/tirón, o como trabajo preventivo 3 veces por semana.',
  },
  {
    'name': 'Círculos de hombro con bastón (calistenia escapular)',
    'type': 'movilidad',
    'jointFamily': 'shoulder',
    'instructions': [
      'Sostén un bastón o palo de escoba con ambas manos al frente.',
      'Realiza círculos amplios con los brazos pasando el bastón por encima de la cabeza.',
      'Mantén los codos ligeramente flexionados durante todo el movimiento.',
      'Realiza 5 círculos hacia adelante y 5 hacia atrás.',
    ],
    'benefits': 'Aumenta la movilidad de toda la cápsula glenohumeral y mejora la conciencia propioceptiva del hombro.',
    'whenToUse': 'Calentamiento articular antes de entrenar hombros, pecho o espalda. También útil en días de recuperación activa.',
  },
  {
    'name': 'Press con mancuerna a una mano (rotador)',
    'type': 'fortalecimiento',
    'jointFamily': 'shoulder',
    'instructions': [
      'De pie o sentado, sostén una mancuerna ligera en una mano.',
      'Eleva el brazo lateralmente a 90° con el codo flexionado.',
      'Desde esa posición rota el antebrazo hacia arriba (como apuntar al techo).',
      'Baja lentamente y repite 12-15 veces por lado.',
    ],
    'benefits': 'Fortalece los rotadores externos del manguito rotador (infraespinoso, redondo menor), reduciendo el riesgo de lesión en press de pecho y press de hombros.',
    'whenToUse': 'Incluir en la rutina de hombros o como trabajo preventivo. Ideal para personas con historial de lesiones en el hombro.',
  },
  {
    'name': 'Face Pull con cuerda (salud del hombro)',
    'type': 'fortalecimiento',
    'jointFamily': 'shoulder',
    'instructions': [
      'Coloca la polea a la altura de los ojos con accesorio de cuerda.',
      'Agarra los extremos de la cuerda con ambas manos.',
      'Tira hacia la cara separando los extremos al llegar cerca.',
      'Los codos deben quedar por encima de los hombros al final.',
      'Vuelve lentamente. 15-20 repeticiones.',
    ],
    'benefits': 'Fortalece deltoides posterior, rotadores externos y romboides. Corrige la postura de hombros caídos hacia adelante.',
    'whenToUse': 'Al final de cualquier sesión de empuje. También 2-3 veces por semana como trabajo postural.',
  },

  // ── CODO ──────────────────────────────────────────────────────────────────
  {
    'name': 'Pronación y supinación de antebrazo',
    'type': 'movilidad',
    'jointFamily': 'elbow',
    'instructions': [
      'Siéntate con el codo apoyado en una mesa, flexionado a 90°.',
      'Sostén un martillo o mancuerna ligera con la mano.',
      'Rota el antebrazo hacia abajo (pronación) lentamente.',
      'Vuelve y rota hacia arriba (supinación).',
      'Realiza 10-12 repeticiones lentas por lado.',
    ],
    'benefits': 'Mantiene el rango completo de pronación/supinación del codo, previene la rigidez post-entrenamiento de brazos.',
    'whenToUse': 'Calentamiento para entrenamientos de brazos o antebrazo. También útil para quienes trabajan mucho con el mouse/teclado.',
  },
  {
    'name': 'Extensión excéntrica de codo (curl excéntrico)',
    'type': 'fortalecimiento',
    'jointFamily': 'elbow',
    'instructions': [
      'Sostén una mancuerna con el codo completamente flexionado.',
      'Baja el peso en 4-5 segundos hasta extender el codo completamente.',
      'Usa la otra mano para subir el peso (fase concéntrica asistida).',
      'Repite 8-10 veces enfocándote en la bajada lenta.',
    ],
    'benefits': 'Fortalece el tendón bicipital y los tejidos conectivos del codo. Previene y rehabilita el codo de tenista y tenista de golf.',
    'whenToUse': 'En días de brazos o como trabajo de prevención de lesiones en el tendón. Evitar si hay dolor agudo en el codo.',
  },
  {
    'name': 'Extensión de tríceps en polea (fortalecimiento del olécranon)',
    'type': 'fortalecimiento',
    'jointFamily': 'elbow',
    'instructions': [
      'Coloca la polea alta con cuerda o barra recta.',
      'Agarra el accesorio con los codos pegados al cuerpo.',
      'Extiende completamente los codos hacia abajo.',
      'Vuelve lentamente controlando la tensión. 12-15 reps.',
    ],
    'benefits': 'Fortalece el tríceps y estabiliza la articulación del codo, protegiéndola durante movimientos de press.',
    'whenToUse': 'Al final de la sesión de brazos o pecho. Buena opción de volumen para el codo sin sobrecargarlo.',
  },

  // ── MUÑECA ────────────────────────────────────────────────────────────────
  {
    'name': 'Flexión y extensión de muñeca con mancuerna',
    'type': 'movilidad',
    'jointFamily': 'wrist',
    'instructions': [
      'Siéntate con el antebrazo apoyado en el muslo, mano hacia afuera.',
      'Sostén una mancuerna ligera (1-2 kg).',
      'Baja la mano hacia el suelo (extensión) lentamente.',
      'Sube la mano hacia arriba (flexión) lentamente.',
      'Realiza 15 repeticiones en cada dirección.',
    ],
    'benefits': 'Mantiene el rango completo de flexión/extensión de la muñeca, reduce la rigidez y previene el síndrome del túnel carpiano.',
    'whenToUse': 'Calentamiento antes de entrenamientos de pecho, brazos o cualquier ejercicio que cargue la muñeca.',
  },
  {
    'name': 'Círculos de muñeca',
    'type': 'movilidad',
    'jointFamily': 'wrist',
    'instructions': [
      'Extiende los brazos al frente o apoya los codos.',
      'Realiza círculos lentos con las muñecas.',
      'Primero 10 círculos hacia la derecha, luego 10 hacia la izquierda.',
      'Mantén los dedos ligeramente extendidos durante el movimiento.',
    ],
    'benefits': 'Lubrica la articulación carpiana, mejora el rango circular de movimiento y reduce tensión acumulada.',
    'whenToUse': 'Parte del calentamiento antes de entrenar o al trabajar muchas horas frente al computador.',
  },
  {
    'name': 'Curl de muñeca con mancuerna (fortalecimiento de flexores)',
    'type': 'fortalecimiento',
    'jointFamily': 'wrist',
    'instructions': [
      'Sentado con el antebrazo apoyado en el muslo, mano hacia arriba.',
      'Sostén una mancuerna ligera.',
      'Flexiona la muñeca subiendo el peso hacia ti.',
      'Baja lentamente hasta el rango máximo de extensión.',
      'Realiza 15-20 repeticiones.',
    ],
    'benefits': 'Fortalece los flexores del carpo, aumenta la fuerza de agarre y protege la muñeca en ejercicios de tirón.',
    'whenToUse': 'Al final de la sesión de brazos o como trabajo de antebrazo independiente.',
  },

  // ── CADERA ────────────────────────────────────────────────────────────────
  {
    'name': 'Apertura de cadera en 90/90',
    'type': 'movilidad',
    'jointFamily': 'hip',
    'instructions': [
      'Siéntate en el suelo con ambas piernas dobladas a 90°.',
      'La pierna delantera forma 90° con el torso; la trasera también.',
      'Inclínate hacia adelante sobre la pierna delantera manteniendo la espalda recta.',
      'Mantén 30-60 segundos y cambia de lado.',
    ],
    'benefits': 'Mejora la rotación interna y externa de la cadera, alivia la tensión del piriforme y prepara para sentadillas profundas.',
    'whenToUse': 'Calentamiento previo a sentadillas, peso muerto o cualquier ejercicio de piernas. También en días de recuperación.',
  },
  {
    'name': 'Hip Flexor Stretch (estiramiento del psoas)',
    'type': 'movilidad',
    'jointFamily': 'hip',
    'instructions': [
      'Arrodíllate con una rodilla en el suelo (posición de zancada baja).',
      'La pierna delantera con el pie plano en el suelo.',
      'Empuja la cadera hacia adelante y abajo.',
      'Mantén la espalda erguida y aprieta el glúteo de la pierna trasera.',
      'Mantén 30-45 segundos por lado.',
    ],
    'benefits': 'Alarga el psoas y el recto femoral acortados por estar sentado, mejora la extensión de cadera en sentadillas y zancadas.',
    'whenToUse': 'Calentamiento antes de piernas o después de largo tiempo sentado. Especialmente importante para estudiantes y trabajadores de escritorio.',
  },
  {
    'name': 'Puente de glúteos isométrico (activación de cadera)',
    'type': 'fortalecimiento',
    'jointFamily': 'hip',
    'instructions': [
      'Tumbado boca arriba con rodillas flexionadas y pies en el suelo.',
      'Empuja las caderas hacia arriba contrayendo glúteos.',
      'Mantén la posición arriba durante 2 segundos.',
      'Baja lentamente sin tocar el suelo completamente.',
      'Realiza 15-20 repeticiones.',
    ],
    'benefits': 'Activa y fortalece el glúteo mayor, estabiliza la articulación coxofemoral y reduce la carga en la región lumbar.',
    'whenToUse': 'Calentamiento de glúteos antes de sentadillas, peso muerto o hip thrust. También como ejercicio preventivo de dolor lumbar.',
  },
  {
    'name': 'Monster Walk con banda elástica',
    'type': 'fortalecimiento',
    'jointFamily': 'hip',
    'instructions': [
      'Coloca una banda elástica alrededor de los tobillos.',
      'Flexiona ligeramente rodillas en posición atlética.',
      'Da pasos laterales manteniendo la tensión de la banda.',
      'Realiza 10-15 pasos en cada dirección.',
    ],
    'benefits': 'Fortalece el glúteo medio y los abductores de cadera, mejora la estabilidad pélvica y previene el colapso de rodilla en valgus.',
    'whenToUse': 'Calentamiento antes de cualquier ejercicio de piernas. Esencial si tienes rodillas que colapsan hacia adentro en la sentadilla.',
  },

  // ── RODILLA ───────────────────────────────────────────────────────────────
  {
    'name': 'Sentadilla parcial con control (0° a 60°)',
    'type': 'movilidad',
    'jointFamily': 'knee',
    'instructions': [
      'De pie con pies al ancho de hombros.',
      'Baja lentamente hasta 60° de flexión de rodilla.',
      'Mantén 2 segundos en la posición baja.',
      'Sube lentamente sin bloquear las rodillas.',
      'Realiza 10-15 repeticiones lentas.',
    ],
    'benefits': 'Lubrica la articulación de la rodilla, mejora la propiocepción y fortalece el cuádriceps en rango seguro.',
    'whenToUse': 'Calentamiento antes de entrenamientos de piernas, especialmente en rodillas con historial de dolor anterior.',
  },
  {
    'name': 'Estiramiento de isquiotibiales (boca arriba)',
    'type': 'movilidad',
    'jointFamily': 'knee',
    'instructions': [
      'Tumbado boca arriba, lleva una pierna hacia el pecho.',
      'Extiende la rodilla lentamente hasta sentir estiramiento en la parte trasera del muslo.',
      'Mantén 30 segundos sin rebotar.',
      'Cambia de pierna.',
    ],
    'benefits': 'Mejora la extensión de rodilla, reduce la tensión en tendones isquiotibiales y alivia dolor posterior de rodilla.',
    'whenToUse': 'Después del entrenamiento de piernas o en días de recuperación. También útil para corredores y ciclistas.',
  },
  {
    'name': 'Extensión de cuádriceps en silla',
    'type': 'fortalecimiento',
    'jointFamily': 'knee',
    'instructions': [
      'Sentado en una silla con la espalda apoyada.',
      'Extiende una pierna hasta quedar recta (contrae el cuádriceps).',
      'Mantén 2 segundos arriba.',
      'Baja lentamente. 15 repeticiones por pierna.',
    ],
    'benefits': 'Fortalece el cuádriceps en rango terminal, previene y rehabilita el dolor femoropatelar (dolor de rótula).',
    'whenToUse': 'Apropiado para personas con dolor en la rótula o en rehabilitación post-lesión de rodilla. También como activación pre-entrenamiento.',
  },
  {
    'name': 'Nordic Curl (curl nórdico)',
    'type': 'fortalecimiento',
    'jointFamily': 'knee',
    'instructions': [
      'Arrodíllate en el suelo con los pies sujetos por una superficie fija o compañero.',
      'Baja el torso hacia adelante controlando la velocidad con los isquiotibiales.',
      'Cuando ya no puedas controlar, apoya las manos y empuja para volver.',
      'Realiza 3-6 repeticiones.',
    ],
    'benefits': 'Fortalece excéntricamente los isquiotibiales, reduciendo en hasta un 50% el riesgo de lesión del tendón y la rotura de isquio.',
    'whenToUse': 'Al final de sesiones de piernas o como trabajo de prevención de lesiones. Empezar con pocos reps: es muy exigente.',
  },

  // ── TOBILLO ───────────────────────────────────────────────────────────────
  {
    'name': 'Rotaciones de tobillo',
    'type': 'movilidad',
    'jointFamily': 'ankle',
    'instructions': [
      'Sentado o de pie, levanta ligeramente un pie del suelo.',
      'Realiza círculos amplios con el pie, usando el tobillo como eje.',
      'Realiza 10 círculos en cada sentido por tobillo.',
      'Mantén el movimiento lento y controlado.',
    ],
    'benefits': 'Mejora la movilidad de la articulación del tobillo en todos los planos, reduce la rigidez y mejora el equilibrio.',
    'whenToUse': 'Calentamiento antes de entrenamientos de piernas, correr, o deportes que impliquen saltos y cambios de dirección.',
  },
  {
    'name': 'Dorsiflexión de tobillo en pared',
    'type': 'movilidad',
    'jointFamily': 'ankle',
    'instructions': [
      'De pie frente a una pared, coloca un pie a unos 5 cm de la base.',
      'Deja caer la rodilla hacia adelante intentando tocar la pared sin levantar el talón.',
      'Si tocas la pared, mueve el pie más atrás.',
      'Mantén 3-5 segundos por repetición. 10 reps por tobillo.',
    ],
    'benefits': 'Mejora la dorsiflexión de tobillo, fundamental para sentadillas profundas, subir escaleras y correr sin compensaciones.',
    'whenToUse': 'Calentamiento antes de sentadillas. Si tienes limitación en la dorsiflexión, trabajar diariamente.',
  },
  {
    'name': 'Elevaciones de talón (calf raises)',
    'type': 'fortalecimiento',
    'jointFamily': 'ankle',
    'instructions': [
      'De pie en el borde de un escalón con los talones hacia afuera.',
      'Baja los talones por debajo del nivel del escalón (carga excéntrica).',
      'Sube lentamente elevando los talones al máximo.',
      'Pausa arriba 1 segundo. 15-20 repeticiones.',
    ],
    'benefits': 'Fortalece el tríceps sural (gastrocnemios y sóleo) y el tendón de Aquiles, previniendo lesiones en corredores y saltadores.',
    'whenToUse': 'Al final de sesiones de piernas o como trabajo preventivo diario. Esencial para personas que corren o practican deportes de salto.',
  },
  {
    'name': 'Equilibrio monopodal (tobillo)',
    'type': 'fortalecimiento',
    'jointFamily': 'ankle',
    'instructions': [
      'De pie, levanta un pie del suelo.',
      'Mantén el equilibrio sobre un pie durante 30-60 segundos.',
      'Progresión: cerrar los ojos, usar superficie inestable (almohada).',
      'Realiza 3 series por pierna.',
    ],
    'benefits': 'Mejora la propiocepción del tobillo, fortalece los músculos estabilizadores y previene esguinces recurrentes.',
    'whenToUse': 'Al final del entrenamiento como trabajo de propiocepción. Imprescindible en rehabilitación post-esguince.',
  },

  // ── CERVICAL ──────────────────────────────────────────────────────────────
  {
    'name': 'Rotación cervical activa',
    'type': 'movilidad',
    'jointFamily': 'cervical',
    'instructions': [
      'Sentado erguido con la mirada al frente.',
      'Gira lentamente la cabeza hacia la derecha hasta el límite cómodo.',
      'Mantén 2-3 segundos y vuelve al centro.',
      'Repite hacia la izquierda.',
      'Realiza 8-10 repeticiones por lado.',
    ],
    'benefits': 'Mantiene el rango de rotación cervical, reduce la rigidez del cuello por tensión postural o sedentarismo.',
    'whenToUse': 'Calentamiento antes de entrenamientos de tirón (jalones, dominadas) o en pausas activas durante el trabajo.',
  },
  {
    'name': 'Estiramiento lateral del cuello',
    'type': 'movilidad',
    'jointFamily': 'cervical',
    'instructions': [
      'Sentado o de pie con la espalda erguida.',
      'Inclina la cabeza lateralmente llevando la oreja hacia el hombro.',
      'Puedes poner una mano sobre la cabeza para añadir suave presión.',
      'Mantén 20-30 segundos por lado. Repite 2-3 veces.',
    ],
    'benefits': 'Estira el músculo trapecio superior y el elevador de la escápula, aliviando la tensión típica del trabajo frente al computador.',
    'whenToUse': 'Después de entrenamientos de hombros o trapecios. También en pausas durante trabajo de escritorio.',
  },
  {
    'name': 'Retracción cervical (chin tuck)',
    'type': 'fortalecimiento',
    'jointFamily': 'cervical',
    'instructions': [
      'Sentado o de pie con la mirada al frente.',
      'Mete el mentón hacia atrás creando una doble papada (sin inclinar la cabeza).',
      'Mantén 5-10 segundos apretando los músculos profundos del cuello.',
      'Vuelve y repite 10-15 veces.',
    ],
    'benefits': 'Fortalece los flexores profundos del cuello, corrige la postura de cabeza adelantada (text neck) y previene el dolor cervical crónico.',
    'whenToUse': 'Diariamente como ejercicio postural. Especialmente indicado para personas que usan mucho el teléfono o trabajan frente al computador.',
  },
  {
    'name': 'Isométrico cervical con resistencia manual',
    'type': 'fortalecimiento',
    'jointFamily': 'cervical',
    'instructions': [
      'Sentado, coloca la mano en la sien.',
      'Intenta girar la cabeza mientras la mano resiste el movimiento (sin moverte).',
      'Mantén la contracción 5-8 segundos.',
      'Realiza en los 4 planos: lateral derecho, lateral izquierdo, flexión, extensión.',
      '3 series por dirección.',
    ],
    'benefits': 'Fortalece todos los grupos musculares cervicales de forma segura, sin movimiento que pueda agravar lesiones existentes.',
    'whenToUse': 'Como trabajo de fortalecimiento cervical para personas con historial de dolor de cuello o cervicalgia. No usar si hay lesión aguda.',
  },

  // ── LUMBAR ────────────────────────────────────────────────────────────────
  {
    'name': 'Cat-Cow (flexión y extensión lumbar)',
    'type': 'movilidad',
    'jointFamily': 'lumbar',
    'instructions': [
      'A cuatro patas con manos bajo los hombros y rodillas bajo las caderas.',
      'Exhala y arquea la espalda hacia arriba (cat): ombligo hacia la columna.',
      'Inhala y baja el abdomen dejando la espalda cóncava (cow): pecho adelante.',
      'Realiza 10-15 repeticiones lentas coordinando con la respiración.',
    ],
    'benefits': 'Mejora la movilidad segmentaria lumbar y torácica, lubrica los discos intervertebrales y alivia la rigidez matutina.',
    'whenToUse': 'Al levantarse por la mañana, como calentamiento antes de peso muerto o sentadillas, o en cualquier momento de rigidez lumbar.',
  },
  {
    'name': 'Extensión lumbar en el suelo (cobra)',
    'type': 'movilidad',
    'jointFamily': 'lumbar',
    'instructions': [
      'Tumbado boca abajo con manos bajo los hombros.',
      'Empuja con las manos levantando el pecho, manteniendo las caderas en el suelo.',
      'Llega hasta donde sea cómodo sin forzar.',
      'Mantén 5-10 segundos y baja. Repite 8-10 veces.',
    ],
    'benefits': 'Promueve la extensión lumbar contrarrestando el sedentarismo, alivia la compresión discal anterior y estira el psoas.',
    'whenToUse': 'Después de estar sentado mucho tiempo, o como parte del calentamiento previo a ejercicios de cadera y piernas.',
  },
  {
    'name': 'Bird-Dog (estabilidad lumbar)',
    'type': 'fortalecimiento',
    'jointFamily': 'lumbar',
    'instructions': [
      'A cuatro patas con la espalda neutral.',
      'Simultáneamente extiende el brazo derecho al frente y la pierna izquierda atrás.',
      'Mantén la cadera nivelada y el core activo durante 3-5 segundos.',
      'Vuelve y alterna al otro lado.',
      'Realiza 10 repeticiones por lado.',
    ],
    'benefits': 'Fortalece los extensores lumbares, glúteos y el core profundo de forma segura. Uno de los ejercicios más recomendados para la salud lumbar.',
    'whenToUse': 'Calentamiento antes de peso muerto o sentadillas. También como ejercicio principal en programas de prevención de dolor lumbar.',
  },
  {
    'name': 'Dead Bug (estabilidad lumbar)',
    'type': 'fortalecimiento',
    'jointFamily': 'lumbar',
    'instructions': [
      'Tumbado boca arriba, brazos extendidos al techo, rodillas a 90° elevadas.',
      'Exhala lentamente y baja simultáneamente el brazo derecho atrás y la pierna izquierda al suelo.',
      'La zona lumbar debe mantenerse pegada al suelo durante todo el movimiento.',
      'Vuelve y alterna. 8-10 repeticiones por lado.',
    ],
    'benefits': 'Fortalece el transverso abdominal y los estabilizadores lumbares, mejora la disociación lumbo-pélvica y previene el dolor lumbar.',
    'whenToUse': 'Como calentamiento de core antes de sentadillas o peso muerto. También en programas de rehabilitación lumbar.',
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Artículos educativos
// ─────────────────────────────────────────────────────────────────────────────

/// Siembra artículos educativos de ejemplo si la tabla está vacía.
Future<void> seedArticles(Connection conn) async {
  if (Platform.environment['RUNMODE'] == 'production') return;

  final count = (await conn.execute('SELECT COUNT(*) AS c FROM articles'))
      .first.toColumnMap()['c'] as int? ?? 0;
  if (count > 0) {
    print('[Seed] Artículos ya presentes ($count), omitiendo.');
    return;
  }

  // Obtener el id del admin para usarlo como autor
  final adminRows = await conn.execute(
    Sql.named('SELECT id FROM users WHERE email = @email'),
    parameters: {'email': 'admin@ubiobio.cl'},
  );
  if (adminRows.isEmpty) {
    print('[Seed] Admin no encontrado, omitiendo artículos.');
    return;
  }
  final adminId = adminRows.first.toColumnMap()['id'].toString();

  print('[Seed] Sembrando artículos educativos...');

  for (final article in _devArticles) {
    final id = _uuid.v4();
    final wordCount = (article['content'] as String).split(' ').length;
    final readTime = (wordCount / 200).ceil().clamp(1, 60);
    await conn.execute(
      "INSERT INTO articles (id, title, category, content, tags, author_id, read_time_minutes, is_published, published_at) "
      "VALUES ('$id'::uuid, \$1, \$2, \$3, \$4, '$adminId'::uuid, $readTime, true, NOW())",
      parameters: [
        article['title'],
        article['category'],
        article['content'],
        article['tags'],
      ],
    );
  }
  print('[Seed] ${_devArticles.length} artículos insertados.');
}

const _devArticles = [
  {
    'title': 'Técnica correcta de la sentadilla: cómo prevenir lesiones',
    'category': 'biomecanica',
    'tags': ['sentadilla', 'técnica', 'rodillas', 'espalda'],
    'content': '''
La sentadilla es uno de los ejercicios más completos del entrenamiento de fuerza, pero también uno de los que más lesiones genera cuando se ejecuta incorrectamente. Comprender la biomecánica detrás del movimiento te permitirá entrenar con mayor eficiencia y seguridad a largo plazo.

## Posición inicial

Los pies deben estar a la anchura de los hombros o ligeramente más separados, con los pies apuntando ligeramente hacia afuera (entre 15 y 30 grados). Esta posición permite que las caderas desciendan libremente entre las rodillas sin forzar la rotación interna.

## Fase de descenso

Inicia el movimiento empujando las caderas hacia atrás antes de doblar las rodillas. Esto activa los isquiotibiales y distribuye la carga entre cuádriceps y glúteos de forma equitativa. Mantén el pecho erguido y la columna en posición neutra durante todo el recorrido.

Las rodillas deben seguir la dirección de los pies. Un error común es el "valgus de rodilla" (rodillas que colapsan hacia adentro), que incrementa el estrés sobre el ligamento cruzado anterior (LCA) y el menisco.

## Profundidad adecuada

La profundidad óptima depende de tu anatomía. El objetivo es alcanzar al menos los 90 grados (muslos paralelos al suelo), pero la prioridad siempre es mantener la postura correcta. Forzar la profundidad con columna flexionada aumenta el riesgo de hernia discal.

## Errores más frecuentes

- Talones que se levantan del suelo: indica falta de movilidad en el tobillo. Trabaja la dorsiflexión con ejercicios específicos.
- Redondeo de la espalda baja: generalmente por falta de fuerza en el core. Agrega planchas y ejercicios de estabilidad lumbar.
- Peso del cuerpo cargado en las puntas: el centro de gravedad debe estar sobre el mediopié.

## Progresión recomendada

Comienza sin carga practicando la sentadilla con apoyo (goblet squat con kettlebell) para aprender la mecánica correcta antes de añadir barra. Solo aumenta el peso cuando domines la técnica con el peso corporal.

La paciencia en la construcción de la técnica es la mejor inversión que puedes hacer para tu longevidad atlética.
''',
  },
  {
    'title': 'Nutrición pre-entrenamiento: qué comer y cuándo',
    'category': 'nutricion',
    'tags': ['nutricion', 'pre-entreno', 'carbohidratos', 'proteína'],
    'content': '''
Lo que comes antes de entrenar puede marcar una diferencia significativa en tu rendimiento y en la calidad de tu sesión. La nutrición pre-entrenamiento tiene como objetivo principal proveer energía suficiente, minimizar el catabolismo muscular y optimizar el enfoque mental.

## El rol de los macronutrientes

### Carbohidratos: el combustible principal
Los carbohidratos son la fuente de energía preferida del músculo durante el ejercicio de alta intensidad. Se almacenan como glucógeno en músculos e hígado. Consumir carbohidratos 1-3 horas antes del entrenamiento asegura que estos depósitos estén llenos.

Fuentes recomendadas: avena, arroz, plátano, tostadas integrales, papa. Preferir carbohidratos de bajo a moderado índice glucémico para una liberación sostenida de energía.

### Proteínas: protección muscular
Una porción moderada de proteína antes de entrenar reduce el catabolismo muscular y facilita la síntesis proteica post-entrenamiento. 20-30 g de proteína completa es suficiente.

Fuentes: huevo, yogur griego, pechuga de pollo, atún.

### Grasas: con moderación
Las grasas enlentecen la digestión, por lo que deben consumirse en cantidades moderadas antes de un entrenamiento intenso para evitar malestar gástrico.

## Timing: ¿cuándo comer?

- **2-3 horas antes**: comida completa con carbohidratos complejos, proteínas y poca grasa.
- **1-1,5 horas antes**: comida más liviana, evitar alto contenido de fibra o grasa.
- **30-45 minutos antes**: snack rápido como un plátano con mantequilla de maní, o un batido de proteína con avena.

## Hidratación

Llega bien hidratado al entrenamiento. El rendimiento decrece con apenas un 2% de deshidratación corporal. Consume al menos 500 ml de agua en las 2 horas previas al ejercicio.

## Caso especial: entrenamiento en ayunas

Algunos atletas prefieren el entrenamiento en ayunas (en particular cardio ligero) para maximizar la oxidación de grasas. Sin embargo, para sesiones de fuerza de alta intensidad, el rendimiento generalmente es superior con una adecuada ingesta previa.

Experimenta con distintos enfoques y registra cómo te sientes durante y después de cada sesión para encontrar tu protocolo ideal.
''',
  },
  {
    'title': 'Prevención de lesiones de hombro en el gimnasio',
    'category': 'prevencion',
    'tags': ['hombro', 'manguito rotador', 'lesión', 'prevención'],
    'content': '''
El hombro es la articulación con mayor movilidad del cuerpo humano, y por eso también es una de las más susceptibles a lesiones en el entrenamiento. La mayoría de las lesiones de hombro en el gimnasio son prevenibles con una correcta programación y trabajo específico de estabilización.

## Anatomía relevante

El complejo articular del hombro incluye la articulación glenohumeral, la escapulotorácica, la acromioclavicular y la esternoclavicular. El manguito rotador, formado por los músculos supraespinoso, infraespinoso, redondo menor y subescapular, es el principal estabilizador dinámico.

Una desbalance entre los músculos del manguito rotador y los músculos movilizadores principales (pectoral, deltoides anterior, dorsal) es la causa más frecuente de lesiones.

## Errores comunes que generan lesiones

### Press de banca con agarre demasiado ancho
Un agarre superior a 1,5 veces la anchura de los hombros en el press de banca incrementa significativamente el estrés sobre el manguito rotador y el bíceps. Mantén los codos a 45-75 grados respecto al torso.

### Dominadas y jalones detrás del cuello
Bajar la barra detrás de la cabeza en jalones o jalones de polea coloca el hombro en posición de máxima vulnerabilidad. Siempre baja hacia el pecho.

### Press militar con excesiva extensión lumbar
Arquear exageradamente la espalda al realizar press de hombros reduce el trabajo del deltoides y aumenta el riesgo de pinzamiento subacromial.

## Ejercicios preventivos clave

1. **Rotaciones externas con banda elástica**: 3 series de 15 repeticiones, codo a 90°. Fortalece infraespinoso y redondo menor.
2. **Face pulls con polea alta**: activa el manguito posterior y los retractores escapulares.
3. **YTW con mancuernas livias**: fortalece la musculatura estabilizadora de la escápula.
4. **Press en W (LYTP)**: trabajo combinado de retracción escapular y rotación externa.

## Programación recomendada

Incluye 2-3 series de ejercicios preventivos al inicio de cada sesión de empuje. La prevención toma 10-15 minutos y puede ahorrarte meses de recuperación.

Ante cualquier dolor agudo, chasquido articular o pérdida de rango de movimiento, consulta con un kinesiólogo antes de continuar entrenando.
''',
  },
  {
    'title': 'Pausas activas en el trabajo: beneficios y rutina de 10 minutos',
    'category': 'pausas_activas',
    'tags': ['pausa activa', 'oficina', 'sedentarismo', 'movilidad'],
    'content': '''
El sedentarismo prolongado es uno de los principales factores de riesgo para el dolor músculo-esquelético y las enfermedades cardiovasculares. Estudios recientes demuestran que pasar más de 8 horas sentado aumenta la mortalidad incluso en personas que realizan actividad física regular.

Las pausas activas son interrupciones breves del trabajo sedentario que incluyen movimiento, estiramiento y ejercicios de activación muscular. Con solo 5-10 minutos cada 1-2 horas, pueden reducir significativamente el dolor de cuello, hombros y zona lumbar.

## Beneficios comprobados

- Reducción del dolor cervical y lumbar hasta un 40% en trabajadores de oficina.
- Mejora de la concentración y productividad al reactivar la circulación.
- Reducción de la fatiga visual por el cambio de foco.
- Prevención del síndrome de túnel carpiano en trabajo con teclado.

## Rutina de pausa activa (10 minutos)

### Cuello y cervicales (2 min)
- Rotaciones cervicales lentas: 5 repeticiones en cada dirección.
- Inclinaciones laterales: sostener 10 segundos por lado.
- Retracción cefálica (llevar mentón hacia atrás): 10 repeticiones.

### Hombros y parte superior del torso (3 min)
- Círculos de hombros hacia adelante y atrás: 10 repeticiones.
- Apertura de pectorales con brazos en cruz: 30 segundos.
- Encogimientos de hombros + retracción escapular: 10 repeticiones.

### Espalda baja y caderas (3 min)
- Rotaciones de cadera de pie: 10 por lado.
- Inclinación hacia adelante suave con rodillas semiflexionadas: 20 segundos.
- Extensión de cadera en apoyo: 10 repeticiones por pierna.

### Activación general (2 min)
- 20 saltos de tijera suaves.
- Marcha en el lugar elevando rodillas durante 30 segundos.
- Respiración diafragmática profunda: 5 respiraciones lentas.

## Cómo implementarlo

Programa recordatorios en tu computadora cada 90 minutos. La constancia es más importante que la intensidad: pequeñas interrupciones frecuentes generan mayores beneficios que una sola sesión larga.
''',
  },
  {
    'title': 'Recuperación muscular: estrategias basadas en evidencia',
    'category': 'recuperacion',
    'tags': ['recuperación', 'descanso', 'DOMS', 'sueño'],
    'content': '''
La recuperación no es simplemente descansar: es un proceso activo mediante el cual el músculo se adapta al estímulo del entrenamiento, se reparan las microlesiones musculares y se resintetizan los sustratos energéticos. Una recuperación deficiente es la principal causa de sobreentrenamiento y estancamiento en el rendimiento.

## ¿Qué ocurre después de un entrenamiento intenso?

Durante las primeras 24-48 horas post-ejercicio intenso, es común experimentar el DOMS (Delayed Onset Muscle Soreness), el dolor muscular de aparición tardía. Este fenómeno es normal y no indica necesariamente lesión, sino el proceso inflamatorio asociado a la adaptación muscular.

El glucógeno muscular tarda entre 24 y 48 horas en resintetizarse completamente con una ingesta adecuada de carbohidratos. La síntesis proteica muscular permanece elevada entre 24 y 48 horas post-ejercicio de fuerza.

## Estrategias con mayor evidencia científica

### 1. Sueño de calidad
Es la estrategia más efectiva. Durante el sueño profundo se libera la mayor concentración de hormona de crecimiento (GH), fundamental para la reparación tisular. 7-9 horas para adultos activos. La privación de sueño eleva el cortisol e inhibe la síntesis proteica.

### 2. Nutrición post-entrenamiento
Consumir carbohidratos + proteínas dentro de las 2 horas post-ejercicio acelera la resíntesis de glucógeno y la síntesis proteica. Una proporción de 3:1 (carbohidratos:proteínas) es una guía práctica efectiva.

### 3. Hidratación
Reponer el líquido perdido durante el entrenamiento. Una orina de color amarillo pálido indica buena hidratación.

### 4. Baños de contraste
Alternar agua fría (10-15°C, 1 min) con agua caliente (38-40°C, 2 min) durante 15-20 minutos puede reducir el DOMS y acelerar la recuperación. Útil especialmente en competencias o bloques de entrenamiento intenso.

### 5. Movilidad activa y trabajo aeróbico liviano
El "active recovery" (30-45 minutos de bicicleta o caminata suave al 50-60% de la frecuencia cardíaca máxima) aumenta el flujo sanguíneo muscular sin generar más daño, acelerando la eliminación de metabolitos.

## Lo que NO tiene suficiente evidencia

- Foam rolling como recuperación acelerada: moderada evidencia de reducción del DOMS, pero no acelera la recuperación funcional.
- Suplementos de BCAA en personas con ingesta proteica adecuada: redundantes si la dieta cubre los requerimientos proteicos totales.
- Baños de hielo inmediatos post-fuerza: pueden inhibir la señalización anabólica si se aplican en los primeros 30-60 minutos post-entrenamiento.

La individualización es clave: lo que funciona para un atleta puede no funciona para otro. Lleva un diario de entrenamiento que incluya variables de recuperación subjetiva.
''',
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Eventos UBB
// ─────────────────────────────────────────────────────────────────────────────

/// Siembra eventos de ejemplo si la tabla está vacía.
Future<void> seedEvents(Connection conn) async {
  if (Platform.environment['RUNMODE'] == 'production') return;

  final count = (await conn.execute('SELECT COUNT(*) AS c FROM events'))
      .first.toColumnMap()['c'] as int? ?? 0;
  if (count > 0) {
    print('[Seed] Eventos ya presentes ($count), omitiendo.');
    return;
  }

  final adminRows = await conn.execute(
    Sql.named('SELECT id FROM users WHERE email = @email'),
    parameters: {'email': 'admin@ubiobio.cl'},
  );
  if (adminRows.isEmpty) {
    print('[Seed] Admin no encontrado, omitiendo eventos.');
    return;
  }
  final adminId = adminRows.first.toColumnMap()['id'].toString();

  print('[Seed] Sembrando eventos UBB...');

  final now = DateTime.now().toUtc();
  final events = [
    {
      'title': 'Torneo de Powerlifting UBB 2026',
      'type': 'Competencia',
      'description': 'Primera competencia de powerlifting estudiantil de la Universidad del Bío-Bío. '
          'Categorías: -66 kg, -74 kg, -83 kg, -93 kg y +93 kg para varones; '
          '-52 kg, -63 kg, -72 kg y +72 kg para mujeres. '
          'Los participantes competirán en sentadilla, press de banca y peso muerto. '
          'Se otorgarán medallas a los tres primeros lugares de cada categoría. '
          'Inscripción gratuita para estudiantes UBB.',
      'location': 'Gimnasio UBB, Campus La Castilla, Chillán',
      'event_date': DateTime(now.year, now.month + 1, 15).toUtc().toIso8601String(),
      'registration_url': 'https://forms.gle/ejemplo',
    },
    {
      'title': 'Charla: Nutrición Deportiva para Universitarios',
      'type': 'Charla',
      'description': 'Charla magistral a cargo del Lic. en Nutrición y Dietética de la Facultad de Ciencias de la Salud UBB. '
          'Se abordarán temas como: requerimientos calóricos y proteicos para deportistas universitarios, '
          'mitos y verdades sobre suplementación deportiva, planificación de comidas en el contexto universitario '
          'y estrategias prácticas de nutrición pre y post entrenamiento. '
          'Habrá espacio para preguntas al final. Cupos limitados.',
      'location': 'Auditorio Facultad de Ciencias de la Salud, UBB',
      'event_date': DateTime(now.year, now.month, now.day + 10).toUtc().toIso8601String(),
      'registration_url': null,
    },
    {
      'title': 'Jornada de Pausas Activas en Campus',
      'type': 'Actividad',
      'description': 'Iniciativa del Gimnasio UBB en colaboración con Bienestar Estudiantil. '
          'Monitores del gimnasio recorrerán los distintos edificios del campus realizando actividades de '
          'pausas activas de 10 minutos para funcionarios y estudiantes. '
          'Participa en tu lugar de trabajo o en los pasillos de tu facultad. '
          'No se requiere inscripción previa. ¡Solo ganas de moverte!',
      'location': 'Campus La Castilla, UBB — distintos puntos del campus',
      'event_date': DateTime(now.year, now.month, now.day + 5).toUtc().toIso8601String(),
      'registration_url': null,
    },
  ];

  for (final event in events) {
    final id = _uuid.v4();
    final regUrl = event['registration_url'];
    final eventDate = event['event_date'] as String;
    if (regUrl != null) {
      await conn.execute(
        "INSERT INTO events (id, title, type, description, location, event_date, registration_url, created_by) "
        "VALUES ('$id'::uuid, \$1, \$2, \$3, \$4, '$eventDate'::timestamptz, \$5, '$adminId'::uuid)",
        parameters: [event['title'], event['type'], event['description'], event['location'], regUrl],
      );
    } else {
      await conn.execute(
        "INSERT INTO events (id, title, type, description, location, event_date, created_by) "
        "VALUES ('$id'::uuid, \$1, \$2, \$3, \$4, '$eventDate'::timestamptz, '$adminId'::uuid)",
        parameters: [event['title'], event['type'], event['description'], event['location']],
      );
    }
  }
  print('[Seed] ${events.length} eventos insertados.');
}
