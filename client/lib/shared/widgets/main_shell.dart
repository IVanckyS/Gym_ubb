import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/gym_icon.dart';
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
    if (location.startsWith('/workout') || location.startsWith('/hiit')) return 2;
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
        _showTrainSheet(context);
      case 3:
        context.go('/history');
      case 4:
        context.go('/profile');
    }
  }

  void _showTrainSheet(BuildContext context) {
    final defaultId = context.read<DefaultRoutineProvider>().routineId;
    final isDark = context.isDarkMode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colorBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '¿Qué quieres hacer?',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLight,
                        ),
                  ),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center,
                      color: AppColors.accentPrimary),
                ),
                title: const Text('Rutinas de Fuerza'),
                subtitle: Text(
                  'Sigue tu plan semanal',
                  style: TextStyle(
                      color: context.colorTextSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right,
                    color: context.colorTextMuted),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  if (defaultId != null) {
                    context.go('/routines/$defaultId');
                  } else {
                    context.go('/routines');
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.accentSecondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.timer_rounded,
                      color: AppColors.accentSecondary),
                ),
                title: const Text('HIIT Timer'),
                subtitle: Text(
                  'Tabata, EMOM, AMRAP y más',
                  style: TextStyle(
                      color: context.colorTextSecondary, fontSize: 12),
                ),
                trailing: Icon(Icons.chevron_right,
                    color: context.colorTextMuted),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  context.go('/hiit');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
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
    final activeColor =
        isDark ? const Color(0xFF4D9FFF) : const Color(0xFF014898);

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
                icon: GymIcon('home', size: 22, color: unselectedColor),
                selectedIcon: GymIcon('home', size: 22, color: activeColor),
                label: 'Inicio',
              ),
              NavigationDestination(
                icon: GymIcon('routines', size: 22, color: unselectedColor),
                selectedIcon: _RoutinesSelectedIcon(isDark: isDark),
                label: 'Rutinas',
              ),
              NavigationDestination(
                icon: _TrainIcon(selected: false, isDark: isDark),
                selectedIcon: _TrainIcon(selected: true, isDark: isDark),
                label: 'Entrenar',
              ),
              NavigationDestination(
                icon: GymIcon('history', size: 22, color: unselectedColor),
                selectedIcon: GymIcon('history', size: 22, color: activeColor),
                label: 'Historial',
              ),
              NavigationDestination(
                icon: GymIcon('profile', size: 22, color: unselectedColor),
                selectedIcon: GymIcon('profile', size: 22, color: activeColor),
                label: 'Perfil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Ícono central "Entrenar" — play button ────────────────────────────────────
class _TrainIcon extends StatelessWidget {
  const _TrainIcon({required this.selected, required this.isDark});
  final bool selected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final Color color;
    if (selected) {
      color = isDark ? const Color(0xFFF9B214) : const Color(0xFF014898);
    } else {
      color = isDark ? AppColors.textSecondary : AppColors.textMutedLight;
    }
    return GymIcon('train', size: 24, color: color);
  }
}

// ── Ícono "Rutinas" seleccionado — 3 azul + 1 amarillo ───────────────────────
class _RoutinesSelectedIcon extends StatelessWidget {
  const _RoutinesSelectedIcon({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final blueHex = isDark ? '#4d9fff' : '#014898';
    return SvgPicture.string(
      '''<svg width="22" height="22" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <rect x="3" y="3" width="7" height="7" rx="2" stroke="$blueHex" stroke-width="1.9"/>
        <rect x="14" y="3" width="7" height="7" rx="2" stroke="$blueHex" stroke-width="1.9"/>
        <rect x="3" y="14" width="7" height="7" rx="2" stroke="$blueHex" stroke-width="1.9"/>
        <rect x="14" y="14" width="7" height="7" rx="2" stroke="#F9B214" stroke-width="1.9"/>
      </svg>''',
      width: 22,
      height: 22,
    );
  }
}
