import 'package:postgres/postgres.dart';

/// Inicializa todas las tablas, enums, índices y triggers.
/// Es idempotente: se puede llamar múltiples veces sin error.
Future<void> initSchema(Connection conn) async {
  print('[DB] Inicializando esquema...');

  for (final sql in _schemaStatements) {
    try {
      await conn.execute(sql.trim());
    } catch (e) {
      final msg = e.toString().toLowerCase();
      // Ignorar errores de "ya existe" para que initSchema sea idempotente
      if (!msg.contains('already exists') && !msg.contains('duplicate')) {
        print('[DB] Error ejecutando SQL: $sql\n  → $e');
        rethrow;
      }
    }
  }

  print('[DB] Esquema listo');
}

// ============================================================
// DDL completo — se ejecuta al arrancar el servidor
// Orden: enums → tablas → índices → función trigger → triggers
// ============================================================
const List<String> _schemaStatements = [
  // ── Enums ─────────────────────────────────────────────────────────────────

  "CREATE TYPE user_role AS ENUM ('student', 'professor', 'staff', 'admin')",

  "CREATE TYPE muscle_group AS ENUM ('pecho', 'espalda', 'piernas', 'hombros', 'brazos', 'core', 'gluteos')",

  "CREATE TYPE difficulty_level AS ENUM ('principiante', 'intermedio', 'avanzado')",

  "CREATE TYPE workout_goal AS ENUM ('fuerza', 'hipertrofia', 'resistencia', 'perdida_de_peso')",

  "CREATE TYPE audit_action AS ENUM ('login', 'logout', 'login_failed', 'role_changed', 'password_changed', 'account_created', 'account_deactivated')",

  // ── Tabla: users ──────────────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS users (
    id                   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email                VARCHAR(255) NOT NULL UNIQUE,
    password_hash        VARCHAR(255) NOT NULL,
    name                 VARCHAR(255) NOT NULL,
    career               VARCHAR(255),
    role                 user_role    NOT NULL DEFAULT \'student\',
    weight_kg            NUMERIC(5,2),
    height_cm            INTEGER,
    body_fat_pct         NUMERIC(4,1),
    units                VARCHAR(3)   NOT NULL DEFAULT \'kg\'
                           CHECK (units IN (\'kg\', \'lbs\')),
    notifications_enabled BOOLEAN    NOT NULL DEFAULT true,
    private_profile      BOOLEAN      NOT NULL DEFAULT false,
    is_active            BOOLEAN      NOT NULL DEFAULT true,
    member_since         DATE         NOT NULL DEFAULT CURRENT_DATE,
    last_login_at        TIMESTAMPTZ,
    created_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  // ── Tabla: careers ───────────────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS careers (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name       VARCHAR(255) NOT NULL UNIQUE,
    is_active  BOOLEAN      NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  'CREATE INDEX IF NOT EXISTS idx_careers_active ON careers(is_active) WHERE is_active = true',

  // ── Tabla: refresh_tokens ─────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS refresh_tokens (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token_hash   TEXT         NOT NULL UNIQUE,
    expires_at   TIMESTAMPTZ  NOT NULL,
    is_revoked   BOOLEAN      NOT NULL DEFAULT false,
    replaced_by  UUID         REFERENCES refresh_tokens(id),
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  // ── Tabla: exercises ──────────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS exercises (
    id                   UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
    name                 VARCHAR(255)     NOT NULL,
    muscle_group         muscle_group     NOT NULL,
    difficulty           difficulty_level NOT NULL,
    description          TEXT,
    muscles              TEXT[]           NOT NULL DEFAULT \'{}\',
    instructions         TEXT[]           NOT NULL DEFAULT \'{}\',
    safety_notes         TEXT,
    variations           TEXT[]           NOT NULL DEFAULT \'{}\',
    video_url            VARCHAR(500),
    image_url            TEXT,
    step_images          TEXT[]           NOT NULL DEFAULT \'{}\',
    equipment            VARCHAR(255),
    default_sets         INTEGER          NOT NULL DEFAULT 3,
    default_reps         VARCHAR(20)      NOT NULL DEFAULT \'8-12\',
    default_rest_seconds INTEGER          NOT NULL DEFAULT 90,
    created_by           UUID             REFERENCES users(id),
    is_active            BOOLEAN          NOT NULL DEFAULT true,
    created_at           TIMESTAMPTZ      NOT NULL DEFAULT NOW()
  )
  ''',

  // ── Tabla: routines ───────────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS routines (
    id             UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID         REFERENCES users(id) ON DELETE CASCADE,
    name           VARCHAR(255) NOT NULL,
    description    TEXT,
    goal           workout_goal NOT NULL DEFAULT \'hipertrofia\',
    frequency_days INTEGER      NOT NULL DEFAULT 3,
    is_public      BOOLEAN      NOT NULL DEFAULT false,
    created_by     UUID         NOT NULL REFERENCES users(id),
    is_active      BOOLEAN      NOT NULL DEFAULT true,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  // Migración idempotente: agrega description si la tabla ya existía sin ella
  'ALTER TABLE routines ADD COLUMN IF NOT EXISTS description TEXT',

  // ── Tabla: routine_days ───────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS routine_days (
    id          UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    routine_id  UUID         NOT NULL REFERENCES routines(id) ON DELETE CASCADE,
    day_name    VARCHAR(20)  NOT NULL,
    label       VARCHAR(255) NOT NULL,
    order_index INTEGER      NOT NULL DEFAULT 0
  )
  ''',

  // ── Tabla: routine_day_exercises ──────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS routine_day_exercises (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    routine_day_id UUID        NOT NULL REFERENCES routine_days(id) ON DELETE CASCADE,
    exercise_id    UUID        NOT NULL REFERENCES exercises(id),
    sets           INTEGER     NOT NULL DEFAULT 3,
    reps           VARCHAR(20) NOT NULL DEFAULT \'8-12\',
    rest_seconds   INTEGER     NOT NULL DEFAULT 90,
    order_index    INTEGER     NOT NULL DEFAULT 0
  )
  ''',

  // ── Tabla: joint_exercises ────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS joint_exercises (
    id           UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name         VARCHAR(255) NOT NULL,
    type         VARCHAR(20)  NOT NULL CHECK (type IN (\'movilidad\', \'fortalecimiento\')),
    joint_family VARCHAR(50)  NOT NULL,
    instructions TEXT[]       NOT NULL DEFAULT \'{}\',
    benefits     TEXT,
    when_to_use  TEXT,
    created_by   UUID         REFERENCES users(id),
    is_active    BOOLEAN      NOT NULL DEFAULT true,
    created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  'CREATE INDEX IF NOT EXISTS idx_joint_exercises_family ON joint_exercises(joint_family)',
  'CREATE INDEX IF NOT EXISTS idx_joint_exercises_active ON joint_exercises(is_active) WHERE is_active = true',

  // ── Tabla: workout_sessions ───────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS workout_sessions (
    id               UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    routine_id       UUID         REFERENCES routines(id),
    routine_day_id   UUID         REFERENCES routine_days(id),
    started_at       TIMESTAMPTZ  NOT NULL,
    ended_at         TIMESTAMPTZ,
    duration_minutes INTEGER,
    total_volume_kg  NUMERIC(10,2),
    notes            TEXT,
    created_at       TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  // ── Tabla: workout_sets ───────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS workout_sets (
    id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    session_id  UUID        NOT NULL REFERENCES workout_sessions(id) ON DELETE CASCADE,
    exercise_id UUID        NOT NULL REFERENCES exercises(id),
    set_number  INTEGER     NOT NULL,
    weight_kg   NUMERIC(6,2),
    reps        INTEGER,
    completed   BOOLEAN     NOT NULL DEFAULT false,
    rpe         SMALLINT    CHECK (rpe BETWEEN 1 AND 10),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )
  ''',

  // ── Tabla: personal_records ───────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS personal_records (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exercise_id  UUID        NOT NULL REFERENCES exercises(id),
    weight_kg    NUMERIC(6,2) NOT NULL,
    reps         INTEGER     NOT NULL DEFAULT 1,
    achieved_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    session_id   UUID        REFERENCES workout_sessions(id),
    is_validated BOOLEAN     NOT NULL DEFAULT false,
    UNIQUE (user_id, exercise_id, reps)
  )
  ''',

  // ── Tabla: body_measurements ──────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS body_measurements (
    id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    measured_at  DATE        NOT NULL DEFAULT CURRENT_DATE,
    weight_kg    NUMERIC(5,2),
    body_fat_pct NUMERIC(4,1),
    chest_cm     NUMERIC(5,1),
    waist_cm     NUMERIC(5,1),
    hip_cm       NUMERIC(5,1),
    arm_cm       NUMERIC(5,1),
    leg_cm       NUMERIC(5,1),
    notes        TEXT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )
  ''',

  // ── Tabla: articles ───────────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS articles (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    title             VARCHAR(255) NOT NULL,
    category          VARCHAR(100) NOT NULL,
    read_time_minutes INTEGER      NOT NULL DEFAULT 5,
    excerpt           TEXT,
    content           TEXT         NOT NULL,
    tags              TEXT[]       NOT NULL DEFAULT \'{}\',
    author_id         UUID         REFERENCES users(id),
    is_published      BOOLEAN      NOT NULL DEFAULT false,
    published_at      TIMESTAMPTZ,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  // ── Tabla: article_favorites ──────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS article_favorites (
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    article_id UUID        NOT NULL REFERENCES articles(id) ON DELETE CASCADE,
    saved_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, article_id)
  )
  ''',

  // ── Tabla: events ─────────────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS events (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    title             VARCHAR(255) NOT NULL,
    type              VARCHAR(100) NOT NULL,
    event_date        DATE         NOT NULL,
    event_time        TIME,
    location          VARCHAR(255),
    description       TEXT,
    max_participants  INTEGER,
    registration_url  VARCHAR(500),
    created_by        UUID         REFERENCES users(id),
    is_active         BOOLEAN      NOT NULL DEFAULT true,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at        TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  // ── Tabla: security_audit_log ─────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS security_audit_log (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         REFERENCES users(id) ON DELETE SET NULL,
    action     audit_action NOT NULL,
    ip_address INET,
    user_agent TEXT,
    details    JSONB,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  // ── Índices ───────────────────────────────────────────────────────────────

  'CREATE INDEX IF NOT EXISTS idx_users_email ON users(email)',
  'CREATE INDEX IF NOT EXISTS idx_users_role ON users(role)',
  'CREATE INDEX IF NOT EXISTS idx_users_active ON users(is_active) WHERE is_active = true',

  'CREATE INDEX IF NOT EXISTS idx_refresh_tokens_user_id ON refresh_tokens(user_id)',
  'CREATE INDEX IF NOT EXISTS idx_refresh_tokens_hash ON refresh_tokens(token_hash)',
  'CREATE INDEX IF NOT EXISTS idx_refresh_tokens_expires ON refresh_tokens(expires_at)',

  'CREATE INDEX IF NOT EXISTS idx_exercises_muscle_group ON exercises(muscle_group)',
  'CREATE INDEX IF NOT EXISTS idx_exercises_difficulty ON exercises(difficulty)',
  'CREATE INDEX IF NOT EXISTS idx_exercises_active ON exercises(is_active) WHERE is_active = true',

  'CREATE INDEX IF NOT EXISTS idx_routines_user_id ON routines(user_id)',
  'CREATE INDEX IF NOT EXISTS idx_routines_public ON routines(is_public) WHERE is_public = true',

  'CREATE INDEX IF NOT EXISTS idx_routine_days_routine_id ON routine_days(routine_id)',
  'ALTER TABLE routine_day_exercises ADD COLUMN IF NOT EXISTS rir INTEGER',
  'ALTER TABLE exercises ADD COLUMN IF NOT EXISTS image_url TEXT',
  "ALTER TABLE exercises ADD COLUMN IF NOT EXISTS step_images TEXT[] NOT NULL DEFAULT '{}'",

  'CREATE INDEX IF NOT EXISTS idx_rde_routine_day_id ON routine_day_exercises(routine_day_id)',

  'CREATE INDEX IF NOT EXISTS idx_sessions_user_id ON workout_sessions(user_id)',
  'CREATE INDEX IF NOT EXISTS idx_sessions_started_at ON workout_sessions(started_at DESC)',
  'CREATE INDEX IF NOT EXISTS idx_sessions_user_started ON workout_sessions(user_id, started_at DESC)',

  'CREATE INDEX IF NOT EXISTS idx_sets_session_id ON workout_sets(session_id)',
  'CREATE INDEX IF NOT EXISTS idx_sets_exercise_id ON workout_sets(exercise_id)',

  'CREATE INDEX IF NOT EXISTS idx_pr_user_id ON personal_records(user_id)',
  'CREATE INDEX IF NOT EXISTS idx_pr_exercise_id ON personal_records(exercise_id)',
  'CREATE INDEX IF NOT EXISTS idx_pr_validated ON personal_records(is_validated, exercise_id) WHERE is_validated = true',

  'CREATE INDEX IF NOT EXISTS idx_measurements_user_id ON body_measurements(user_id)',
  'CREATE INDEX IF NOT EXISTS idx_measurements_date ON body_measurements(user_id, measured_at DESC)',

  'CREATE INDEX IF NOT EXISTS idx_articles_category ON articles(category)',
  'CREATE INDEX IF NOT EXISTS idx_articles_published ON articles(published_at DESC) WHERE is_published = true',

  'CREATE INDEX IF NOT EXISTS idx_events_date ON events(event_date)',
  'CREATE INDEX IF NOT EXISTS idx_events_active ON events(is_active, event_date) WHERE is_active = true',

  'CREATE INDEX IF NOT EXISTS idx_audit_user_id ON security_audit_log(user_id)',
  'CREATE INDEX IF NOT EXISTS idx_audit_created ON security_audit_log(created_at DESC)',

  // ── Columnas adicionales (idempotentes) ───────────────────────────────────
  "ALTER TABLE exercises ADD COLUMN IF NOT EXISTS exercise_type TEXT NOT NULL DEFAULT 'dinamico'",
  'ALTER TABLE exercises DROP CONSTRAINT IF EXISTS exercises_exercise_type_check',
  "ALTER TABLE exercises ADD CONSTRAINT exercises_exercise_type_check CHECK (exercise_type IN ('dinamico', 'isometrico', 'calistenia'))",
  'ALTER TABLE workout_sets ADD COLUMN IF NOT EXISTS duration_seconds INTEGER',
  'ALTER TABLE routine_day_exercises ADD COLUMN IF NOT EXISTS duration_seconds INTEGER',
  'ALTER TABLE users ADD COLUMN IF NOT EXISTS faculty TEXT',
  'ALTER TABLE articles ADD COLUMN IF NOT EXISTS image_url TEXT',
  'ALTER TABLE articles ADD COLUMN IF NOT EXISTS bibliography TEXT',
  'ALTER TABLE articles ADD COLUMN IF NOT EXISTS resources JSONB',
  'ALTER TABLE events ADD COLUMN IF NOT EXISTS image_url TEXT',
  'ALTER TABLE events ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ',
  'ALTER TABLE routines ADD COLUMN IF NOT EXISTS is_default BOOLEAN NOT NULL DEFAULT false',

  // ── Flag rankeable en ejercicios ─────────────────────────────────────────
  'ALTER TABLE exercises ADD COLUMN IF NOT EXISTS is_rankeable BOOLEAN NOT NULL DEFAULT false',

  // ── Enum y tablas de postulaciones al ranking ─────────────────────────────
  "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'lift_submission_status') THEN CREATE TYPE lift_submission_status AS ENUM ('pending', 'approved', 'rejected'); END IF; END \$\$",

  '''
  CREATE TABLE IF NOT EXISTS lift_submissions (
    id                  UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID          NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    exercise_id         UUID          NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    weight_kg           NUMERIC(6,2)  NOT NULL CHECK (weight_kg > 0),
    reps                SMALLINT      NOT NULL DEFAULT 1 CHECK (reps > 0),
    location_name       VARCHAR(300),
    location_lat        DOUBLE PRECISION,
    location_lng        DOUBLE PRECISION,
    description         TEXT,
    was_witnessed       BOOLEAN       NOT NULL DEFAULT false,
    witness_name        VARCHAR(200),
    video_url           VARCHAR(500)  NOT NULL,
    status              lift_submission_status NOT NULL DEFAULT \'pending\',
    reviewed_by         UUID          REFERENCES users(id) ON DELETE SET NULL,
    review_comment      TEXT,
    reviewed_at         TIMESTAMPTZ,
    is_record_breaking  BOOLEAN       DEFAULT false,
    created_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ   NOT NULL DEFAULT NOW()
  )
  ''',

  '''
  CREATE TABLE IF NOT EXISTS lift_submission_images (
    id             UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    submission_id  UUID        NOT NULL REFERENCES lift_submissions(id) ON DELETE CASCADE,
    image_url      VARCHAR(500) NOT NULL,
    sort_order     SMALLINT    NOT NULL DEFAULT 0,
    uploaded_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
  )
  ''',

  "CREATE INDEX IF NOT EXISTS idx_lift_submissions_user ON lift_submissions(user_id)",
  "CREATE INDEX IF NOT EXISTS idx_lift_submissions_exercise ON lift_submissions(exercise_id, weight_kg DESC) WHERE status = 'approved'",
  "CREATE INDEX IF NOT EXISTS idx_lift_submissions_pending ON lift_submissions(status) WHERE status = 'pending'",
  "CREATE INDEX IF NOT EXISTS idx_lift_submission_images ON lift_submission_images(submission_id)",

  // ── Estados de sesión de entrenamiento ───────────────────────────────────
  "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'workout_session_status') THEN CREATE TYPE workout_session_status AS ENUM ('in_progress', 'completed', 'partial'); END IF; END \$\$",
  "ALTER TABLE workout_sessions ADD COLUMN IF NOT EXISTS status workout_session_status NOT NULL DEFAULT 'in_progress'",
  'ALTER TABLE workout_sessions ADD COLUMN IF NOT EXISTS early_finish_reason TEXT',

  // ── Tabla: app_notifications (notificaciones del sistema / parches / noticias) ─
  """
  CREATE TABLE IF NOT EXISTS app_notifications (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    type       VARCHAR(30)  NOT NULL DEFAULT 'news'
                              CHECK (type IN ('news', 'patch', 'feature', 'reminder')),
    title      VARCHAR(255) NOT NULL,
    body       TEXT         NOT NULL,
    created_by UUID         REFERENCES users(id),
    is_active  BOOLEAN      NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  """,

  // ── Tabla: notification_reads (rastrea lecturas por usuario) ─────────────────
  '''
  CREATE TABLE IF NOT EXISTS notification_reads (
    user_id      UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    notif_type   VARCHAR(20) NOT NULL,
    reference_id UUID        NOT NULL,
    read_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, notif_type, reference_id)
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_notif_reads_user ON notification_reads(user_id)',

  // ── Tabla: event_interests ────────────────────────────────────────────────
  '''
  CREATE TABLE IF NOT EXISTS event_interests (
    user_id    UUID        NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id   UUID        NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, event_id)
  )
  ''',
  'CREATE INDEX IF NOT EXISTS idx_event_interests_event ON event_interests(event_id)',

  // ── HIIT ─────────────────────────────────────────────────────────────────────
  "DO \$\$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'hiit_mode') THEN CREATE TYPE hiit_mode AS ENUM ('tabata', 'emom', 'amrap', 'for_time', 'mix'); END IF; END \$\$",

  '''
  CREATE TABLE IF NOT EXISTS hiit_workouts (
    id         UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID         REFERENCES users(id) ON DELETE CASCADE,
    name       VARCHAR(255) NOT NULL,
    mode       hiit_mode    NOT NULL,
    config     JSONB        NOT NULL DEFAULT \'{}\',
    is_public  BOOLEAN      NOT NULL DEFAULT false,
    is_active  BOOLEAN      NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  '''
  CREATE TABLE IF NOT EXISTS hiit_sessions (
    id                     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                UUID         NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    hiit_workout_id        UUID         REFERENCES hiit_workouts(id) ON DELETE SET NULL,
    name                   VARCHAR(255) NOT NULL,
    mode                   hiit_mode    NOT NULL,
    config                 JSONB        NOT NULL DEFAULT \'{}\',
    total_duration_seconds INTEGER,
    rounds_completed       INTEGER      NOT NULL DEFAULT 0,
    started_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    ended_at               TIMESTAMPTZ,
    created_at             TIMESTAMPTZ  NOT NULL DEFAULT NOW()
  )
  ''',

  'CREATE INDEX IF NOT EXISTS idx_hiit_workouts_user ON hiit_workouts(user_id)',
  'CREATE INDEX IF NOT EXISTS idx_hiit_sessions_user ON hiit_sessions(user_id, started_at DESC)',

  // ── Función trigger: updated_at automático ────────────────────────────────
  r'''
  CREATE OR REPLACE FUNCTION update_updated_at_column()
  RETURNS TRIGGER AS $$
  BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
  END;
  $$ LANGUAGE plpgsql
  ''',

  // ── Triggers ──────────────────────────────────────────────────────────────

  '''
  DO \$\$
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger WHERE tgname = \'users_updated_at\'
    ) THEN
      CREATE TRIGGER users_updated_at
        BEFORE UPDATE ON users
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
  END
  \$\$
  ''',

  '''
  DO \$\$
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger WHERE tgname = \'routines_updated_at\'
    ) THEN
      CREATE TRIGGER routines_updated_at
        BEFORE UPDATE ON routines
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
  END
  \$\$
  ''',

  '''
  DO \$\$
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger WHERE tgname = \'articles_updated_at\'
    ) THEN
      CREATE TRIGGER articles_updated_at
        BEFORE UPDATE ON articles
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
  END
  \$\$
  ''',

  '''
  DO \$\$
  BEGIN
    IF NOT EXISTS (
      SELECT 1 FROM pg_trigger WHERE tgname = \'events_updated_at\'
    ) THEN
      CREATE TRIGGER events_updated_at
        BEFORE UPDATE ON events
        FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
  END
  \$\$
  ''',
];
