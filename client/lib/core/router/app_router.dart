import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/admin/presentation/users_screen.dart';
import '../../features/admin/presentation/careers_screen.dart';
import '../../features/exercises/presentation/exercises_screen.dart';
import '../../features/exercises/presentation/exercise_detail_screen.dart';
import '../../shared/providers/auth_provider.dart';

// Placeholder para la pantalla home (se implementa en el siguiente módulo)
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.user;
    final isAdmin = user?['role'] == 'admin';

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bienvenido, ${user?['name'] ?? 'Usuario'}',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              user?['role'] ?? '',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: ElevatedButton.icon(
                onPressed: () => context.go('/exercises'),
                icon: const Icon(Icons.fitness_center),
                label: const Text('Ejercicios'),
              ),
            ),
            if (isAdmin) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/admin/users'),
                  icon: const Icon(Icons.manage_accounts),
                  label: const Text('Gestionar usuarios'),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/admin/careers'),
                  icon: const Icon(Icons.school),
                  label: const Text('Gestionar carreras'),
                ),
              ),
            ],
            ElevatedButton(
              onPressed: () async => auth.logout(),
              child: const Text('Cerrar sesión'),
            ),
          ],
        ),
      ),
    );
  }
}

GoRouter buildRouter(AuthProvider auth) => GoRouter(
      refreshListenable: auth,
      initialLocation: '/login',
      redirect: (context, state) {
        final status = auth.status;
        final isLoginRoute = state.matchedLocation == '/login';

        if (status == AuthStatus.unknown) return null;

        if (status == AuthStatus.unauthenticated && !isLoginRoute) {
          return '/login';
        }

        if (status == AuthStatus.authenticated && isLoginRoute) {
          return '/home';
        }

        // Solo admins en rutas /admin
        if (state.matchedLocation.startsWith('/admin')) {
          if (status != AuthStatus.authenticated) return '/login';
          if (auth.user?['role'] != 'admin') return '/home';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/admin/users',
          builder: (context, state) => const UsersScreen(),
        ),
        GoRoute(
          path: '/admin/careers',
          builder: (context, state) => const CareersScreen(),
        ),
        GoRoute(
          path: '/exercises',
          builder: (context, state) => const ExercisesScreen(),
        ),
        GoRoute(
          path: '/exercises/:id',
          builder: (context, state) =>
              ExerciseDetailScreen(id: state.pathParameters['id']!),
        ),
      ],
    );
