import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
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
  String _selectedGroup = '';
  String _selectedDifficulty = '';

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
      setState(() {
        _exercises = list;
        _filtered = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _applyFilters() {
    final search = _searchController.text.toLowerCase();
    setState(() {
      _filtered = _exercises.where((e) {
        final nameMatch = search.isEmpty ||
            (e['name'] as String? ?? '').toLowerCase().contains(search);
        final groupMatch = _selectedGroup.isEmpty ||
            e['muscleGroup'] == _selectedGroup;
        final diffMatch = _selectedDifficulty.isEmpty ||
            e['difficulty'] == _selectedDifficulty;
        return nameMatch && groupMatch && diffMatch;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: const Text('Ejercicios'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
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
          color: AppColors.bgSecondary,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            children: [
              // Search field
              TextField(
                controller: _searchController,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Buscar ejercicio...',
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppColors.textMuted,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: AppColors.textMuted),
                          onPressed: () {
                            _searchController.clear();
                            _applyFilters();
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              // Muscle group filter
              SizedBox(
                height: 34,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _FilterChip(
                      label: 'Todos',
                      selected: _selectedGroup.isEmpty,
                      onTap: () {
                        setState(() => _selectedGroup = '');
                        _applyFilters();
                      },
                    ),
                    ...BodyMapData.muscleGroupDisplayName.entries.map((entry) {
                      final color = BodyMapData.muscleColors[entry.value] ??
                          AppColors.accentPrimary;
                      return _FilterChip(
                        label: entry.value,
                        selected: _selectedGroup == entry.key,
                        activeColor: color,
                        onTap: () {
                          setState(() => _selectedGroup =
                              _selectedGroup == entry.key ? '' : entry.key);
                          _applyFilters();
                        },
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Difficulty filter
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
              const SizedBox(height: 10),
            ],
          ),
        ),
        // Results count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                '${_filtered.length} ejercicios',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
                    childAspectRatio: 0.82,
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
