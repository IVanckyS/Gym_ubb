import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/careers_service.dart';

class CareersScreen extends StatefulWidget {
  const CareersScreen({super.key});

  @override
  State<CareersScreen> createState() => _CareersScreenState();
}

class _CareersScreenState extends State<CareersScreen> {
  final _service = CareersService();
  List<Map<String, dynamic>> _careers = [];
  bool _loading = true;
  String? _error;
  bool _showInactive = false;

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
      final careers = await _service.listCareers(onlyActive: !_showInactive);
      setState(() {
        _careers = careers;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Error al cargar carreras';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        title: const Text('Gestión de carreras'),
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Inicio',
          onPressed: () => context.go('/home'),
        ),
        actions: [
          Row(
            children: [
              Text('Ver inactivas', style: TextStyle(color: context.colorTextSecondary, fontSize: 13)),
              Switch(
                value: _showInactive,
                activeThumbColor: AppColors.accentPrimary,
                onChanged: (v) {
                  setState(() => _showInactive = v);
                  _load();
                },
              ),
            ],
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCareerDialog(context),
        backgroundColor: AppColors.accentPrimary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva carrera', style: TextStyle(color: Colors.white)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.accentPrimary));
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.accentSecondary, size: 48),
            SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.colorTextSecondary)),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _load, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_careers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.school_outlined, color: AppColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text('No hay carreras registradas', style: TextStyle(color: context.colorTextSecondary)),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: _careers.length,
          separatorBuilder: (context, index) => SizedBox(height: 8),
          itemBuilder: (context, i) {
            final career = _careers[i];
            final isActive = career['isActive'] as bool? ?? true;
            return Container(
              decoration: BoxDecoration(
                color: context.colorBgSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? AppColors.border : AppColors.textMuted.withValues(alpha: 0.3),
                ),
              ),
              child: ListTile(
                leading: Icon(
                  Icons.school,
                  color: isActive ? AppColors.accentPrimary : AppColors.textMuted,
                ),
                title: Text(
                  career['name'] as String? ?? '',
                  style: TextStyle(
                    color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                subtitle: isActive
                    ? null
                    : Text('Inactiva', style: TextStyle(color: context.colorTextMuted, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                      tooltip: 'Renombrar',
                      onPressed: () => _showCareerDialog(context, career: career),
                    ),
                    IconButton(
                      icon: Icon(
                        isActive ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: isActive ? AppColors.accentSecondary : AppColors.accentGreen,
                        size: 20,
                      ),
                      tooltip: isActive ? 'Desactivar' : 'Activar',
                      onPressed: () => _toggle(career),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _toggle(Map<String, dynamic> career) async {
    final isActive = career['isActive'] as bool? ?? true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isActive ? 'Desactivar carrera' : 'Activar carrera',
          style: TextStyle(color: context.colorTextPrimary),
        ),
        content: Text(
          isActive
              ? 'La carrera "${career['name']}" no aparecerá al crear usuarios.'
              : 'La carrera "${career['name']}" volverá a estar disponible.',
          style: TextStyle(color: context.colorTextSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isActive ? AppColors.accentSecondary : AppColors.accentGreen,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(isActive ? 'Desactivar' : 'Activar'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.toggleCareer(career['id'] as String);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.accentSecondary),
        );
      }
    }
  }

  Future<void> _showCareerDialog(BuildContext context, {Map<String, dynamic>? career}) async {
    final ctrl = TextEditingController(text: career?['name'] as String? ?? '');
    final formKey = GlobalKey<FormState>();
    String? error;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            career == null ? 'Nueva carrera' : 'Renombrar carrera',
            style: TextStyle(color: context.colorTextPrimary),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(error!, style: const TextStyle(color: AppColors.accentSecondary, fontSize: 13)),
                  ),
                TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  style: TextStyle(color: context.colorTextPrimary),
                  decoration: const InputDecoration(
                    labelText: 'Nombre de la carrera',
                    hintText: 'Ej: Ingeniería Civil Informática',
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'El nombre es requerido' : null,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                try {
                  if (career == null) {
                    await _service.createCareer(ctrl.text.trim());
                  } else {
                    await _service.updateCareer(career['id'] as String, ctrl.text.trim());
                  }
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  setDialogState(() => error = e.toString());
                }
              },
              child: Text(career == null ? 'Crear' : 'Guardar'),
            ),
          ],
        ),
      ),
    );

    if (result == true) _load();
  }
}






