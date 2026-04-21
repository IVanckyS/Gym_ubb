import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/services/exercises_service.dart';
import '../data/body_map_data.dart';
import '../widgets/body_map_widget.dart';
import '../widgets/exercise_card.dart';

class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ExercisesService _service = ExercisesService();

  List<Map<String, dynamic>> _exercises = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  String? _error;

  final TextEditingController _searchController = TextEditingController();
  Set<String> _selectedGroups = {};       // vacío = Todos
  Set<String> _selectedEquipment = {};    // vacío = Todos
  String _selectedDifficulty = '';

  // Lista de valores únicos de equipamiento extraídos de los ejercicios cargados
  List<String> _availableEquipment = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExercises();
    _searchController.addListener(_applyFilters);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.listExercises();
      // Extraer valores únicos de equipamiento (no nulos, no vacíos)
      final equips = list
          .map((e) => (e['equipment'] as String? ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
      setState(() {
        _exercises = list;
        _filtered = list;
        _availableEquipment = equips;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _CreateExerciseDialog(service: _service),
    );
    if (result == true) _loadExercises();
  }

  void _applyFilters() {
    final search = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _exercises.where((e) {
        final nameMatch = search.isEmpty ||
            (e['name'] as String? ?? '').toLowerCase().contains(search);
        final groupMatch = _selectedGroups.isEmpty ||
            _selectedGroups.contains(e['muscleGroup']);
        final diffMatch = _selectedDifficulty.isEmpty ||
            e['difficulty'] == _selectedDifficulty;
        final equip = (e['equipment'] as String? ?? '').toLowerCase();
        final equipMatch = _selectedEquipment.isEmpty ||
            _selectedEquipment.any((eq) => equip.contains(eq.toLowerCase()));
        return nameMatch && groupMatch && diffMatch && equipMatch;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedGroups = {};
      _selectedEquipment = {};
      _selectedDifficulty = '';
      _searchController.clear();
      _filtered = _exercises;
    });
  }

  int get _activeFilterCount =>
      (_selectedGroups.isNotEmpty ? 1 : 0) +
      (_selectedEquipment.isNotEmpty ? 1 : 0) +
      (_selectedDifficulty.isNotEmpty ? 1 : 0);

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?['role'] as String? ?? '';
    final canCreate = role == 'admin' || role == 'professor';

    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        title: const Text('Ejercicios'),
        automaticallyImplyLeading: false,
        actions: canCreate
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: IconButton(
                    onPressed: () => _showCreateDialog(context),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.accentPrimary.withValues(alpha: 0.15),
                      foregroundColor: AppColors.accentPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: AppColors.accentPrimary.withValues(alpha: 0.4),
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 22),
                    tooltip: 'Agregar ejercicio',
                  ),
                ),
              ]
            : null,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accentPrimary,
          labelColor: AppColors.accentPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: 'Mapa Corporal'),
            Tab(text: 'Lista'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppColors.accentPrimary,
              ),
            )
          : _error != null
              ? _buildError()
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildBodyMapTab(),
                    _buildListTab(),
                  ],
                ),
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
              'Error al cargar ejercicios',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadExercises,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyMapTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: BodyMapWidget(exercises: _exercises),
        ),
      ),
    );
  }

  Widget _buildListTab() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
        // Search & filters
        Container(
          color: context.colorBgSecondary,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _searchController,
                style: TextStyle(color: context.colorTextPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar ejercicio...',
                  prefixIcon: Icon(
                    Icons.search,
                    color: context.colorTextMuted,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.clear, color: context.colorTextMuted),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              // Muscle group filter — multi-selección
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _selectedGroups.isEmpty,
                      onTap: () {
                        setState(() => _selectedGroups = {});
                        _applyFilters();
                      },
                    ),
                    ...BodyMapData.muscleGroupDisplayName.entries.map((entry) {
                      final color = BodyMapData.muscleColors[entry.value] ??
                          AppColors.accentPrimary;
                      return _FilterChip(
                        label: entry.value,
                        selected: _selectedGroups.contains(entry.key),
                        activeColor: color,
                        onTap: () {
                          setState(() {
                            if (_selectedGroups.contains(entry.key)) {
                              _selectedGroups = Set.from(_selectedGroups)
                                ..remove(entry.key);
                            } else {
                              _selectedGroups = Set.from(_selectedGroups)
                                ..add(entry.key);
                            }
                          });
                          _applyFilters();
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Difficulty filter — selección única
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _selectedDifficulty.isEmpty,
                      onTap: () {
                        setState(() => _selectedDifficulty = '');
                        _applyFilters();
                      },
                    ),
                    _FilterChip(
                      label: 'Principiante',
                      selected: _selectedDifficulty == 'principiante',
                      activeColor: const Color(0xFF4ECDC4),
                      onTap: () {
                        setState(() => _selectedDifficulty =
                            _selectedDifficulty == 'principiante'
                                ? ''
                                : 'principiante');
                        _applyFilters();
                      },
                    ),
                    _FilterChip(
                      label: 'Intermedio',
                      selected: _selectedDifficulty == 'intermedio',
                      activeColor: const Color(0xFFFFB347),
                      onTap: () {
                        setState(() => _selectedDifficulty =
                            _selectedDifficulty == 'intermedio'
                                ? ''
                                : 'intermedio');
                        _applyFilters();
                      },
                    ),
                    _FilterChip(
                      label: 'Avanzado',
                      selected: _selectedDifficulty == 'avanzado',
                      activeColor: const Color(0xFFFF6B6B),
                      onTap: () {
                        setState(() => _selectedDifficulty =
                            _selectedDifficulty == 'avanzado' ? '' : 'avanzado');
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
              // Equipment filter — solo aparece si hay valores disponibles
              if (_availableEquipment.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 34,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _FilterChip(
                        label: 'Todo equipo',
                        selected: _selectedEquipment.isEmpty,
                        onTap: () {
                          setState(() => _selectedEquipment = {});
                          _applyFilters();
                        },
                      ),
                      ..._availableEquipment.map((eq) => _FilterChip(
                            label: eq,
                            selected: _selectedEquipment.contains(eq),
                            onTap: () {
                              setState(() {
                                if (_selectedEquipment.contains(eq)) {
                                  _selectedEquipment = Set.from(_selectedEquipment)
                                    ..remove(eq);
                                } else {
                                  _selectedEquipment = Set.from(_selectedEquipment)
                                    ..add(eq);
                                }
                              });
                              _applyFilters();
                            },
                          )),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),
            ],
          ),
        ),
        // Results count + limpiar filtros
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_filtered.length} ejercicios',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (_activeFilterCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.accentPrimary.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$_activeFilterCount filtro${_activeFilterCount > 1 ? 's' : ''}',
                    style: const TextStyle(
                      color: AppColors.accentPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: _clearFilters,
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(
                      color: AppColors.accentSecondary,
                      fontSize: 12,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        // List
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.fitness_center,
                        size: 48,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Sin resultados',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount:
                        MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.66,
                  ),
                  itemCount: _filtered.length,
                  itemBuilder: (context, i) => ExerciseCard(
                    exercise: _filtered[i],
                    onTap: () =>
                        context.push('/exercises/${_filtered[i]['id']}'),
                  ),
                ),
        ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? activeColor;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = activeColor ?? AppColors.accentPrimary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? color.withValues(alpha: 0.18)
                : AppColors.bgTertiary,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? color : AppColors.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? color : AppColors.textSecondary,
              fontSize: 12,
              fontWeight:
                  selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Create Exercise Dialog ────────────────────────────────────────────────────

class _CreateExerciseDialog extends StatefulWidget {
  const _CreateExerciseDialog({required this.service});
  final ExercisesService service;

  @override
  State<_CreateExerciseDialog> createState() => _CreateExerciseDialogState();
}

class _CreateExerciseDialogState extends State<_CreateExerciseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _equipmentCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  final _safetyCtrl = TextEditingController();
  String _muscleGroup = 'pecho';
  String _difficulty = 'principiante';
  int _defaultSets = 3;
  String _defaultReps = '8-12';
  int _defaultDurationSeconds = 30;
  bool _isIsometric = false;
  bool _isRankeable = false;
  bool _saving = false;
  String? _saveStep;
  String? _error;

  File? _mainImage;
  final List<TextEditingController> _muscleCtrl = [];
  final List<TextEditingController> _instructionCtrl = [];
  final List<File?> _stepImages = [];
  // Combo searchable de variaciones: lista de {id, name, muscleGroup} seleccionados
  final List<Map<String, dynamic>> _selectedVariations = [];
  final _variationSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _variationResults = [];
  bool _searchingVariations = false;
  Timer? _variationDebounce;
  final _picker = ImagePicker();

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
    _instructionCtrl.add(TextEditingController());
    _stepImages.add(null);
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose(); _equipmentCtrl.dispose();
    _videoUrlCtrl.dispose(); _safetyCtrl.dispose();
    for (final c in _muscleCtrl) { c.dispose(); }
    for (final c in _instructionCtrl) { c.dispose(); }
    _variationSearchCtrl.dispose();
    _variationDebounce?.cancel();
    super.dispose();
  }

  Future<void> _pickMainImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null && mounted) setState(() => _mainImage = File(picked.path));
  }

  Future<void> _pickStepImage(int index) async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null && mounted) {
      setState(() {
        while (_stepImages.length <= index) { _stepImages.add(null); }
        _stepImages[index] = File(picked.path);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _saving = true; _saveStep = 'Creando ejercicio...'; _error = null; });
    try {
      final muscles = _muscleCtrl.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
      final instructions = _instructionCtrl.map((c) => c.text.trim()).where((s) => s.isNotEmpty).toList();
      final variations = _selectedVariations.map((v) => v['name'] as String).toList();

      final result = await widget.service.createExercise({
        'name': _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'muscleGroup': _muscleGroup,
        'difficulty': _difficulty,
        'equipment': _equipmentCtrl.text.trim(),
        'defaultSets': _defaultSets,
        'defaultReps': _defaultReps,
        'videoUrl': _videoUrlCtrl.text.trim(),
        'safetyNotes': _safetyCtrl.text.trim(),
        'muscles': muscles,
        'instructions': instructions,
        'variations': variations,
        'isRankeable': _isRankeable,
        'exerciseType': _isIsometric ? 'isometrico' : 'dinamico',
        if (_isIsometric) 'defaultDurationSeconds': _defaultDurationSeconds,
      });

      final id = result['id'] as String;

      String? imageUrl;
      if (_mainImage != null) {
        setState(() => _saveStep = 'Subiendo imagen principal...');
        imageUrl = await widget.service.uploadImage(id, _mainImage!, type: 'main');
      }

      final stepImagesUrls = List<String>.filled(instructions.length, '');
      bool hasStepImages = false;
      for (int i = 0; i < _stepImages.length && i < instructions.length; i++) {
        if (_stepImages[i] != null) {
          setState(() => _saveStep = 'Subiendo imagen paso ${i + 1}...');
          stepImagesUrls[i] = await widget.service.uploadImage(id, _stepImages[i]!, type: 'step_$i');
          hasStepImages = true;
        }
      }

      if (imageUrl != null || hasStepImages) {
        setState(() => _saveStep = 'Guardando imágenes...');
        final updates = <String, dynamic>{};
        if (imageUrl != null) { updates['imageUrl'] = imageUrl; }
        if (hasStepImages) { updates['stepImages'] = stepImagesUrls; }
        await widget.service.updateExercise(id, updates);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() { _saving = false; _saveStep = null; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildBasicFields(),
                      const SizedBox(height: 16),
                      _buildMainImagePicker(),
                      const SizedBox(height: 16),
                      _buildVideoUrlField(),
                      const SizedBox(height: 16),
                      _buildMusclesList(),
                      const SizedBox(height: 16),
                      _buildInstructionsList(),
                      const SizedBox(height: 16),
                      _buildSafetyField(),
                      const SizedBox(height: 16),
                      _buildVariationsList(),
                      const SizedBox(height: 16),
                      _buildIsometricToggle(),
                      const SizedBox(height: 12),
                      _buildRankeableToggle(),
                      if (_error != null) ...[
                        const SizedBox(height: 10),
                        Text(_error!, style: const TextStyle(color: AppColors.accentSecondary, fontSize: 12)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentPrimary,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _saving
                            ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(width: 20, height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                                  const SizedBox(width: 12),
                                  Text(_saveStep ?? 'Guardando...',
                                      style: const TextStyle(color: Colors.white, fontSize: 13)),
                                ],
                              )
                            : const Text('Crear ejercicio', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: Text('Nuevo ejercicio',
                style: TextStyle(color: context.colorTextPrimary, fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.textMuted),
            onPressed: () => Navigator.pop(context),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildBasicFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel('Nombre *'),
        SizedBox(height: 6),
        TextFormField(
          controller: _nameCtrl,
          style: TextStyle(color: context.colorTextPrimary),
          decoration: _inputDeco('Ej. Press de banca'),
          validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogLabel('Grupo muscular *'),
                  const SizedBox(height: 6),
                  _DropdownField<String>(
                    value: _muscleGroup,
                    items: _muscleOptions.map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2))).toList(),
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
                  _DialogLabel('Dificultad *'),
                  const SizedBox(height: 6),
                  _DropdownField<String>(
                    value: _difficulty,
                    items: _difficultyOptions.map((d) => DropdownMenuItem(value: d.$1, child: Text(d.$2))).toList(),
                    onChanged: (v) => setState(() => _difficulty = v!),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DialogLabel('Equipo'),
        SizedBox(height: 6),
        TextFormField(
          controller: _equipmentCtrl,
          style: TextStyle(color: context.colorTextPrimary),
          decoration: _inputDeco('Ej. Barra + Banco'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DialogLabel('Series'),
                  const SizedBox(height: 6),
                  _DropdownField<int>(
                    value: _defaultSets,
                    items: [2, 3, 4, 5].map((n) => DropdownMenuItem(value: n, child: Text('$n'))).toList(),
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
                  _DialogLabel(_isIsometric ? 'Duración (seg)' : 'Reps'),
                  SizedBox(height: 6),
                  if (_isIsometric)
                    TextFormField(
                      initialValue: '$_defaultDurationSeconds',
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: _inputDeco('Ej. 30'),
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _defaultDurationSeconds = int.tryParse(v) ?? 30,
                    )
                  else
                    TextFormField(
                      initialValue: _defaultReps,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: _inputDeco('Ej. 8-12'),
                      onChanged: (v) => _defaultReps = v,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _DialogLabel('Descripción'),
        SizedBox(height: 6),
        TextFormField(
          controller: _descCtrl,
          style: TextStyle(color: context.colorTextPrimary),
          decoration: _inputDeco('Descripción general del ejercicio...'),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildMainImagePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel('Imagen principal'),
        SizedBox(height: 8),
        GestureDetector(
          onTap: _mainImage == null ? _pickMainImage : null,
          child: Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.colorBgTertiary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
              image: _mainImage != null
                  ? DecorationImage(image: FileImage(_mainImage!), fit: BoxFit.cover)
                  : null,
            ),
            child: _mainImage == null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, color: AppColors.textMuted, size: 36),
                      SizedBox(height: 6),
                      Text('Seleccionar de galería',
                          style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
                    ],
                  )
                : Stack(
                    children: [
                      Positioned(
                        top: 6, right: 6,
                        child: GestureDetector(
                          onTap: () => setState(() => _mainImage = null),
                          child: Container(
                            decoration: const BoxDecoration(
                                color: Colors.black54, shape: BoxShape.circle),
                            padding: const EdgeInsets.all(4),
                            child: const Icon(Icons.close, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 6, right: 6,
                        child: GestureDetector(
                          onTap: _pickMainImage,
                          child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(6)),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: const Text('Cambiar',
                                style: TextStyle(color: Colors.white, fontSize: 11)),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel('Video tutorial (YouTube)'),
        SizedBox(height: 6),
        TextFormField(
          controller: _videoUrlCtrl,
          style: TextStyle(color: context.colorTextPrimary),
          decoration: _inputDeco('https://youtube.com/watch?v=...'),
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _buildMusclesList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _DialogLabel('Músculos trabajados')),
            TextButton.icon(
              onPressed: () => setState(() => _muscleCtrl.add(TextEditingController())),
              icon: const Icon(Icons.add, size: 16, color: AppColors.accentPrimary),
              label: const Text('Agregar', style: TextStyle(color: AppColors.accentPrimary, fontSize: 12)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ],
        ),
        SizedBox(height: 8),
        ..._muscleCtrl.asMap().entries.map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: entry.value,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: _inputDeco('Ej. Pectoral mayor'),
                    ),
                  ),
                  SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() {
                      entry.value.dispose();
                      _muscleCtrl.removeAt(entry.key);
                    }),
                    child: const Icon(Icons.remove_circle_outline,
                        color: AppColors.accentSecondary, size: 22),
                  ),
                ],
              ),
            )),
        if (_muscleCtrl.isEmpty)
          Text('Sin músculos especificados',
              style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
      ],
    );
  }

  Widget _buildInstructionsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _DialogLabel('Pasos / instrucciones')),
            TextButton.icon(
              onPressed: () => setState(() {
                _instructionCtrl.add(TextEditingController());
                _stepImages.add(null);
              }),
              icon: const Icon(Icons.add, size: 16, color: AppColors.accentPrimary),
              label: const Text('Paso', style: TextStyle(color: AppColors.accentPrimary, fontSize: 12)),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ],
        ),
        SizedBox(height: 8),
        ..._instructionCtrl.asMap().entries.map((entry) {
          final i = entry.key;
          final stepImg = i < _stepImages.length ? _stepImages[i] : null;
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: context.colorBgTertiary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24, height: 24,
                      margin: const EdgeInsets.only(right: 8, top: 2),
                      decoration: BoxDecoration(
                        color: AppColors.accentPrimary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: AppColors.accentPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: entry.value,
                        style: TextStyle(color: context.colorTextPrimary, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Describe el paso ${i + 1}...',
                          hintStyle: TextStyle(color: context.colorTextMuted),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          isDense: true,
                        ),
                        maxLines: 2,
                      ),
                    ),
                    if (_instructionCtrl.length > 1)
                      GestureDetector(
                        onTap: () => setState(() {
                          entry.value.dispose();
                          _instructionCtrl.removeAt(i);
                          if (i < _stepImages.length) _stepImages.removeAt(i);
                        }),
                        child: const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.remove_circle_outline,
                              color: AppColors.accentSecondary, size: 18),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (stepImg != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.file(stepImg, width: 60, height: 44, fit: BoxFit.cover),
                      ),
                      SizedBox(width: 8),
                      GestureDetector(
                        onTap: () => setState(() { _stepImages[i] = null; }),
                        child: const Text('Quitar',
                            style: TextStyle(color: AppColors.accentSecondary, fontSize: 11)),
                      ),
                      const Spacer(),
                    ] else
                      const Spacer(),
                    TextButton.icon(
                      onPressed: () => _pickStepImage(i),
                      icon: const Icon(Icons.image_outlined,
                          size: 14, color: AppColors.textSecondary),
                      label: Text(
                        stepImg != null ? 'Cambiar imagen' : 'Adjuntar imagen',
                        style: TextStyle(color: context.colorTextSecondary, fontSize: 11),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSafetyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel('Recomendaciones de seguridad'),
        SizedBox(height: 6),
        TextFormField(
          controller: _safetyCtrl,
          style: TextStyle(color: context.colorTextPrimary),
          decoration: _inputDeco('Notas sobre postura, lesiones a evitar...'),
          maxLines: 3,
        ),
      ],
    );
  }

  Future<void> _onVariationSearchChanged(String q) async {
    _variationDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _variationResults = []; _searchingVariations = false; });
      return;
    }
    _variationDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _searchingVariations = true);
      try {
        final results = await widget.service.searchExercises(q.trim());
        if (!mounted) return;
        // Excluir los ya seleccionados
        final selectedIds = _selectedVariations.map((v) => v['id']).toSet();
        setState(() {
          _variationResults = results.where((r) => !selectedIds.contains(r['id'])).toList();
          _searchingVariations = false;
        });
      } catch (_) {
        if (mounted) setState(() => _searchingVariations = false);
      }
    });
  }

  Widget _buildVariationsList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DialogLabel('Variaciones'),
        const SizedBox(height: 8),
        // Chips de variaciones seleccionadas
        if (_selectedVariations.isNotEmpty) ...[
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedVariations.map((v) => Chip(
              label: Text(v['name'] as String,
                  style: TextStyle(color: context.colorTextPrimary, fontSize: 12)),
              backgroundColor: context.colorBgTertiary,
              side: BorderSide(color: AppColors.accentPrimary.withValues(alpha: 0.4)),
              deleteIconColor: context.colorTextMuted,
              onDeleted: () => setState(() => _selectedVariations.remove(v)),
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
          const SizedBox(height: 8),
        ],
        // Campo de búsqueda
        TextField(
          controller: _variationSearchCtrl,
          onChanged: _onVariationSearchChanged,
          style: TextStyle(color: context.colorTextPrimary),
          decoration: _inputDeco('Buscar ejercicio...').copyWith(
            prefixIcon: _searchingVariations
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16, height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentPrimary),
                    ))
                : Icon(Icons.search_rounded, color: context.colorTextMuted, size: 18),
            suffixIcon: _variationSearchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: context.colorTextMuted, size: 16),
                    onPressed: () {
                      _variationSearchCtrl.clear();
                      setState(() { _variationResults = []; });
                    })
                : null,
          ),
        ),
        // Resultados de búsqueda
        if (_variationResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: context.colorBgTertiary,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.colorBorder),
            ),
            child: Column(
              children: _variationResults.take(6).map((r) => InkWell(
                onTap: () {
                  setState(() {
                    _selectedVariations.add(r);
                    _variationResults = [];
                  });
                  _variationSearchCtrl.clear();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(r['name'] as String,
                            style: TextStyle(color: context.colorTextPrimary, fontSize: 13)),
                      ),
                      Text(r['muscleGroup'] as String? ?? '',
                          style: TextStyle(color: context.colorTextMuted, fontSize: 11)),
                    ],
                  ),
                ),
              )).toList(),
            ),
          ),
        if (_selectedVariations.isEmpty && _variationResults.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Sin variaciones — busca un ejercicio para añadir',
                style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
          ),
      ],
    );
  }

  Widget _buildIsometricToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _isIsometric
            ? const Color(0xFF818cf8).withValues(alpha: 0.08)
            : context.colorBgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isIsometric
              ? const Color(0xFF818cf8).withValues(alpha: 0.3)
              : context.colorBorder,
        ),
      ),
      child: SwitchListTile(
        value: _isIsometric,
        onChanged: (v) => setState(() => _isIsometric = v),
        activeThumbColor: const Color(0xFF818cf8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Row(
          children: [
            const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF818cf8)),
            const SizedBox(width: 8),
            Text('Ejercicio isométrico',
                style: TextStyle(
                    color: context.colorTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        subtitle: Text(
          'Se mide por tiempo (segundos), no por kg y repeticiones',
          style: TextStyle(color: context.colorTextMuted, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildRankeableToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _isRankeable
            ? AppColors.accentPrimary.withValues(alpha: 0.08)
            : context.colorBgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isRankeable
              ? AppColors.accentPrimary.withValues(alpha: 0.3)
              : context.colorBorder,
        ),
      ),
      child: SwitchListTile(
        value: _isRankeable,
        onChanged: (v) => setState(() => _isRankeable = v),
        activeThumbColor: AppColors.accentPrimary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        title: Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 16, color: AppColors.accentPrimary),
            const SizedBox(width: 8),
            Text('Permitir en rankings',
                style: TextStyle(
                    color: context.colorTextPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500)),
          ],
        ),
        subtitle: Text(
          'Los usuarios podrán postular levantamientos de este ejercicio',
          style: TextStyle(color: context.colorTextMuted, fontSize: 11),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colorTextMuted),
        filled: true,
        fillColor: AppColors.bgSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      );
}

class _DialogLabel extends StatelessWidget {
  const _DialogLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) =>
      Text(text, style: TextStyle(color: context.colorTextSecondary, fontSize: 12, fontWeight: FontWeight.w600));
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({required this.value, required this.items, required this.onChanged});
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
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
          dropdownColor: AppColors.bgSecondary,
          style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
        ),
      ),
    );
  }
}




