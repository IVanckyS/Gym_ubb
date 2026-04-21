import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/events_service.dart';

Color _typeColor(String type) => switch (type.toLowerCase()) {
      'competencia' || 'torneo' => const Color(0xFFFF6B6B),
      'charla' || 'conferencia' => const Color(0xFF3B82F6),
      'taller' || 'workshop' => const Color(0xFF22C55E),
      'jornada' => const Color(0xFFF97316),
      _ => AppColors.accentPrimary,
    };

String _formatEventDate(String? dateStr, String? timeStr) {
  if (dateStr == null) return '';
  try {
    final date = DateTime.parse(dateStr);
    final days = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    final months = [
      '', 'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final day = days[date.weekday - 1];
    final time = timeStr != null ? ' a las ${timeStr.substring(0, 5)}' : '';
    return '$day ${date.day} de ${months[date.month]} de ${date.year}$time';
  } catch (_) {
    return dateStr;
  }
}

class EventDetailScreen extends StatefulWidget {
  final String id;
  const EventDetailScreen({super.key, required this.id});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  final _service = EventsService();
  Map<String, dynamic>? _event;
  bool _loading = true;
  String _error = '';
  bool _togglingInterest = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final event = await _service.getEvent(widget.id);
      if (mounted) setState(() { _event = event; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _toggleInterest() async {
    if (_togglingInterest || _event == null) return;
    setState(() => _togglingInterest = true);
    try {
      final result = await _service.toggleInterest(widget.id);
      if (mounted) {
        setState(() {
          _event!['isInterested'] = result['isInterested'];
          _event!['interestCount'] = result['interestCount'];
          _togglingInterest = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _togglingInterest = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: AppColors.accentSecondary,
          ),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: context.colorBgPrimary,
        appBar: _simpleAppBar(context),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary),
        ),
      );
    }

    if (_error.isNotEmpty) {
      return Scaffold(
        backgroundColor: context.colorBgPrimary,
        appBar: _simpleAppBar(context),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 48, color: AppColors.accentSecondary),
              SizedBox(height: 12),
              Text(_error,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.colorTextSecondary)),
              const SizedBox(height: 16),
              TextButton(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }

    final event = _event!;
    final type = event['type'] as String? ?? '';
    final color = _typeColor(type);
    final isInterested = event['isInterested'] as bool? ?? false;
    final interestCount = event['interestCount'] as int? ?? 0;
    final maxP = event['maxParticipants'] as int?;
    final regUrl = event['registrationUrl'] as String?;
    final dateStr = _formatEventDate(
      event['eventDate'] as String?,
      event['eventTime'] as String?,
    );

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: event['imageUrl'] != null ? 200 : 110,
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: _togglingInterest
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFEAB308),
                        ),
                      )
                    : Icon(
                        isInterested ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isInterested
                            ? const Color(0xFFEAB308)
                            : context.colorTextSecondary,
                      ),
                onPressed: _toggleInterest,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: event['imageUrl'] != null
                  ? Image.network(
                      event['imageUrl'] as String,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _Banner(color: color),
                    )
                  : _Banner(color: color),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withAlpha(30),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withAlpha(80)),
                    ),
                    child: Text(
                      type,
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Title
                  Text(
                    event['title'] as String? ?? '',
                    style: TextStyle(
                      color: context.colorTextPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Info cards
                  _InfoRow(
                    icon: Icons.calendar_today_rounded,
                    color: AppColors.accentPrimary,
                    label: 'Fecha',
                    value: dateStr.isNotEmpty ? dateStr : 'Por confirmar',
                  ),
                  if (event['location'] != null) ...[
                    const SizedBox(height: 10),
                    _InfoRow(
                      icon: Icons.location_on_rounded,
                      color: AppColors.accentSecondary,
                      label: 'Lugar',
                      value: event['location'] as String,
                    ),
                  ],
                  const SizedBox(height: 10),
                  _InfoRow(
                    icon: Icons.people_outline_rounded,
                    color: AppColors.accentGreen,
                    label: 'Interesados',
                    value: maxP != null
                        ? '$interestCount de $maxP cupos'
                        : '$interestCount personas interesadas',
                  ),

                  if (event['description'] != null) ...[
                    const SizedBox(height: 24),
                    Divider(color: context.colorBorder),
                    const SizedBox(height: 16),
                    Text(
                      'Descripción',
                      style: TextStyle(
                        color: context.colorTextPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      event['description'] as String,
                      style: TextStyle(
                        color: context.colorTextSecondary,
                        fontSize: 15,
                        height: 1.6,
                      ),
                    ),
                  ],

                  const SizedBox(height: 28),

                  // Interest button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _togglingInterest ? null : _toggleInterest,
                      icon: Icon(
                        isInterested ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isInterested
                            ? const Color(0xFFEAB308)
                            : context.colorTextSecondary,
                      ),
                      label: Text(
                        isInterested ? 'Ya me interesa' : 'Me interesa',
                        style: TextStyle(
                          color: isInterested
                              ? const Color(0xFFEAB308)
                              : context.colorTextSecondary,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(
                          color: isInterested
                              ? const Color(0xFFEAB308)
                              : context.colorBorder,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),

                  // Registration button
                  if (regUrl != null && regUrl.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openUrl(regUrl),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Inscribirse'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBar _simpleAppBar(BuildContext context) => AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      );
}

class _Banner extends StatelessWidget {
  final Color color;
  const _Banner({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withAlpha(40),
      alignment: Alignment.center,
      child: Icon(Icons.event_rounded, size: 52, color: color),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  const _InfoRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: context.colorTextMuted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: context.colorTextPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}



