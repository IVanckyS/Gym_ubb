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
    await conn.execute(
      Sql.named('''
        INSERT INTO exercises (
          name, muscle_group, difficulty, description,
          muscles, instructions, safety_notes, variations,
          video_url, equipment, default_sets, default_reps, default_rest_seconds
        ) VALUES (
          @name, @muscle_group::muscle_group, @difficulty::difficulty_level, @description,
          @muscles, @instructions, @safety_notes, @variations,
          @video_url, @equipment, @default_sets, @default_reps, @default_rest_seconds
        )
      '''),
      parameters: exercise,
    );
  }

  final inserted = _devExercises.length;
  print('[Seed] $inserted ejercicios insertados correctamente.');
}

// ─────────────────────────────────────────────────────────────────────────────
// Datos del mockup (src/data/mockData.js)
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _devExercises = [
  // ── Pecho ─────────────────────────────────────────────────────────────────
  {
    'name': 'Press de Banca',
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
