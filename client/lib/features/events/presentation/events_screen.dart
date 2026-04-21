import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/events_service.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

const _eventTypes = [
  'charla', 'taller', 'jornada', 'competencia', 'torneo', 'conferencia', 'workshop',
];

Color _typeColor(String type) {
  return switch (type.toLowerCase()) {
    'competencia' || 'torneo' => const Color(0xFFFF6B6B),
    'charla' || 'conferencia' => const Color(0xFF3B82F6),
    'taller' || 'workshop' => const Color(0xFF22C55E),
    'jornada' => const Color(0xFFF97316),
    _ => AppColors.accentPrimary,
  };
}

String _formatEventDate(String? dateStr, String? timeStr) {
  if (dateStr == null) return '';
  try {
    final date = DateTime.parse(dateStr);
    final months = [
      '', 'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
      'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
    ];
    final time = timeStr != null ? ' · ${timeStr.substring(0, 5)}' : '';
    return '${date.day} ${months[date.month]} ${date.year}$time';
  } catch (_) {
    return dateStr;
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// EventsScreen
// ══════════════════════════════════════════════════════════════════════════════

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _service = EventsService();
  final _upcomingKey = GlobalKey<_UpcomingTabState>();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?['role'] as String? ?? 'student';
    final canManage = role == 'admin' || role == 'professor';

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Eventos'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.accentPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.accentPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: const [
            Tab(text: 'Próximos'),
            Tab(text: 'Mis intereses'),
          ],
        ),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _showEventForm(context),
              backgroundColor: AppColors.accentPrimary,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text('Nuevo evento',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
      body: TabBarView(
        controller: _tabs,
        children: [
          _UpcomingTab(key: _upcomingKey, service: _service),
          _InterestsTab(service: _service),
        ],
      ),
    );
  }

  Future<void> _showEventForm(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventFormSheet(service: _service),
    );
    if (created == true) {
      _upcomingKey.currentState?._load();
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 1 — Upcoming events
// ══════════════════════════════════════════════════════════════════════════════

class _UpcomingTab extends StatefulWidget {
  final EventsService service;
  const _UpcomingTab({super.key, required this.service});

  @override
  State<_UpcomingTab> createState() => _UpcomingTabState();
}

class _UpcomingTabState extends State<_UpcomingTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await widget.service.listEvents(upcoming: true, limit: 50);
      if (mounted) setState(() { _events = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_error.isNotEmpty) {
      return _ErrorView(message: _error, onRetry: _load);
    }
    if (_events.isEmpty) {
      return const _EmptyView(message: 'No hay eventos próximos');
    }
    return RefreshIndicator(
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.bgSecondary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        itemCount: _events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _EventCard(event: _events[i]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB 2 — My interests
// ══════════════════════════════════════════════════════════════════════════════

class _InterestsTab extends StatefulWidget {
  final EventsService service;
  const _InterestsTab({required this.service});

  @override
  State<_InterestsTab> createState() => _InterestsTabState();
}

class _InterestsTabState extends State<_InterestsTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Map<String, dynamic>> _events = [];
  bool _loading = true;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = ''; });
    try {
      final data = await widget.service.getMyInterests();
      if (mounted) setState(() { _events = data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_error.isNotEmpty) return _ErrorView(message: _error, onRetry: _load);
    if (_events.isEmpty) {
      return const _EmptyView(message: 'Aún no marcaste interés en ningún evento');
    }
    return RefreshIndicator(
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.bgSecondary,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (ctx, i) => _EventCard(event: _events[i]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Event Card
// ══════════════════════════════════════════════════════════════════════════════

class _EventCard extends StatelessWidget {
  final Map<String, dynamic> event;
  const _EventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final type = event['type'] as String? ?? '';
    final color = _typeColor(type);
    final isInterested = event['isInterested'] as bool? ?? false;
    final interestCount = event['interestCount'] as int? ?? 0;
    final maxP = event['maxParticipants'] as int?;
    final dateStr = _formatEventDate(
      event['eventDate'] as String?,
      event['eventTime'] as String?,
    );

    return GestureDetector(
      onTap: () => context.push('/events/${event['id']}'),
      child: Container(
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.colorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Color banner or image
            if (event['imageUrl'] != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Image.network(
                  event['imageUrl'] as String,
                  height: 130,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _EventBanner(color: color, type: type),
                ),
              )
            else
              _EventBanner(color: color, type: type),

            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type chip + interest indicator
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: color.withAlpha(30),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: color.withAlpha(80)),
                        ),
                        child: Text(
                          type,
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (isInterested)
                        const Icon(Icons.star_rounded,
                            size: 18, color: Color(0xFFEAB308)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Title
                  Text(
                    event['title'] as String? ?? '',
                    style: TextStyle(
                      color: context.colorTextPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Meta
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      if (dateStr.isNotEmpty)
                        _MetaItem(
                          icon: Icons.calendar_today_rounded,
                          label: dateStr,
                        ),
                      if (event['location'] != null)
                        _MetaItem(
                          icon: Icons.location_on_rounded,
                          label: event['location'] as String,
                        ),
                      _MetaItem(
                        icon: Icons.people_outline_rounded,
                        label: maxP != null
                            ? '$interestCount / $maxP interesados'
                            : '$interestCount interesados',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventBanner extends StatelessWidget {
  final Color color;
  final String type;
  const _EventBanner({required this.color, required this.type});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 72,
      width: double.infinity,
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      alignment: Alignment.center,
      child: Icon(Icons.event_rounded, size: 32, color: color),
    );
  }
}

class _MetaItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.colorTextMuted),
        SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: context.colorTextMuted, fontSize: 12),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Event Form Sheet (admin / professor)
// ══════════════════════════════════════════════════════════════════════════════

class _EventFormSheet extends StatefulWidget {
  final EventsService service;
  const _EventFormSheet({required this.service});

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _maxPartCtrl = TextEditingController();
  final _regUrlCtrl = TextEditingController();
  String _type = 'charla';
  DateTime? _date;
  TimeOfDay? _time;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _locationCtrl.dispose();
    _descCtrl.dispose();
    _maxPartCtrl.dispose();
    _regUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _time = picked);
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_date == null) {
      setState(() => _error = 'Selecciona una fecha para el evento');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final maxP = _maxPartCtrl.text.trim().isNotEmpty
          ? int.tryParse(_maxPartCtrl.text.trim())
          : null;
      await widget.service.createEvent(
        title: _titleCtrl.text.trim(),
        type: _type,
        eventDate: _isoDate(_date!),
        eventTime: _time != null ? '${_formatTime(_time!)}:00' : null,
        location: _locationCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        maxParticipants: maxP,
        registrationUrl: _regUrlCtrl.text.trim().isNotEmpty ? _regUrlCtrl.text.trim() : null,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.90,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: context.colorBgSecondary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: context.colorBorder,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text('Nuevo evento',
                        style: TextStyle(
                            color: context.colorTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.colorTextMuted),
                    onPressed: () => Navigator.pop(context, false),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // Form
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  children: [
                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentSecondary.withAlpha(20),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.accentSecondary.withAlpha(60)),
                        ),
                        child: Text(_error!,
                            style: const TextStyle(
                                color: AppColors.accentSecondary, fontSize: 13)),
                      ),

                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(labelText: 'Título *'),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'El título es requerido' : null,
                    ),
                    const SizedBox(height: 16),

                    // Type chips
                    Text('Tipo de evento *',
                        style: TextStyle(
                            color: context.colorTextSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _eventTypes.map((t) {
                        final selected = _type == t;
                        final color = _typeColor(t);
                        return ChoiceChip(
                          label: Text(t[0].toUpperCase() + t.substring(1)),
                          selected: selected,
                          selectedColor: color.withAlpha(40),
                          backgroundColor: context.colorBgTertiary,
                          labelStyle: TextStyle(
                            color: selected ? color : context.colorTextSecondary,
                            fontSize: 12,
                            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: selected ? color : context.colorBorder,
                          ),
                          onSelected: (_) => setState(() => _type = t),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Date + Time row
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickDate,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: context.colorBgTertiary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.colorBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today_rounded,
                                      size: 18,
                                      color: _date != null
                                          ? AppColors.accentPrimary
                                          : context.colorTextMuted),
                                  const SizedBox(width: 8),
                                  Text(
                                    _date != null
                                        ? _formatDate(_date!)
                                        : 'Fecha *',
                                    style: TextStyle(
                                      color: _date != null
                                          ? context.colorTextPrimary
                                          : context.colorTextMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: _pickTime,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 14),
                              decoration: BoxDecoration(
                                color: context.colorBgTertiary,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.colorBorder),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.access_time_rounded,
                                      size: 18,
                                      color: _time != null
                                          ? AppColors.accentPrimary
                                          : context.colorTextMuted),
                                  const SizedBox(width: 8),
                                  Text(
                                    _time != null
                                        ? _formatTime(_time!)
                                        : 'Hora (opc.)',
                                    style: TextStyle(
                                      color: _time != null
                                          ? context.colorTextPrimary
                                          : context.colorTextMuted,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Location
                    TextFormField(
                      controller: _locationCtrl,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Lugar (opcional)',
                        hintText: 'Gimnasio UBB, Aula Magna...',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'Descripción (opcional)',
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                    ),
                    const SizedBox(height: 16),

                    // Max participants + Registration URL
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _maxPartCtrl,
                            style: TextStyle(color: context.colorTextPrimary),
                            decoration: const InputDecoration(
                              labelText: 'Cupos máx.',
                              hintText: '50',
                            ),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              if (v == null || v.isEmpty) return null;
                              if (int.tryParse(v) == null) return 'Número inválido';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _regUrlCtrl,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(
                        labelText: 'URL de inscripción (opcional)',
                        hintText: 'https://...',
                        prefixIcon: Icon(Icons.link_rounded),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _submit,
                        icon: _saving
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.event_available_rounded),
                        label: const Text('Crear evento'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Shared helpers
// ══════════════════════════════════════════════════════════════════════════════

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 48, color: AppColors.accentSecondary),
            SizedBox(height: 12),
            Text(message,
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colorTextSecondary)),
            const SizedBox(height: 16),
            TextButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String message;
  const _EmptyView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.event_busy_rounded,
              size: 48, color: context.colorTextMuted),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: context.colorTextSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}
