# GymUBB

App móvil institucional para el gimnasio de la Universidad del Bío-Bío. Permite a estudiantes, profesores y funcionarios gestionar rutinas, registrar sesiones de entrenamiento, consultar rankings, acceder a contenido educativo y mucho más.

Proyecto de titulación — Ingeniería en Ejecución en Computación e Informática, UBB.

---

## Tecnologías

| Capa | Tecnología | Versión |
|---|---|---|
| App móvil | Flutter (Android + iOS) | SDK ^3.11 |
| Backend API | Dart + Shelf | ^1.4.1 |
| Enrutamiento backend | shelf_router | ^1.1.4 |
| Base de datos | PostgreSQL | 16 |
| Caché / Blacklist / OTP | Redis | 7 |
| Storage de archivos | Cloudflare R2 | — |
| Contenedores | Docker + Docker Compose | — |
| Reverse proxy (prod) | Nginx | — |

---

## Arquitectura

### Estructura de carpetas

```
gym_ubb/
├── docker-compose.yml          ← Producción
├── docker-compose.dev.yml      ← Desarrollo local
├── .env.example                ← Plantilla de variables de entorno
│
├── server/
│   ├── bin/main.dart
│   └── lib/src/
│       ├── handlers/
│       │   ├── auth_handler.dart          ← login, logout, refresh, me, register OTP
│       │   ├── users_handler.dart         ← CRUD + /me + /me/stats + /me/preferences
│       │   ├── careers_handler.dart
│       │   ├── exercises_handler.dart     ← catálogo, filtros, subida de imagen
│       │   ├── routines_handler.dart      ← CRUD + días + copyRoutine + setDefault
│       │   ├── joint_exercises_handler.dart
│       │   ├── workout_handler.dart       ← sesión activa, logSet, finish, week-status
│       │   ├── history_handler.dart       ← progreso, récords, medidas corporales
│       │   ├── rankings_handler.dart      ← leaderboard, validación PRs
│       │   ├── articles_handler.dart      ← catálogo, favoritos, CRUD
│       │   ├── events_handler.dart        ← eventos, intereses, CRUD
│       │   ├── notifications_handler.dart ← sistema, unread, marcar leída
│       │   └── lift_submissions_handler.dart ← postulaciones, aprobar/rechazar
│       ├── middleware/
│       │   ├── auth_middleware.dart
│       │   ├── cors_middleware.dart
│       │   └── security_headers_middleware.dart
│       ├── services/
│       │   ├── jwt_service.dart
│       │   ├── email_service.dart         ← envío OTP por SMTP (fallback a logs en dev)
│       │   └── rate_limit_service.dart
│       ├── database/
│       │   ├── connection.dart
│       │   ├── redis_client.dart
│       │   ├── schema.dart
│       │   └── seed.dart
│       └── utils/response.dart
│
└── client/
    └── lib/
        ├── core/
        │   ├── theme/app_theme.dart
        │   ├── router/app_router.dart
        │   └── constants/
        ├── shared/
        │   ├── providers/
        │   ├── services/
        │   └── widgets/main_shell.dart
        └── features/
            ├── auth/           ← login · register · verify_email
            ├── onboarding/     ← terms · notifications
            ├── home/
            ├── exercises/
            ├── routines/
            ├── workout/
            ├── history/
            ├── rankings/
            ├── education/
            ├── events/
            ├── notifications/
            ├── profile/
            └── admin/
```

---

## Flujo JWT y registro

- **accessToken** HS256: expira en 15 minutos
- **refreshToken** rotativo: expira en 30 días, almacenado en PostgreSQL
- **Logout**: jti añadido a blacklist Redis (TTL = tiempo restante del token)
- **Rate limiting**: 5 intentos login por IP cada 15 min (Redis)
- **OTP registro**: clave `reg:<email>` en Redis, TTL 600s, máximo 5 intentos

Flujo de registro:
1. POST `/auth/register/request` con email institucional (@ubiobio.cl / @alumnos.ubiobio.cl) → envía OTP al correo
2. POST `/auth/register/verify` con código 6 dígitos → crea usuario y retorna tokens JWT
3. Auto-login: el cliente guarda los tokens y navega directo al home

---

## Schema de base de datos

| Tabla | Descripción |
|---|---|
| `users` | Perfil, rol, datos físicos, preferencias |
| `careers` | Carreras UBB (soft delete) |
| `refresh_tokens` | Rotación + cadena replaced_by |
| `exercises` | Catálogo muscular: grupo, dificultad, tipo (dinámico/isométrico) |
| `routines` | Rutinas personales y públicas |
| `routine_days` | Días de una rutina |
| `routine_day_exercises` | Ejercicios por día con sets/reps/descanso |
| `joint_exercises` | Ejercicios de articulaciones (8 familias) |
| `workout_sessions` | Sesiones activas e historial |
| `workout_sets` | Series completadas por sesión |
| `personal_records` | PR por usuario+ejercicio+reps (auto-upsert) |
| `body_measurements` | Medidas corporales por fecha |
| `articles` | Artículos educativos con tags |
| `article_favorites` | Favoritos por usuario |
| `events` | Eventos UBB |
| `event_interests` | Intereses de usuarios en eventos |
| `app_notifications` | Notificaciones del sistema |
| `notification_reads` | Registro de lectura |
| `lift_submissions` | Postulaciones de récords (video, weight, reps, status) |
| `lift_submission_images` | Imágenes adicionales de postulaciones |
| `security_audit_log` | Auditoría de acciones sensibles |

---

## Roles y permisos

| Rol | Permisos |
|---|---|
| `student` | Catálogo, rutinas personales, sesiones, rankings, artículos, eventos |
| `professor` | Todo lo anterior + crear ejercicios, rutinas públicas, artículos y eventos |
| `staff` | Igual que student |
| `admin` | Acceso total: usuarios, carreras, validación de récords y contenido |

---

## Módulos implementados

| Módulo | Backend | App |
|---|---|---|
| Autenticación: login, logout, refresh, /me | ✅ | ✅ |
| Registro con verificación OTP por email institucional | ✅ | ✅ |
| Onboarding legal (términos + notificaciones) | ✅ | ✅ |
| Admin: gestión de usuarios (CRUD + roles) | ✅ | ✅ |
| Admin: gestión de carreras | ✅ | ✅ |
| Catálogo ejercicios con filtros múltiples OR | ✅ | ✅ |
| Ejercicios: crear/editar con imagen y pasos | ✅ | ✅ |
| Ejercicios isométricos (badge, input duración seg) | ✅ | ✅ |
| Mapa corporal SVG interactivo | — | ✅ |
| Ejercicios de articulaciones (8 familias) | ✅ | ✅ |
| Home / Dashboard (stats reales + mis marcas) | ✅ | ✅ |
| Rutinas CRUD + wizard 3 pasos | ✅ | ✅ |
| Rutinas: copiar pública al espacio personal | ✅ | ✅ |
| Rutinas: marcar como por defecto | ✅ | ✅ |
| Rutinas: week-status (días completados/parciales) | ✅ | ✅ |
| Rutinas: adelantar / recuperar día | — | ✅ |
| Sesión activa (timer, series, timer descanso) | ✅ | ✅ |
| Sesión: sonidos countdown | — | ✅ |
| Resumen post-sesión | ✅ | ✅ |
| Historial de sesiones (paginado, lazy load) | ✅ | ✅ |
| Historial: gráfico progreso por ejercicio | ✅ | ✅ |
| Historial: medidas corporales CRUD | ✅ | ✅ |
| Historial: récords personales (mejor PR) | ✅ | ✅ |
| Exportar historial PDF (récords + medidas) | — | ✅ |
| Rankings: leaderboard por ejercicio/reps | ✅ | ✅ |
| Rankings: calculadora Wilks | — | ✅ |
| Rankings: postular levantamiento con video | ✅ | ✅ |
| Rankings: validación admin (aprobar/rechazar) | ✅ | ✅ |
| Educación: catálogo artículos, favoritos, crear | ✅ | ✅ |
| Eventos: listado, detalle, toggle interés, crear | ✅ | ✅ |
| Notificaciones: sistema + eventos + artículos | ✅ | ✅ |
| Perfil: editar datos + preferencias | ✅ | ✅ |
| Perfil: tema claro/oscuro en tiempo real | — | ✅ |
| Perfil: unidades kg/lbs global | — | ✅ |
| Perfil: marcas pinned en inicio (hasta 4) | — | ✅ |

---

## Puesta en marcha (desarrollo local)

### Requisitos previos

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.11)
- Android Studio con emulador, o dispositivo físico Android

### 1. Clonar y configurar variables de entorno

```bash
git clone https://github.com/IVanckyS/Gym_Ubb.git
cd Gym_Ubb
cp .env.example .env
# Editar .env con los valores reales
```

### 2. Levantar backend

```bash
docker compose -f docker-compose.dev.yml up -d
curl http://localhost:8080/health   # debe responder {"status":"ok"}
```

### 3. Correr la app Flutter

```bash
cd client

# Emulador Android
flutter run --dart-define=API_URL=http://10.0.2.2:8080

# Dispositivo físico (reemplazar con IP local)
flutter run --dart-define=API_URL=http://192.168.x.x:8080
```

### Credenciales de desarrollo

| Campo | Valor |
|---|---|
| Email | `admin@ubiobio.cl` |
| Contraseña | `Admin1234` |
| Rol | `admin` |

---

## Variables de entorno

Ver `.env.example` para referencia completa. Variables principales:

```
RUNMODE=development  PORT=8080
DB_HOST=postgres  DB_PORT=5432  DB_NAME=gym_ubb_dev  DB_USER=...  DB_PASSWORD=...
REDIS_HOST=redis  REDIS_PORT=6379
JWT_SECRET=secreto_minimo_32_caracteres  JWT_AUDIENCE=gym-ubb
SMTP_HOST=smtp.gmail.com  SMTP_PORT=587  SMTP_USER=...  SMTP_PASSWORD=...
ALLOWED_ORIGIN=*
```

> Si se omite SMTP, el código OTP aparece en los logs: `docker compose -f docker-compose.dev.yml logs -f server`

---

## Comandos útiles

```bash
# Logs del servidor
docker compose -f docker-compose.dev.yml logs -f server

# Reconstruir servidor tras cambios en pubspec.yaml
docker compose -f docker-compose.dev.yml build --no-cache server
docker compose -f docker-compose.dev.yml up -d server

# Actualizar dependencias Dart dentro del contenedor
docker compose -f docker-compose.dev.yml run --rm server dart pub get

# Reiniciar BD desde cero
docker compose -f docker-compose.dev.yml down -v
docker compose -f docker-compose.dev.yml up -d

# Acceder a PostgreSQL
docker exec -it gym_ubb-postgres-1 psql -U gym_ubb_user -d gym_ubb_dev
```

---

## API — Referencia rápida

Todas las respuestas: `{ "data": ..., "error": null }` o `{ "data": null, "error": { "code", "message" } }`

| Módulo | Endpoints principales |
|---|---|
| Auth | POST register/request · register/verify · login · logout · refresh · GET me |
| Usuarios | GET me/stats · PATCH me · me/preferences · CRUD admin |
| Ejercicios | GET listExercises · getExercise · byMuscleGroup · search · POST create · PATCH update · uploadImage |
| Rutinas | GET listRoutines · myDefault · getRoutine · POST create · copyRoutine · PATCH setDefault · update · DELETE |
| Workout | POST start · logSet · PATCH finish · DELETE cancel · GET active · history · session · week-status |
| Historial | GET records · progress/:id · measurements · POST measurements · DELETE measurements/:id |
| Rankings | GET exercises · leaderboard/:id · pending · POST validate/:id · DELETE reject/:id |
| Artículos | GET list · favorites · get/:id · POST create · PATCH update · deactivate · POST :id/favorite |
| Eventos | GET list · my-interests · get/:id · POST create · PATCH update · deactivate · POST :id/interest |
| Notificaciones | GET list · unreadCount · PATCH read/:id · readAll · POST create |
| Lift submissions | POST / · GET / · /:id · POST /:id/approve · /:id/reject · GET rankings · records |

---

## Rutas Flutter

```
Sin shell: /login  /register  /register/verify  /onboarding/terms  /onboarding/notifications
           /workout/session  /workout/summary

Con shell (5 tabs):
/home  /exercises  /exercises/:id
/routines  /routines/create  /routines/:id  /routines/:id/edit  /workout/history
/history
/rankings  /rankings/postulate  /rankings/submission/:id
/education  /education/:id  /events  /events/:id  /notifications  /profile
/admin/users  /admin/careers   (guard: admin)
```

---

## Dependencias Flutter principales

| Paquete | Uso |
|---|---|
| `go_router` | Navegación declarativa + ShellRoute |
| `provider` | Estado global (Auth, Theme, WeightUnit, DefaultRoutine) |
| `flutter_secure_storage` | Tokens JWT |
| `flutter_svg` | Mapa corporal SVG interactivo |
| `webview_flutter` | Videos YouTube embed |
| `fl_chart` | Gráficos de progreso |
| `image_picker` | Subida de imágenes |
| `audioplayers` | Sonidos countdown timer |
| `pdf` + `printing` | Exportar historial PDF |
| `shared_preferences` | Onboarding, tema, unidades, pinned exercises |

---

## Seguridad

- JWT HS256: blacklist por `jti` en Redis al hacer logout
- OTP registro: 6 dígitos, TTL 600s, máx 5 intentos (Redis)
- Rotación refresh tokens + detección de reutilización
- Rate limiting login: 5 intentos/15 min por IP
- bcrypt cost 12 · Queries parametrizadas · Headers OWASP
- Audit log en `security_audit_log`
