import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/error_handler.dart';
import '../../core/permissions/permission.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_input_decoration.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/permission_gate.dart';
import '../../models/role_definition.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/role_repository.dart';

/// Administración de roles parametrizables (solo super_admin).
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});

  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  final _repo = RoleRepository.instance;
  List<RoleDefinition> _roles = [];
  final Map<String, int> _userCounts = {};
  bool _loading = true;
  String? _error;

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
      final roles = await _repo.listRoles(ensureBase: true);
      final counts = <String, int>{};
      for (final role in roles) {
        counts[role.code] = await _repo.countUsersWithRole(role.code);
      }
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _userCounts
          ..clear()
          ..addAll(counts);
        _loading = false;
      });
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'loadRoles');
      if (!mounted) return;
      setState(() {
        _error = ErrorHandler.userMessage(error);
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({RoleDefinition? initial}) async {
    final saved = await showDialog<RoleDefinition>(
      context: context,
      builder: (_) => _RoleFormDialog(initial: initial),
    );
    if (saved != null) await _load();
  }

  Future<void> _toggleActive(RoleDefinition role) async {
    if (role.isSuperAdmin) return;
    try {
      if (role.isActive) {
        await _repo.deactivateRole(role.code);
      } else {
        await _repo.activateRole(role.code);
      }
      await _load();
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'toggleRole');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.userMessage(error))),
      );
    }
  }

  Future<void> _deleteRole(RoleDefinition role) async {
    final count = _userCounts[role.code] ?? 0;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar rol'),
        content: Text(
          count > 0
              ? 'El rol "${role.name}" tiene $count usuario(s). '
                  'No se puede eliminar; desactívelo.'
              : '¿Eliminar el rol personalizado "${role.name}"? '
                  'La eliminación la valida el servidor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          if (count == 0)
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Eliminar'),
            ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _repo.deleteRole(role.code);
      await _load();
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'deleteRole');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.userMessage(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final profile = auth.profile;

    return PermissionGate(
      permission: Permission.manageUsers,
      child: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Roles y permisos',
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                    ),
                  ),
                  if (profile?.canManageRoles == true)
                    FilledButton.icon(
                      onPressed: _loading ? null : () => _openEditor(),
                      icon: const Icon(Icons.add),
                      label: const Text('Nuevo rol'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Los permisos se resuelven desde la definición del rol. '
                'super_admin no es editable ni asignable.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.muted,
                    ),
              ),
              const SizedBox(height: 16),
              if (_loading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator()))
              else if (_error != null)
                Expanded(
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: 'No se pudieron cargar los roles',
                    message: _error!,
                    actions: [
                      EmptyStateAction(label: 'Reintentar', onPressed: _load),
                    ],
                  ),
                )
              else if (_roles.isEmpty)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.security_outlined,
                    title: 'Sin roles',
                    message: 'No hay roles configurados.',
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    itemCount: _roles.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final role = _roles[index];
                      final count = _userCounts[role.code] ?? 0;
                      return Card(
                        child: ListTile(
                          title: Text(
                            role.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          subtitle: Text(
                            '${role.code} · '
                            '${role.isActive ? 'Activo' : 'Inactivo'} · '
                            '${role.permissions.length} permisos · '
                            '$count usuario(s) · '
                            '${role.isSystem ? 'Sistema' : 'Personalizado'}',
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              if (!role.isSuperAdmin)
                                IconButton(
                                  tooltip: 'Editar',
                                  onPressed: () => _openEditor(initial: role),
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              if (!role.isSuperAdmin)
                                IconButton(
                                  tooltip:
                                      role.isActive ? 'Desactivar' : 'Activar',
                                  onPressed: () => _toggleActive(role),
                                  icon: Icon(
                                    role.isActive
                                        ? Icons.toggle_on
                                        : Icons.toggle_off_outlined,
                                  ),
                                ),
                              if (!role.isSystem && !role.isSuperAdmin)
                                IconButton(
                                  tooltip: 'Eliminar',
                                  onPressed: () => _deleteRole(role),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleFormDialog extends StatefulWidget {
  const _RoleFormDialog({this.initial});

  final RoleDefinition? initial;

  @override
  State<_RoleFormDialog> createState() => _RoleFormDialogState();
}

class _RoleFormDialogState extends State<_RoleFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repo = RoleRepository.instance;
  late final TextEditingController _nameController;
  late final TextEditingController _codeController;
  late final TextEditingController _descriptionController;
  late Set<Permission> _selected;
  late bool _isActive;
  bool _loading = false;

  bool get _isEdit => widget.initial != null;
  bool get _isSystem => widget.initial?.isSystem == true;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _codeController = TextEditingController(text: initial?.code ?? '');
    _descriptionController =
        TextEditingController(text: initial?.description ?? '');
    _selected = Set<Permission>.from(initial?.permissions ?? {});
    _isActive = initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final code = _isEdit
          ? widget.initial!.code
          : _codeController.text.trim().toLowerCase();
      final draft = RoleDefinition(
        code: code,
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        permissions: _selected,
        isActive: _isActive,
        isSystem: widget.initial?.isSystem ?? false,
        isAssignable: widget.initial?.isAssignable ?? true,
        sortOrder: widget.initial?.sortOrder ?? 60,
      );
      final saved = _isEdit
          ? await _repo.updateRole(draft)
          : await _repo.createRole(draft);
      if (mounted) Navigator.pop(context, saved);
    } catch (error, stack) {
      ErrorHandler.log(error, stack, 'roleFormSubmit');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.userMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar rol' : 'Nuevo rol'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: appInputDecoration('Nombre'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _codeController,
                  enabled: !_isEdit,
                  decoration: appInputDecoration('código_rol'),
                  validator: _isEdit ? null : RoleDefinition.validateCode,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  decoration: appInputDecoration('Descripción'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activo'),
                  value: _isActive,
                  onChanged: _isSystem && widget.initial?.isSuperAdmin == true
                      ? null
                      : (v) => setState(() => _isActive = v),
                ),
                const SizedBox(height: 8),
                Text(
                  'Permisos',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 8),
                ...PermissionCatalog.groups.entries.map((entry) {
                  return ExpansionTile(
                    initiallyExpanded: true,
                    title: Text(entry.key),
                    children: entry.value.map((permission) {
                      final checked = _selected.contains(permission);
                      return CheckboxListTile(
                        value: checked,
                        title: Text(PermissionCatalog.labelOf(permission)),
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(permission);
                            } else {
                              _selected.remove(permission);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                }),
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
              : Text(_isEdit ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}
