import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exercise = await _service.getExercise(widget.id);
      final allExercises = await _service.listExercises(
        muscleGroup: exercise['muscleGroup'] as String? ?? '',
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
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
    final variations = (e['variations'] as List?)?.cast<String>() ?? [];

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
          backgroundColor: AppColors.bgSecondary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    muscleColor.withValues(alpha: 0.6),
                    AppColors.bgSecondary,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 50, 20, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
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
                    color: AppColors.bgSecondary,
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
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            margin: const EdgeInsets.only(right: 12, top: 1),
                            decoration: BoxDecoration(
                              color: muscleColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: muscleColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${entry.key + 1}',
                                style: TextStyle(
                                  color: muscleColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                entry.value,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                          ),
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

                // ── Variations ────────────────────────────────────────────
                if (variations.isNotEmpty) ...[
                  _SectionTitle(title: 'Variaciones'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: variations.map((v) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(right: 10),
                                  decoration: BoxDecoration(
                                    color: muscleColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    v,
                                    style: Theme.of(context).textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          )).toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Video ─────────────────────────────────────────────────
                if (videoUrl != null && videoUrl.isNotEmpty) ...[
                  _SectionTitle(title: 'Video tutorial'),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgSecondary,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppColors.accentSecondary.withValues(
                              alpha: 0.15,
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_circle_outline,
                            color: AppColors.accentSecondary,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Ver en YouTube',
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('URL: $videoUrl'),
                                      backgroundColor: AppColors.bgTertiary,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Text(
                                  videoUrl,
                                  style: const TextStyle(
                                    color: AppColors.accentPrimary,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.accentPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
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
