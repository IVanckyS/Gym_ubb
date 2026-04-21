import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/workout_service.dart';

class WorkoutHistoryScreen extends StatefulWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  State<WorkoutHistoryScreen> createState() => _WorkoutHistoryScreenState();
}

class _WorkoutHistoryScreenState extends State<WorkoutHistoryScreen> {
  final _service = WorkoutService();
  final List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _total = 0;
  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _sessions.clear();
      setState(() { _loading = true; _error = null; });
    }

    try {
      final data = await _service.getHistory(limit: _pageSize, offset: _sessions.length);
      final list = (data['sessions'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _sessions.addAll(list);
        _total = int.tryParse(data['total']?.toString() ?? '0') ?? 0;
        _loading = false;
        _loadingMore = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _sessions.length >= _total) return;
    setState(() => _loadingMore = true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        title: const Text('Historial de entrenamientos'),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.show_chart_rounded),
            tooltip: 'Ver progreso',
            onPressed: () => context.push('/history'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary))
          : _error != null
              ? _buildError()
              : _buildList(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.accentSecondary, size: 40),
          SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: context.colorTextSecondary)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentPrimary),
            onPressed: () => _load(refresh: true),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.fitness_center, color: AppColors.textMuted, size: 56),
            SizedBox(height: 16),
            Text(
              'Sin entrenamientos aún',
              style: TextStyle(color: context.colorTextSecondary, fontSize: 16),
            ),
            SizedBox(height: 6),
            Text(
              'Completa tu primera sesión para verla aquí',
              style: TextStyle(color: context.colorTextMuted, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.bgSecondary,
      onRefresh: () => _load(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (n is ScrollEndNotification &&
              n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            _loadMore();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: _sessions.length + (_loadingMore ? 1 : 0),
          itemBuilder: (context, i) {
            if (i == _sessions.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppColors.accentPrimary),
                ),
              );
            }
            return _SessionCard(session: _sessions[i]);
          },
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.session});
  final Map<String, dynamic> session;

  String _formatDate(String? iso) {
    if (iso == null) return '--';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '--';
    final months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final weekdays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final wd = weekdays[dt.weekday - 1];
    final mo = months[dt.month - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$wd ${dt.day} $mo · $h:$min';
  }

  String _formatDuration(dynamic minutes) {
    final m = int.tryParse(minutes?.toString() ?? '') ?? 0;
    if (m == 0) return '--';
    final h = m ~/ 60;
    final rem = m % 60;
    return h > 0 ? '${h}h ${rem}min' : '${m}min';
  }

  String _formatVolume(dynamic v) {
    if (v == null) return '0 kg';
    final d = double.tryParse(v.toString()) ?? 0;
    return '${d.toStringAsFixed(1)} kg';
  }

  @override
  Widget build(BuildContext context) {
    final routineName = session['routineName'] as String?;
    final dayLabel = session['dayLabel'] as String?;
    final completedSets = int.tryParse(session['completedSets']?.toString() ?? '0') ?? 0;
    final exerciseCount = int.tryParse(session['exerciseCount']?.toString() ?? '0') ?? 0;

    final title = routineName != null
        ? (dayLabel != null ? '$routineName · $dayLabel' : routineName)
        : 'Sesión libre';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Completado',
                  style: TextStyle(color: AppColors.accentGreen, fontSize: 11),
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            _formatDate(session['startedAt'] as String?),
            style: TextStyle(color: context.colorTextSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Chip(
                icon: Icons.timer_outlined,
                label: _formatDuration(session['durationMinutes']),
                color: AppColors.accentPrimary,
              ),
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.fitness_center,
                label: _formatVolume(session['totalVolumeKg']),
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.sports_gymnastics,
                label: '$exerciseCount ej.',
                color: const Color(0xFF8b5cf6),
              ),
              const SizedBox(width: 8),
              _Chip(
                icon: Icons.check_box_rounded,
                label: '$completedSets series',
                color: AppColors.accentGreen,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
      ],
    );
  }
}



