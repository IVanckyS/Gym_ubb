import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../providers/default_routine_provider.dart';

class MainShell extends StatefulWidget {
  final Widget child;

  const MainShell({required this.child, super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  DateTime? _lastBackPress;

  int _indexFromLocation(String location) {
    if (location.startsWith('/routines')) return 1;
    if (location.startsWith('/workout')) return 2;
    if (location.startsWith('/history')) return 3;
    if (location.startsWith('/profile') || location.startsWith('/admin')) return 4;
    return 0; // home, exercises, rankings, education, events
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/home');
      case 1:
        context.go('/routines');
      case 2:
        final defaultId = context.read<DefaultRoutineProvider>().routineId;
        if (defaultId != null) {
          context.go('/routines/$defaultId');
        } else {
          context.go('/routines');
        }
      case 3:
        context.go('/history');
      case 4:
        context.go('/profile');
    }
  }

  Future<bool> _handlePop(BuildContext context, int selectedIndex) async {
    if (selectedIndex != 0) {
      context.go('/home');
      return false;
    }
    // Ya estamos en Inicio: doble tap para salir
    final now = DateTime.now();
    if (_lastBackPress == null ||
        now.difference(_lastBackPress!) > const Duration(seconds: 2)) {
      _lastBackPress = now;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Presiona de nuevo para salir'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            backgroundColor: context.colorBgTertiary,
          ),
        );
      }
      return false;
    }
    SystemNavigator.pop();
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexFromLocation(location);
    final isDark = context.isDarkMode;

    final navBgColor = context.colorBgSecondary;
    final borderColor = context.colorBorder;
    final unselectedColor =
        isDark ? AppColors.textSecondary : AppColors.textMutedLight;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _handlePop(context, selectedIndex);
      },
      child: Scaffold(
        backgroundColor: context.colorBgPrimary,
        body: widget.child,
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: borderColor, width: 1)),
          ),
          child: NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => _onTap(context, i),
            backgroundColor: navBgColor,
            indicatorColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            shadowColor: Colors.transparent,
            elevation: 0,
            height: 64,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.home_outlined, color: unselectedColor, size: 22),
                selectedIcon: const Icon(Icons.home_rounded, color: AppColors.accentPrimary, size: 22),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: Icon(Icons.list_alt_outlined, color: unselectedColor, size: 22),
                selectedIcon: const Icon(Icons.list_alt_rounded, color: AppColors.accentPrimary, size: 22),
                label: 'Rutinas',
              ),
              // Botón central: Entrenar (destacado)
              NavigationDestination(
                icon: _TrainIcon(selected: false, isDark: isDark),
                selectedIcon: _TrainIcon(selected: true, isDark: isDark),
                label: 'Entrenar',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined, color: unselectedColor, size: 22),
                selectedIcon: const Icon(Icons.bar_chart_rounded, color: AppColors.accentPrimary, size: 22),
                label: 'Historial',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded, color: unselectedColor, size: 22),
                selectedIcon: const Icon(Icons.person_rounded, color: AppColors.accentPrimary, size: 22),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ícono central "Entrenar" con fondo de acento ──────────────────────────────
class _TrainIcon extends StatelessWidget {
  const _TrainIcon({required this.selected, required this.isDark});
  final bool selected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 32,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF5A52E0), AppColors.accentPrimary],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: selected
            ? [BoxShadow(color: AppColors.accentPrimary.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 2))]
            : null,
      ),
      child: Icon(
        selected ? Icons.play_arrow_rounded : Icons.play_arrow_outlined,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}
