import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/weight_utils.dart';
import '../../../features/profile/providers/weight_unit_notifier.dart';
import '../../../shared/services/exercises_service.dart';
import '../data/lift_submissions_service.dart';
import 'package:provider/provider.dart';

class PostulateRankingScreen extends StatefulWidget {
  const PostulateRankingScreen({super.key});

  @override
  State<PostulateRankingScreen> createState() => _PostulateRankingScreenState();
}

class _PostulateRankingScreenState extends State<PostulateRankingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = LiftSubmissionsService();
  final _exService = ExercisesService();

  // Campos del formulario
  Map<String, dynamic>? _selectedExercise;
  final _weightCtrl = TextEditingController();
  int _reps = 1;
  final _locationCtrl = TextEditingController();
  bool _wasWitnessed = false;
  final _witnessCtrl = TextEditingController();
  final _videoUrlCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  // Búsqueda de ejercicios
  final _exSearchCtrl = TextEditingController();
  List<Map<String, dynamic>> _exResults = [];
  bool _searchingEx = false;
  Timer? _exDebounce;

  WeightUnit _unit = WeightUnit.kg;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _unit = context.read<WeightUnitNotifier>().unit;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _locationCtrl.dispose();
    _witnessCtrl.dispose();
    _videoUrlCtrl.dispose();
    _descCtrl.dispose();
    _exSearchCtrl.dispose();
    _exDebounce?.cancel();
    super.dispose();
  }

  Future<void> _searchExercises(String q) async {
    _exDebounce?.cancel();
    if (q.trim().isEmpty) {
      setState(() { _exResults = []; _searchingEx = false; });
      return;
    }
    _exDebounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() => _searchingEx = true);
      try {
        // Solo ejercicios rankeables
        final all = await _exService.searchExercises(q.trim());
        if (!mounted) return;
        setState(() { _exResults = all; _searchingEx = false; });
      } catch (_) {
        if (mounted) setState(() => _searchingEx = false);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedExercise == null) {
      _showError('Selecciona un ejercicio');
      return;
    }
    if (_videoUrlCtrl.text.trim().isEmpty) {
      _showError('El video es obligatorio');
      return;
    }

    setState(() => _submitting = true);
    try {
      final displayWeight = double.tryParse(_weightCtrl.text.trim()) ?? 0;
      final weightKg = fromDisplayUnit(displayWeight, _unit);

      await _service.create({
        'exerciseId': _selectedExercise!['id'],
        'weightKg': weightKg,
        'reps': _reps,
        'videoUrl': _videoUrlCtrl.text.trim(),
        'locationName': _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
        'wasWitnessed': _wasWitnessed,
        'witnessName': _wasWitnessed && _witnessCtrl.text.trim().isNotEmpty
            ? _witnessCtrl.text.trim()
            : null,
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solicitud enviada. Será revisada por un moderador.'),
          backgroundColor: AppColors.accentGreen,
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) _showError(e.toString());
      setState(() => _submitting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.accentSecondary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        title: const Text('Postular al ranking'),
        actions: [
          if (_submitting)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.accentPrimary),
                ),
              ),
            )
          else
            TextButton(
              onPressed: _submit,
              child: const Text('Enviar',
                  style: TextStyle(
                      color: AppColors.accentPrimary, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SectionLabel('Ejercicio'),
            const SizedBox(height: 8),
            _buildExerciseSearch(),
            const SizedBox(height: 20),

            _SectionLabel('Levantamiento'),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  style: TextStyle(color: context.colorTextPrimary),
                  decoration: _deco('Peso (${_unit.name})'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    if (double.tryParse(v.trim()) == null || double.parse(v.trim()) <= 0) {
                      return 'Peso inválido';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Reps', style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    _RepStepper(
                      value: _reps,
                      onChanged: (v) => setState(() => _reps = v),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 20),

            _SectionLabel('Video (obligatorio)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _videoUrlCtrl,
              style: TextStyle(color: context.colorTextPrimary),
              decoration: _deco('URL del video (YouTube, Drive, etc.)').copyWith(
                prefixIcon: Icon(Icons.videocam_outlined, color: context.colorTextMuted),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El video es obligatorio' : null,
            ),
            const SizedBox(height: 20),

            _SectionLabel('Ubicación (opcional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _locationCtrl,
              style: TextStyle(color: context.colorTextPrimary),
              decoration: _deco('Ej. Gimnasio UBB Concepción').copyWith(
                prefixIcon: Icon(Icons.place_outlined, color: context.colorTextMuted),
              ),
            ),
            const SizedBox(height: 20),

            _SectionLabel('Testigo'),
            const SizedBox(height: 8),
            SwitchListTile(
              value: _wasWitnessed,
              onChanged: (v) => setState(() => _wasWitnessed = v),
              title: Text('Fue presenciado por alguien',
                  style: TextStyle(color: context.colorTextPrimary, fontSize: 14)),
              activeThumbColor: AppColors.accentPrimary,
              contentPadding: EdgeInsets.zero,
            ),
            if (_wasWitnessed) ...[
              const SizedBox(height: 8),
              TextFormField(
                controller: _witnessCtrl,
                style: TextStyle(color: context.colorTextPrimary),
                decoration: _deco('Nombre del testigo'),
              ),
            ],
            const SizedBox(height: 20),

            _SectionLabel('Descripción (opcional)'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descCtrl,
              style: TextStyle(color: context.colorTextPrimary),
              maxLines: 3,
              decoration: _deco('Detalles del levantamiento, condiciones, etc.'),
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: const Icon(Icons.send_rounded),
                label: const Text('Enviar solicitud'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentPrimary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_selectedExercise != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.accentPrimary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.accentPrimary.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded,
                    color: AppColors.accentPrimary, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedExercise!['name'] as String,
                          style: TextStyle(
                              color: context.colorTextPrimary,
                              fontWeight: FontWeight.w600,
                              fontSize: 14)),
                      Text(_selectedExercise!['muscleGroup'] as String? ?? '',
                          style: TextStyle(
                              color: context.colorTextMuted, fontSize: 11)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedExercise = null),
                  child:
                      Icon(Icons.close, color: context.colorTextMuted, size: 18),
                ),
              ],
            ),
          )
        else ...[
          TextField(
            controller: _exSearchCtrl,
            onChanged: _searchExercises,
            style: TextStyle(color: context.colorTextPrimary),
            decoration: _deco('Buscar ejercicio rankeable...').copyWith(
              prefixIcon: _searchingEx
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.accentPrimary),
                      ))
                  : Icon(Icons.search_rounded, color: context.colorTextMuted),
            ),
          ),
          if (_exResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: context.colorBgTertiary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.colorBorder),
              ),
              child: Column(
                children: _exResults.take(8).map((ex) => InkWell(
                  onTap: () {
                    setState(() {
                      _selectedExercise = ex;
                      _exResults = [];
                    });
                    _exSearchCtrl.clear();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events_outlined,
                            size: 16, color: AppColors.accentPrimary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(ex['name'] as String,
                              style: TextStyle(
                                  color: context.colorTextPrimary, fontSize: 13)),
                        ),
                        Text(ex['muscleGroup'] as String? ?? '',
                            style: TextStyle(
                                color: context.colorTextMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                )).toList(),
              ),
            ),
          if (_exSearchCtrl.text.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Solo ejercicios marcados como rankeables por el admin',
                style: TextStyle(color: context.colorTextMuted, fontSize: 11),
              ),
            ),
        ],
      ],
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: context.colorTextMuted),
        filled: true,
        fillColor: context.colorBgSecondary,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: context.colorBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: const BorderSide(color: AppColors.accentPrimary)),
      );
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            color: context.colorTextSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5),
      );
}

class _RepStepper extends StatelessWidget {
  const _RepStepper({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.colorBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 16),
            color: context.colorTextMuted,
            onPressed: value > 1 ? () => onChanged(value - 1) : null,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
          Text('$value',
              style: TextStyle(
                  color: context.colorTextPrimary, fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.add, size: 16),
            color: context.colorTextMuted,
            onPressed: () => onChanged(value + 1),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
