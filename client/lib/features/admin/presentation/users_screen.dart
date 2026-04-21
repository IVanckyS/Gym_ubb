import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/services/users_service.dart';
import '../../../shared/services/careers_service.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _service = UsersService();
  final _searchCtrl = TextEditingController();

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String _roleFilter = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _service.listUsers(
        search: _searchCtrl.text,
        role: _roleFilter,
      );
      setState(() {
        _users = users;
        _loading = false;
      });
    } on UsersException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Error de conexión';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorBgPrimary,
      appBar: AppBar(
        title: const Text('Gestión de usuarios'),
        leading: IconButton(
          icon: const Icon(Icons.home_outlined),
          tooltip: 'Inicio',
          onPressed: () => context.go('/home'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
            tooltip: 'Actualizar',
          ),
          SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showUserDialog(context),
        backgroundColor: AppColors.accentPrimary,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Nuevo usuario', style: TextStyle(color: Colors.white)),
      ),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      color: context.colorBgSecondary,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Row(
        children: [
          // Búsqueda
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              style: TextStyle(color: context.colorTextPrimary),
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email...',
                hintStyle: TextStyle(color: context.colorTextMuted),
                prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                filled: true,
                fillColor: AppColors.bgTertiary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: AppColors.accentPrimary),
                ),
              ),
              onSubmitted: (_) => _load(),
            ),
          ),
          SizedBox(width: 12),
          // Filtro por rol
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _roleFilter.isEmpty ? 'all' : _roleFilter,
              dropdownColor: AppColors.bgTertiary,
              style: TextStyle(color: context.colorTextPrimary, fontSize: 14),
              borderRadius: BorderRadius.circular(8),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('Todos')),
                DropdownMenuItem(value: 'student', child: Text('Estudiante')),
                DropdownMenuItem(value: 'professor', child: Text('Profesor')),
                DropdownMenuItem(value: 'staff', child: Text('Funcionario')),
                DropdownMenuItem(value: 'admin', child: Text('Admin')),
              ],
              onChanged: (val) {
                setState(() => _roleFilter = val == 'all' ? '' : (val ?? ''));
                _load();
              },
            ),
          ),
        ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.accentPrimary),
      );
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

    if (_users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, color: AppColors.textMuted, size: 48),
            SizedBox(height: 12),
            Text('No se encontraron usuarios', style: TextStyle(color: context.colorTextSecondary)),
          ],
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860),
        child: ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: _users.length,
      separatorBuilder: (context, index) => SizedBox(height: 8),
      itemBuilder: (_, i) => _UserCard(
        user: _users[i],
        onEdit: () => _showUserDialog(context, user: _users[i]),
        onToggleActive: () => _toggleActive(_users[i]),
        onResetPassword: () => _showResetPasswordDialog(context, _users[i]),
      ),
        ),
      ),
    );
  }

  Future<void> _toggleActive(Map<String, dynamic> user) async {
    final isActive = user['isActive'] as bool? ?? true;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          isActive ? 'Desactivar usuario' : 'Activar usuario',
          style: TextStyle(color: context.colorTextPrimary),
        ),
        content: Text(
          isActive
              ? '¿Desactivar a ${user['name']}? No podrá iniciar sesión.'
              : '¿Activar a ${user['name']}?',
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
      await _service.setActive(user['id'] as String, active: !isActive);
      _load();
    } on UsersException catch (e) {
      if (mounted) _showSnack(e.message, error: true);
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.accentSecondary : AppColors.accentGreen,
    ));
  }

  Future<void> _showUserDialog(BuildContext context,
      {Map<String, dynamic>? user}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => _UserDialog(service: _service, user: user),
    );
    if (result == true) _load();
  }

  Future<void> _showResetPasswordDialog(
      BuildContext context, Map<String, dynamic> user) async {
    final ctrl = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Resetear contraseña',
            style: TextStyle(color: context.colorTextPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Usuario: ${user['name']}',
                style: TextStyle(color: context.colorTextSecondary)),
            SizedBox(height: 16),
            TextField(
              controller: ctrl,
              obscureText: true,
              style: TextStyle(color: context.colorTextPrimary),
              decoration: const InputDecoration(
                labelText: 'Nueva contraseña',
                hintText: 'Mínimo 6 caracteres',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (result != true || ctrl.text.isEmpty) return;
    try {
      await _service.resetPassword(user['id'] as String, ctrl.text);
      if (mounted) _showSnack('Contraseña actualizada');
    } on UsersException catch (e) {
      if (mounted) _showSnack(e.message, error: true);
    }
  }
}

// ── Tarjeta de usuario ────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;
  final VoidCallback onResetPassword;

  const _UserCard({
    required this.user,
    required this.onEdit,
    required this.onToggleActive,
    required this.onResetPassword,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = user['isActive'] as bool? ?? true;
    final role = user['role'] as String? ?? 'student';

    return Container(
      decoration: BoxDecoration(
        color: context.colorBgSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _roleColor(role).withValues(alpha: 0.15),
          child: Text(
            (user['name'] as String? ?? '?')[0].toUpperCase(),
            style: TextStyle(
              color: _roleColor(role),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user['name'] as String? ?? '',
                style: TextStyle(
                  color: isActive ? AppColors.textPrimary : AppColors.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            _RoleBadge(role: role),
            if (!isActive) ...[
              SizedBox(width: 6),
              _StatusBadge(label: 'Inactivo', color: AppColors.accentSecondary),
            ],
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user['email'] as String? ?? '',
                style: TextStyle(color: context.colorTextSecondary, fontSize: 13),
              ),
              if (user['career'] != null && (user['career'] as String).isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.school_outlined, size: 12, color: AppColors.textMuted),
                      SizedBox(width: 4),
                      Text(
                        user['career'] as String,
                        style: TextStyle(color: context.colorTextMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          color: context.colorBgTertiary,
          icon: const Icon(Icons.more_vert, color: AppColors.textMuted),
          onSelected: (val) {
            if (val == 'edit') onEdit();
            if (val == 'toggle') onToggleActive();
            if (val == 'password') onResetPassword();
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(children: [
                Icon(Icons.edit_outlined, size: 18, color: context.colorTextPrimary),
                SizedBox(width: 8),
                Text('Editar', style: TextStyle(color: context.colorTextPrimary)),
              ]),
            ),
            PopupMenuItem(
              value: 'password',
              child: Row(children: [
                Icon(Icons.lock_reset, size: 18, color: context.colorTextPrimary),
                SizedBox(width: 8),
                Text('Resetear contraseña', style: TextStyle(color: context.colorTextPrimary)),
              ]),
            ),
            PopupMenuItem(
              value: 'toggle',
              child: Row(children: [
                Icon(
                  isActive ? Icons.block : Icons.check_circle_outline,
                  size: 18,
                  color: isActive ? AppColors.accentSecondary : AppColors.accentGreen,
                ),
                const SizedBox(width: 8),
                Text(
                  isActive ? 'Desactivar' : 'Activar',
                  style: TextStyle(
                    color: isActive ? AppColors.accentSecondary : AppColors.accentGreen,
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Color _roleColor(String role) => switch (role) {
        'admin' => AppColors.accentSecondary,
        'professor' => AppColors.accentPrimary,
        'staff' => AppColors.accentGreen,
        _ => AppColors.textSecondary,
      };
}

class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (role) {
      'admin' => ('Admin', AppColors.accentSecondary),
      'professor' => ('Profesor', AppColors.accentPrimary),
      'staff' => ('Funcionario', AppColors.accentGreen),
      _ => ('Estudiante', AppColors.textSecondary),
    };
    return _StatusBadge(label: label, color: color);
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Diálogo crear/editar usuario ──────────────────────────────────────────────

class _UserDialog extends StatefulWidget {
  final UsersService service;
  final Map<String, dynamic>? user;

  const _UserDialog({required this.service, this.user});

  @override
  State<_UserDialog> createState() => _UserDialogState();
}

class _UserDialogState extends State<_UserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  String _role = 'student';
  String? _selectedCareer;
  List<Map<String, dynamic>> _careers = [];
  bool _loading = false;
  bool _loadingCareers = true;
  String? _error;

  bool get _isEditing => widget.user != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameCtrl.text = widget.user!['name'] as String? ?? '';
      _emailCtrl.text = widget.user!['email'] as String? ?? '';
      _selectedCareer = widget.user!['career'] as String?;
      _role = widget.user!['role'] as String? ?? 'student';
    }
    _loadCareers();
  }

  Future<void> _loadCareers() async {
    try {
      final careers = await CareersService().listCareers();
      setState(() {
        _careers = careers;
        _loadingCareers = false;
        // Si la carrera actual del usuario no está en la lista (inactiva), la agregamos
        if (_isEditing && _selectedCareer != null) {
          final exists = _careers.any((c) => c['name'] == _selectedCareer);
          if (!exists) {
            _careers.insert(0, {'id': 'legacy', 'name': _selectedCareer, 'isActive': false});
          }
        }
      });
    } catch (_) {
      setState(() => _loadingCareers = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isEditing) {
        await widget.service.updateUser(
          widget.user!['id'] as String,
          name: _nameCtrl.text.trim(),
          career: _selectedCareer,
          role: _role,
        );
      } else {
        await widget.service.createUser(
          email: _emailCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          password: _passwordCtrl.text,
          role: _role,
          career: _selectedCareer,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on UsersException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _error = 'Error de conexión';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEditing ? 'Editar usuario' : 'Nuevo usuario',
        style: TextStyle(color: context.colorTextPrimary),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(_error!,
                      style: const TextStyle(color: AppColors.accentSecondary, fontSize: 13)),
                ),
              TextFormField(
                controller: _nameCtrl,
                style: TextStyle(color: context.colorTextPrimary),
                decoration: const InputDecoration(labelText: 'Nombre completo'),
                validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
              ),
              SizedBox(height: 12),
              if (!_isEditing) ...[
                TextFormField(
                  controller: _emailCtrl,
                  style: TextStyle(color: context.colorTextPrimary),
                  decoration: const InputDecoration(labelText: 'Correo institucional'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Requerido';
                    final email = v.trim().toLowerCase();
                    if (!email.endsWith('@alumnos.ubiobio.cl') &&
                        !email.endsWith('@ubiobio.cl')) {
                      return 'Solo @alumnos.ubiobio.cl o @ubiobio.cl';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: true,
                  style: TextStyle(color: context.colorTextPrimary),
                  decoration: const InputDecoration(labelText: 'Contraseña'),
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Mínimo 6 caracteres' : null,
                ),
                const SizedBox(height: 12),
              ],
              _loadingCareers
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: LinearProgressIndicator(color: AppColors.accentPrimary),
                    )
                  : DropdownButtonFormField<String?>(
                      initialValue: _selectedCareer,
                      dropdownColor: AppColors.bgTertiary,
                      style: TextStyle(color: context.colorTextPrimary),
                      decoration: const InputDecoration(labelText: 'Carrera (opcional)'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Sin carrera')),
                        ..._careers.map((c) => DropdownMenuItem(
                              value: c['name'] as String,
                              child: Text(c['name'] as String),
                            )),
                      ],
                      onChanged: (v) => setState(() => _selectedCareer = v),
                    ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _role,
                dropdownColor: AppColors.bgTertiary,
                style: TextStyle(color: context.colorTextPrimary),
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'student', child: Text('Estudiante')),
                  DropdownMenuItem(value: 'professor', child: Text('Profesor')),
                  DropdownMenuItem(value: 'staff', child: Text('Funcionario')),
                  DropdownMenuItem(value: 'admin', child: Text('Admin')),
                ],
                onChanged: (v) => setState(() => _role = v ?? 'student'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}






