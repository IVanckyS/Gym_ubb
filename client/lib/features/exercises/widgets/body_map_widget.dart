import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../data/body_map_data.dart';
import 'exercise_card.dart';

class BodyMapWidget extends StatefulWidget {
  final List<Map<String, dynamic>> exercises;

  const BodyMapWidget({required this.exercises, super.key});

  @override
  State<BodyMapWidget> createState() => _BodyMapWidgetState();
}

class _BodyMapWidgetState extends State<BodyMapWidget> {
  String _gender = 'male';
  String _view = 'front';
  String _mode = 'muscles'; // 'muscles' | 'joints'
  String? _selectedGroup;
  String? _selectedJointFamily;

  List<MuscleZone> get _currentZones =>
      _view == 'front' ? BodyMapData.zonesFront : BodyMapData.zonesBack;

  List<JointPoint> get _currentJoints =>
      _view == 'front' ? BodyMapData.jointsFront : BodyMapData.jointsBack;

  void _handleMuscleTap(Offset localPos, Size widgetSize) {
    final scaleX = widgetSize.width / 200;
    final scaleY = widgetSize.height / 338;

    for (final zone in _currentZones) {
      final pts = _parsePoints(zone.points, scaleX, scaleY);
      final path = Path()..addPolygon(pts, true);
      if (path.contains(localPos)) {
        setState(() => _selectedGroup = zone.muscleGroup);
        _showMuscleBottomSheet(zone.muscleGroup);
        return;
      }
    }
    setState(() => _selectedGroup = null);
  }

  List<Offset> _parsePoints(String points, double scaleX, double scaleY) {
    return points.split(' ').map((p) {
      final parts = p.split(',');
      return Offset(
        double.parse(parts[0]) * scaleX,
        double.parse(parts[1]) * scaleY,
      );
    }).toList();
  }

  void _showMuscleBottomSheet(String muscleGroup) {
    final groupExercises = widget.exercises.where((e) {
      final mg = BodyMapData.muscleGroupDisplayName[e['muscleGroup'] as String? ?? ''];
      return mg == muscleGroup;
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _MuscleBottomSheet(
        muscleGroup: muscleGroup,
        exercises: groupExercises,
      ),
    );
  }

  void _showJointBottomSheet(String family) {
    final familyExercises = BodyMapData.jointExercises
        .where((e) => e.jointFamily == family)
        .toList();
    final familyName = BodyMapData.jointFamilyNames[family] ?? family;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _JointBottomSheet(
        familyName: familyName,
        exercises: familyExercises,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildControls(),
        const SizedBox(height: 16),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: AspectRatio(
              aspectRatio: 200 / 338,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Background body image
                      Image.asset(
                        'assets/body-map/body-map_${_gender}_$_view.png',
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        fit: BoxFit.fill,
                        errorBuilder: (c, e, s) =>
                            _buildPlaceholder(constraints),
                      ),
                      // Interactive overlay
                      if (_mode == 'muscles')
                        GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTapDown: (d) => _handleMuscleTap(
                            d.localPosition,
                            constraints.biggest,
                          ),
                          child: CustomPaint(
                            size: constraints.biggest,
                            painter: _MusclePainter(
                              zones: _currentZones,
                              selectedGroup: _selectedGroup,
                              viewBox: const Size(200, 338),
                            ),
                          ),
                        )
                      else
                        _buildJointsOverlay(constraints.biggest),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_mode == 'muscles') _buildMuscleLegend(),
        if (_mode == 'joints') _buildJointLegend(),
      ],
    );
  }

  Widget _buildPlaceholder(BoxConstraints constraints) {
    return Container(
      width: constraints.maxWidth,
      height: constraints.maxHeight,
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.accessibility_new, size: 60, color: AppColors.textMuted),
          SizedBox(height: 8),
          Text(
            'Imagen no disponible',
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        _ToggleGroup(
          options: const [('male', '♂ Masculino'), ('female', '♀ Femenino')],
          value: _gender,
          onChanged: (v) => setState(() {
            _gender = v;
            _selectedGroup = null;
            _selectedJointFamily = null;
          }),
        ),
        _ToggleGroup(
          options: const [('front', 'Frontal'), ('back', 'Posterior')],
          value: _view,
          onChanged: (v) => setState(() {
            _view = v;
            _selectedGroup = null;
            _selectedJointFamily = null;
          }),
        ),
        _ToggleGroup(
          options: const [('muscles', '💪 Músculos'), ('joints', '🔴 Articulaciones')],
          value: _mode,
          onChanged: (v) => setState(() {
            _mode = v;
            _selectedGroup = null;
            _selectedJointFamily = null;
          }),
        ),
      ],
    );
  }

  Widget _buildJointsOverlay(Size size) {
    final scaleX = size.width / 200;
    final scaleY = size.height / 338;

    final renderedFamilies = <String>{};
    final widgets = <Widget>[];

    for (final joint in _currentJoints) {
      final isSelected = _selectedJointFamily == joint.family;
      final alreadyRendered = renderedFamilies.contains(joint.family);

      final color = isSelected
          ? AppColors.accentSecondary
          : alreadyRendered
              ? AppColors.accentPrimary.withValues(alpha: 0.6)
              : AppColors.accentPrimary;

      final px = joint.x * scaleX;
      final py = joint.y * scaleY;
      const radius = 7.0;

      widgets.add(
        Positioned(
          left: px - radius,
          top: py - radius,
          child: GestureDetector(
            onTap: () {
              setState(() => _selectedJointFamily = joint.family);
              _showJointBottomSheet(joint.family);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.8),
                  width: 1.5,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.accentSecondary.withValues(alpha: 0.5),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ]
                    : null,
              ),
            ),
          ),
        ),
      );

      renderedFamilies.add(joint.family);
    }

    return Stack(children: widgets);
  }

  Widget _buildMuscleLegend() {
    final groups = BodyMapData.muscleColors.entries.toList();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: groups.map((entry) {
        final isSelected = _selectedGroup == entry.key;
        return GestureDetector(
          onTap: () {
            setState(() =>
                _selectedGroup = isSelected ? null : entry.key);
            if (!isSelected) _showMuscleBottomSheet(entry.key);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? entry.value.withValues(alpha: 0.25)
                  : entry.value.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected
                    ? entry.value
                    : entry.value.withValues(alpha: 0.4),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: entry.value,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  entry.key,
                  style: TextStyle(
                    color: isSelected ? entry.value : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildJointLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: BodyMapData.jointFamilyNames.entries.map((entry) {
        final isSelected = _selectedJointFamily == entry.key;
        return GestureDetector(
          onTap: () {
            setState(() => _selectedJointFamily =
                isSelected ? null : entry.key);
            if (!isSelected) _showJointBottomSheet(entry.key);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentPrimary.withValues(alpha: 0.2)
                  : AppColors.bgTertiary,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppColors.accentPrimary : AppColors.border,
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.accentPrimary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  entry.value,
                  style: TextStyle(
                    color: isSelected
                        ? AppColors.accentPrimary
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ── CustomPainter for muscle zones ───────────────────────────────────────────

class _MusclePainter extends CustomPainter {
  final List<MuscleZone> zones;
  final String? selectedGroup;
  final Size viewBox;

  const _MusclePainter({
    required this.zones,
    required this.selectedGroup,
    required this.viewBox,
  });

  List<Offset> _parsePoints(String points, double scaleX, double scaleY) {
    return points.split(' ').map((p) {
      final parts = p.split(',');
      return Offset(
        double.parse(parts[0]) * scaleX,
        double.parse(parts[1]) * scaleY,
      );
    }).toList();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / viewBox.width;
    final scaleY = size.height / viewBox.height;

    for (final zone in zones) {
      final color = BodyMapData.muscleColors[zone.muscleGroup] ??
          AppColors.accentPrimary;
      final isSelected = selectedGroup == zone.muscleGroup;

      final pts = _parsePoints(zone.points, scaleX, scaleY);
      final path = Path()..addPolygon(pts, true);

      // Fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 0.55 : 0.25)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Stroke
      final strokePaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 0.9 : 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.5 : 0.8;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_MusclePainter old) =>
      old.selectedGroup != selectedGroup || old.zones != zones;
}

// ── Toggle group helper widget ────────────────────────────────────────────────

class _ToggleGroup extends StatelessWidget {
  final List<(String, String)> options;
  final String value;
  final ValueChanged<String> onChanged;

  const _ToggleGroup({
    required this.options,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final (key, label) = opt;
          final isActive = value == key;
          return GestureDetector(
            onTap: () => onChanged(key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isActive ? AppColors.accentPrimary : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Bottom sheet: muscle exercises ───────────────────────────────────────────

class _MuscleBottomSheet extends StatefulWidget {
  final String muscleGroup;
  final List<Map<String, dynamic>> exercises;

  const _MuscleBottomSheet({
    required this.muscleGroup,
    required this.exercises,
  });

  @override
  State<_MuscleBottomSheet> createState() => _MuscleBottomSheetState();
}

class _MuscleBottomSheetState extends State<_MuscleBottomSheet> {
  String _diffFilter = 'Todos';

  @override
  Widget build(BuildContext context) {
    final color = BodyMapData.muscleColors[widget.muscleGroup] ??
        AppColors.accentPrimary;
    final emoji =
        BodyMapData.muscleEmoji[widget.muscleGroup] ?? '💪';

    final filtered = _diffFilter == 'Todos'
        ? widget.exercises
        : widget.exercises
            .where((e) => e['difficulty'] == _diffFilter.toLowerCase())
            .toList();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.35,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              // Handle
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.muscleGroup,
                          style: TextStyle(
                            color: color,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${widget.exercises.length} ejercicios',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Difficulty filter
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: ['Todos', 'Principiante', 'Intermedio', 'Avanzado']
                      .map((d) {
                    final isActive = _diffFilter == d;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _diffFilter = d),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color.withValues(alpha: 0.2)
                                : AppColors.bgTertiary,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive
                                  ? color
                                  : AppColors.border,
                            ),
                          ),
                          child: Text(
                            d,
                            style: TextStyle(
                              color: isActive
                                  ? color
                                  : AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              // Exercise list
              Expanded(
                child: filtered.isEmpty
                    ? const Center(
                        child: Text(
                          'No hay ejercicios para este filtro',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        separatorBuilder: (context2, i2) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => ExerciseCard(
                          exercise: filtered[i],
                          compact: true,
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.of(context).pushNamed(
                              '/exercises/${filtered[i]['id']}',
                            );
                          },
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Bottom sheet: joint exercises ─────────────────────────────────────────────

class _JointBottomSheet extends StatelessWidget {
  final String familyName;
  final List<JointExercise> exercises;

  const _JointBottomSheet({
    required this.familyName,
    required this.exercises,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.bgSecondary,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.accentPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      familyName,
                      style: const TextStyle(
                        color: AppColors.accentPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${exercises.length} ejercicios',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: exercises.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin ejercicios registrados',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: exercises.length,
                        separatorBuilder: (context2, i2) =>
                            const SizedBox(height: 12),
                        itemBuilder: (_, i) =>
                            _JointExerciseCard(exercise: exercises[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _JointExerciseCard extends StatelessWidget {
  final JointExercise exercise;

  const _JointExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final isMovilidad = exercise.type == 'movilidad';
    final typeColor = isMovilidad
        ? const Color(0xFF4ECDC4)
        : AppColors.accentPrimary;
    final typeLabel = isMovilidad ? 'Movilidad' : 'Fortalecimiento';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgTertiary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: typeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            exercise.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ...exercise.instructions.asMap().entries.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 8, top: 1),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${entry.key + 1}',
                          style: const TextStyle(
                            color: AppColors.accentPrimary,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              )),
          if (exercise.benefits != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF4ECDC4).withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 14,
                    color: Color(0xFF4ECDC4),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      exercise.benefits!,
                      style: const TextStyle(
                        color: Color(0xFF4ECDC4),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (exercise.whenToUse != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.accentPrimary.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 14,
                    color: AppColors.accentPrimary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      exercise.whenToUse!,
                      style: const TextStyle(
                        color: AppColors.accentPrimary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
