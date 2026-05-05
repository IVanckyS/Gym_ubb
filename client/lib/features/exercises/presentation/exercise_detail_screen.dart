import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../hiit/data/hiit_models.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/exercises_service.dart';
import '../data/body_map_data.dart';
import '../widgets/exercise_card.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final String id;

  const ExerciseDetailScreen({required this.id, super.key});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  final ExercisesService _service = ExercisesService();

  Map<String, dynamic>? _exercise;
  List<Map<String, dynamic>> _related = [];
  bool _loading = true;
  String? _error;
  WebViewController? _videoController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _load();
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  static String? _extractVideoId(String url) {
    final patterns = [
      RegExp(r'[?&]v=([a-zA-Z0-9_-]{11})'),
      RegExp(r'embed/([a-zA-Z0-9_-]{11})'),
      RegExp(r'youtu\.be/([a-zA-Z0-9_-]{11})'),
      RegExp(r'shorts/([a-zA-Z0-9_-]{11})'),
    ];
    for (final re in patterns) {
      final m = re.firstMatch(url);
      if (m != null) return m.group(1);
    }
    return null;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exercise = await _service.getExercise(widget.id);
      final group = exercise['muscleGroup'] as String? ?? '';
      final allExercises = await _service.listExercises(
        muscleGroups: group.isNotEmpty ? {group} : {},
      );
      // Inicializar WebView si hay videoUrl válida
      final videoUrl = exercise['videoUrl'] as String?;
      if (!kIsWeb && videoUrl != null && videoUrl.isNotEmpty) {
        final videoId = _extractVideoId(videoUrl);
        if (videoId != null) {
          _videoController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(Colors.black)
            ..loadRequest(Uri.parse(
                'https://www.youtube.com/embed/$videoId?rel=0&playsinline=1'));
        }
      }
      setState(() {
        _exercise = exercise;
        _related = allExercises
            .where((e) => e['id'] != widget.id)
            .take(6)
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showStepImage(BuildContext context, int step, String imgUrl) {
    final fullUrl = imgUrl.startsWith('http')
        ? imgUrl
        : '${ApiConstants.baseUrl}$imgUrl';
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Paso $step',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                fullUrl,
                fit: BoxFit.contain,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : SizedBox(
                        height: 160,
                        child: Center(
                            child: CircularProgressIndicator(
                                color: AppColors.accentPrimary))),
                errorBuilder: (_, __, e2) => Container(
                  height: 120,
                  decoration: BoxDecoration(
                      color: context.colorBgSecondary,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Center(
                    child: Icon(Icons.broken_image_outlined,
                        color: AppColors.textMuted, size: 40),
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentPrimary),
            )
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppColors.accentSecondary,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('Volver'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final e = _exercise!;
    final name = e['name'] as String? ?? '';
    final muscleGroup = e['muscleGroup'] as String?;
    final difficulty = e['difficulty'] as String?;
    final description = e['description'] as String?;
    final equipment = e['equipment'] as String?;
    final safetyNotes = e['safetyNotes'] as String?;
    final videoUrl = e['videoUrl'] as String?;
    final defaultSets = e['defaultSets'] as int? ?? 3;
    final defaultReps = e['defaultReps'] as String? ?? '8-12';
    final defaultRestSeconds = e['defaultRestSeconds'] as int? ?? 90;
    final muscles = (e['muscles'] as List?)?.cast<String>() ?? [];
    final instructions = (e['instructions'] as List?)?.cast<String>() ?? [];


    final imageUrl = e['imageUrl'] as String?;
    final stepImages = (e['stepImages'] as List?)?.cast<String>() ?? [];

    final exerciseType = e['exerciseType'] as String? ?? 'dinamico';
    final isIsometric = exerciseType == 'isometrico';
    final isCalistenia = exerciseType == 'calistenia';
    final displayGroup =
        BodyMapData.muscleGroupDisplayName[muscleGroup] ?? muscleGroup ?? '';
    final muscleColor =
        BodyMapData.muscleColors[displayGroup] ?? AppColors.accentPrimary;
    final emoji = BodyMapData.muscleEmoji[displayGroup] ?? '💪';
    final difficultyColor = _difficultyColor(difficulty);
    final difficultyLabel = _difficultyLabel(difficulty);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: CustomScrollView(
      slivers: [
        // ── Hero header ──────────────────────────────────────────────────────
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          actions: [
            if (['admin', 'professor'].contains(
                context.read<AuthProvider>().user?['role'] as String?))
              IconButton(
                icon: const Icon(Icons.edit_outlined, color: Colors.white70),
                tooltip: 'Editar ejercicio',
                onPressed: () async {
                  final updated = await showDialog<bool>(
                    context: context,
                    builder: (_) => _EditExerciseDialog(
                      exercise: _exercise!,
                      service: _service,
                    ),
                  );
                  if (updated == true && mounted) _load();
                },
              ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Image.network(
                    '${ApiConstants.baseUrl}$imageUrl',
                    fit: BoxFit.cover,
                    errorBuilder: (_, e2, st) => const SizedBox.shrink(),
                  ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: imageUrl != null && imageUrl.isNotEmpty
                          ? [Colors.black54, Colors.black87]
                          : [
                              muscleColor.withValues(alpha: 0.6),
                              AppColors.bgSecondary,
                            ],
                    ),
                  ),
                ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (imageUrl == null || imageUrl.isEmpty)
                          Text(emoji, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _Badge(label: displayGroup, color: muscleColor),
                          const SizedBox(width: 8),
                          _Badge(
                            label: difficultyLabel,
                            color: difficultyColor,
                          ),
                          if (isIsometric) ...[
                            const SizedBox(width: 8),
                            const _Badge(
                              label: 'Isométrico',
                              color: Color(0xFF818cf8),
                            ),
                          ],
                          if (isCalistenia) ...[
                            const SizedBox(width: 8),
                            const _Badge(
                              label: 'Calistenia',
                              color: Color(0xFF4ECDC4),
                            ),
                          ],
                          if (equipment != null && equipment.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            _Badge(
                              label: equipment,
                              color: AppColors.textSecondary,
                              small: true,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Key params card ────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: context.colorBgSecondary,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _ParamChip(
                        icon: Icons.repeat,
                        label: 'Series',
                        value: '$defaultSets',
                        color: AppColors.accentPrimary,
                      ),
                      _divider(),
                      _ParamChip(
                        icon: Icons.tag,
                        label: 'Reps',
                        value: defaultReps,
                        color: muscleColor,
                      ),
                      _divider(),
                      _ParamChip(
                        icon: Icons.timer_outlined,
                        label: 'Descanso',
                        value: '${defaultRestSeconds}s',
                        color: difficultyColor,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Description ───────────────────────────────────────────
                if (description != null && description.isNotEmpty) ...[
                  _SectionTitle(title: 'Descripción'),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Muscles ───────────────────────────────────────────────
                if (muscles.isNotEmpty) ...[
                  _SectionTitle(title: 'Músculos trabajados'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: muscles.map((m) => _MusclePill(
                          muscle: m,
                          color: muscleColor,
                        )).toList(),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Instructions ──────────────────────────────────────────
                if (instructions.isNotEmpty) ...[
                  _SectionTitle(title: 'Cómo hacerlo'),
                  const SizedBox(height: 12),
                  ...instructions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final imgUrl = idx < stepImages.length ? stepImages[idx] : '';
                    final hasImg = imgUrl.isNotEmpty;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Número
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              color: muscleColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                  color: muscleColor.withValues(alpha: 0.4)),
                            ),
                            child: Center(
                              child: Text(
                                '${idx + 1}',
                                style: TextStyle(
                                  color: muscleColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          // Texto
                          Expanded(
                            child: Text(
                              entry.value,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          // Thumbnail (solo si tiene imagen)
                          if (hasImg) ...[
                            SizedBox(width: 10),
                            GestureDetector(
                              onTap: () =>
                                  _showStepImage(context, idx + 1, imgUrl),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  imgUrl.startsWith('http')
                                      ? imgUrl
                                      : '${ApiConstants.baseUrl}$imgUrl',
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, e2, st) => Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: context.colorBgTertiary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.broken_image_outlined,
                                        color: AppColors.textMuted, size: 20),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                ],

                // ── Safety notes ──────────────────────────────────────────
                if (safetyNotes != null && safetyNotes.isNotEmpty) ...[
                  _SectionTitle(title: 'Recomendaciones de seguridad'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB347).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFFFB347).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFFFB347),
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            safetyNotes,
                            style: const TextStyle(
                              color: Color(0xFFFFB347),
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Video ─────────────────────────────────────────────────
                if (videoUrl != null && videoUrl.isNotEmpty) ...[
                  _SectionTitle(title: 'Video tutorial'),
                  const SizedBox(height: 10),
                  if (kIsWeb)
                    // En web: botón para abrir en YouTube
                    OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(videoUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri,
                              mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.play_circle_outline, size: 20),
                      label: const Text('Ver video en YouTube'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accentPrimary,
                        side: const BorderSide(color: AppColors.accentPrimary),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    )
                  else if (_videoController != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 210,
                        child: WebViewWidget(controller: _videoController!),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: context.colorBgSecondary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: AppColors.textMuted, size: 18),
                          SizedBox(width: 8),
                          Text('URL de video no válida',
                              style: TextStyle(
                                  color: AppColors.textMuted, fontSize: 13)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],

                // ── Related exercises ─────────────────────────────────────
                if (_related.isNotEmpty) ...[
                  _SectionTitle(title: 'Más ejercicios de $displayGroup'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 170,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _related.length,
                      separatorBuilder: (context2, i2) =>
                          const SizedBox(width: 12),
                      itemBuilder: (context2, i) => SizedBox(
                        width: 160,
                        child: ExerciseCard(
                          exercise: _related[i],
                          onTap: () => context
                              .push('/exercises/${_related[i]['id']}'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ── Agregar a HIIT ────────────────────────────────────────
                FilledButton.icon(
                  onPressed: () {
                    final rawUrl = e['imageUrl'] as String?;
                    final fullUrl = rawUrl == null || rawUrl.isEmpty
                        ? null
                        : rawUrl.startsWith('http')
                            ? rawUrl
                            : '${ApiConstants.baseUrl}$rawUrl';
                    context.go('/hiit/config', extra: {
                      'mode': HiitMode.tabata,
                      'exercise': {
                        'id': e['id'],
                        'name': e['name'],
                        'imageUrl': fullUrl,
                      },
                    });
                  },
                  icon: const Icon(Icons.timer_outlined),
                  label: const Text('Agregar a HIIT'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    minimumSize: const Size.fromHeight(52),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
        ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 36,
        color: AppColors.border,
      );

  static Color _difficultyColor(String? d) {
    switch (d) {
      case 'principiante':
        return const Color(0xFF4ECDC4);
      case 'intermedio':
        return const Color(0xFFFFB347);
      case 'avanzado':
        return const Color(0xFFFF6B6B);
      default:
        return AppColors.textMuted;
    }
  }

  static String _difficultyLabel(String? d) {
    switch (d) {
      case 'principiante':
        return 'Principiante';
      case 'intermedio':
        return 'Intermedio';
      case 'avanzado':
        return 'Avanzado';
      default:
        return d ?? '';
    }
  }
}

// ── Local widgets ─────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final bool small;

  const _Badge({required this.label, required this.color, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ParamChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ParamChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ── Edit Exercise Dialog ──────────────────────────────────────────────────────

class _EditExerciseDialog extends StatefulWidget {
  const _EditExerciseDialog({required this.exercise, required this.service});
  final Map<String, dynamic> exercise;
  final ExercisesService service;

  @override
  State<_EditExerciseDialog> createState() => _EditExerciseDialogState();
}

class _EditExerciseDialogState extends State<_EditExerciseDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _equipmentCtrl;
  late final TextEditingController _videoUrlCtrl;
  late final TextEditingController _safetyCtrl;
  late final TextEditingController _repsCtrl;
  late final TextEditingController _durationCtrl;

  late String _muscleGroup;
  late String _difficulty;
  late int _defaultSets;
  late bool _isIsometric;
  late bool _isCalistenia;
  late bool _isRankeable;

  bool _saving = false;
  String? _error;

  static const _muscleOptions = [
    ('pecho', 'Pecho'), ('espalda', 'Espalda'), ('piernas', 'Piernas'),
    ('hombros', 'Hombros'), ('brazos', 'Brazos'), ('core', 'Core'), ('gluteos', 'Glúteos'),
  ];
  static const _difficultyOptions = [
    ('principiante', 'Principiante'), ('intermedio', 'Intermedio'), ('avanzado', 'Avanzado'),
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.exercise;
    final exType = e['exerciseType'] as String? ?? 'dinamico';
    _isIsometric = exType == 'isometrico';
    _isCalistenia = exType == 'calistenia';
    _isRankeable = e['isRankeable'] as bool? ?? false;
    _muscleGroup = e['muscleGroup'] as String? ?? 'pecho';
    _difficulty = e['difficulty'] as String? ?? 'principiante';
    _defaultSets = e['defaultSets'] as int? ?? 3;

    _nameCtrl = TextEditingController(text: e['name'] as String? ?? '');
    _descCtrl = TextEditingController(text: e['description'] as String? ?? '');
    _equipmentCtrl = TextEditingController(text: e['equipment'] as String? ?? '');
    _videoUrlCtrl = TextEditingController(text: e['videoUrl'] as String? ?? '');
    _safetyCtrl = TextEditingController(text: e['safetyNotes'] as String? ?? '');
    _repsCtrl = TextEditingController(text: e['defaultReps'] as String? ?? '8-12');
    final durSec = e['defaultDurationSeconds'] as int? ?? 30;
    _durationCtrl = TextEditingController(text: '$durSec');
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _equipmentCtrl.dispose();
    _videoUrlCtrl.dispose(); _safetyCtrl.dispose();
    _repsCtrl.dispose(); _durationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'muscleGroup': _muscleGroup,
        'difficulty': _difficulty,
        'equipment': _equipmentCtrl.text.trim(),
        'defaultSets': _defaultSets,
        'videoUrl': _videoUrlCtrl.text.trim(),
        'safetyNotes': _safetyCtrl.text.trim(),
        'exerciseType': _isIsometric
            ? 'isometrico'
            : (_isCalistenia ? 'calistenia' : 'dinamico'),
        'isRankeable': _isRankeable,
      };
      if (_isIsometric) {
        body['defaultDurationSeconds'] = int.tryParse(_durationCtrl.text) ?? 30;
      } else {
        body['defaultReps'] = _repsCtrl.text.trim();
      }
      await widget.service.updateExercise(widget.exercise['id'] as String, body);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: context.colorBgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Editar ejercicio',
                        style: TextStyle(
                            color: context.colorTextPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w700)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nombre
                      _label('Nombre *'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _nameCtrl,
                        style: TextStyle(color: context.colorTextPrimary),
                        decoration: _deco('Ej. Press de banca'),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 12),
                      // Grupo muscular + Dificultad
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Grupo muscular'),
                                const SizedBox(height: 6),
                                _dropdown<String>(
                                  value: _muscleGroup,
                                  items: _muscleOptions
                                      .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _muscleGroup = v!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Dificultad'),
                                const SizedBox(height: 6),
                                _dropdown<String>(
                                  value: _difficulty,
                                  items: _difficultyOptions
                                      .map((d) => DropdownMenuItem(value: d.$1, child: Text(d.$2)))
                                      .toList(),
                                  onChanged: (v) => setState(() => _difficulty = v!),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Equipo
                      _label('Equipo'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _equipmentCtrl,
                        style: TextStyle(color: context.colorTextPrimary),
                        decoration: _deco('Ej. Barra + Banco'),
                      ),
                      const SizedBox(height: 12),
                      // Series + Reps/Duración
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Series'),
                                const SizedBox(height: 6),
                                _dropdown<int>(
                                  value: _defaultSets,
                                  items: [2, 3, 4, 5]
                                      .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                                      .toList(),
                                  onChanged: (v) => setState(() => _defaultSets = v!),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label(_isIsometric ? 'Duración (seg)' : 'Reps'),
                                const SizedBox(height: 6),
                                if (_isIsometric)
                                  TextFormField(
                                    controller: _durationCtrl,
                                    style: TextStyle(color: context.colorTextPrimary),
                                    decoration: _deco('Ej. 30'),
                                    keyboardType: TextInputType.number,
                                  )
                                else
                                  TextFormField(
                                    controller: _repsCtrl,
                                    style: TextStyle(color: context.colorTextPrimary),
                                    decoration: _deco('Ej. 8-12'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Descripción
                      _label('Descripción'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _descCtrl,
                        style: TextStyle(color: context.colorTextPrimary),
                        decoration: _deco('Descripción general del ejercicio...'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 12),
                      // Video URL
                      _label('URL Video (YouTube)'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _videoUrlCtrl,
                        style: TextStyle(color: context.colorTextPrimary),
                        decoration: _deco('https://youtube.com/watch?v=...'),
                      ),
                      const SizedBox(height: 12),
                      // Notas de seguridad
                      _label('Notas de seguridad'),
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _safetyCtrl,
                        style: TextStyle(color: context.colorTextPrimary),
                        decoration: _deco('Precauciones, errores comunes...'),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      // Toggle isométrico
                      _buildToggle(
                        value: _isIsometric,
                        onChanged: (v) => setState(() {
                          _isIsometric = v;
                          if (v) _isCalistenia = false;
                        }),
                        color: const Color(0xFF818cf8),
                        icon: Icons.timer_outlined,
                        title: 'Ejercicio isométrico',
                        subtitle: 'Se mide por tiempo (segundos), no por kg y repeticiones',
                      ),
                      const SizedBox(height: 12),
                      // Toggle calistenia
                      _buildToggle(
                        value: _isCalistenia,
                        onChanged: (v) => setState(() {
                          _isCalistenia = v;
                          if (v) _isIsometric = false;
                        }),
                        color: const Color(0xFF4ECDC4),
                        icon: Icons.accessibility_new_rounded,
                        title: 'Ejercicio de peso corporal',
                        subtitle: 'Calistenia: el volumen incluye el peso corporal + lastre opcional',
                      ),
                      const SizedBox(height: 12),
                      // Toggle rankeable
                      _buildToggle(
                        value: _isRankeable,
                        onChanged: (v) => setState(() => _isRankeable = v),
                        color: AppColors.accentPrimary,
                        icon: Icons.emoji_events_rounded,
                        title: 'Permitir en rankings',
                        subtitle: 'Los usuarios podrán postular levantamientos de este ejercicio',
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!,
                            style: const TextStyle(
                                color: AppColors.accentSecondary, fontSize: 12)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Guardar cambios',
                                style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggle({
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: value ? color.withValues(alpha: 0.08) : context.colorBgTertiary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: value ? color.withValues(alpha: 0.3) : context.colorBorder),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(title,
                style: TextStyle(
                    color: context.colorTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        subtitle: Text(subtitle,
            style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(
          color: context.colorTextSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600));

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colorTextMuted),
        filled: true,
        fillColor: context.colorBgTertiary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      );

  Widget _dropdown<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: context.colorBgTertiary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: context.colorBgSecondary,
          style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _MusclePill extends StatelessWidget {
  final String muscle;
  final Color color;

  const _MusclePill({required this.muscle, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        muscle,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}



