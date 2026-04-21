import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/weight_utils.dart';
import '../../../features/profile/providers/weight_unit_notifier.dart';
import '../../../shared/providers/auth_provider.dart';
import '../data/lift_submissions_service.dart';

class LiftSubmissionDetailScreen extends StatefulWidget {
  const LiftSubmissionDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<LiftSubmissionDetailScreen> createState() =>
      _LiftSubmissionDetailScreenState();
}

class _LiftSubmissionDetailScreenState
    extends State<LiftSubmissionDetailScreen> {
  final _service = LiftSubmissionsService();

  Map<String, dynamic>? _submission;
  bool _loading = true;
  bool _acting = false;
  WeightUnit _unit = WeightUnit.kg;

  @override
  void initState() {
    super.initState();
    _unit = context.read<WeightUnitNotifier>().unit;
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final s = await _service.getOne(widget.id);
      setState(() { _submission = s; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _approve() async {
    setState(() => _acting = true);
    try {
      final updated = await _service.approve(widget.id);
      setState(() { _submission = updated; _acting = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Postulación aprobada'),
              backgroundColor: AppColors.accentGreen),
        );
      }
    } catch (e) {
      setState(() => _acting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.accentSecondary));
      }
    }
  }

  Future<void> _reject() async {
    final ctrl = TextEditingController();
    final comment = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.colorBgSecondary,
        title: Text('Motivo de rechazo',
            style: TextStyle(color: context.colorTextPrimary)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: context.colorTextPrimary),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Describe el motivo...',
            hintStyle: TextStyle(color: context.colorTextMuted),
            filled: true,
            fillColor: context.colorBgTertiary,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancelar',
                style: TextStyle(color: context.colorTextSecondary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentSecondary),
            onPressed: () {
              if (ctrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop(ctrl.text.trim());
            },
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (comment == null || comment.isEmpty) return;

    setState(() => _acting = true);
    try {
      final updated = await _service.reject(widget.id, comment);
      setState(() { _submission = updated; _acting = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Postulación rechazada')),
        );
      }
    } catch (e) {
      setState(() => _acting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.accentSecondary));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().user?['role'] as String? ?? '';
    final canReview = ['admin', 'professor', 'staff'].contains(role);

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(title: const Text('Detalle del levantamiento')),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary))
          : _submission == null
              ? Center(
                  child: Text('No se encontró la postulación',
                      style: TextStyle(color: context.colorTextSecondary)))
              : _buildBody(canReview),
    );
  }

  Widget _buildBody(bool canReview) {
    final s = _submission!;
    final status = s['status'] as String? ?? 'pending';
    final weightKg = (s['weightKg'] as num?)?.toDouble() ?? 0;
    final displayWeight = toDisplayUnit(weightKg, _unit);
    final reps = s['reps'] as int? ?? 1;
    final images = (s['images'] as List? ?? []).cast<Map<String, dynamic>>();
    final isRecordBreaking = s['isRecordBreaking'] as bool? ?? false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Cabecera ──────────────────────────────────────────────────────
        _StatusBanner(status: status, isRecord: isRecordBreaking),
        const SizedBox(height: 16),

        // ── Info principal ────────────────────────────────────────────────
        _InfoCard(children: [
          _InfoRow(
              icon: Icons.fitness_center_rounded,
              label: 'Ejercicio',
              value: s['exerciseName'] as String? ?? ''),
          _InfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Atleta',
              value: s['userName'] as String? ?? ''),
          _InfoRow(
              icon: Icons.monitor_weight_outlined,
              label: 'Peso',
              value:
                  '${displayWeight.toStringAsFixed(1)} ${_unit.name}  ×  $reps rep${reps != 1 ? 's' : ''}'),
          if (s['locationName'] != null)
            _InfoRow(
                icon: Icons.place_outlined,
                label: 'Lugar',
                value: s['locationName'] as String),
          if (s['wasWitnessed'] == true)
            _InfoRow(
                icon: Icons.visibility_outlined,
                label: 'Testigo',
                value: s['witnessName'] as String? ?? 'Sí'),
        ]),
        const SizedBox(height: 16),

        // ── Video ─────────────────────────────────────────────────────────
        if (s['videoUrl'] != null) ...[
          _SectionLabel('Video'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              // Abrir URL en navegador externo
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('URL: ${s['videoUrl']}'),
                  action: SnackBarAction(label: 'OK', onPressed: () {}),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colorBgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accentSecondary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.play_circle_outline_rounded,
                        color: AppColors.accentSecondary, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Ver video',
                            style: TextStyle(
                                color: context.colorTextPrimary,
                                fontWeight: FontWeight.w600)),
                        Text(s['videoUrl'] as String,
                            style: TextStyle(
                                color: context.colorTextMuted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new_rounded,
                      color: context.colorTextMuted, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Imágenes adicionales ──────────────────────────────────────────
        if (images.isNotEmpty) ...[
          _SectionLabel('Imágenes'),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: images.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  images[i]['imageUrl'] as String,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 100,
                    height: 100,
                    color: context.colorBgSecondary,
                    child: Icon(Icons.broken_image_outlined,
                        color: context.colorTextMuted),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Descripción ───────────────────────────────────────────────────
        if (s['description'] != null && (s['description'] as String).isNotEmpty) ...[
          _SectionLabel('Descripción'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.colorBgSecondary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(s['description'] as String,
                style: TextStyle(color: context.colorTextSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 16),
        ],

        // ── Revisión ──────────────────────────────────────────────────────
        if (status != 'pending' && s['reviewComment'] != null) ...[
          _SectionLabel('Comentario del revisor'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: status == 'approved'
                  ? AppColors.accentGreen.withValues(alpha: 0.08)
                  : AppColors.accentSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: status == 'approved'
                      ? AppColors.accentGreen.withValues(alpha: 0.3)
                      : AppColors.accentSecondary.withValues(alpha: 0.3)),
            ),
            child: Text(s['reviewComment'] as String,
                style: TextStyle(color: context.colorTextSecondary, fontSize: 13)),
          ),
          const SizedBox(height: 16),
        ],

        // ── Botones de revisión ───────────────────────────────────────────
        if (canReview && status == 'pending') ...[
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _acting ? null : _reject,
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('Rechazar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accentSecondary,
                  side: const BorderSide(color: AppColors.accentSecondary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _acting ? null : _approve,
                icon: _acting
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_rounded, size: 16),
                label: const Text('Aprobar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ]),
          const SizedBox(height: 32),
        ],
      ],
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.isRecord});
  final String status;
  final bool isRecord;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (status) {
      'approved' => ('Aprobado', AppColors.accentGreen, Icons.check_circle_rounded),
      'rejected' => ('Rechazado', AppColors.accentSecondary, Icons.cancel_rounded),
      _ => ('Pendiente de revisión', const Color(0xFFFFB347), Icons.hourglass_empty_rounded),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          if (isRecord) ...[
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emoji_events_rounded,
                      color: Color(0xFFFFD700), size: 14),
                  SizedBox(width: 4),
                  Text('Récord',
                      style: TextStyle(
                          color: Color(0xFFFFD700),
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colorBorder),
        ),
        child: Column(
          children: children
              .expand((w) => [w, const Divider(height: 12, thickness: 0.5)])
              .toList()
            ..removeLast(),
        ),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(icon, size: 16, color: context.colorTextMuted),
            const SizedBox(width: 8),
            Text('$label: ',
                style: TextStyle(
                    color: context.colorTextMuted, fontSize: 12)),
            Expanded(
              child: Text(value,
                  style: TextStyle(
                      color: context.colorTextPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: context.colorTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5));
}
