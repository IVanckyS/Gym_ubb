import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/joint_exercises_service.dart';
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
  String? _hoveredGroup;
  String? _selectedJointFamily;
  final JointExercisesService _jointService = JointExercisesService();

  List<MuscleZone> get _currentZones =>
      _view == 'front' ? BodyMapData.zonesFront : BodyMapData.zonesBack;

  List<JointPoint> get _currentJoints =>
      _view == 'front' ? BodyMapData.jointsFront : BodyMapData.jointsBack;

  void _handleMuscleTap(Offset localPos, Size widgetSize) {
    final scaleX = widgetSize.width / 658;
    final scaleY = widgetSize.height / 1024;

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

  String? _groupAtPosition(Offset localPos, Size widgetSize) {
    final scaleX = widgetSize.width / 658;
    final scaleY = widgetSize.height / 1024;
    for (final zone in _currentZones) {
      final pts = _parsePoints(zone.points, scaleX, scaleY);
      final path = Path()..addPolygon(pts, true);
      if (path.contains(localPos)) return zone.muscleGroup;
    }
    return null;
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
    final familyName = BodyMapData.jointFamilyNames[family] ?? family;
    final role = context.read<AuthProvider>().user?['role'] as String? ?? '';
    final canCreate = role == 'admin' || role == 'professor';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _JointBottomSheet(
        family: family,
        familyName: familyName,
        service: _jointService,
        canCreate: canCreate,
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
              aspectRatio: 658 / 1024,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Background body image
                      SvgPicture.asset(
                        _gender == 'male'
                            ? (_view == 'front'
                                ? 'assets/body-map/FRONT_MELE.svg'
                                : 'assets/body-map/BACK_MELE.svg')
                            : (_view == 'front'
                                ? 'assets/body-map/FRONT_WOMAN.svg'
                                : 'assets/body-map/BACK_WOMAN.svg'),
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        fit: BoxFit.fill,
                      ),
                      // Interactive overlay
                      if (_mode == 'muscles')
                        MouseRegion(
                          onHover: (e) {
                            final g = _groupAtPosition(e.localPosition, constraints.biggest);
                            if (g != _hoveredGroup) setState(() => _hoveredGroup = g);
                          },
                          onExit: (_) {
                            if (_hoveredGroup != null) setState(() => _hoveredGroup = null);
                          },
                          child: GestureDetector(
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
                                hoveredGroup: _hoveredGroup,
                                viewBox: const Size(658, 1024),
                              ),
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
    final scaleX = size.width / 658;
    final scaleY = size.height / 1024;

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
  final String? hoveredGroup;
  final Size viewBox;

  const _MusclePainter({
    required this.zones,
    required this.selectedGroup,
    required this.hoveredGroup,
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
      final isHovered = hoveredGroup == zone.muscleGroup;
      final isActive = isSelected || isHovered;

      if (!isActive) continue; // transparent when idle

      final pts = _parsePoints(zone.points, scaleX, scaleY);
      final path = Path()..addPolygon(pts, true);

      // Fill
      final fillPaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 0.55 : 0.30)
        ..style = PaintingStyle.fill;
      canvas.drawPath(path, fillPaint);

      // Stroke
      final strokePaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 0.9 : 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.5 : 1.0;
      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(_MusclePainter old) =>
      old.selectedGroup != selectedGroup ||
      old.hoveredGroup != hoveredGroup ||
      old.zones != zones;
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
        color: context.colorBgTertiary,
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
            color: context.colorBgSecondary,
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
                    ? Center(
                        child: Text(
                          'No hay ejercicios para este filtro',
                          style: TextStyle(color: context.colorTextMuted),
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
                            context.push('/exercises/${filtered[i]['id']}');
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

class _JointBottomSheet extends StatefulWidget {
  final String family;
  final String familyName;
  final JointExercisesService service;
  final bool canCreate;

  const _JointBottomSheet({
    required this.family,
    required this.familyName,
    required this.service,
    required this.canCreate,
  });

  @override
  State<_JointBottomSheet> createState() => _JointBottomSheetState();
}

class _JointBottomSheetState extends State<_JointBottomSheet> {
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await widget.service.list(family: widget.family);
      if (mounted) setState(() { _exercises = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreateForm() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CreateJointExerciseSheet(
        family: widget.family,
        familyName: widget.familyName,
        service: widget.service,
      ),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.92,
      minChildSize: 0.3,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.colorBgSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
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
                      width: 12, height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.accentPrimary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      widget.familyName,
                      style: const TextStyle(
                        color: AppColors.accentPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (!_loading)
                      Text(
                        '${_exercises.length} ejercicios',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const Spacer(),
                    if (widget.canCreate)
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            color: AppColors.accentPrimary),
                        tooltip: 'Agregar ejercicio',
                        onPressed: _showCreateForm,
                        splashRadius: 20,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accentPrimary))
                    : _exercises.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.fitness_center,
                                    color: AppColors.textMuted, size: 40),
                                const SizedBox(height: 12),
                                const Text('Sin ejercicios registrados',
                                    style: TextStyle(
                                        color: AppColors.textMuted)),
                                if (widget.canCreate) ...[
                                  const SizedBox(height: 12),
                                  TextButton.icon(
                                    onPressed: _showCreateForm,
                                    icon: const Icon(Icons.add,
                                        color: AppColors.accentPrimary),
                                    label: const Text('Agregar ejercicio',
                                        style: TextStyle(
                                            color: AppColors.accentPrimary)),
                                  ),
                                ],
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: _exercises.length,
                            separatorBuilder: (_, i) =>
                                const SizedBox(height: 12),
                            itemBuilder: (_, i) =>
                                _JointExerciseCard(exercise: _exercises[i]),
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
  final Map<String, dynamic> exercise;

  const _JointExerciseCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final type = exercise['type'] as String? ?? '';
    final name = exercise['name'] as String? ?? '';
    final instructions = (exercise['instructions'] as List?)?.cast<String>() ?? [];
    final benefits = exercise['benefits'] as String?;
    final whenToUse = exercise['whenToUse'] as String?;

    final isMovilidad = type == 'movilidad';
    final typeColor = isMovilidad ? const Color(0xFF4ECDC4) : AppColors.accentPrimary;
    final typeLabel = isMovilidad ? 'Movilidad' : 'Fortalecimiento';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.colorBgTertiary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: typeColor.withValues(alpha: 0.4)),
            ),
            child: Text(typeLabel,
                style: TextStyle(
                    color: typeColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 8),
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          if (instructions.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...instructions.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 18, height: 18,
                        margin: const EdgeInsets.only(right: 8, top: 1),
                        decoration: BoxDecoration(
                          color: AppColors.accentPrimary.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text('${entry.key + 1}',
                              style: const TextStyle(
                                  color: AppColors.accentPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                      Expanded(
                        child: Text(entry.value,
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                    ],
                  ),
                )),
          ],
          if (benefits != null && benefits.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF4ECDC4).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF4ECDC4).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFF4ECDC4)),
                  const SizedBox(width: 6),
                  Expanded(child: Text(benefits,
                      style: const TextStyle(color: Color(0xFF4ECDC4), fontSize: 12))),
                ],
              ),
            ),
          ],
          if (whenToUse != null && whenToUse.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentPrimary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.accentPrimary),
                  const SizedBox(width: 6),
                  Expanded(child: Text(whenToUse,
                      style: const TextStyle(color: AppColors.accentPrimary, fontSize: 12))),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Create joint exercise sheet ───────────────────────────────────────────────

class _CreateJointExerciseSheet extends StatefulWidget {
  final String family;
  final String familyName;
  final JointExercisesService service;

  const _CreateJointExerciseSheet({
    required this.family,
    required this.familyName,
    required this.service,
  });

  @override
  State<_CreateJointExerciseSheet> createState() =>
      _CreateJointExerciseSheetState();
}

class _CreateJointExerciseSheetState extends State<_CreateJointExerciseSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _benefitsCtrl = TextEditingController();
  final _whenToUseCtrl = TextEditingController();
  final List<TextEditingController> _stepCtrl = [TextEditingController()];
  String _type = 'movilidad';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _benefitsCtrl.dispose();
    _whenToUseCtrl.dispose();
    for (final c in _stepCtrl) { c.dispose(); }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _error = null; });
    try {
      final instructions = _stepCtrl
          .map((c) => c.text.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      await widget.service.create({
        'name': _nameCtrl.text.trim(),
        'type': _type,
        'jointFamily': widget.family,
        'instructions': instructions,
        'benefits': _benefitsCtrl.text.trim(),
        'whenToUse': _whenToUseCtrl.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _saving = false; _error = e.toString(); });
    }
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colorTextMuted),
        filled: true,
        fillColor: AppColors.bgTertiary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(
            color: context.colorBgSecondary,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.textMuted,
                    borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Nuevo ejercicio — ${widget.familyName}',
                        style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: AppColors.textMuted),
                      onPressed: () => Navigator.pop(context),
                      splashRadius: 18,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.border),
              Expanded(
                child: SingleChildScrollView(
                  controller: scroll,
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Nombre
                        _Label('Nombre *'),
                        SizedBox(height: 6),
                        TextFormField(
                          controller: _nameCtrl,
                          style: TextStyle(color: context.colorTextPrimary),
                          decoration: _deco('Ej. Rotaciones de hombro'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 14),
                        // Tipo
                        _Label('Tipo *'),
                        SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: context.colorBgTertiary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _type,
                              isExpanded: true,
                              dropdownColor: AppColors.bgSecondary,
                              style: const TextStyle(
                                  color: AppColors.textPrimary, fontSize: 14),
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: AppColors.textMuted),
                              items: const [
                                DropdownMenuItem(
                                    value: 'movilidad',
                                    child: Text('Movilidad')),
                                DropdownMenuItem(
                                    value: 'fortalecimiento',
                                    child: Text('Fortalecimiento')),
                              ],
                              onChanged: (v) =>
                                  setState(() => _type = v!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        // Pasos
                        Row(
                          children: [
                            const Expanded(child: _Label('Pasos / instrucciones')),
                            TextButton.icon(
                              onPressed: () => setState(
                                  () => _stepCtrl.add(TextEditingController())),
                              icon: const Icon(Icons.add,
                                  size: 16, color: AppColors.accentPrimary),
                              label: const Text('Paso',
                                  style: TextStyle(
                                      color: AppColors.accentPrimary,
                                      fontSize: 12)),
                              style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ..._stepCtrl.asMap().entries.map((entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24, height: 24,
                                    margin: const EdgeInsets.only(right: 8),
                                    decoration: BoxDecoration(
                                      color: AppColors.accentPrimary
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text('${entry.key + 1}',
                                          style: const TextStyle(
                                              color: AppColors.accentPrimary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                  Expanded(
                                    child: TextFormField(
                                      controller: entry.value,
                                      style: const TextStyle(
                                          color: AppColors.textPrimary,
                                          fontSize: 13),
                                      decoration:
                                          _deco('Describe el paso ${entry.key + 1}...'),
                                    ),
                                  ),
                                  if (_stepCtrl.length > 1) ...[
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        entry.value.dispose();
                                        _stepCtrl.removeAt(entry.key);
                                      }),
                                      child: const Icon(
                                          Icons.remove_circle_outline,
                                          color: AppColors.accentSecondary,
                                          size: 20),
                                    ),
                                  ],
                                ],
                              ),
                            )),
                        const SizedBox(height: 14),
                        // Beneficios
                        _Label('Beneficios'),
                        SizedBox(height: 6),
                        TextFormField(
                          controller: _benefitsCtrl,
                          style: TextStyle(color: context.colorTextPrimary),
                          decoration: _deco('Ej. Mejora la estabilidad del hombro'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        // Cuándo usarlo
                        _Label('Cuándo usarlo'),
                        SizedBox(height: 6),
                        TextFormField(
                          controller: _whenToUseCtrl,
                          style: TextStyle(color: context.colorTextPrimary),
                          decoration:
                              _deco('Ej. Antes de entrenar pecho o espalda'),
                          maxLines: 2,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 10),
                          Text(_error!,
                              style: const TextStyle(
                                  color: AppColors.accentSecondary,
                                  fontSize: 12)),
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
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Crear ejercicio',
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
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600));
}



