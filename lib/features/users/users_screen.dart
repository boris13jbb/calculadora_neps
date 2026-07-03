import 'package:flutter/material.dart';

import '../../core/permissions/permission.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_input_decoration.dart';
import '../../core/widgets/app_material_list_tile.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/permission_gate.dart';
import '../../models/app_user.dart';
import '../../models/app_user_role.dart';
import '../../repositories/user_admin_repository.dart';
import '../../utils/username_auth_helper.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _adminRepo = UserAdminRepository.instance;
  final _searchController = TextEditingController();

  List<AppUser> _users = [];
  bool _loading = true;
  String? _error;
  String? _roleFilter;
  bool? _activeFilter;
  String? _actionUid;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final users = await _adminRepo.listUsers(
        search: _searchController.text,
        roleFilter: _roleFilter,
        activeOnly: _activeFilter,
      );
      if (mounted) {
        setState(() {
          _users = users;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  int get _activeCount => _users.where((u) => u.isActive).length;
  int get _inactiveCount => _users.length - _activeCount;
  int get _operarioCount =>
      _users.where((u) => u.role == AppUserRole.operario).length;

  Future<void> _showResetPasswordDialog(AppUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _ResetPasswordDialog(user: user),
    );
    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Contraseña reseteada para ${user.username}. '
            'Entregue la nueva contraseña de forma segura.',
          ),
        ),
      );
    }
  }

  Future<void> _showCreateDialog() async {
    final created = await showDialog<AppUser>(
      context: context,
      builder: (_) => const _UserFormDialog(isCreate: true),
    );
    if (created != null) {
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario creado correctamente.')),
        );
      }
    }
  }

  Future<void> _showEditDialog(AppUser user) async {
    final updated = await showDialog<AppUser>(
      context: context,
      builder: (_) => _UserFormDialog(isCreate: false, initial: user),
    );
    if (updated != null) {
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario actualizado.')),
        );
      }
    }
  }

  Future<bool> _confirm(String title, String message) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _toggleActive(AppUser user) async {
    final activate = !user.isActive;
    final ok = await _confirm(
      activate ? 'Activar usuario' : 'Desactivar usuario',
      activate
          ? '¿Activar a ${user.effectiveDisplayName}?'
          : '¿Desactivar a ${user.effectiveDisplayName}? No podrá iniciar sesión.',
    );
    if (!ok) return;

    setState(() => _actionUid = user.uid);
    try {
      if (activate) {
        await _adminRepo.enableUser(user.uid);
      } else {
        await _adminRepo.disableUser(user.uid);
      }
      await _loadUsers();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionUid = null);
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final d = date.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final hh = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  String _formatDateShort(DateTime? date) {
    if (date == null) return '—';
    final d = date.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _deleteUser(AppUser user) async {
    final ok = await _confirm(
      'Eliminar usuario',
      '¿Archivar a ${user.effectiveDisplayName}? Esta acción desactiva la cuenta.',
    );
    if (!ok) return;

    setState(() => _actionUid = user.uid);
    try {
      await _adminRepo.deleteUser(user.uid);
      await _loadUsers();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Usuario archivado.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _actionUid = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PermissionGate(
      permission: Permission.manageUsers,
      child: Scaffold(
        backgroundColor: AppColors.surface,
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(context),
              _buildStats(),
              _buildFilters(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Administración de usuarios',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: AppColors.textDark,
              ),
            ),
          ),
          FilledButton.icon(
            onPressed: _showCreateDialog,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Nuevo usuario'),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _StatCard(label: 'Total', value: '${_users.length}'),
          _StatCard(label: 'Activos', value: '$_activeCount'),
          _StatCard(label: 'Inactivos', value: '$_inactiveCount'),
          _StatCard(label: 'Operarios', value: '$_operarioCount'),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: _searchController,
              decoration: appInputDecoration('Buscar...').copyWith(
                labelText: 'Buscar',
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => _loadUsers(),
            ),
          ),
          DropdownButton<String?>(
            value: _roleFilter,
            hint: const Text('Rol'),
            items: [
              const DropdownMenuItem(
                  value: null, child: Text('Todos los roles')),
              ...AppUserRole.values.map(
                (role) => DropdownMenuItem(
                  value: role.code,
                  child: Text(role.label),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _roleFilter = value);
              _loadUsers();
            },
          ),
          DropdownButton<bool?>(
            value: _activeFilter,
            hint: const Text('Estado'),
            items: const [
              DropdownMenuItem(value: null, child: Text('Todos')),
              DropdownMenuItem(value: true, child: Text('Activos')),
              DropdownMenuItem(value: false, child: Text('Inactivos')),
            ],
            onChanged: (value) {
              setState(() => _activeFilter = value);
              _loadUsers();
            },
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Error al cargar usuarios',
        message: _error!,
        iconColor: AppColors.danger,
        actions: [
          EmptyStateAction(
            label: 'Reintentar',
            icon: Icons.refresh,
            onPressed: _loadUsers,
          ),
        ],
      );
    }
    if (_users.isEmpty) {
      return const EmptyState(
        icon: Icons.people_outline,
        title: 'Sin usuarios',
        message: 'No hay usuarios que coincidan con los filtros.',
      );
    }

    final isWide = MediaQuery.sizeOf(context).width >= 900;
    if (isWide) return _buildTable();
    return _buildCards();
  }

  Widget _buildTable() {
    final dateFormat = _formatDate;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DataTable(
        headingRowColor: WidgetStateProperty.all(AppColors.surfaceAlt),
        columns: const [
          DataColumn(label: Text('Usuario')),
          DataColumn(label: Text('Nombre')),
          DataColumn(label: Text('Rol')),
          DataColumn(label: Text('Estado')),
          DataColumn(label: Text('Último acceso')),
          DataColumn(label: Text('Acciones')),
        ],
        rows: _users.map((user) {
          final busy = _actionUid == user.uid;
          return DataRow(cells: [
            DataCell(Text(user.username)),
            DataCell(Text(user.effectiveDisplayName)),
            DataCell(_RoleBadge(role: user.role)),
            DataCell(_StatusBadge(active: user.isActive)),
            DataCell(Text(dateFormat(user.lastLoginAt))),
            DataCell(
              busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Editar',
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _showEditDialog(user),
                        ),
                        IconButton(
                          tooltip: 'Resetear contraseña',
                          icon: const Icon(Icons.lock_reset_outlined),
                          onPressed: () => _showResetPasswordDialog(user),
                        ),
                        IconButton(
                          tooltip: user.isActive ? 'Desactivar' : 'Activar',
                          icon: Icon(
                            user.isActive
                                ? Icons.pause_circle_outline
                                : Icons.play_circle_outline,
                          ),
                          onPressed: () => _toggleActive(user),
                        ),
                        IconButton(
                          tooltip: 'Archivar',
                          icon: const Icon(Icons.archive_outlined),
                          onPressed: () => _deleteUser(user),
                        ),
                      ],
                    ),
            ),
          ]);
        }).toList(),
      ),
    );
  }

  Widget _buildCards() {
    final dateFormat = _formatDateShort;
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final user = _users[index];
        final busy = _actionUid == user.uid;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.username,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    _RoleBadge(role: user.role),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  user.effectiveDisplayName,
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _StatusBadge(active: user.isActive),
                    const Spacer(),
                    if (user.createdAt != null)
                      Text(
                        'Creado: ${dateFormat(user.createdAt)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                if (busy)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => _showEditDialog(user),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Editar'),
                      ),
                      TextButton.icon(
                        onPressed: () => _showResetPasswordDialog(user),
                        icon: const Icon(Icons.lock_reset_outlined),
                        label: const Text('Reset'),
                      ),
                      TextButton.icon(
                        onPressed: () => _toggleActive(user),
                        icon: Icon(
                          user.isActive
                              ? Icons.pause_circle_outline
                              : Icons.play_circle_outline,
                        ),
                        label: Text(user.isActive ? 'Desactivar' : 'Activar'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final AppUserRole role;

  Color get _color {
    switch (role) {
      case AppUserRole.superAdmin:
        return Colors.deepPurple;
      case AppUserRole.admin:
        return Colors.blue;
      case AppUserRole.supervisor:
        return Colors.green;
      case AppUserRole.operario:
        return Colors.grey;
      case AppUserRole.gerencia:
        return const Color(0xFFB8860B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          color: _color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (active ? AppColors.primaryGreen : AppColors.danger)
            .withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'Activo' : 'Inactivo',
        style: TextStyle(
          color: active ? AppColors.primaryGreen : AppColors.danger,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({required this.isCreate, this.initial});

  final bool isCreate;
  final AppUser? initial;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _DialogFormField extends StatelessWidget {
  const _DialogFormField({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _adminRepo = UserAdminRepository.instance;
  late final TextEditingController _usernameController;
  late final TextEditingController _nameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late AppUserRole _role;
  late bool _isActive;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: widget.initial?.username);
    _nameController =
        TextEditingController(text: widget.initial?.displayName ?? '');
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _role = widget.initial?.role ?? AppUserRole.operario;
    _isActive = widget.initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  List<AppUserRole> get _assignableRoles {
    return AppUserRole.values
        .where((role) => role != AppUserRole.superAdmin)
        .toList();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      AppUser result;
      if (widget.isCreate) {
        result = await _adminRepo.createUser(
          username: _usernameController.text,
          password: _passwordController.text,
          displayName: _nameController.text,
          role: _role,
          isActive: _isActive,
        );
      } else {
        result = await _adminRepo.updateUser(
          uid: widget.initial!.uid,
          displayName: _nameController.text,
          role: _role,
          isActive: _isActive,
        );
      }
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isCreate ? 'Nuevo usuario' : 'Editar usuario'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.isCreate) ...[
                  _DialogFormField(
                    label: 'Usuario',
                    child: TextFormField(
                      controller: _usernameController,
                      autocorrect: false,
                      decoration: appInputDecoration('operario01'),
                      validator:
                          UsernameAuthHelper.validateUsernameOrEmailInput,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  _DialogFormField(
                    label: 'Usuario',
                    child: Text(
                      widget.initial?.username ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                _DialogFormField(
                  label: 'Nombre (opcional)',
                  child: TextFormField(
                    controller: _nameController,
                    decoration: appInputDecoration('Nombre opcional'),
                  ),
                ),
                if (widget.isCreate) ...[
                  const SizedBox(height: 12),
                  _DialogFormField(
                    label: 'Contraseña temporal',
                    child: TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: appInputDecoration('Mínimo 8 caracteres'),
                      validator: (v) =>
                          (v ?? '').length < 8 ? 'Mínimo 8 caracteres' : null,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DialogFormField(
                    label: 'Confirmar contraseña',
                    child: TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: appInputDecoration('Repetir contraseña'),
                      validator: (v) => v != _passwordController.text
                          ? 'Las contraseñas no coinciden'
                          : null,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'La contraseña temporal debe entregarse al usuario '
                      'de forma segura. No se guardará en el sistema.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _DialogFormField(
                  label: 'Rol',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _assignableRoles.map((role) {
                      final selected = _role == role;
                      return ChoiceChip(
                        label: Text(role.label),
                        selected: selected,
                        onSelected: _loading
                            ? null
                            : (_) => setState(() => _role = role),
                      );
                    }).toList(),
                  ),
                ),
                AppMaterialSwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Usuario activo'),
                  value: _isActive,
                  onChanged: _loading
                      ? null
                      : (value) => setState(() => _isActive = value),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.isCreate ? 'Crear' : 'Guardar'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.user});

  final AppUser user;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _adminRepo = UserAdminRepository.instance;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      await _adminRepo.resetUserPassword(
        uid: widget.user.uid,
        newPassword: _passwordController.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Resetear contraseña'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Usuario: ${widget.user.username}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              _DialogFormField(
                label: 'Nueva contraseña',
                child: TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: appInputDecoration('Mínimo 8 caracteres'),
                  validator: (v) =>
                      (v ?? '').length < 8 ? 'Mínimo 8 caracteres' : null,
                ),
              ),
              const SizedBox(height: 12),
              _DialogFormField(
                label: 'Confirmar nueva contraseña',
                child: TextFormField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: appInputDecoration('Repetir contraseña'),
                  validator: (v) => v != _passwordController.text
                      ? 'Las contraseñas no coinciden'
                      : null,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'La nueva contraseña debe entregarse al usuario de forma '
                'segura. No se guardará en el sistema.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
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
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Resetear'),
        ),
      ],
    );
  }
}
