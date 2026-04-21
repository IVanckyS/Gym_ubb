import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/legal_constants.dart';
import '../../../shared/providers/onboarding_provider.dart';

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  bool _accepted = false;

  Future<bool?> _showRejectDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '¿Estás seguro?',
          style: TextStyle(color: context.colorTextPrimary, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Debes aceptar los Términos y Condiciones para usar GymUBB. Si rechazas, la aplicación se cerrará.',
          style: TextStyle(color: context.colorTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver', style: TextStyle(color: AppColors.accentPrimary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(true);
              SystemNavigator.pop();
            },
            child: const Text('Cerrar app', style: TextStyle(color: AppColors.accentSecondary)),
          ),
        ],
      ),
    );
  }

  Future<void> _onAccept() async {
    await context.read<OnboardingProvider>().markCompleted();
    if (mounted) context.go('/onboarding/notifications');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _showRejectDialog();
      },
      child: Scaffold(
        backgroundColor: context.colorBgPrimary,
        body: SafeArea(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColors.accentPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: const Icon(
                        Icons.fitness_center_rounded,
                        color: AppColors.accentPrimary,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'GymUBB',
                      style: TextStyle(
                        color: AppColors.accentPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Antes de comenzar',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Lee y acepta nuestros Términos y Condiciones',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // ── Texto T&C (scroll) ──────────────────────────────────────────
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: context.colorBgSecondary,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const SingleChildScrollView(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      kTermsText,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ),

              // ── Checkbox + botones ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _accepted = !_accepted),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: _accepted
                                  ? AppColors.accentPrimary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: _accepted
                                    ? AppColors.accentPrimary
                                    : AppColors.textMuted,
                                width: 1.5,
                              ),
                            ),
                            child: _accepted
                                ? const Icon(Icons.check, color: Colors.white, size: 14)
                                : null,
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'He leído y acepto los Términos y Condiciones',
                              style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _accepted ? _onAccept : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          disabledBackgroundColor: AppColors.bgTertiary,
                          foregroundColor: Colors.white,
                          disabledForegroundColor: AppColors.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continuar',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        final close = await _showRejectDialog();
                        if (close == true && mounted) SystemNavigator.pop();
                      },
                      child: Text(
                        'Rechazar',
                        style: TextStyle(color: context.colorTextMuted, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}





