import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/exercises_service.dart';
import '../data/hiit_models.dart';

class HiitConfigScreen extends StatefulWidget {
  final HiitMode mode;
  final HiitExerciseRef? initialExercise;

  const HiitConfigScreen({
    required this.mode,
    this.initialExercise,
    super.key,
  });

  @override
  State<HiitConfigScreen> createState() => _HiitConfigScreenState();
}

class _HiitConfigScreenState extends State<HiitConfigScreen> {
  late HiitConfig _config;

  @override
  void initState() {
    super.initState();
    _config = HiitConfig.defaultFor(widget.mode);
    if (widget.initialExercise != null) {
      _config = _config.copyWith(exercises: [widget.initialExercise!]);
    }
  }

  void _start() {
    if (_config.exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un ejercicio')),
      );
      return;
    }
    context.go('/hiit/session', extra: _config);
  }

  Future<void> _addExercise() async {
    final exercise = await showModalBottomSheet<HiitExerciseRef>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.colorBgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => const _ExercisePickerSheet(),
    );

    if (exercise != null && mounted) {
      setState(() {
        _config = _config.copyWith(
          exercises: [..._config.exercises, exercise],
        );
      });
    }
  }

  void _removeExercise(int index) {
    setState(() {
      final list = List<HiitExerciseRef>.from(_config.exercises)
        ..removeAt(index);
      _config = _config.copyWith(exercises: list);
    });
  }

  Widget _buildSlider({
    required String label,
    required int value,
    required int min,
    required int max,
    required String unit,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            Text(
              '$value $unit',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: max - min,
          activeColor: AppColors.accentPrimary,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        backgroundColor: context.colorBgPrimary,
        title: Text(mode.label),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Mode-specific sliders ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Configuración',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                if (mode == HiitMode.tabata ||
                    mode == HiitMode.emom ||
                    mode == HiitMode.mix)
                  _buildSlider(
                    label: 'Tiempo de trabajo',
                    value: _config.workSeconds,
                    min: 5,
                    max: 120,
                    unit: 's',
                    onChanged: (v) =>
                        setState(() => _config = _config.copyWith(workSeconds: v)),
                  ),
                if (mode == HiitMode.tabata || mode == HiitMode.mix)
                  _buildSlider(
                    label: 'Descanso entre ejercicios',
                    value: _config.restSeconds,
                    min: 0,
                    max: 120,
                    unit: 's',
                    onChanged: (v) =>
                        setState(() => _config = _config.copyWith(restSeconds: v)),
                  ),
                if (mode == HiitMode.tabata ||
                    mode == HiitMode.forTime ||
                    mode == HiitMode.mix)
                  _buildSlider(
                    label: 'Rondas',
                    value: _config.rounds,
                    min: 1,
                    max: 20,
                    unit: '',
                    onChanged: (v) =>
                        setState(() => _config = _config.copyWith(rounds: v)),
                  ),
                if (mode == HiitMode.amrap || mode == HiitMode.emom)
                  _buildSlider(
                    label: 'Tiempo total',
                    value: _config.totalSeconds ~/ 60,
                    min: 1,
                    max: 60,
                    unit: 'min',
                    onChanged: (v) => setState(
                        () => _config = _config.copyWith(totalSeconds: v * 60)),
                  ),
                if (mode == HiitMode.forTime || mode == HiitMode.mix)
                  _buildSlider(
                    label: 'Descanso entre rondas',
                    value: _config.restBetweenRounds,
                    min: 0,
                    max: 180,
                    unit: 's',
                    onChanged: (v) => setState(
                        () => _config = _config.copyWith(restBetweenRounds: v)),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Exercise list ─────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.colorBgSecondary,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.colorBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Ejercicios',
                        style: Theme.of(context).textTheme.titleSmall),
                    TextButton.icon(
                      onPressed: _addExercise,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Agregar'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.accentPrimary),
                    ),
                  ],
                ),
                if (_config.exercises.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      'Sin ejercicios. Agrega al menos uno.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: context.colorTextMuted,
                          ),
                    ),
                  ),
                ..._config.exercises.asMap().entries.map((entry) {
                  final i = entry.key;
                  final ex = entry.value;
                  final hasImage =
                      ex.imageUrl != null && ex.imageUrl!.isNotEmpty;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: hasImage
                          ? CachedNetworkImage(
                              imageUrl: ex.imageUrl!,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              placeholder: (ctx2, p) =>
                                  _ExerciseAvatar(index: i + 1),
                              errorWidget: (ctx2, e2, st) =>
                                  _ExerciseAvatar(index: i + 1),
                            )
                          : _ExerciseAvatar(index: i + 1),
                    ),
                    title: Text(ex.name),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: AppColors.accentSecondary),
                      onPressed: () => _removeExercise(i),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _start,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Iniciar'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentPrimary,
              minimumSize: const Size.fromHeight(52),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Avatar numérico para ejercicio sin imagen ─────────────────────────────────

class _ExerciseAvatar extends StatelessWidget {
  final int index;
  const _ExerciseAvatar({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColors.accentPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '$index',
          style: const TextStyle(
            color: AppColors.accentPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── Bottom sheet picker de ejercicios del catálogo ────────────────────────────

class _ExercisePickerSheet extends StatefulWidget {
  const _ExercisePickerSheet();

  @override
  State<_ExercisePickerSheet> createState() => _ExercisePickerSheetState();
}

class _ExercisePickerSheetState extends State<_ExercisePickerSheet> {
  final _service = ExercisesService();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _allExercises = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final exercises = await _service.listExercises();
      if (mounted) {
        setState(() {
          _allExercises = exercises;
          _filtered = exercises;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _allExercises
          : _allExercises
              .where((e) =>
                  (e['name'] as String? ?? '').toLowerCase().contains(q))
              .toList();
    });
  }

  void _pick(Map<String, dynamic> exercise) {
    final rawUrl = exercise['imageUrl'] as String?;
    final imageUrl = rawUrl == null || rawUrl.isEmpty
        ? null
        : rawUrl.startsWith('http')
            ? rawUrl
            : '${ApiConstants.baseUrl}$rawUrl';

    Navigator.pop(
      context,
      HiitExerciseRef(
        name: exercise['name'] as String? ?? '',
        exerciseId: exercise['id'] as String?,
        imageUrl: imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: context.colorBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header + buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agregar ejercicio',
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Buscar ejercicio...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    filled: true,
                    fillColor: context.colorBgTertiary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
          // Lista de ejercicios
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          'Sin resultados',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final ex = _filtered[i];
                          final name = ex['name'] as String? ?? '';
                          final rawUrl = ex['imageUrl'] as String?;
                          final imgUrl = rawUrl == null || rawUrl.isEmpty
                              ? null
                              : rawUrl.startsWith('http')
                                  ? rawUrl
                                  : '${ApiConstants.baseUrl}$rawUrl';
                          final muscleGroup = ex['muscleGroup'] as String?;

                          return ListTile(
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: imgUrl != null
                                  ? CachedNetworkImage(
                                      imageUrl: imgUrl,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      placeholder: (ctx2, p) =>
                                          _PlaceholderBox(),
                                      errorWidget: (ctx2, e2, st) =>
                                          _PlaceholderBox(),
                                    )
                                  : _PlaceholderBox(),
                            ),
                            title: Text(name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: muscleGroup != null
                                ? Text(
                                    muscleGroup,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: context.colorTextSecondary),
                                  )
                                : null,
                            trailing: const Icon(Icons.add_circle_outline,
                                color: AppColors.accentPrimary),
                            onTap: () => _pick(ex),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _PlaceholderBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      color: context.colorBgTertiary,
      child: const Icon(Icons.fitness_center_rounded,
          color: AppColors.textMuted, size: 22),
    );
  }
}
