import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../data/hiit_models.dart';
import '../data/hiit_service.dart';

class HiitListScreen extends StatefulWidget {
  const HiitListScreen({super.key});

  @override
  State<HiitListScreen> createState() => _HiitListScreenState();
}

class _HiitListScreenState extends State<HiitListScreen> {
  List<HiitSession> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sessions = await hiitService.listSessions(limit: 5);
      if (mounted) setState(() { _sessions = sessions; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  static Color _modeColor(HiitMode mode) => switch (mode) {
        HiitMode.tabata => const Color(0xFFFF6B6B),
        HiitMode.emom => const Color(0xFF6C63FF),
        HiitMode.amrap => const Color(0xFF4ECDC4),
        HiitMode.forTime => const Color(0xFFFFB347),
        HiitMode.mix => const Color(0xFFEC4899),
      };

  static IconData _modeIcon(HiitMode mode) => switch (mode) {
        HiitMode.tabata => Icons.repeat_rounded,
        HiitMode.emom => Icons.schedule_rounded,
        HiitMode.amrap => Icons.loop_rounded,
        HiitMode.forTime => Icons.speed_rounded,
        HiitMode.mix => Icons.tune_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        backgroundColor: context.colorBgPrimary,
        title: Text('HIIT Timer', style: Theme.of(context).textTheme.titleLarge),
        automaticallyImplyLeading: false,
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Elige un modo',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: context.colorTextSecondary),
            ),
            const SizedBox(height: 12),
            ...HiitMode.values.map((mode) => _ModeCard(
                  mode: mode,
                  color: _modeColor(mode),
                  icon: _modeIcon(mode),
                  onTap: () => context.go('/hiit/config', extra: mode),
                )),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_sessions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'Sesiones recientes',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(color: context.colorTextSecondary),
              ),
              const SizedBox(height: 8),
              ..._sessions.map((s) => _SessionTile(session: s)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final HiitMode mode;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.mode,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: context.colorBgSecondary,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.colorBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mode.label,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mode.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colorTextSecondary,
                          ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: context.colorTextMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final HiitSession session;

  const _SessionTile({required this.session});

  String _fmt(int? secs) {
    if (secs == null) return '—';
    final m = secs ~/ 60;
    final s = secs % 60;
    return '${m}m ${s.toString().padLeft(2, '0')}s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colorBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.name,
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  '${session.mode.label} · ${session.roundsCompleted} rondas · ${_fmt(session.totalDurationSeconds)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colorTextSecondary,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
