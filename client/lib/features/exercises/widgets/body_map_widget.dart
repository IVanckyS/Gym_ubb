import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/exercises_service.dart';
import '../../../shared/services/joint_exercises_service.dart';
import '../data/body_map_data.dart';
import 'exercise_card.dart';

class BodyMapWidget extends StatefulWidget {
  const BodyMapWidget({super.key});

  @override
  State<BodyMapWidget> createState() => _BodyMapWidgetState();
}

class _BodyMapWidgetState extends State<BodyMapWidget> {
  Gender _gender = Gender.male;
  BodyView _view = BodyView.front;
  BodyMapMode _mode = BodyMapMode.muscle;

  MuscleSubgroup? _selectedMuscle;
  MuscleGroup? _selectedMuscleGroup;
  String? _hoveredId; // hitboxId — solo en web

  JointFamily? _selectedJoint;

  final JointExercisesService _jointService = JointExercisesService();

  String get _svgPath {
    if (_gender == Gender.male) {
      return _view == BodyView.front
          ? 'assets/body-map/FRONT_MELE.svg'
          : 'assets/body-map/BACK_MELE.svg';
    } else {
      return _view == BodyView.front
          ? 'assets/body-map/FRONT_WOMAN.svg'
          : 'assets/body-map/BACK_WOMAN.svg';
    }
  }

  List<MuscleRegion> get _currentRegions =>
      kMuscleRegions.where((r) => r.view == _view).toList();

  List<JointPoint> get _currentJoints =>
      kJointPoints.where((p) => p.view == _view).toList();

  // ── Hit testing ────────────────────────────────────────────────────────────

  /// Hit-test sobre forma normalizada. La elipse soporta rotación (campo `rot`
  /// en grados): se traslada el punto al sistema local de la elipse, se rota
  /// por -rot, y se aplica la fórmula estándar (lx²/rx²) + (ly²/ry²) ≤ 1.
  bool _hitTest(HitboxShape shape, Offset pos, Size size) {
    if (shape is EllipseShape) {
      final px = pos.dx / size.width;
      final py = pos.dy / size.height;
      final dx = px - shape.cx;
      final dy = py - shape.cy;
      final rad = -shape.rot * math.pi / 180;
      final lx = dx * math.cos(rad) - dy * math.sin(rad);
      final ly = dx * math.sin(rad) + dy * math.cos(rad);
      return (lx * lx) / (shape.rx * shape.rx) +
              (ly * ly) / (shape.ry * shape.ry) <=
          1.0;
    }
    if (shape is PolygonShape) {
      return _pointInPolygon(pos, shape.points, size);
    }
    return false;
  }

  bool _pointInPolygon(Offset point, List<Point> points, Size size) {
    final n = points.length;
    bool inside = false;
    var j = n - 1;
    for (var i = 0; i < n; i++) {
      final xi = points[i].x * size.width;
      final yi = points[i].y * size.height;
      final xj = points[j].x * size.width;
      final yj = points[j].y * size.height;
      if ((yi > point.dy) != (yj > point.dy) &&
          point.dx < (xj - xi) * (point.dy - yi) / (yj - yi) + xi) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  // ── Handlers ───────────────────────────────────────────────────────────────

  void _handleMuscleTap(TapDownDetails d, Size size) {
    for (final region in _currentRegions) {
      if (_hitTest(region.shape, d.localPosition, size)) {
        setState(() {
          _selectedMuscle = region.subgroup;
          _selectedMuscleGroup = region.group;
        });
        _showMuscleBottomSheet(region.group, region.subgroup);
        return;
      }
    }
    setState(() {
      _selectedMuscle = null;
      _selectedMuscleGroup = null;
    });
  }

  void _handleHover(PointerEvent e, Size size) {
    String? hit;
    for (final region in _currentRegions) {
      if (_hitTest(region.shape, e.localPosition, size)) {
        hit = region.hitboxId;
        break;
      }
    }
    if (hit != _hoveredId) setState(() => _hoveredId = hit);
  }

  void _showMuscleBottomSheet(MuscleGroup group, [MuscleSubgroup? subgroup]) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _MuscleBottomSheet(group: group, subgroup: subgroup),
    );
  }

  void _showJointBottomSheet(JointFamily family) {
    final role = context.read<AuthProvider>().user?['role'] as String? ?? '';
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bgSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) => _JointBottomSheet(
        family: family.name,
        familyName: family.displayName,
        service: _jointService,
        canCreate: role == 'admin' || role == 'professor',
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

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
                  final size = constraints.biggest;
                  return Stack(
                    children: [
                      SvgPicture.asset(
                        _svgPath,
                        width: size.width,
                        height: size.height,
                        fit: BoxFit.fill,
                      ),
                      if (_mode == BodyMapMode.muscle)
                        MouseRegion(
                          onHover: (e) => _handleHover(e, size),
                          onExit: (_) {
                            if (_hoveredId != null) {
                              setState(() => _hoveredId = null);
                            }
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTapDown: (d) => _handleMuscleTap(d, size),
                            child: CustomPaint(
                              size: size,
                              painter: _MusclePainter(
                                regions: _currentRegions,
                                selectedMuscle: _selectedMuscle,
                                hoveredId: _hoveredId,
                              ),
                            ),
                          ),
                        )
                      else
                        _buildJointsOverlay(size),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_mode == BodyMapMode.muscle) _buildMuscleLegend(),
        if (_mode == BodyMapMode.joint) _buildJointLegend(),
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
          value: _gender == Gender.male ? 'male' : 'female',
          onChanged: (v) => setState(() {
            _gender = v == 'male' ? Gender.male : Gender.female;
            _selectedMuscle = null;
            _selectedMuscleGroup = null;
            _selectedJoint = null;
          }),
        ),
        _ToggleGroup(
          options: const [('front', 'Frontal'), ('back', 'Posterior')],
          value: _view == BodyView.front ? 'front' : 'back',
          onChanged: (v) => setState(() {
            _view = v == 'front' ? BodyView.front : BodyView.back;
            _selectedMuscle = null;
            _selectedMuscleGroup = null;
            _selectedJoint = null;
            _hoveredId = null;
          }),
        ),
        _ToggleGroup(
          options: const [('muscle', '💪 Músculos'), ('joint', '🔴 Articulaciones')],
          value: _mode == BodyMapMode.muscle ? 'muscle' : 'joint',
          onChanged: (v) => setState(() {
            _mode = v == 'muscle' ? BodyMapMode.muscle : BodyMapMode.joint;
            _selectedMuscle = null;
            _selectedMuscleGroup = null;
            _selectedJoint = null;
            _hoveredId = null;
          }),
        ),
      ],
    );
  }

  Widget _buildJointsOverlay(Size size) {
    return Stack(
      children: _currentJoints.map((point) {
        final px = point.cx * size.width;
        final py = point.cy * size.height;
        final isSelected = _selectedJoint == point.family;
        const hitR = 28.0;
        const visR = 8.0;
        const visRSel = 10.0;

        return Positioned(
          left: px - hitR,
          top: py - hitR,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              setState(() => _selectedJoint = point.family);
              _showJointBottomSheet(point.family);
            },
            child: SizedBox(
              width: hitR * 2,
              height: hitR * 2,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isSelected)
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.accentSecondary.withValues(alpha: 0.25),
                          shape: BoxShape.circle,
                        ),
                      ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: isSelected ? visRSel * 2 : visR * 2,
                      height: isSelected ? visRSel * 2 : visR * 2,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentSecondary.withValues(alpha: 0.95)
                            : AppColors.accentPrimary.withValues(alpha: 0.6),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: isSelected ? 1.0 : 0.9),
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
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMuscleLegend() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 6,
      children: MuscleGroup.values.map((group) {
        final isSelected = _selectedMuscleGroup == group;
        final color = group.color;
        return GestureDetector(
          onTap: () {
            if (isSelected) {
              setState(() {
                _selectedMuscleGroup = null;
                _selectedMuscle = null;
              });
            } else {
              setState(() {
                _selectedMuscleGroup = group;
                _selectedMuscle = null;
              });
              _showMuscleBottomSheet(group);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? color.withValues(alpha: 0.25)
                  : color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.4),
                width: isSelected ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
                Text(
                  group.displayName,
                  style: TextStyle(
                    color: isSelected ? color : AppColors.textSecondary,
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
      children: JointFamily.values.map((family) {
        final isSelected = _selectedJoint == family;
        return GestureDetector(
          onTap: () {
            if (isSelected) {
              setState(() => _selectedJoint = null);
            } else {
              setState(() => _selectedJoint = family);
              _showJointBottomSheet(family);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.accentPrimary.withValues(alpha: 0.2)
                  : context.colorBgTertiary,
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
                  family.displayName,
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

// ── CustomPainter ─────────────────────────────────────────────────────────────

class _MusclePainter extends CustomPainter {
  final List<MuscleRegion> regions;
  final MuscleSubgroup? selectedMuscle;
  final String? hoveredId;

  const _MusclePainter({
    required this.regions,
    required this.selectedMuscle,
    required this.hoveredId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final region in regions) {
      final isSelected = selectedMuscle == region.subgroup;
      final isHovered = hoveredId == region.hitboxId;
      if (!isSelected && !isHovered) continue;

      final color = region.group.color;
      final fillPaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 0.55 : 0.35)
        ..style = PaintingStyle.fill;
      final strokePaint = Paint()
        ..color = color.withValues(alpha: isSelected ? 1.0 : 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 1.5 : 1.0;

      _drawShape(canvas, region.shape, size, fillPaint, strokePaint);
    }
  }

  void _drawShape(
      Canvas canvas, HitboxShape shape, Size size, Paint fill, Paint stroke) {
    if (shape is EllipseShape) {
      final cx = shape.cx * size.width;
      final cy = shape.cy * size.height;
      final rx = shape.rx * size.width;
      final ry = shape.ry * size.height;
      final rect = Rect.fromCenter(
          center: Offset(cx, cy), width: rx * 2, height: ry * 2);
      if (shape.rot == 0) {
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
      } else {
        canvas.save();
        canvas.translate(cx, cy);
        canvas.rotate(shape.rot * math.pi / 180);
        canvas.translate(-cx, -cy);
        canvas.drawOval(rect, fill);
        canvas.drawOval(rect, stroke);
        canvas.restore();
      }
      return;
    }
    if (shape is PolygonShape) {
      if (shape.points.isEmpty) return;
      final pts = shape.points
          .map((p) => Offset(p.x * size.width, p.y * size.height))
          .toList();
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_MusclePainter old) =>
      old.selectedMuscle != selectedMuscle ||
      old.hoveredId != hoveredId ||
      old.regions != regions;
}

// ── Toggle group ──────────────────────────────────────────────────────────────

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
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Bottom sheet: músculos (llama API) ────────────────────────────────────────

class _MuscleBottomSheet extends StatefulWidget {
  final MuscleGroup group;
  final MuscleSubgroup? subgroup;

  const _MuscleBottomSheet({required this.group, this.subgroup});

  @override
  State<_MuscleBottomSheet> createState() => _MuscleBottomSheetState();
}

class _MuscleBottomSheetState extends State<_MuscleBottomSheet> {
  final _service = ExercisesService();
  List<Map<String, dynamic>> _exercises = [];
  bool _loading = true;
  String _diffFilter = 'Todos';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await _service.listExercises(
        muscleGroups: {widget.group.name},
      );
      if (mounted) setState(() { _exercises = list; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.group.color;
    final emoji = BodyMapData.muscleEmoji[widget.group.displayName] ?? '💪';

    final filtered = _diffFilter == 'Todos'
        ? _exercises
        : _exercises
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 28)),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.group.displayName,
                          style: TextStyle(
                            color: color,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (widget.subgroup != null)
                          Text(
                            widget.subgroup!.displayName,
                            style: TextStyle(
                              color: color.withValues(alpha: 0.7),
                              fontSize: 13,
                            ),
                          ),
                        if (!_loading)
                          Text(
                            '${_exercises.length} ejercicios',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
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
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isActive
                                ? color.withValues(alpha: 0.2)
                                : AppColors.bgTertiary,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isActive ? color : AppColors.border,
                            ),
                          ),
                          child: Text(
                            d,
                            style: TextStyle(
                              color: isActive ? color : AppColors.textSecondary,
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
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.accentPrimary))
                    : filtered.isEmpty
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
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (_, i) => ExerciseCard(
                              exercise: filtered[i],
                              compact: true,
                              onTap: () {
                                Navigator.pop(ctx);
                                context
                                    .push('/exercises/${filtered[i]['id']}');
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

// ── Bottom sheet: articulaciones ──────────────────────────────────────────────

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
                                    style:
                                        TextStyle(color: AppColors.textMuted)),
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
                            separatorBuilder: (_, _) =>
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
    final typeColor =
        isMovilidad ? const Color(0xFF4ECDC4) : AppColors.accentPrimary;
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
                    color: typeColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
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
                        width: 18,
                        height: 18,
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
                border: Border.all(
                    color: const Color(0xFF4ECDC4).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: Color(0xFF4ECDC4)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(benefits,
                        style: const TextStyle(
                            color: Color(0xFF4ECDC4), fontSize: 12)),
                  ),
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
                border: Border.all(
                    color: AppColors.accentPrimary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      size: 14, color: AppColors.accentPrimary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(whenToUse,
                        style: const TextStyle(
                            color: AppColors.accentPrimary, fontSize: 12)),
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

class _CreateJointExerciseSheetState
    extends State<_CreateJointExerciseSheet> {
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (ctx, scroll) => Container(
          decoration: BoxDecoration(
            color: context.colorBgSecondary,
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
                        const _Label('Nombre *'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _nameCtrl,
                          style: TextStyle(color: context.colorTextPrimary),
                          decoration: _deco('Ej. Rotaciones de hombro'),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Requerido' : null,
                        ),
                        const SizedBox(height: 14),
                        const _Label('Tipo *'),
                        const SizedBox(height: 6),
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
                              onChanged: (v) => setState(() => _type = v!),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Expanded(
                                child: _Label('Pasos / instrucciones')),
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
                                    width: 24,
                                    height: 24,
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
                                      decoration: _deco(
                                          'Describe el paso ${entry.key + 1}...'),
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
                        const _Label('Beneficios'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _benefitsCtrl,
                          style: TextStyle(color: context.colorTextPrimary),
                          decoration:
                              _deco('Ej. Mejora la estabilidad del hombro'),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 14),
                        const _Label('Cuándo usarlo'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _whenToUseCtrl,
                          style: TextStyle(color: context.colorTextPrimary),
                          decoration: _deco(
                              'Ej. Antes de entrenar pecho o espalda'),
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
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Text('Crear ejercicio',
                                  style:
                                      TextStyle(fontWeight: FontWeight.w600)),
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
