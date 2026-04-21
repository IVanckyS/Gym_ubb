import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/weight_utils.dart';
import '../../../features/profile/providers/weight_unit_notifier.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/rankings_service.dart';
import '../data/lift_submissions_service.dart';

class RankingsScreen extends StatefulWidget {
  const RankingsScreen({super.key});

  @override
  State<RankingsScreen> createState() => _RankingsScreenState();
}

class _RankingsScreenState extends State<RankingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _isPrivileged = false;

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().user?['role'] as String? ?? '';
    _isPrivileged = ['admin', 'professor', 'staff'].contains(role);
    _tabs = TabController(length: _isPrivileged ? 4 : 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        title: const Text('Rankings'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.accentPrimary,
          unselectedLabelColor: context.colorTextSecondary,
          indicatorColor: AppColors.accentPrimary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            const Tab(text: 'Récords'),
            const Tab(text: 'Leaderboard'),
            const Tab(text: 'Wilks'),
            if (_isPrivileged) const Tab(text: 'Revisar'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/rankings/postulate'),
        backgroundColor: AppColors.accentPrimary,
        icon: const Icon(Icons.emoji_events_rounded, color: Colors.white),
        label: const Text('Postular', style: TextStyle(color: Colors.white)),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          const _RecordsTab(),
          const _LeaderboardTab(),
          const _WilksTab(),
          if (_isPrivileged) const _ReviewTab(),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 1 — LEADERBOARD
// ═══════════════════════════════════════════════════════════════════════════════

class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab();

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  final _service = RankingsService();

  List<Map<String, dynamic>> _exercises = [];
  Map<String, dynamic>? _selected;
  Map<String, dynamic>? _leaderboard;
  bool _loadingEx = true;
  bool _loadingLb = false;
  String? _error;
  int _reps = 1;

  static const _repOptions = [1, 3, 5, 8, 10, 12];

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    setState(() { _loadingEx = true; _error = null; });
    try {
      final list = await _service.getExercises();
      setState(() {
        _exercises = list;
        _loadingEx = false;
        if (list.isNotEmpty) {
          _selected = list.first;
          _loadLeaderboard();
        }
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loadingEx = false; });
    }
  }

  Future<void> _loadLeaderboard() async {
    if (_selected == null) return;
    setState(() { _loadingLb = true; _leaderboard = null; });
    try {
      final data = await _service.getLeaderboard(
        _selected!['id'] as String,
        reps: _reps,
      );
      setState(() { _leaderboard = data; _loadingLb = false; });
    } catch (e) {
      setState(() { _loadingLb = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEx) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _loadExercises);
    }
    if (_exercises.isEmpty) {
      return const _EmptyView(
        icon: Icons.emoji_events_outlined,
        title: 'Sin rankings disponibles',
        subtitle: 'Completa entrenamientos para aparecer\nen las tablas de líderes',
      );
    }

    final entries = (_leaderboard?['entries'] as List? ?? [])
        .cast<Map<String, dynamic>>();
    final myPosition = _leaderboard?['myPosition'] as int?;
    final myRecord = _leaderboard?['myRecord'] as Map<String, dynamic>?;

    final top3 = entries.take(3).toList();
    final rest = entries.length > 3 ? entries.sublist(3) : <Map<String, dynamic>>[];

    return CustomScrollView(
      slivers: [
        // ── Controles ──
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector ejercicio
                Text('Ejercicio',
                    style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                _Dropdown(
                  items: _exercises,
                  selected: _selected,
                  onChanged: (ex) {
                    setState(() => _selected = ex);
                    _loadLeaderboard();
                  },
                ),
                SizedBox(height: 12),
                // Selector reps
                Text('Repeticiones',
                    style: TextStyle(color: context.colorTextSecondary, fontSize: 12)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _repOptions.map((r) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _RepChip(
                        reps: r,
                        selected: _reps == r,
                        onTap: () {
                          setState(() => _reps = r);
                          _loadLeaderboard();
                        },
                      ),
                    )).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        if (_loadingLb)
          const SliverFillRemaining(
            child: Center(
                child: CircularProgressIndicator(color: AppColors.accentPrimary)),
          )
        else if (entries.isEmpty)
          const SliverFillRemaining(
            child: _EmptyView(
              icon: Icons.leaderboard_rounded,
              title: 'Sin datos para esta selección',
              subtitle: 'Nadie ha registrado este ejercicio\ncon ese número de reps aún',
            ),
          )
        else ...[
          // ── Mi posición (si no está en el podio) ──
          if (myRecord != null && myPosition == null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _MyRecordBanner(record: myRecord),
              ),
            ),

          // ── Podio top 3 ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _Podium(top3: top3, myPosition: myPosition),
            ),
          ),

          // ── Resto del ranking ──
          if (rest.isNotEmpty) ...[
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text('Clasificación completa',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500)),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _LeaderboardRow(entry: rest[i], isMe: rest[i]['isCurrentUser'] == true),
                  childCount: rest.length,
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ── Podio ─────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  const _Podium({required this.top3, required this.myPosition});
  final List<Map<String, dynamic>> top3;
  final int? myPosition;

  @override
  Widget build(BuildContext context) {
    if (top3.isEmpty) return const SizedBox.shrink();

    // Ordenar para render: 2° | 1° | 3°
    final ordered = <Map<String, dynamic>?>[
      top3.length > 1 ? top3[1] : null,
      top3[0],
      top3.length > 2 ? top3[2] : null,
    ];

    final heights = [80.0, 110.0, 60.0];
    final colors = [
      const Color(0xFFC0C0C0), // plata
      const Color(0xFFFFD700), // oro
      const Color(0xFFCD7F32), // bronce
    ];
    final medals = ['🥈', '🥇', '🥉'];
    final positions = [2, 1, 3];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text('PODIO',
              style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (i) {
              final entry = ordered[i];
              if (entry == null) return const Expanded(child: SizedBox());
              final isMe = entry['isCurrentUser'] == true;
              final unit = context.watch<WeightUnitNotifier>().unit;
              final rawKg = (entry['weightKg'] as num?)?.toDouble();
              final weight = rawKg != null ? formatWeight(rawKg, unit) : '--';
              final name = (entry['userName'] as String? ?? '').split(' ').first;

              return Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(medals[i], style: const TextStyle(fontSize: 24)),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      style: TextStyle(
                        color: isMe ? AppColors.accentPrimary : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      weight,
                      style: TextStyle(
                        color: colors[i],
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      height: heights[i],
                      decoration: BoxDecoration(
                        color: colors[i].withValues(alpha: isMe ? 0.35 : 0.15),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                        border: isMe
                            ? Border.all(color: AppColors.accentPrimary, width: 1.5)
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '${positions[i]}',
                          style: TextStyle(
                              color: colors[i],
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Mi récord (si no está en el ranking visible) ──────────────────────────────

class _MyRecordBanner extends StatelessWidget {
  const _MyRecordBanner({required this.record});
  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<WeightUnitNotifier>().unit;
    final rawKg = (record['weightKg'] as num?)?.toDouble();
    final weight = rawKg != null ? formatWeight(rawKg, unit) : '--';
    final validated = record['isValidated'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_rounded, color: AppColors.accentPrimary, size: 18),
          SizedBox(width: 10),
          Text('Mi récord:', style: TextStyle(color: context.colorTextSecondary, fontSize: 13)),
          SizedBox(width: 8),
          Text(weight,
              style: const TextStyle(
                  color: AppColors.accentPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
          const Spacer(),
          if (!validated)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Pendiente',
                  style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

// ── Fila del ranking ──────────────────────────────────────────────────────────

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.isMe});
  final Map<String, dynamic> entry;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final unit = context.watch<WeightUnitNotifier>().unit;
    final position = entry['position'] as int? ?? 0;
    final name = entry['userName'] as String? ?? '--';
    final rawKg = (entry['weightKg'] as num?)?.toDouble();
    final weight = rawKg != null ? formatWeight(rawKg, unit) : '--';
    final validated = entry['isValidated'] as bool? ?? false;
    final wilks = entry['wilks'] as double?;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? AppColors.accentPrimary.withValues(alpha: 0.08) : AppColors.bgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isMe
              ? AppColors.accentPrimary.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$position',
              style: TextStyle(
                color: isMe ? AppColors.accentPrimary : AppColors.textMuted,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: isMe ? AppColors.accentPrimary : AppColors.textPrimary,
                    fontWeight: isMe ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (wilks != null)
                  Text(
                    'Wilks ${wilks.toStringAsFixed(1)}',
                    style: TextStyle(color: context.colorTextMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            weight,
            style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
          const SizedBox(width: 8),
          Icon(
            validated ? Icons.verified_rounded : Icons.pending_rounded,
            size: 14,
            color: validated ? AppColors.accentGreen : AppColors.textMuted,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 2 — CALCULADORA WILKS
// ═══════════════════════════════════════════════════════════════════════════════

class _WilksTab extends StatefulWidget {
  const _WilksTab();

  @override
  State<_WilksTab> createState() => _WilksTabState();
}

class _WilksTabState extends State<_WilksTab> {
  final _lifted = TextEditingController();
  final _bodyWeight = TextEditingController();
  bool _isMale = true;
  double? _result;

  @override
  void dispose() {
    _lifted.dispose();
    _bodyWeight.dispose();
    super.dispose();
  }

  void _calculate() {
    final l = double.tryParse(_lifted.text);
    final bw = double.tryParse(_bodyWeight.text);
    if (l == null || bw == null || l <= 0 || bw <= 0) {
      setState(() => _result = null);
      return;
    }
    setState(() {
      _result = RankingsService.wilks(lifted: l, bodyWeight: bw, isMale: _isMale);
    });
  }

  String _category(double wilks) {
    if (wilks >= 500) return 'Élite mundial';
    if (wilks >= 400) return 'Élite nacional';
    if (wilks >= 300) return 'Avanzado';
    if (wilks >= 200) return 'Intermedio';
    return 'Principiante';
  }

  Color _categoryColor(double wilks) {
    if (wilks >= 400) return const Color(0xFFFFD700);
    if (wilks >= 300) return AppColors.accentPrimary;
    if (wilks >= 200) return AppColors.accentGreen;
    return AppColors.textSecondary;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Descripción ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.colorBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'El coeficiente Wilks permite comparar el rendimiento entre atletas de diferentes pesos corporales. '
              'Cuanto mayor el número, mejor el rendimiento relativo al peso corporal.',
              style: TextStyle(color: context.colorTextSecondary, fontSize: 13, height: 1.5),
            ),
          ),
          SizedBox(height: 24),

          // ── Sexo ──
          Text('Sexo', style: TextStyle(color: context.colorTextSecondary, fontSize: 13)),
          const SizedBox(height: 8),
          Row(
            children: [
              _GenderChip(
                label: 'Masculino',
                selected: _isMale,
                onTap: () => setState(() { _isMale = true; _result = null; }),
              ),
              const SizedBox(width: 10),
              _GenderChip(
                label: 'Femenino',
                selected: !_isMale,
                onTap: () => setState(() { _isMale = false; _result = null; }),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── Inputs ──
          Row(
            children: [
              Expanded(
                child: _CalcField(
                  controller: _bodyWeight,
                  label: 'Peso corporal (kg)',
                  hint: '75.0',
                  onChanged: (_) => _calculate(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CalcField(
                  controller: _lifted,
                  label: 'Peso levantado (kg)',
                  hint: '120.0',
                  onChanged: (_) => _calculate(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Resultado ──
          if (_result != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.accentPrimary.withValues(alpha: 0.15),
                    AppColors.bgSecondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Text('Coeficiente Wilks',
                      style: TextStyle(color: context.colorTextSecondary, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    _result!.toStringAsFixed(2),
                    style: const TextStyle(
                      color: AppColors.accentPrimary,
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _categoryColor(_result!).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _category(_result!),
                      style: TextStyle(
                        color: _categoryColor(_result!),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24),
            // ── Escala de referencia ──
            Text('Escala de referencia',
                style: TextStyle(color: context.colorTextSecondary, fontSize: 13)),
            const SizedBox(height: 10),
            ...[
              ('< 200', 'Principiante', AppColors.textSecondary),
              ('200 – 299', 'Intermedio', AppColors.accentGreen),
              ('300 – 399', 'Avanzado', AppColors.accentPrimary),
              ('400 – 499', 'Élite nacional', const Color(0xFFC0C0C0)),
              ('500+', 'Élite mundial', const Color(0xFFFFD700)),
            ].map((row) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: row.$3, shape: BoxShape.circle),
                  ),
                  SizedBox(width: 10),
                  Text(row.$1,
                      style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
                      ),
                  const SizedBox(width: 8),
                  Text('→ ${row.$2}',
                      style: TextStyle(color: row.$3, fontSize: 13, fontWeight: FontWeight.w500)),
                ],
              ),
            )),
          ] else
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  Icon(Icons.calculate_rounded, color: AppColors.textMuted, size: 52),
                  SizedBox(height: 12),
                  Text(
                    'Ingresa tu peso corporal y el peso\nlevantado para calcular tu coeficiente',
                    style: TextStyle(color: context.colorTextMuted, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB 3 — VALIDACIÓN ADMIN
// ═══════════════════════════════════════════════════════════════════════════════
// TAB — RÉCORDS (nuevo sistema lift_submissions)
// ═══════════════════════════════════════════════════════════════════════════════

class _RecordsTab extends StatefulWidget {
  const _RecordsTab();
  @override
  State<_RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<_RecordsTab> {
  final _service = LiftSubmissionsService();
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
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
      final list = await _service.records();
      setState(() { _records = list; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_records.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined,
                size: 52, color: context.colorTextMuted),
            const SizedBox(height: 12),
            Text('Aún no hay récords aprobados',
                style: TextStyle(color: context.colorTextSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.accentPrimary,
      backgroundColor: context.colorBgSecondary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _records.length,
        itemBuilder: (_, i) {
          final r = _records[i];
          final weightKg = (r['weightKg'] as num?)?.toDouble() ?? 0;
          final display = toDisplayUnit(weightKg, _unit);
          return InkWell(
            onTap: () => context.push('/rankings/submission/${r['id']}'),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colorBgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.colorBorder),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.accentPrimary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.emoji_events_rounded,
                        color: AppColors.accentPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['exerciseName'] as String? ?? '',
                            style: TextStyle(
                                color: context.colorTextPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14)),
                        Text(r['userName'] as String? ?? '',
                            style: TextStyle(
                                color: context.colorTextMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          '${display.toStringAsFixed(1)} ${_unit.name}',
                          style: const TextStyle(
                              color: AppColors.accentPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 15)),
                      Text('${r['reps']} rep',
                          style: TextStyle(
                              color: context.colorTextMuted, fontSize: 11)),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.chevron_right_rounded,
                      color: context.colorTextMuted, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TAB — REVISAR (admin/professor/staff)
// ═══════════════════════════════════════════════════════════════════════════════

class _ReviewTab extends StatefulWidget {
  const _ReviewTab();
  @override
  State<_ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<_ReviewTab> {
  final _service = LiftSubmissionsService();
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _service.list(status: 'pending');
      setState(() { _pending = list; _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_pending.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded,
                size: 52, color: AppColors.accentGreen),
            const SizedBox(height: 12),
            Text('Sin postulaciones pendientes',
                style: TextStyle(color: context.colorTextSecondary)),
          ],
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.accentPrimary,
      backgroundColor: context.colorBgSecondary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pending.length,
        itemBuilder: (_, i) {
          final r = _pending[i];
          return InkWell(
            onTap: () async {
              await context.push('/rankings/submission/${r['id']}');
              _load(); // recargar al volver
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.colorBgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFB347).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.hourglass_empty_rounded,
                        color: Color(0xFFFFB347), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r['exerciseName'] as String? ?? '',
                            style: TextStyle(
                                color: context.colorTextPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 13)),
                        Text(
                            '${r['userName']}  ·  ${(r['weightKg'] as num?)?.toStringAsFixed(1)} kg × ${r['reps']} rep',
                            style: TextStyle(
                                color: context.colorTextMuted, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded,
                      color: context.colorTextMuted, size: 18),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// (legacy) TAB — VALIDAR personal_records
// ═══════════════════════════════════════════════════════════════════════════════

class _ValidationTab extends StatefulWidget {
  const _ValidationTab();

  @override
  State<_ValidationTab> createState() => _ValidationTabState();
}

class _ValidationTabState extends State<_ValidationTab> {
  final _service = RankingsService();
  List<Map<String, dynamic>> _pending = [];
  bool _loading = true;
  String? _error;
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final list = await _service.getPending();
      setState(() { _pending = list; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _validate(String id) async {
    setState(() => _processing.add(id));
    try {
      await _service.validateRecord(id);
      setState(() {
        _pending.removeWhere((r) => r['id'] == id);
        _processing.remove(id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Récord validado'),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      setState(() => _processing.remove(id));
    }
  }

  Future<void> _reject(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rechazar récord',
            style: TextStyle(color: context.colorTextPrimary)),
        content: Text('¿Estás seguro? El récord será eliminado.',
            style: TextStyle(color: context.colorTextSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancelar',
                style: TextStyle(color: context.colorTextSecondary)),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.accentSecondary),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rechazar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _processing.add(id));
    try {
      await _service.rejectRecord(id);
      setState(() {
        _pending.removeWhere((r) => r['id'] == id);
        _processing.remove(id);
      });
    } catch (e) {
      setState(() => _processing.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _load);
    }
    if (_pending.isEmpty) {
      return const _EmptyView(
        icon: Icons.task_alt_rounded,
        title: 'Sin récords pendientes',
        subtitle: 'Todos los récords han sido revisados',
      );
    }

    return RefreshIndicator(
      color: AppColors.accentPrimary,
      backgroundColor: AppColors.bgSecondary,
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pending.length,
        itemBuilder: (_, i) {
          final r = _pending[i];
          final id = r['id'] as String;
          final isProcessing = _processing.contains(id);

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
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
                        r['exerciseName'] as String? ?? '--',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.textMuted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${r['reps']} rep',
                        style: TextStyle(color: context.colorTextMuted, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  r['userName'] as String? ?? '--',
                  style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
                ),
                if (r['career'] != null)
                  Text(
                    r['career'] as String,
                    style: TextStyle(color: context.colorTextMuted, fontSize: 12),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      r['weightKg'] != null
                          ? '${(r['weightKg'] as num).toStringAsFixed(1)} kg'
                          : '--',
                      style: const TextStyle(
                          color: AppColors.accentPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 18),
                    ),
                    SizedBox(width: 12),
                    Text(
                      r['achievedAt'] as String? ?? '',
                      style: TextStyle(color: context.colorTextMuted, fontSize: 12),
                    ),
                    const Spacer(),
                    if (isProcessing)
                      const SizedBox(
                        width: 24, height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accentPrimary),
                      )
                    else ...[
                      IconButton(
                        onPressed: () => _reject(id),
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.accentSecondary),
                        tooltip: 'Rechazar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 16),
                      IconButton(
                        onPressed: () => _validate(id),
                        icon: const Icon(Icons.check_rounded,
                            color: AppColors.accentGreen),
                        tooltip: 'Validar',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Widgets de utilidad
// ═══════════════════════════════════════════════════════════════════════════════

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.items, required this.selected, required this.onChanged});
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? selected;
  final void Function(Map<String, dynamic>?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButton<Map<String, dynamic>>(
        value: selected,
        isExpanded: true,
        underline: const SizedBox.shrink(),
        dropdownColor: AppColors.bgSecondary,
        style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
        icon: const Icon(Icons.expand_more, color: AppColors.textSecondary),
        items: items.map((ex) => DropdownMenuItem(
          value: ex,
          child: Text(ex['name'] as String? ?? '', overflow: TextOverflow.ellipsis),
        )).toList(),
        onChanged: onChanged,
      ),
    );
  }
}

class _RepChip extends StatelessWidget {
  const _RepChip({required this.reps, required this.selected, required this.onTap});
  final int reps;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? AppColors.accentPrimary : AppColors.bgSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? AppColors.accentPrimary : AppColors.border),
        ),
        child: Text(
          reps == 1 ? '1RM' : '${reps}RM',
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

class _GenderChip extends StatelessWidget {
  const _GenderChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accentPrimary : AppColors.bgSecondary,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? AppColors.accentPrimary : AppColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

class _CalcField extends StatelessWidget {
  const _CalcField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final String hint;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      onChanged: onChanged,
      style: TextStyle(color: context.colorTextPrimary, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: context.colorTextSecondary, fontSize: 13),
        hintStyle: TextStyle(color: context.colorTextMuted),
        filled: true,
        fillColor: AppColors.bgTertiary,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.textMuted, size: 52),
          const SizedBox(height: 16),
          Text(title,
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500)),
          SizedBox(height: 6),
          Text(subtitle,
              style: TextStyle(color: context.colorTextMuted, fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});
  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.accentSecondary, size: 40),
          SizedBox(height: 12),
          Text(error,
              style: TextStyle(color: context.colorTextSecondary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accentPrimary),
            onPressed: onRetry,
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}




