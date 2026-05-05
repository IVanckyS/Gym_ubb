import 'dart:io';
import 'package:postgres/postgres.dart';
import 'package:bcrypt/bcrypt.dart';
import 'package:uuid/uuid.dart';

final _uuid = Uuid();

/// Crea el usuario administrador de desarrollo si no existe.
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

/// Limpia y resiembra ejercicios completos en cada arranque dev.
Future<void> seedDev(Connection conn) async {
  if (Platform.environment['RUNMODE'] == 'production') return;

  print('[Seed] Limpiando datos de ejercicios anteriores...');
  await conn.execute('DELETE FROM hiit_sessions');
  await conn.execute('DELETE FROM lift_submissions');
  await conn.execute('DELETE FROM personal_records');
  await conn.execute('DELETE FROM workout_sets');
  await conn.execute('DELETE FROM workout_sessions');
  await conn.execute('DELETE FROM routine_day_exercises');
  await conn.execute('DELETE FROM exercises');

  print('[Seed] Sembrando ${_devExercises.length} ejercicios...');

  for (final exercise in _devExercises) {
    final isRankeable = exercise['is_rankeable'] as bool? ?? false;
    final exerciseType = exercise['exercise_type'] as String? ?? 'dinamico';
    final imageUrl = exercise['image_url'] as String?;
    await conn.execute(
      Sql.named('''
        INSERT INTO exercises (
          name, muscle_group, difficulty, description,
          muscles, instructions, safety_notes, variations,
          video_url, image_url, equipment,
          default_sets, default_reps, default_rest_seconds,
          is_rankeable, exercise_type
        ) VALUES (
          @name, @muscle_group::muscle_group, @difficulty::difficulty_level, @description,
          @muscles, @instructions, @safety_notes, @variations,
          @video_url, @image_url, @equipment,
          @default_sets, @default_reps, @default_rest_seconds,
          @is_rankeable, @exercise_type
        )
      '''),
      parameters: {
        'name': exercise['name'],
        'muscle_group': exercise['muscle_group'],
        'difficulty': exercise['difficulty'],
        'description': exercise['description'],
        'muscles': (exercise['muscles'] as List).cast<String>(),
        'instructions': (exercise['instructions'] as List).cast<String>(),
        'safety_notes': exercise['safety_notes'],
        'variations': (exercise['variations'] as List).cast<String>(),
        'video_url': exercise['video_url'],
        'image_url': imageUrl,
        'equipment': exercise['equipment'],
        'default_sets': exercise['default_sets'],
        'default_reps': exercise['default_reps'],
        'default_rest_seconds': exercise['default_rest_seconds'],
        'is_rankeable': isRankeable,
        'exercise_type': exerciseType,
      },
    );
  }

  print('[Seed] ${_devExercises.length} ejercicios insertados correctamente.');
}

// ─────────────────────────────────────────────────────────────────────────────
// Ejercicios — 52 en total, todos los grupos musculares y tipos
// ─────────────────────────────────────────────────────────────────────────────
const List<Map<String, dynamic>> _devExercises = [

  // ══════════════════════════════════════════════════════════════
  // PECHO  (7 ejercicios)
  // ══════════════════════════════════════════════════════════════
  {
    'name': 'Press de Banca',
    'exercise_type': 'dinamico',
    'is_rankeable': true,
    'muscle_group': 'pecho',
    'difficulty': 'intermedio',
    'description': 'El ejercicio rey del pecho. Trabaja pectoral mayor, tríceps y deltoides anterior con carga libre.',
    'muscles': ['Pectoral mayor', 'Tríceps braquial', 'Deltoides anterior'],
    'instructions': [
      'Túmbate en el banco con los pies planos en el suelo.',
      'Agarra la barra a una anchura ligeramente mayor que los hombros.',
      'Desrackea la barra y bájala controladamente hasta rozar el pecho.',
      'Empuja explosivamente hasta extender los codos sin bloquearlos.',
      'Mantén los omóplatos retraídos y la espalda baja con leve arco natural.',
    ],
    'safety_notes': 'Usa siempre spotter o barras de seguridad. No rebotes la barra en el pecho.',
    'variations': ['Press inclinado', 'Press declinado', 'Press con mancuernas', 'Press en máquina'],
    'video_url': 'https://www.youtube.com/embed/rT7DgCr-3pg',
    'image_url': 'https://img.youtube.com/vi/rT7DgCr-3pg/hqdefault.jpg',
    'equipment': 'Barra + Banco',
    'default_sets': 4,
    'default_reps': '5-8',
    'default_rest_seconds': 120,
  },
  {
    'name': 'Press Inclinado con Mancuernas',
    'exercise_type': 'dinamico',
    'muscle_group': 'pecho',
    'difficulty': 'intermedio',
    'description': 'Variante inclinada que enfatiza el pectoral superior y mejora la forma del escote.',
    'muscles': ['Pectoral mayor (clavicular)', 'Tríceps braquial', 'Deltoides anterior'],
    'instructions': [
      'Ajusta el banco a 30-45°.',
      'Sujeta una mancuerna en cada mano a la altura de los hombros.',
      'Empuja hacia arriba y ligeramente hacia el centro.',
      'Baja controladamente hasta que los codos queden en línea con el banco.',
    ],
    'safety_notes': 'No subas la inclinación más de 45°; trabajarías más hombros que pecho.',
    'variations': ['Press inclinado con barra', 'Aperturas inclinadas', 'Press en máquina inclinada'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas + Banco inclinado',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Aperturas en Cables (Crossover)',
    'exercise_type': 'dinamico',
    'muscle_group': 'pecho',
    'difficulty': 'principiante',
    'description': 'Ejercicio de aislamiento con tensión constante en el pectoral gracias al cable.',
    'muscles': ['Pectoral mayor', 'Deltoides anterior'],
    'instructions': [
      'Coloca las poleas en la posición alta y pon un peso ligero-moderado.',
      'Párate en el centro con un pie adelantado para estabilidad.',
      'Tira de los cables hacia adelante y hacia abajo cruzándolos frente al pecho.',
      'Vuelve lentamente controlando la tensión en cada repetición.',
    ],
    'safety_notes': 'Mantén ligera flexión en codos durante todo el movimiento.',
    'variations': ['Aperturas con mancuernas', 'Pec-deck', 'Cable crossover bajo'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Máquina de cables',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Press de Pecho en Máquina',
    'exercise_type': 'dinamico',
    'muscle_group': 'pecho',
    'difficulty': 'principiante',
    'description': 'Opción segura y guiada ideal para principiantes o para acumular volumen al final del entrenamiento.',
    'muscles': ['Pectoral mayor', 'Tríceps braquial', 'Deltoides anterior'],
    'instructions': [
      'Ajusta el asiento para que las manijas queden a la altura del pecho.',
      'Siéntate con la espalda completamente apoyada en el respaldo.',
      'Empuja las manijas hasta extender casi los brazos.',
      'Vuelve lentamente sin dejar que el peso toque el stack.',
    ],
    'safety_notes': 'No bloquees los codos al extender. Mantén los pies en el suelo.',
    'variations': ['Press de pecho con banda', 'Press declinado en máquina'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Máquina de press de pecho',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Pullover con Mancuerna',
    'exercise_type': 'dinamico',
    'muscle_group': 'pecho',
    'difficulty': 'intermedio',
    'description': 'Ejercicio único que trabaja pecho y dorsal simultáneamente, excelente para expansión del tórax.',
    'muscles': ['Pectoral mayor', 'Dorsal ancho', 'Tríceps largo'],
    'instructions': [
      'Túmbate perpendicular al banco apoyando solo la zona alta de la espalda.',
      'Sostén una mancuerna con ambas manos sobre el pecho.',
      'Lleva la mancuerna hacia atrás describiendo un arco amplio.',
      'Vuelve al punto de partida contrayendo el pecho.',
    ],
    'safety_notes': 'Mantén las caderas al nivel del banco o más bajas. No uses pesos excesivos.',
    'variations': ['Pullover con barra', 'Pullover en polea'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuerna + Banco',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Push Up (Flexiones)',
    'exercise_type': 'calistenia',
    'muscle_group': 'pecho',
    'difficulty': 'principiante',
    'description': 'El ejercicio de pecho más accesible. Sin equipamiento, en cualquier lugar, con decenas de variantes.',
    'muscles': ['Pectoral mayor', 'Tríceps braquial', 'Deltoides anterior', 'Core'],
    'instructions': [
      'Posición de plancha alta: manos ligeramente más anchas que los hombros.',
      'Mantén el cuerpo en línea recta de cabeza a talones, core activo.',
      'Baja el pecho hacia el suelo flexionando los codos a 45°.',
      'Empuja hasta extender los brazos sin bloquear los codos.',
    ],
    'safety_notes': 'No dejes caer las caderas. Si no aguantas el peso completo, apoya las rodillas.',
    'variations': ['Flexiones diamante', 'Flexiones declinadas', 'Flexiones con palmada', 'Archer push-up'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 3,
    'default_reps': '15-20',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Fondos en Paralelas',
    'exercise_type': 'calistenia',
    'muscle_group': 'pecho',
    'difficulty': 'intermedio',
    'description': 'Ejercicio compuesto de peso corporal que carga fuertemente pecho inferior, tríceps y hombros.',
    'muscles': ['Pectoral mayor (esternal)', 'Tríceps braquial', 'Deltoides anterior'],
    'instructions': [
      'Sujétate en las barras con los brazos extendidos.',
      'Inclina el torso 20-30° hacia adelante para enfatizar el pecho.',
      'Baja flexionando codos hasta que los hombros queden al nivel de los codos (90°).',
      'Empuja hacia arriba volviendo a la posición inicial.',
    ],
    'safety_notes': 'No bajes más de 90° si tienes historial de lesiones de hombro.',
    'variations': ['Fondos con lastre', 'Fondos asistidos con banda', 'Dips en banco'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Barras paralelas',
    'default_sets': 3,
    'default_reps': '8-12',
    'default_rest_seconds': 90,
  },

  // ══════════════════════════════════════════════════════════════
  // ESPALDA  (7 ejercicios)
  // ══════════════════════════════════════════════════════════════
  {
    'name': 'Peso Muerto',
    'exercise_type': 'dinamico',
    'is_rankeable': true,
    'muscle_group': 'espalda',
    'difficulty': 'avanzado',
    'description': 'El ejercicio más completo del gimnasio. Activa más de 20 grupos musculares en un solo movimiento.',
    'muscles': ['Isquiotibiales', 'Glúteo mayor', 'Erector espinal', 'Trapecios', 'Core', 'Dorsales'],
    'instructions': [
      'Para frente a la barra, pies al ancho de caderas, barra sobre el mediopié.',
      'Agáchate y agarra la barra con agarre prono o mixto.',
      'Espalda recta, pecho elevado, caderas más altas que rodillas.',
      'Empuja el suelo con los pies y extiende caderas y rodillas simultáneamente.',
      'Bloquea arriba apretando glúteos. Baja controladamente.',
    ],
    'safety_notes': 'CRÍTICO: nunca redondees la zona lumbar. Empieza con pesos ligeros para aprender la técnica.',
    'variations': ['Peso muerto rumano', 'Peso muerto sumo', 'Peso muerto con trampa hexagonal'],
    'video_url': 'https://www.youtube.com/embed/op9kVnSso6Q',
    'image_url': 'https://img.youtube.com/vi/op9kVnSso6Q/hqdefault.jpg',
    'equipment': 'Barra',
    'default_sets': 3,
    'default_reps': '3-5',
    'default_rest_seconds': 180,
  },
  {
    'name': 'Dominadas',
    'exercise_type': 'calistenia',
    'muscle_group': 'espalda',
    'difficulty': 'intermedio',
    'description': 'El mejor ejercicio de peso corporal para construir un dorsal ancho y una espalda fuerte.',
    'muscles': ['Dorsal ancho', 'Bíceps braquial', 'Romboides', 'Trapecio inferior'],
    'instructions': [
      'Cuelga de la barra con agarre prono, manos algo más anchas que los hombros.',
      'Activa el core y retrae las escápulas antes de subir.',
      'Tira hacia arriba hasta que la barbilla supere la barra.',
      'Baja completamente de forma controlada.',
    ],
    'safety_notes': 'No balancees. Si no puedes hacer ninguna, usa banda elástica como asistencia.',
    'variations': ['Chin-ups (agarre supino)', 'Dominadas con lastre', 'Dominadas neutras', 'Archer pull-up'],
    'video_url': 'https://www.youtube.com/embed/eGo4IYlbE5g',
    'image_url': 'https://img.youtube.com/vi/eGo4IYlbE5g/hqdefault.jpg',
    'equipment': 'Barra de dominadas',
    'default_sets': 4,
    'default_reps': '6-10',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Remo con Barra',
    'exercise_type': 'dinamico',
    'muscle_group': 'espalda',
    'difficulty': 'intermedio',
    'description': 'Ejercicio compuesto fundamental para el grosor de la espalda media y baja.',
    'muscles': ['Dorsal ancho', 'Romboides', 'Trapecio medio', 'Bíceps braquial', 'Erector espinal'],
    'instructions': [
      'Inclínate hacia adelante a ~45° con rodillas ligeramente flexionadas.',
      'Agarra la barra con agarre prono ligeramente más ancho que los hombros.',
      'Tira de la barra hacia el abdomen apretando los codos cerca del cuerpo.',
      'Aprieta los omóplatos al final del recorrido y baja lentamente.',
    ],
    'safety_notes': 'Nunca redondees la espalda. La cabeza va en extensión neutral del cuello.',
    'variations': ['Remo Pendlay', 'Remo con mancuernas', 'Remo en polea baja', 'Remo en máquina'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Barra',
    'default_sets': 4,
    'default_reps': '8-10',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Jalón al Pecho',
    'exercise_type': 'dinamico',
    'muscle_group': 'espalda',
    'difficulty': 'principiante',
    'description': 'Alternativa a las dominadas en polea, ideal para principiantes o para acumular volumen.',
    'muscles': ['Dorsal ancho', 'Bíceps braquial', 'Romboides', 'Trapecio inferior'],
    'instructions': [
      'Siéntate en la máquina con los muslos bien sujetos bajo el rodillo.',
      'Agarra la barra con agarre amplio prono.',
      'Inclínate ligeramente hacia atrás y tira de la barra hacia el pecho superior.',
      'Vuelve lentamente a la posición inicial sin soltarte.',
    ],
    'safety_notes': 'NUNCA jales detrás de la nuca: aumenta el riesgo de lesión cervical.',
    'variations': ['Jalón agarre neutro', 'Jalón agarre cerrado', 'Jalón unilateral'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Máquina de polea',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 75,
  },
  {
    'name': 'Remo con Mancuerna',
    'exercise_type': 'dinamico',
    'muscle_group': 'espalda',
    'difficulty': 'principiante',
    'description': 'Ejercicio unilateral que permite mayor rango de movimiento y corrige desequilibrios entre lados.',
    'muscles': ['Dorsal ancho', 'Romboides', 'Bíceps braquial', 'Trapecio medio'],
    'instructions': [
      'Apoya una rodilla y la mano del mismo lado en un banco.',
      'Sujeta la mancuerna con el brazo colgante, espalda paralela al suelo.',
      'Tira de la mancuerna hacia la cadera llevando el codo hacia el techo.',
      'Baja controladamente hasta extender el brazo.',
    ],
    'safety_notes': 'No rotes el torso al tirar. El movimiento viene del codo, no del hombro.',
    'variations': ['Remo en polea unilateral', 'Kroc row'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuerna + Banco',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Remo en Polea Baja',
    'exercise_type': 'dinamico',
    'muscle_group': 'espalda',
    'difficulty': 'principiante',
    'description': 'Movimiento de tracción horizontal en máquina que trabaja la espalda media con tensión constante.',
    'muscles': ['Dorsal ancho', 'Romboides', 'Trapecio medio', 'Bíceps braquial'],
    'instructions': [
      'Siéntate en la máquina con los pies en los apoyos y rodillas levemente flexionadas.',
      'Agarra el accesorio y tira hacia el abdomen manteniendo la espalda erguida.',
      'Retrae los omóplatos al final y mantén 1 segundo.',
      'Vuelve extendiendo los brazos sin redondear la espalda.',
    ],
    'safety_notes': 'No te eches hacia atrás para tomar impulso. El torso queda casi estático.',
    'variations': ['Remo con barra en polea baja', 'Remo unilateral en polea'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Máquina de polea baja',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Dead Hang (Colgada Estática)',
    'exercise_type': 'isometrico',
    'muscle_group': 'espalda',
    'difficulty': 'principiante',
    'description': 'Ejercicio isométrico que descomprime la columna, fortalece el agarre y activa los estabilizadores del hombro.',
    'muscles': ['Dorsal ancho', 'Manguito rotador', 'Antebrazos', 'Core'],
    'instructions': [
      'Cuelga de la barra con agarre prono, brazos completamente extendidos.',
      'Relaja los hombros dejando que suban hacia las orejas (descompresión pasiva).',
      'Mantén la posición respirando con normalidad.',
      'Incrementa el tiempo progresivamente: 20s → 30s → 60s.',
    ],
    'safety_notes': 'Si tienes lesión de hombro activa, consulta antes de realizar este ejercicio.',
    'variations': ['Dead hang activo (escápulas bajas)', 'Dead hang unilateral'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Barra de dominadas',
    'default_sets': 3,
    'default_reps': '30-60 seg',
    'default_rest_seconds': 60,
  },

  // ══════════════════════════════════════════════════════════════
  // PIERNAS  (9 ejercicios)
  // ══════════════════════════════════════════════════════════════
  {
    'name': 'Sentadilla con Barra',
    'exercise_type': 'dinamico',
    'is_rankeable': true,
    'muscle_group': 'piernas',
    'difficulty': 'intermedio',
    'description': 'El rey de los ejercicios de piernas. Activa cuádriceps, isquiotibiales, glúteos y core de forma integral.',
    'muscles': ['Cuádriceps', 'Glúteo mayor', 'Isquiotibiales', 'Core', 'Erector espinal'],
    'instructions': [
      'Coloca la barra sobre la parte alta de la espalda (sentadilla alta) o baja.',
      'Pies al ancho de hombros o ligeramente más, punteras hacia afuera.',
      'Desrackea, inhala y baja empujando las rodillas hacia afuera.',
      'Profundidad mínima: muslos paralelos al suelo.',
      'Sube empujando desde los talones manteniendo el pecho elevado.',
    ],
    'safety_notes': 'No colapses las rodillas hacia adentro. Nunca redondees la zona lumbar.',
    'variations': ['Sentadilla goblet', 'Sentadilla frontal', 'Hack squat', 'Sentadilla búlgara'],
    'video_url': 'https://www.youtube.com/embed/ultWZbUMPL8',
    'image_url': 'https://img.youtube.com/vi/ultWZbUMPL8/hqdefault.jpg',
    'equipment': 'Barra + Rack',
    'default_sets': 4,
    'default_reps': '5-8',
    'default_rest_seconds': 120,
  },
  {
    'name': 'Peso Muerto Rumano',
    'exercise_type': 'dinamico',
    'muscle_group': 'piernas',
    'difficulty': 'intermedio',
    'description': 'Variante del peso muerto que aísla isquiotibiales y glúteos con énfasis en el estiramiento.',
    'muscles': ['Isquiotibiales', 'Glúteo mayor', 'Erector espinal'],
    'instructions': [
      'De pie con la barra en agarre prono, piernas casi extendidas.',
      'Empuja las caderas hacia atrás inclinando el torso hacia adelante.',
      'Desliza la barra por las piernas manteniendo espalda recta.',
      'Baja hasta sentir estiramiento intenso en isquiotibiales.',
      'Vuelve contrayendo glúteos y extendiendo caderas.',
    ],
    'safety_notes': 'No redondees la espalda baja. La profundidad la limita tu flexibilidad.',
    'variations': ['PDR con mancuernas', 'PDR unilateral (single-leg)', 'Good morning'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Barra o Mancuernas',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Leg Press',
    'exercise_type': 'dinamico',
    'muscle_group': 'piernas',
    'difficulty': 'principiante',
    'description': 'Ejercicio en máquina para cuádriceps con menor riesgo técnico que la sentadilla libre.',
    'muscles': ['Cuádriceps', 'Glúteo mayor', 'Isquiotibiales'],
    'instructions': [
      'Siéntate con la espalda bien pegada al respaldo.',
      'Coloca los pies a la anchura de la cadera en la mitad de la plataforma.',
      'Libera los seguros y baja la plataforma hasta ~90° de rodilla.',
      'Empuja hasta casi extender (no bloquees las rodillas).',
      'Vuelve a poner los seguros antes de bajar del aparato.',
    ],
    'safety_notes': 'No bloquees las rodillas. No despegues la zona baja de la espalda del respaldo.',
    'variations': ['Leg press con pies altos (isquios/glúteos)', 'Leg press unilateral', 'Prensa 45°'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Máquina Leg Press',
    'default_sets': 4,
    'default_reps': '10-15',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Sentadilla Búlgara',
    'exercise_type': 'dinamico',
    'muscle_group': 'piernas',
    'difficulty': 'avanzado',
    'description': 'Sentadilla unilateral con pie trasero elevado: máxima activación de cuádriceps y glúteo con desafío de equilibrio.',
    'muscles': ['Cuádriceps', 'Glúteo mayor', 'Isquiotibiales', 'Core'],
    'instructions': [
      'Coloca el empeine del pie trasero en un banco a ~50 cm.',
      'El pie delantero adelantado un paso largo del banco.',
      'Baja el cuerpo flexionando la rodilla delantera a 90°.',
      'La rodilla trasera desciende casi hasta el suelo.',
      'Empuja desde el talón delantero para volver.',
    ],
    'safety_notes': 'Empieza sin peso hasta dominar el equilibrio. La rodilla delantera no debe sobrepasar los dedos del pie.',
    'variations': ['Con mancuernas', 'Con barra', 'Con goblet', 'Zancada inversa elevada'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Banco + Mancuernas o Barra',
    'default_sets': 3,
    'default_reps': '8-10 por pierna',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Curl Femoral',
    'exercise_type': 'dinamico',
    'muscle_group': 'piernas',
    'difficulty': 'principiante',
    'description': 'Aislamiento de isquiotibiales en máquina, imprescindible para equilibrar el desarrollo cuádriceps/isquios.',
    'muscles': ['Isquiotibiales', 'Gastrocnemio'],
    'instructions': [
      'Tumbado boca arriba o boca abajo según la máquina, con el eje a la altura de las rodillas.',
      'Flexiona las rodillas trayendo los talones hacia los glúteos.',
      'Aprieta los isquiotibiales en el punto máximo.',
      'Extiende lentamente durante 3-4 segundos.',
    ],
    'safety_notes': 'No uses inercia. El movimiento excéntrico lento es clave para prevenir lesiones.',
    'variations': ['Curl nórdico', 'Curl femoral de pie', 'Glute-ham raise'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Máquina curl femoral',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Extensiones de Cuádriceps',
    'exercise_type': 'dinamico',
    'muscle_group': 'piernas',
    'difficulty': 'principiante',
    'description': 'Aislamiento de cuádriceps en máquina, útil para reforzar la rodilla y trabajo de finalización.',
    'muscles': ['Cuádriceps (4 cabezas)'],
    'instructions': [
      'Siéntate con la espalda apoyada y el eje de la máquina alineado con la rodilla.',
      'Extiende las piernas hasta casi rectas contrayendo el cuádriceps.',
      'Mantén la contracción 1 segundo en la parte alta.',
      'Baja lentamente durante 3-4 segundos.',
    ],
    'safety_notes': 'Personas con dolor femoropatelar deben evitar el rango 0-30° de extensión.',
    'variations': ['Extensión unilateral', 'Extensión en rango terminal (TKE)'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Máquina de extensión',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Zancadas con Mancuernas',
    'exercise_type': 'dinamico',
    'muscle_group': 'piernas',
    'difficulty': 'principiante',
    'description': 'Ejercicio unilateral funcional para cuádriceps y glúteos con gran transferencia a movimientos cotidianos.',
    'muscles': ['Cuádriceps', 'Glúteo mayor', 'Isquiotibiales'],
    'instructions': [
      'De pie con mancuernas a los costados.',
      'Da un paso largo hacia adelante.',
      'Baja la rodilla trasera casi hasta el suelo manteniendo el torso erguido.',
      'Empuja con el pie delantero para volver a la posición inicial.',
    ],
    'safety_notes': 'La rodilla delantera no debe superar la punta del pie. Mantén el torso vertical.',
    'variations': ['Zancadas caminando', 'Zancadas inversas', 'Zancadas laterales'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas',
    'default_sets': 3,
    'default_reps': '10-12 por pierna',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Wall Sit (Sentadilla en Pared)',
    'exercise_type': 'isometrico',
    'muscle_group': 'piernas',
    'difficulty': 'principiante',
    'description': 'Ejercicio isométrico que construye resistencia muscular en cuádriceps sin carga compresiva en la rodilla.',
    'muscles': ['Cuádriceps', 'Glúteo mayor', 'Isquiotibiales'],
    'instructions': [
      'Apoya la espalda completamente contra una pared.',
      'Desliza hacia abajo hasta que rodillas y caderas queden a 90°.',
      'Los pies directamente debajo de las rodillas.',
      'Mantén la posición respirando normalmente.',
    ],
    'safety_notes': 'No aguantes la respiración. Si sientes dolor en la rótula, sube un poco la posición.',
    'variations': ['Wall sit con banda', 'Wall sit unilateral', 'Wall sit con peso en muslos'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Pared',
    'default_sets': 3,
    'default_reps': '30-60 seg',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Sentadilla con Salto',
    'exercise_type': 'calistenia',
    'muscle_group': 'piernas',
    'difficulty': 'intermedio',
    'description': 'Variante pliométrica de la sentadilla que desarrolla potencia explosiva en piernas y eleva el ritmo cardíaco.',
    'muscles': ['Cuádriceps', 'Glúteo mayor', 'Isquiotibiales', 'Gemelos'],
    'instructions': [
      'De pie con pies al ancho de hombros.',
      'Realiza una sentadilla hasta 90° de rodilla.',
      'Impulsate explosivamente hacia arriba hasta despegar del suelo.',
      'Aterriza suavemente con rodillas ligeramente flexionadas.',
      'Amortigua el aterrizaje y enlaza directamente con la siguiente repetición.',
    ],
    'safety_notes': 'Aterriza siempre con rodillas flexionadas, nunca con piernas rectas. No recomendado con lesiones de rodilla activas.',
    'variations': ['Box jump', 'Split squat jump', 'Broad jump'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 4,
    'default_reps': '10-15',
    'default_rest_seconds': 60,
  },

  // ══════════════════════════════════════════════════════════════
  // HOMBROS  (6 ejercicios)
  // ══════════════════════════════════════════════════════════════
  {
    'name': 'Press Militar con Barra',
    'exercise_type': 'dinamico',
    'is_rankeable': true,
    'muscle_group': 'hombros',
    'difficulty': 'intermedio',
    'description': 'El ejercicio de empuje vertical por excelencia. Construye masa y fuerza en el deltoides y tríceps.',
    'muscles': ['Deltoides anterior', 'Deltoides lateral', 'Tríceps braquial', 'Trapecio superior'],
    'instructions': [
      'De pie o sentado, barra a la altura de la clavícula con agarre prono.',
      'Empuja hacia arriba en trayectoria ligeramente arqueada.',
      'Mete la cabeza hacia adelante cuando la barra pasa por la frente.',
      'Bloquea los brazos arriba y vuelve controladamente.',
    ],
    'safety_notes': 'Evita el exceso de extensión lumbar. Si hay dolor de hombro, prueba con mancuernas.',
    'variations': ['Press Arnold', 'Press con mancuernas', 'Push press', 'Press en máquina'],
    'video_url': 'https://www.youtube.com/embed/2yjwXTZQDDI',
    'image_url': 'https://img.youtube.com/vi/2yjwXTZQDDI/hqdefault.jpg',
    'equipment': 'Barra o Mancuernas',
    'default_sets': 4,
    'default_reps': '6-10',
    'default_rest_seconds': 120,
  },
  {
    'name': 'Press Arnold',
    'exercise_type': 'dinamico',
    'muscle_group': 'hombros',
    'difficulty': 'intermedio',
    'description': 'Variante del press de hombros con rotación que activa las tres cabezas del deltoides.',
    'muscles': ['Deltoides (3 cabezas)', 'Tríceps braquial', 'Trapecio superior'],
    'instructions': [
      'Sentado, sujeta mancuernas frente a ti con agarre supino a la altura del pecho.',
      'Al empujar hacia arriba, rota las muñecas para que las palmas miren hacia adelante.',
      'Extiende los brazos completamente arriba.',
      'Invierte el movimiento al bajar: rota hacia supino volviendo a la posición inicial.',
    ],
    'safety_notes': 'Usa pesos moderados. La rotación aumenta el ROM pero también el estrés en el manguito.',
    'variations': ['Press de hombros con mancuernas', 'Press militar'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas + Banco con respaldo',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Elevaciones Laterales',
    'exercise_type': 'dinamico',
    'muscle_group': 'hombros',
    'difficulty': 'principiante',
    'description': 'Ejercicio de aislamiento para el deltoides lateral: el responsable de la amplitud de hombros.',
    'muscles': ['Deltoides lateral', 'Deltoides anterior'],
    'instructions': [
      'De pie con mancuernas a los costados, codos ligeramente flexionados.',
      'Eleva los brazos hacia los lados hasta la altura de los hombros.',
      'El pulgar ligeramente hacia abajo (como verter agua de un vaso).',
      'Baja lentamente en 3-4 segundos.',
    ],
    'safety_notes': 'No subas los hombros. Usa pesos que permitan control total.',
    'variations': ['Elevaciones en cable', 'Elevaciones unilaterales', 'Elevaciones laterales tumbado'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Elevaciones Frontales',
    'exercise_type': 'dinamico',
    'muscle_group': 'hombros',
    'difficulty': 'principiante',
    'description': 'Aislamiento del deltoides anterior, complementario al press de pecho que ya lo trabaja indirectamente.',
    'muscles': ['Deltoides anterior', 'Pectoral mayor (porción clavicular)'],
    'instructions': [
      'De pie con mancuernas delante de los muslos, agarre prono.',
      'Sube un brazo hacia adelante hasta la altura de los hombros.',
      'Baja controladamente y alterna con el otro brazo.',
    ],
    'safety_notes': 'No uses impulso del torso. Si entrenas mucho press de pecho, este ejercicio puede ser redundante.',
    'variations': ['Elevaciones con barra', 'Elevaciones con disco', 'Elevaciones en cable'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Face Pull',
    'exercise_type': 'dinamico',
    'muscle_group': 'hombros',
    'difficulty': 'principiante',
    'description': 'Ejercicio preventivo fundamental para la salud del hombro. Contrarresta el exceso de trabajo en empuje.',
    'muscles': ['Deltoides posterior', 'Rotadores externos', 'Romboides', 'Trapecio medio'],
    'instructions': [
      'Polea alta con cuerda, agarra los extremos con agarre neutro.',
      'Tira hacia la cara separando los extremos al final del recorrido.',
      'Los codos quedan por encima de los hombros al llegar al punto final.',
      'Vuelve lentamente manteniendo tensión.',
    ],
    'safety_notes': 'Ejercicio de salud articular, no de fuerza máxima. Prioriza la técnica sobre el peso.',
    'variations': ['Face pull con banda', 'YWT en banco inclinado', 'Remo al cuello'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Polea con cuerda',
    'default_sets': 3,
    'default_reps': '15-20',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Encogimientos de Hombros (Shrugs)',
    'exercise_type': 'dinamico',
    'muscle_group': 'hombros',
    'difficulty': 'principiante',
    'description': 'Ejercicio de aislamiento para el trapecio superior, que define el perfil del cuello y hombros.',
    'muscles': ['Trapecio superior', 'Trapecio medio', 'Elevador de la escápula'],
    'instructions': [
      'De pie con mancuernas a los costados o barra delante.',
      'Encoge los hombros hacia las orejas en movimiento vertical.',
      'Mantén la contracción arriba 1-2 segundos.',
      'Baja completamente y repite.',
    ],
    'safety_notes': 'No hagas círculos con los hombros: puede lesionar la articulación AC.',
    'variations': ['Encogimientos con barra', 'Encogimientos en máquina', 'Encogimientos tras nuca'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas o Barra',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },

  // ══════════════════════════════════════════════════════════════
  // BRAZOS  (7 ejercicios)
  // ══════════════════════════════════════════════════════════════
  {
    'name': 'Curl de Bíceps con Mancuernas',
    'exercise_type': 'dinamico',
    'muscle_group': 'brazos',
    'difficulty': 'principiante',
    'description': 'Ejercicio de aislamiento clásico para el bíceps con rango completo de movimiento.',
    'muscles': ['Bíceps braquial', 'Braquial', 'Braquiorradial'],
    'instructions': [
      'De pie, mancuernas a los costados con agarre supino.',
      'Codos pegados al cuerpo, sin moverlos durante el ejercicio.',
      'Sube contrayendo el bíceps hasta que el antebrazo quede vertical.',
      'Baja controladamente en 3 segundos.',
    ],
    'safety_notes': 'No balancees el torso para levantar más peso. Codos fijos.',
    'variations': ['Curl alterno', 'Curl simultáneo', 'Curl con barra', 'Curl en predicador'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas',
    'default_sets': 3,
    'default_reps': '10-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Curl Martillo',
    'exercise_type': 'dinamico',
    'muscle_group': 'brazos',
    'difficulty': 'principiante',
    'description': 'Variante con agarre neutro que enfatiza el braquial y braquiorradial, construyendo brazos más gruesos.',
    'muscles': ['Braquial', 'Braquiorradial', 'Bíceps braquial'],
    'instructions': [
      'De pie con mancuernas en agarre neutro (pulgares hacia arriba).',
      'Sube la mancuerna manteniendo el agarre neutro durante todo el recorrido.',
      'Baja controladamente.',
    ],
    'safety_notes': 'No supines la muñeca; eso lo convierte en un curl normal.',
    'variations': ['Curl martillo simultáneo', 'Curl de cuerda en polea baja', 'Cross-body curl'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Curl con Barra EZ',
    'exercise_type': 'dinamico',
    'muscle_group': 'brazos',
    'difficulty': 'principiante',
    'description': 'Curl bilateral con barra zigzag que reduce el estrés en muñecas y permite mayor carga que mancuernas.',
    'muscles': ['Bíceps braquial', 'Braquial', 'Braquiorradial'],
    'instructions': [
      'Agarra la barra EZ por los segmentos inclinados interiores.',
      'Codos pegados al cuerpo.',
      'Sube la barra hasta que los antebrazos queden verticales.',
      'Baja en 3-4 segundos.',
    ],
    'safety_notes': 'La barra EZ reduce el estrés en muñecas. Preferible sobre barra recta si hay molestia.',
    'variations': ['Curl con barra recta', 'Curl 21s (7+7+7)'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Barra EZ',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Press Francés (Skull Crusher)',
    'exercise_type': 'dinamico',
    'muscle_group': 'brazos',
    'difficulty': 'intermedio',
    'description': 'Ejercicio de aislamiento para las tres cabezas del tríceps con máximo estiramiento muscular.',
    'muscles': ['Tríceps braquial (3 cabezas)', 'Codo: ligamento lateral'],
    'instructions': [
      'Tumbado en banco, sujeta barra EZ o mancuernas sobre el pecho, brazos verticales.',
      'Dobla los codos bajando el peso hacia la frente (o detrás de la cabeza).',
      'Los codos permanecen fijos apuntando al techo.',
      'Extiende los brazos volviendo a la posición inicial.',
    ],
    'safety_notes': 'Comienza con pesos ligeros. El nombre "skull crusher" describe el riesgo de mala técnica.',
    'variations': ['Press francés con mancuernas', 'JM press', 'Press francés en polea'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Barra EZ o Mancuernas + Banco',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Jalón de Tríceps en Polea',
    'exercise_type': 'dinamico',
    'muscle_group': 'brazos',
    'difficulty': 'principiante',
    'description': 'El ejercicio de tríceps más popular del gimnasio por su seguridad y efectividad.',
    'muscles': ['Tríceps braquial (cabeza lateral y medial)'],
    'instructions': [
      'Polea alta con barra recta, V o cuerda. Agarra el accesorio con codos a 90°.',
      'Codos pegados al cuerpo, estáticos durante todo el movimiento.',
      'Extiende los brazos hacia abajo hasta bloquear los codos.',
      'Vuelve controladamente hasta 90° de flexión.',
    ],
    'safety_notes': 'No separes los codos del cuerpo. El movimiento es solo de antebrazo.',
    'variations': ['Jalón con cuerda (separando extremos)', 'Jalón supino', 'Kickback'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Polea con barra o cuerda',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Fondos en Banco (Triceps Dips)',
    'exercise_type': 'calistenia',
    'muscle_group': 'brazos',
    'difficulty': 'principiante',
    'description': 'Ejercicio de peso corporal efectivo para tríceps y pecho inferior, accesible para todos los niveles.',
    'muscles': ['Tríceps braquial', 'Pectoral mayor (inferior)', 'Deltoides anterior'],
    'instructions': [
      'Apoya las manos en el borde de un banco detrás de ti, dedos hacia adelante.',
      'Las piernas extendidas al frente o rodillas flexionadas para mayor facilidad.',
      'Baja flexionando los codos hasta 90°.',
      'Empuja hasta extender los brazos.',
    ],
    'safety_notes': 'No bajes más de 90° para proteger el hombro anterior.',
    'variations': ['Fondos en banco con lastre', 'Fondos en paralelas', 'Dips asistidos en máquina'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Banco o silla',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Curl Inclinado con Mancuernas',
    'exercise_type': 'dinamico',
    'muscle_group': 'brazos',
    'difficulty': 'intermedio',
    'description': 'Variante en banco inclinado que proporciona el mayor estiramiento del bíceps para máxima hipertrofia.',
    'muscles': ['Bíceps braquial (porción larga)', 'Braquial'],
    'instructions': [
      'Siéntate en un banco inclinado a 45-60° con mancuernas colgando.',
      'Los brazos cuelgan completamente extendidos detrás del cuerpo.',
      'Sube las mancuernas alternando o simultáneamente.',
      'Baja lentamente aprovechando el estiramiento máximo.',
    ],
    'safety_notes': 'No uses pesos pesados. El estiramiento extremo aumenta el riesgo de desgarro si hay demasiada carga.',
    'variations': ['Curl en predicador', 'Curl con cable en polea baja'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas + Banco inclinado',
    'default_sets': 3,
    'default_reps': '10-12',
    'default_rest_seconds': 60,
  },

  // ══════════════════════════════════════════════════════════════
  // CORE  (8 ejercicios)
  // ══════════════════════════════════════════════════════════════
  {
    'name': 'Plancha Abdominal',
    'exercise_type': 'isometrico',
    'muscle_group': 'core',
    'difficulty': 'principiante',
    'description': 'El ejercicio isométrico de core por excelencia. Activa todos los estabilizadores del tronco.',
    'muscles': ['Transverso abdominal', 'Recto abdominal', 'Oblicuos', 'Glúteos', 'Erector espinal'],
    'instructions': [
      'Apoya antebrazos y puntas de los pies en el suelo.',
      'Cuerpo en línea recta de cabeza a talones, sin que suban o bajen las caderas.',
      'Contrae abdomen, glúteos y cuádriceps simultáneamente.',
      'Mantén la posición respirando con normalidad.',
    ],
    'safety_notes': 'No aguantes la respiración. Si notas dolor lumbar, baja las caderas un poco.',
    'variations': ['Plancha alta', 'Plancha con elevación de brazo', 'Plancha con toque de hombro', 'Rueda de plancha'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 3,
    'default_reps': '30-60 seg',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Plancha Lateral',
    'exercise_type': 'isometrico',
    'muscle_group': 'core',
    'difficulty': 'intermedio',
    'description': 'Versión lateral de la plancha que aísla los oblicuos y trabaja la estabilidad lateral del tronco.',
    'muscles': ['Oblicuo externo', 'Oblicuo interno', 'Cuadrado lumbar', 'Glúteo medio'],
    'instructions': [
      'Apoya el antebrazo y el pie lateral en el suelo.',
      'Eleva las caderas formando una línea recta con el cuerpo.',
      'El cuerpo no debe rotar ni hacia adelante ni hacia atrás.',
      'Mantén la posición y repite en el otro lado.',
    ],
    'safety_notes': 'Asegúrate de que el antebrazo esté perpendicular al cuerpo, no en diagonal.',
    'variations': ['Plancha lateral alta (brazo extendido)', 'Plancha lateral con elevación de cadera', 'Plancha lateral con apertura de pierna'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 3,
    'default_reps': '20-40 seg por lado',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Hollow Body Hold',
    'exercise_type': 'isometrico',
    'muscle_group': 'core',
    'difficulty': 'intermedio',
    'description': 'Posición isométrica fundamental en calistenia que construye una tensión corporal total y un core a prueba de balas.',
    'muscles': ['Transverso abdominal', 'Recto abdominal', 'Psoas ilíaco', 'Serratos'],
    'instructions': [
      'Tumbado boca arriba, extiende brazos por encima de la cabeza.',
      'Eleva hombros y pies del suelo manteniendo la zona lumbar pegada al suelo.',
      'Los brazos y piernas quedan a unos 15-30 cm del suelo.',
      'Mantén la posición apretando el abdomen.',
    ],
    'safety_notes': 'La zona lumbar DEBE estar pegada al suelo. Si no puedes, sube los pies más.',
    'variations': ['Hollow body rock', 'Hollow body con piernas más altas (más fácil)', 'Dragon flag'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 3,
    'default_reps': '20-40 seg',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Crunch Abdominal',
    'exercise_type': 'dinamico',
    'muscle_group': 'core',
    'difficulty': 'principiante',
    'description': 'Ejercicio básico para el recto abdominal con flexión de columna controlada.',
    'muscles': ['Recto abdominal', 'Oblicuos'],
    'instructions': [
      'Tumbado boca arriba, rodillas flexionadas a 90°, pies en el suelo.',
      'Manos detrás de la cabeza sin tirar del cuello.',
      'Eleva los hombros del suelo contrayendo el abdomen.',
      'Vuelve sin apoyar completamente los hombros.',
    ],
    'safety_notes': 'El movimiento es corto. No te sientes completamente: eso trabaja más el psoas.',
    'variations': ['Crunch con giro (oblicuos)', 'Crunch en cable', 'Crunch en fitball'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 3,
    'default_reps': '15-20',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Crunch Inverso',
    'exercise_type': 'dinamico',
    'muscle_group': 'core',
    'difficulty': 'principiante',
    'description': 'Variante que trabaja la porción inferior del recto abdominal elevando la pelvis en lugar del torso.',
    'muscles': ['Recto abdominal (porción inferior)', 'Transverso abdominal'],
    'instructions': [
      'Tumbado boca arriba, manos apoyadas a los lados o bajo los glúteos.',
      'Eleva las piernas a 90° con rodillas ligeramente flexionadas.',
      'Curva la pelvis hacia el pecho elevando los glúteos del suelo.',
      'Baja controladamente sin que las piernas toquen el suelo.',
    ],
    'safety_notes': 'No balancees las piernas. El movimiento viene de la contracción abdominal.',
    'variations': ['Crunch inverso en banco declinado', 'Leg raise', 'Hanging leg raise'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 3,
    'default_reps': '15-20',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Rueda Abdominal (Ab Wheel)',
    'exercise_type': 'dinamico',
    'muscle_group': 'core',
    'difficulty': 'avanzado',
    'description': 'Uno de los ejercicios de core más efectivos y desafiantes. Activa el abdomen en su máxima elongación.',
    'muscles': ['Recto abdominal', 'Oblicuos', 'Dorsal ancho', 'Serrato anterior'],
    'instructions': [
      'Arrodíllado con la rueda delante, manos en las empuñaduras.',
      'Rueda hacia adelante extendiendo los brazos lo máximo posible.',
      'Mantén la espalda recta (no la arquees).',
      'Vuelve contrayendo el abdomen, no usando los brazos.',
    ],
    'safety_notes': 'Ejercicio avanzado: comienza rodando solo hasta donde puedas mantener la forma. Puede causar dolor lumbar si se hace incorrectamente.',
    'variations': ['Ab wheel de rodillas', 'Ab wheel de pie (dragon flag)', 'Ab wheel con pausa'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Rueda abdominal',
    'default_sets': 3,
    'default_reps': '8-12',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Russian Twist',
    'exercise_type': 'dinamico',
    'muscle_group': 'core',
    'difficulty': 'principiante',
    'description': 'Ejercicio rotacional para oblicuos que mejora la estabilidad del torso en movimientos deportivos.',
    'muscles': ['Oblicuos', 'Recto abdominal', 'Transverso abdominal'],
    'instructions': [
      'Siéntate con rodillas flexionadas y torso a ~45° del suelo.',
      'Mantén los pies levantados o apoyados para mayor facilidad.',
      'Rota el torso de lado a lado llevando las manos (o peso) hacia el suelo.',
    ],
    'safety_notes': 'Con disco o balón medicinal para añadir carga. No hagas el movimiento demasiado rápido.',
    'variations': ['Russian twist con peso', 'Russian twist con pies levantados', 'Cable woodchop'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento o Disco',
    'default_sets': 3,
    'default_reps': '20 (10 por lado)',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Mountain Climbers',
    'exercise_type': 'calistenia',
    'muscle_group': 'core',
    'difficulty': 'principiante',
    'description': 'Ejercicio funcional de core con componente cardiovascular. Ideal para HIIT y circuitos.',
    'muscles': ['Recto abdominal', 'Oblicuos', 'Cuádriceps', 'Deltoides', 'Hip flexors'],
    'instructions': [
      'Posición de plancha alta, manos bajo los hombros.',
      'Lleva una rodilla al pecho de forma explosiva.',
      'Cambia rápidamente llevando la otra rodilla al pecho.',
      'Mantén las caderas bajas y estables, sin que suban.',
    ],
    'safety_notes': 'Las caderas no deben subir ni bajar. El core activo estabiliza todo el movimiento.',
    'variations': ['Mountain climbers lentos (técnica)', 'Cross-body mountain climbers (oblicuos)', 'Spider mountain climbers'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 4,
    'default_reps': '30-40 alternando',
    'default_rest_seconds': 30,
  },

  // ══════════════════════════════════════════════════════════════
  // GLÚTEOS  (8 ejercicios)
  // ══════════════════════════════════════════════════════════════
  {
    'name': 'Hip Thrust con Barra',
    'exercise_type': 'dinamico',
    'muscle_group': 'gluteos',
    'difficulty': 'principiante',
    'description': 'El ejercicio más efectivo para hipertrofia de glúteo mayor. Mayor activación EMG que sentadilla o peso muerto.',
    'muscles': ['Glúteo mayor', 'Glúteo medio', 'Isquiotibiales'],
    'instructions': [
      'Apoya la espalda alta en un banco, barra sobre las caderas con almohadilla.',
      'Pies al ancho de caderas, rodillas a 90° en la posición más alta.',
      'Empuja las caderas hacia arriba apretando fuertemente los glúteos.',
      'Mantén la contracción 1 segundo arriba y baja controladamente.',
    ],
    'safety_notes': 'Usa siempre almohadilla protectora. No hiperextiendas la zona lumbar en la parte alta.',
    'variations': ['Puente de glúteos', 'Hip thrust unilateral', 'Hip thrust con banda', 'Hip thrust en máquina'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Barra + Banco + Almohadilla',
    'default_sets': 4,
    'default_reps': '10-15',
    'default_rest_seconds': 90,
  },
  {
    'name': 'Puente de Glúteos Isométrico',
    'exercise_type': 'isometrico',
    'muscle_group': 'gluteos',
    'difficulty': 'principiante',
    'description': 'Versión estática del puente de glúteos. Perfecto para activación pre-entrenamiento y trabajo preventivo de espalda baja.',
    'muscles': ['Glúteo mayor', 'Isquiotibiales', 'Core'],
    'instructions': [
      'Tumbado boca arriba, rodillas flexionadas y pies en el suelo al ancho de caderas.',
      'Empuja caderas hacia arriba contrayendo fuertemente los glúteos.',
      'Cuerpo en línea recta de rodillas a hombros.',
      'Mantén la posición sin dejar caer las caderas.',
    ],
    'safety_notes': 'No hiperextiendas la espalda. Las costillas deben estar fijas.',
    'variations': ['Con banda alrededor de rodillas', 'Unilateral (single-leg)', 'Con peso en caderas'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 3,
    'default_reps': '30-45 seg',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Patada de Glúteo en Cuadrupedia',
    'exercise_type': 'dinamico',
    'muscle_group': 'gluteos',
    'difficulty': 'principiante',
    'description': 'Ejercicio de aislamiento para glúteo mayor que trabaja la extensión de cadera en su rango más efectivo.',
    'muscles': ['Glúteo mayor', 'Isquiotibiales'],
    'instructions': [
      'A cuatro patas, muñecas bajo los hombros, rodillas bajo las caderas.',
      'Extiende una pierna hacia atrás y arriba, manteniendo la rodilla a 90°.',
      'Aprieta el glúteo en el punto máximo.',
      'Vuelve sin tocar el suelo con la rodilla y repite.',
    ],
    'safety_notes': 'No gires la pelvis. El movimiento es solo extensión de cadera.',
    'variations': ['Con banda de resistencia', 'Con mancuerna detrás de la rodilla', 'En máquina cable'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento o Banda elástica',
    'default_sets': 3,
    'default_reps': '15-20 por pierna',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Abducción de Cadera con Banda',
    'exercise_type': 'dinamico',
    'muscle_group': 'gluteos',
    'difficulty': 'principiante',
    'description': 'Ejercicio de aislamiento para glúteo medio, clave para la estabilidad pélvica y rodillas sanas.',
    'muscles': ['Glúteo medio', 'Glúteo menor', 'Tensor de la fascia lata'],
    'instructions': [
      'De pie o tumbado, con banda alrededor de los muslos o tobillos.',
      'De pie: separa lateralmente una pierna manteniendo el tronco estático.',
      'Aprieta el glúteo medio en el punto máximo.',
      'Vuelve lentamente y repite.',
    ],
    'safety_notes': 'No inclines el torso hacia el lado. El movimiento viene solo de la cadera.',
    'variations': ['Abducción tumbada', 'Clamshell (almeja)', 'Monster walk'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Banda elástica',
    'default_sets': 3,
    'default_reps': '15-20 por lado',
    'default_rest_seconds': 45,
  },
  {
    'name': 'Sentadilla Sumo con Mancuerna',
    'exercise_type': 'dinamico',
    'muscle_group': 'gluteos',
    'difficulty': 'principiante',
    'description': 'Variante de sentadilla con apertura amplia que enfatiza la cara interna del muslo y glúteos.',
    'muscles': ['Glúteo mayor', 'Aductores', 'Cuádriceps', 'Isquiotibiales'],
    'instructions': [
      'Pies más anchos que los hombros, puntas a 45°.',
      'Sujeta una mancuerna vertical con ambas manos colgando entre las piernas.',
      'Baja profundamente manteniendo el torso erguido.',
      'Empuja desde los talones volviendo a la posición de pie.',
    ],
    'safety_notes': 'Asegúrate de que las rodillas sigan la dirección de las puntas del pie.',
    'variations': ['Sentadilla sumo con barra', 'Sumo deadlift', 'Goblet squat sumo'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuerna',
    'default_sets': 3,
    'default_reps': '12-15',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Step Up con Mancuernas',
    'exercise_type': 'dinamico',
    'muscle_group': 'gluteos',
    'difficulty': 'principiante',
    'description': 'Ejercicio funcional unilateral que trabaja glúteos, cuádriceps y mejora el equilibrio.',
    'muscles': ['Glúteo mayor', 'Cuádriceps', 'Isquiotibiales'],
    'instructions': [
      'Párate frente a un banco o cajón con mancuernas a los lados.',
      'Coloca el pie derecho completamente en el banco.',
      'Empuja desde el talón derecho subiendo el cuerpo.',
      'Baja controladamente con el pie izquierdo primero.',
    ],
    'safety_notes': 'El pie completo debe estar en la superficie. No te impulses con el pie de abajo.',
    'variations': ['Step up con rotación', 'Step up lateral', 'Deficit step up'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Mancuernas + Banco o cajón',
    'default_sets': 3,
    'default_reps': '10-12 por pierna',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Zancadas Caminando',
    'exercise_type': 'calistenia',
    'muscle_group': 'gluteos',
    'difficulty': 'principiante',
    'description': 'Variante dinámica de la zancada que desarrolla glúteos, cuádriceps y coordinación en un solo movimiento continuo.',
    'muscles': ['Glúteo mayor', 'Cuádriceps', 'Isquiotibiales', 'Core'],
    'instructions': [
      'De pie, da un paso largo hacia adelante.',
      'Baja la rodilla trasera casi hasta el suelo.',
      'Sin volver al punto de inicio, da el siguiente paso con la otra pierna.',
      'Continúa avanzando de forma rítmica.',
    ],
    'safety_notes': 'Mantén el torso erguido durante todo el recorrido. Si hay limitaciones de espacio, usa zancadas estáticas.',
    'variations': ['Zancadas caminando con mancuernas', 'Zancadas con barra en espalda', 'Zancadas en sentido inverso'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 3,
    'default_reps': '20 (10 por pierna)',
    'default_rest_seconds': 60,
  },
  {
    'name': 'Burpees',
    'exercise_type': 'calistenia',
    'muscle_group': 'gluteos',
    'difficulty': 'intermedio',
    'description': 'Ejercicio de cuerpo completo de alta intensidad. Combina fuerza, potencia y cardiovascular en un solo movimiento.',
    'muscles': ['Glúteo mayor', 'Cuádriceps', 'Pectoral', 'Deltoides', 'Tríceps', 'Core'],
    'instructions': [
      'De pie, agáchate y apoya las manos en el suelo.',
      'Lanza los pies hacia atrás a posición de plancha.',
      'Realiza una flexión (opcional).',
      'Regresa los pies hacia las manos de un salto.',
      'Impulsate hacia arriba saltando con los brazos al techo.',
    ],
    'safety_notes': 'Para un nivel menor de intensidad, omite el salto y la flexión. No recomendado con lesiones de rodilla o hombro activas.',
    'variations': ['Burpee sin salto', 'Burpee con push-up', 'Burpee con box jump'],
    'video_url': null,
    'image_url': null,
    'equipment': 'Sin equipamiento',
    'default_sets': 4,
    'default_reps': '8-15',
    'default_rest_seconds': 45,
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Ejercicios de articulaciones — movilidad y fortalecimiento
// ─────────────────────────────────────────────────────────────────────────────
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
    'name': 'Círculos de hombro con bastón',
    'type': 'movilidad',
    'jointFamily': 'shoulder',
    'instructions': [
      'Sostén un bastón con ambas manos al frente.',
      'Realiza círculos amplios pasando el bastón por encima de la cabeza.',
      'Mantén los codos ligeramente flexionados.',
      'Realiza 5 círculos hacia adelante y 5 hacia atrás.',
    ],
    'benefits': 'Aumenta la movilidad de toda la cápsula glenohumeral y mejora la conciencia propioceptiva del hombro.',
    'whenToUse': 'Calentamiento antes de entrenar hombros, pecho o espalda.',
  },
  {
    'name': 'Press con mancuerna rotador',
    'type': 'fortalecimiento',
    'jointFamily': 'shoulder',
    'instructions': [
      'De pie o sentado, sostén una mancuerna ligera en una mano.',
      'Eleva el brazo lateralmente a 90° con el codo flexionado.',
      'Rota el antebrazo hacia arriba.',
      'Baja lentamente y repite 12-15 veces por lado.',
    ],
    'benefits': 'Fortalece los rotadores externos del manguito rotador, reduciendo el riesgo de lesión en press de pecho.',
    'whenToUse': 'En la rutina de hombros o como trabajo preventivo.',
  },
  {
    'name': 'Face Pull con cuerda (salud del hombro)',
    'type': 'fortalecimiento',
    'jointFamily': 'shoulder',
    'instructions': [
      'Coloca la polea a la altura de los ojos con cuerda.',
      'Agarra los extremos con ambas manos.',
      'Tira hacia la cara separando los extremos.',
      'Los codos quedan por encima de los hombros. 15-20 reps.',
    ],
    'benefits': 'Fortalece deltoides posterior, rotadores externos y romboides. Corrige hombros caídos.',
    'whenToUse': 'Al final de sesiones de empuje. También 2-3 veces por semana como trabajo postural.',
  },

  // ── CODO ──────────────────────────────────────────────────────────────────
  {
    'name': 'Pronación y supinación de antebrazo',
    'type': 'movilidad',
    'jointFamily': 'elbow',
    'instructions': [
      'Siéntate con el codo apoyado en mesa, flexionado a 90°.',
      'Sostén un martillo o mancuerna ligera.',
      'Rota el antebrazo hacia abajo (pronación) lentamente.',
      'Vuelve y rota hacia arriba (supinación).',
      '10-12 reps lentas por lado.',
    ],
    'benefits': 'Mantiene el rango de pronación/supinación, previene rigidez post-entrenamiento.',
    'whenToUse': 'Calentamiento para entrenamientos de brazos.',
  },
  {
    'name': 'Curl excéntrico de bíceps',
    'type': 'fortalecimiento',
    'jointFamily': 'elbow',
    'instructions': [
      'Sostén una mancuerna con el codo completamente flexionado.',
      'Baja el peso en 4-5 segundos hasta extender el codo.',
      'Usa la otra mano para subir (fase concéntrica asistida).',
      '8-10 reps enfocándose en la bajada.',
    ],
    'benefits': 'Fortalece el tendón bicipital y tejidos del codo. Previene el codo de tenista.',
    'whenToUse': 'En días de brazos como trabajo de prevención de lesiones.',
  },
  {
    'name': 'Extensión de tríceps en polea (olécranon)',
    'type': 'fortalecimiento',
    'jointFamily': 'elbow',
    'instructions': [
      'Polea alta con cuerda o barra recta.',
      'Codos pegados al cuerpo.',
      'Extiende completamente los codos hacia abajo.',
      'Vuelve lentamente. 12-15 reps.',
    ],
    'benefits': 'Fortalece el tríceps y estabiliza el codo, protegiéndolo en movimientos de press.',
    'whenToUse': 'Al final de sesión de brazos o pecho.',
  },

  // ── MUÑECA ────────────────────────────────────────────────────────────────
  {
    'name': 'Flexión y extensión de muñeca con mancuerna',
    'type': 'movilidad',
    'jointFamily': 'wrist',
    'instructions': [
      'Antebrazo apoyado en el muslo, mano hacia afuera.',
      'Sostén mancuerna ligera (1-2 kg).',
      'Baja la mano hacia el suelo (extensión).',
      'Sube la mano hacia arriba (flexión). 15 reps.',
    ],
    'benefits': 'Mantiene el rango de flexión/extensión de la muñeca, previene el síndrome del túnel carpiano.',
    'whenToUse': 'Calentamiento antes de entrenamientos de pecho o brazos.',
  },
  {
    'name': 'Círculos de muñeca',
    'type': 'movilidad',
    'jointFamily': 'wrist',
    'instructions': [
      'Extiende los brazos o apoya los codos.',
      'Realiza círculos lentos con las muñecas.',
      '10 círculos en cada sentido por muñeca.',
    ],
    'benefits': 'Lubrica la articulación carpiana y reduce tensión acumulada.',
    'whenToUse': 'Calentamiento antes de entrenar o tras trabajo prolongado con teclado.',
  },
  {
    'name': 'Curl de muñeca con mancuerna',
    'type': 'fortalecimiento',
    'jointFamily': 'wrist',
    'instructions': [
      'Antebrazo apoyado en el muslo, mano hacia arriba.',
      'Sostén mancuerna ligera.',
      'Flexiona la muñeca subiendo el peso.',
      'Baja lentamente al máximo de extensión. 15-20 reps.',
    ],
    'benefits': 'Fortalece los flexores del carpo y la fuerza de agarre.',
    'whenToUse': 'Al final de la sesión de brazos.',
  },

  // ── CADERA ────────────────────────────────────────────────────────────────
  {
    'name': 'Apertura de cadera en 90/90',
    'type': 'movilidad',
    'jointFamily': 'hip',
    'instructions': [
      'Siéntate en el suelo con ambas piernas dobladas a 90°.',
      'Pierna delantera 90° con torso; trasera también.',
      'Inclínate sobre la pierna delantera con espalda recta.',
      'Mantén 30-60 segundos y cambia.',
    ],
    'benefits': 'Mejora rotación interna y externa de cadera, prepara para sentadillas profundas.',
    'whenToUse': 'Calentamiento antes de piernas o en días de recuperación.',
  },
  {
    'name': 'Estiramiento del psoas (hip flexor)',
    'type': 'movilidad',
    'jointFamily': 'hip',
    'instructions': [
      'Arrodíllate con una rodilla en el suelo.',
      'Pie delantero plano en el suelo.',
      'Empuja la cadera hacia adelante y abajo.',
      'Mantén 30-45 segundos por lado.',
    ],
    'benefits': 'Alarga el psoas acortado por sedentarismo, mejora la extensión de cadera.',
    'whenToUse': 'Calentamiento antes de piernas o tras trabajo de escritorio prolongado.',
  },
  {
    'name': 'Monster Walk con banda',
    'type': 'fortalecimiento',
    'jointFamily': 'hip',
    'instructions': [
      'Banda elástica alrededor de los tobillos.',
      'Posición atlética con rodillas semiflexionadas.',
      'Da pasos laterales manteniendo tensión de la banda.',
      '10-15 pasos en cada dirección.',
    ],
    'benefits': 'Fortalece glúteo medio y abductores. Previene colapso de rodilla en valgus.',
    'whenToUse': 'Calentamiento antes de piernas.',
  },
  {
    'name': 'Puente de glúteos activación (cadera)',
    'type': 'fortalecimiento',
    'jointFamily': 'hip',
    'instructions': [
      'Tumbado boca arriba, rodillas flexionadas, pies en el suelo.',
      'Empuja las caderas hacia arriba contrayendo glúteos.',
      'Mantén 2 segundos arriba.',
      'Baja sin tocar completamente el suelo. 15-20 reps.',
    ],
    'benefits': 'Activa glúteo mayor, estabiliza la coxofemoral y reduce carga lumbar.',
    'whenToUse': 'Calentamiento de glúteos antes de sentadillas o hip thrust.',
  },

  // ── RODILLA ───────────────────────────────────────────────────────────────
  {
    'name': 'Sentadilla parcial controlada (0°-60°)',
    'type': 'movilidad',
    'jointFamily': 'knee',
    'instructions': [
      'De pie con pies al ancho de hombros.',
      'Baja lentamente hasta 60° de flexión.',
      'Mantén 2 segundos abajo.',
      'Sube lentamente. 10-15 reps.',
    ],
    'benefits': 'Lubrica la rodilla, mejora propiocepción y fortalece cuádriceps en rango seguro.',
    'whenToUse': 'Calentamiento antes de piernas, especialmente con historial de dolor de rodilla.',
  },
  {
    'name': 'Estiramiento de isquiotibiales en decúbito',
    'type': 'movilidad',
    'jointFamily': 'knee',
    'instructions': [
      'Tumbado boca arriba, lleva una pierna al pecho.',
      'Extiende la rodilla lentamente hasta sentir estiramiento.',
      'Mantén 30 segundos sin rebotar.',
      'Cambia de pierna.',
    ],
    'benefits': 'Mejora extensión de rodilla y alivia tensión en tendones isquiotibiales.',
    'whenToUse': 'Después de piernas o en días de recuperación.',
  },
  {
    'name': 'Nordic Curl (curl nórdico)',
    'type': 'fortalecimiento',
    'jointFamily': 'knee',
    'instructions': [
      'Arrodíllate con pies sujetos por compañero o superficie fija.',
      'Baja el torso hacia adelante controlando con los isquiotibiales.',
      'Al perder control, apoya las manos y empuja para volver.',
      '3-6 repeticiones.',
    ],
    'benefits': 'Reduce en hasta un 50% el riesgo de rotura de isquiotibiales.',
    'whenToUse': 'Al final de piernas como prevención.',
  },

  // ── TOBILLO ───────────────────────────────────────────────────────────────
  {
    'name': 'Rotaciones de tobillo',
    'type': 'movilidad',
    'jointFamily': 'ankle',
    'instructions': [
      'Levanta un pie del suelo.',
      'Realiza círculos amplios con el pie.',
      '10 círculos en cada sentido por tobillo.',
    ],
    'benefits': 'Mejora la movilidad del tobillo en todos los planos y reduce rigidez.',
    'whenToUse': 'Calentamiento antes de piernas o deportes de salto.',
  },
  {
    'name': 'Dorsiflexión de tobillo en pared',
    'type': 'movilidad',
    'jointFamily': 'ankle',
    'instructions': [
      'Pie a 5 cm de la pared.',
      'Deja caer la rodilla hacia adelante intentando tocar la pared sin levantar el talón.',
      'Mueve el pie más atrás si tocas la pared.',
      '3-5 segundos por rep. 10 reps por tobillo.',
    ],
    'benefits': 'Mejora la dorsiflexión, fundamental para sentadillas profundas.',
    'whenToUse': 'Calentamiento antes de sentadillas.',
  },
  {
    'name': 'Elevaciones de talón (calf raises)',
    'type': 'fortalecimiento',
    'jointFamily': 'ankle',
    'instructions': [
      'De pie en el borde de un escalón.',
      'Baja los talones por debajo del escalón.',
      'Sube elevando los talones al máximo.',
      'Pausa 1 segundo arriba. 15-20 reps.',
    ],
    'benefits': 'Fortalece el tríceps sural y el tendón de Aquiles.',
    'whenToUse': 'Al final de piernas o como trabajo preventivo diario.',
  },

  // ── CERVICAL ──────────────────────────────────────────────────────────────
  {
    'name': 'Rotación cervical activa',
    'type': 'movilidad',
    'jointFamily': 'cervical',
    'instructions': [
      'Sentado erguido con la mirada al frente.',
      'Gira lentamente la cabeza hacia un lado hasta el límite cómodo.',
      'Mantén 2-3 segundos y vuelve al centro.',
      '8-10 repeticiones por lado.',
    ],
    'benefits': 'Mantiene el rango de rotación cervical y reduce rigidez por postura.',
    'whenToUse': 'Calentamiento antes de dominadas o en pausas de trabajo.',
  },
  {
    'name': 'Chin tuck (retracción cervical)',
    'type': 'fortalecimiento',
    'jointFamily': 'cervical',
    'instructions': [
      'Sentado o de pie con mirada al frente.',
      'Mete el mentón hacia atrás creando doble papada.',
      'Mantén 5-10 segundos.',
      '10-15 repeticiones.',
    ],
    'benefits': 'Fortalece flexores profundos del cuello, corrige "text neck" y previene dolor cervical.',
    'whenToUse': 'Diariamente como ejercicio postural.',
  },

  // ── LUMBAR ────────────────────────────────────────────────────────────────
  {
    'name': 'Cat-Cow (flexión y extensión lumbar)',
    'type': 'movilidad',
    'jointFamily': 'lumbar',
    'instructions': [
      'A cuatro patas con manos bajo hombros y rodillas bajo caderas.',
      'Exhala y arquea la espalda hacia arriba (cat).',
      'Inhala y baja el abdomen dejando espalda cóncava (cow).',
      '10-15 repeticiones coordinando con respiración.',
    ],
    'benefits': 'Mejora movilidad lumbar y torácica, lubrica los discos intervertebrales.',
    'whenToUse': 'Al levantarse, antes de peso muerto o sentadillas.',
  },
  {
    'name': 'Bird-Dog (estabilidad lumbar)',
    'type': 'fortalecimiento',
    'jointFamily': 'lumbar',
    'instructions': [
      'A cuatro patas con espalda neutral.',
      'Extiende brazo derecho al frente y pierna izquierda atrás simultáneamente.',
      'Cadera nivelada y core activo durante 3-5 segundos.',
      '10 repeticiones por lado.',
    ],
    'benefits': 'Fortalece extensores lumbares y core profundo de forma segura.',
    'whenToUse': 'Calentamiento antes de peso muerto. También en programas de prevención lumbar.',
  },
  {
    'name': 'Dead Bug (estabilidad lumbar)',
    'type': 'fortalecimiento',
    'jointFamily': 'lumbar',
    'instructions': [
      'Tumbado boca arriba, brazos al techo, rodillas a 90° elevadas.',
      'Baja brazo derecho atrás y pierna izquierda al suelo exhalando.',
      'Zona lumbar pegada al suelo todo el tiempo.',
      '8-10 repeticiones por lado.',
    ],
    'benefits': 'Fortalece transverso abdominal y estabilizadores lumbares. Previene dolor lumbar.',
    'whenToUse': 'Calentamiento de core antes de sentadillas. También en rehabilitación lumbar.',
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Artículos educativos
// ─────────────────────────────────────────────────────────────────────────────
Future<void> seedArticles(Connection conn) async {
  if (Platform.environment['RUNMODE'] == 'production') return;

  final count = (await conn.execute('SELECT COUNT(*) AS c FROM articles'))
      .first.toColumnMap()['c'] as int? ?? 0;
  if (count > 0) {
    print('[Seed] Artículos ya presentes ($count), omitiendo.');
    return;
  }

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
La sentadilla es uno de los ejercicios más completos del entrenamiento de fuerza, pero también uno de los que más lesiones genera cuando se ejecuta incorrectamente.

## Posición inicial

Los pies deben estar a la anchura de los hombros o ligeramente más separados, con los pies apuntando ligeramente hacia afuera (entre 15 y 30 grados).

## Fase de descenso

Inicia el movimiento empujando las caderas hacia atrás antes de doblar las rodillas. Las rodillas deben seguir la dirección de los pies.

## Profundidad adecuada

El objetivo es alcanzar al menos los 90 grados (muslos paralelos al suelo), pero la prioridad siempre es mantener la postura correcta.

## Errores más frecuentes

- Talones que se levantan del suelo: indica falta de movilidad en el tobillo.
- Redondeo de la espalda baja: por falta de fuerza en el core.
- Colapso de rodillas: por glúteo medio débil.

La paciencia en la construcción de la técnica es la mejor inversión que puedes hacer.
''',
  },
  {
    'title': 'Nutrición pre-entrenamiento: qué comer y cuándo',
    'category': 'nutricion',
    'tags': ['nutricion', 'pre-entreno', 'carbohidratos', 'proteína'],
    'content': '''
Lo que comes antes de entrenar puede marcar una diferencia significativa en tu rendimiento.

## El rol de los macronutrientes

Los carbohidratos son la fuente de energía preferida del músculo durante el ejercicio de alta intensidad. Consumir carbohidratos 1-3 horas antes del entrenamiento asegura que los depósitos de glucógeno estén llenos.

Una porción moderada de proteína antes de entrenar reduce el catabolismo muscular y facilita la síntesis proteica post-entrenamiento.

## Timing

- **2-3 horas antes**: comida completa con carbohidratos complejos y proteínas.
- **1-1,5 horas antes**: comida más liviana.
- **30-45 minutos antes**: snack rápido como un plátano con mantequilla de maní.

## Hidratación

Llega bien hidratado al entrenamiento. El rendimiento decrece con apenas un 2% de deshidratación.
''',
  },
  {
    'title': 'Prevención de lesiones de hombro en el gimnasio',
    'category': 'prevencion',
    'tags': ['hombro', 'manguito rotador', 'lesión', 'prevención'],
    'content': '''
El hombro es la articulación con mayor movilidad del cuerpo humano, y por eso también es una de las más susceptibles a lesiones.

## Errores comunes que generan lesiones

- Press de banca con agarre demasiado ancho.
- Dominadas y jalones detrás del cuello.
- Press militar con excesiva extensión lumbar.

## Ejercicios preventivos clave

1. Rotaciones externas con banda elástica: 3 series de 15 reps.
2. Face pulls con polea alta: activa el manguito posterior.
3. YTW con mancuernas livianas: estabilizadora escapular.

Incluye 2-3 series de ejercicios preventivos al inicio de cada sesión de empuje.
''',
  },
  {
    'title': 'Pausas activas en el trabajo: beneficios y rutina de 10 minutos',
    'category': 'pausas_activas',
    'tags': ['pausa activa', 'oficina', 'sedentarismo', 'movilidad'],
    'content': '''
El sedentarismo prolongado es uno de los principales factores de riesgo para el dolor músculo-esquelético.

## Beneficios comprobados

- Reducción del dolor cervical y lumbar hasta un 40%.
- Mejora de la concentración y productividad.
- Prevención del síndrome de túnel carpiano.

## Rutina de pausa activa (10 minutos)

**Cuello y cervicales (2 min):** Rotaciones cervicales, inclinaciones laterales, retracción cefálica.

**Hombros (3 min):** Círculos de hombros, apertura de pectorales, encogimientos y retracción escapular.

**Espalda baja y caderas (3 min):** Rotaciones de cadera, inclinación suave hacia adelante.

**Activación general (2 min):** 20 saltos de tijera, marcha en el lugar.

Programa recordatorios cada 90 minutos para máximo beneficio.
''',
  },
  {
    'title': 'Recuperación muscular: estrategias basadas en evidencia',
    'category': 'recuperacion',
    'tags': ['recuperación', 'descanso', 'DOMS', 'sueño'],
    'content': '''
La recuperación es un proceso activo mediante el cual el músculo se adapta al estímulo del entrenamiento.

## Estrategias con mayor evidencia científica

**1. Sueño de calidad:** 7-9 horas para adultos activos. Durante el sueño profundo se libera la mayor concentración de hormona de crecimiento.

**2. Nutrición post-entrenamiento:** Carbohidratos + proteínas dentro de las 2 horas post-ejercicio. Proporción 3:1 como guía práctica.

**3. Hidratación:** Orina de color amarillo pálido como indicador de buena hidratación.

**4. Baños de contraste:** Agua fría (10-15°C, 1 min) alternada con agua caliente (38-40°C, 2 min) puede reducir el DOMS.

**5. Movilidad activa:** 30-45 minutos de cardio suave al 50-60% de FCmáx aumenta el flujo sanguíneo sin generar daño adicional.
''',
  },
];

// ─────────────────────────────────────────────────────────────────────────────
// Eventos UBB
// ─────────────────────────────────────────────────────────────────────────────
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
          'Categorías masculinas y femeninas en sentadilla, press de banca y peso muerto. '
          'Inscripción gratuita para estudiantes UBB.',
      'location': 'Gimnasio UBB, Campus La Castilla, Chillán',
      'event_date': DateTime(now.year, now.month + 1, 15).toUtc().toIso8601String(),
      'registration_url': 'https://forms.gle/ejemplo',
    },
    {
      'title': 'Charla: Nutrición Deportiva para Universitarios',
      'type': 'Charla',
      'description': 'Charla magistral a cargo del área de Nutrición y Dietética de la Facultad de Ciencias de la Salud UBB. '
          'Temas: requerimientos calóricos para deportistas universitarios, mitos sobre suplementación y planificación de comidas.',
      'location': 'Auditorio Facultad de Ciencias de la Salud, UBB',
      'event_date': DateTime(now.year, now.month, now.day + 10).toUtc().toIso8601String(),
      'registration_url': null,
    },
    {
      'title': 'Jornada de Pausas Activas en Campus',
      'type': 'Actividad',
      'description': 'Iniciativa del Gimnasio UBB en colaboración con Bienestar Estudiantil. '
          'Monitores recorrerán el campus realizando actividades de pausas activas de 10 minutos. '
          'No se requiere inscripción previa.',
      'location': 'Campus La Castilla, UBB',
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
