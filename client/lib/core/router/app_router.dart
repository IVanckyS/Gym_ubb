import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/admin/presentation/users_screen.dart';
import '../../features/admin/presentation/careers_screen.dart';
import '../../features/exercises/presentation/exercises_screen.dart';
import '../../features/exercises/presentation/exercise_detail_screen.dart';
import '../../features/onboarding/presentation/terms_screen.dart';
import '../../features/onboarding/presentation/notifications_screen.dart';
import '../../features/routines/presentation/routines_screen.dart';
import '../../features/routines/presentation/routine_detail_screen.dart';
import '../../features/routines/presentation/create_routine_screen.dart';
import '../../features/workout/presentation/workout_session_screen.dart';
import '../../features/workout/presentation/workout_summary_screen.dart';
import '../../features/workout/presentation/workout_history_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/rankings/presentation/rankings_screen.dart';
import '../../features/rankings/presentation/postulate_ranking_screen.dart';
import '../../features/rankings/presentation/lift_submission_detail_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/education/presentation/education_screen.dart';
import '../../features/education/presentation/article_detail_screen.dart';
import '../../features/events/presentation/events_screen.dart';
import '../../features/events/presentation/event_detail_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart' as notif_screen;
import '../../shared/providers/auth_provider.dart';
import '../../shared/providers/onboarding_provider.dart';
import '../../shared/widgets/main_shell.dart';

GoRouter buildRouter(
  AuthProvider auth,
  OnboardingProvider onboarding, {
  GlobalKey<NavigatorState>? navigatorKey,
}) =>
    GoRouter(
      navigatorKey: navigatorKey,
      refreshListenable: Listenable.merge([auth, onboarding]),
      initialLocation: '/login',
      redirect: (context, state) {
        // Esperar a que se inicialice el onboarding
        if (!onboarding.isInitialized) return null;

        final loc = state.matchedLocation;
        final isOnboarding = loc.startsWith('/onboarding');

        // Si no completó onboarding → ir a terms (salvo que ya esté ahí)
        if (!onboarding.isCompleted && !isOnboarding) {
          return '/onboarding/terms';
        }

        // Si ya completó onboarding y está en rutas de onboarding → login
        if (onboarding.isCompleted && isOnboarding) {
          return '/login';
        }

        // Si no completó onboarding, dejar pasar las rutas de onboarding
        if (!onboarding.isCompleted) return null;

        // ── Guards de autenticación ────────────────────────────────────────
        final status = auth.status;
        final isAuthRoute = loc == '/login' ||
            loc == '/register' ||
            loc == '/register/verify';

        if (status == AuthStatus.unknown) return null;

        if (status == AuthStatus.unauthenticated && !isAuthRoute) {
          return '/login';
        }

        if (status == AuthStatus.authenticated && isAuthRoute) {
          return '/home';
        }

        // Solo admins en rutas /admin
        if (loc.startsWith('/admin')) {
          if (status != AuthStatus.authenticated) return '/login';
          if (auth.user?['role'] != 'admin') return '/home';
        }

        return null;
      },
      routes: [
        // ── Onboarding (sin shell, solo primera vez) ────────────────────────
        GoRoute(
          path: '/onboarding/terms',
          builder: (context, state) => const TermsScreen(),
        ),
        GoRoute(
          path: '/onboarding/notifications',
          builder: (context, state) => const NotificationsScreen(),
        ),

        // ── Sin shell (pantallas full-screen / flujo especial) ──────────────
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/register/verify',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>? ?? {};
            return VerifyEmailScreen(
              email: extra['email'] as String? ?? '',
              name: extra['name'] as String? ?? '',
            );
          },
        ),
        GoRoute(
          path: '/workout/session',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            return WorkoutSessionScreen(
              routineId: extra?['routineId'] as String?,
              routineDayId: extra?['routineDayId'] as String?,
              routineName: extra?['routineName'] as String?,
              dayLabel: extra?['dayLabel'] as String?,
            );
          },
        ),
        GoRoute(
          path: '/workout/summary',
          builder: (context, state) => WorkoutSummaryScreen(
            session: state.extra as Map<String, dynamic>,
          ),
        ),

        // ── Con shell (barra de navegación inferior) ────────────────────────
        ShellRoute(
          builder: (context, state, child) => MainShell(child: child),
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
            GoRoute(
              path: '/exercises',
              builder: (context, state) => const ExercisesScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      ExerciseDetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: '/routines',
              builder: (context, state) => const RoutinesScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (context, state) => const CreateRoutineScreen(),
                ),
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      RoutineDetailScreen(id: state.pathParameters['id']!),
                  routes: [
                    GoRoute(
                      path: 'edit',
                      builder: (context, state) => CreateRoutineScreen(
                          routineId: state.pathParameters['id']!),
                    ),
                  ],
                ),
              ],
            ),
            GoRoute(
              path: '/workout/history',
              builder: (context, state) => const WorkoutHistoryScreen(),
            ),
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryScreen(),
            ),
            GoRoute(
              path: '/rankings',
              builder: (context, state) => const RankingsScreen(),
              routes: [
                GoRoute(
                  path: 'postulate',
                  builder: (context, state) => const PostulateRankingScreen(),
                ),
                GoRoute(
                  path: 'submission/:id',
                  builder: (context, state) => LiftSubmissionDetailScreen(
                      id: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
            GoRoute(
              path: '/education',
              builder: (context, state) => const EducationScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      ArticleDetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: '/events',
              builder: (context, state) => const EventsScreen(),
              routes: [
                GoRoute(
                  path: ':id',
                  builder: (context, state) =>
                      EventDetailScreen(id: state.pathParameters['id']!),
                ),
              ],
            ),
            GoRoute(
              path: '/notifications',
              builder: (context, state) => const notif_screen.NotificationsScreen(),
            ),
            GoRoute(
              path: '/admin/users',
              builder: (context, state) => const UsersScreen(),
            ),
            GoRoute(
              path: '/admin/careers',
              builder: (context, state) => const CareersScreen(),
            ),
          ],
        ),
      ],
    );
