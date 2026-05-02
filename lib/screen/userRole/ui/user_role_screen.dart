import 'package:crm_app/modals/modals.dart' show AppConstants, AppRole, AppUser;
import 'package:crm_app/screen/userRole/cubit/user_role.dart' show UserRoleCubit;
import 'package:crm_app/screen/userRole/cubit/user_role_state.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart'
    show
        FormActionButtons,
        CrmTextField,
        LoadingState,
        EmptyState,
        showApiSnack,
        ErrorState,
        UserAvatar,
        StatusBadge,
        CrmDropdown;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'dart:io' show File;
import 'dart:typed_data' show Uint8List;
import 'package:file_picker/file_picker.dart';

// ══════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════
class UserRoleScreen extends StatelessWidget {
  const UserRoleScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => UserRoleCubit()..loadAll(),
        child: const _UserRoleView(),
      );
}

class _UserRoleView extends StatefulWidget {
  const _UserRoleView();

  @override
  State<_UserRoleView> createState() => _UserRoleViewState();
}

class _UserRoleViewState extends State<_UserRoleView>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UserRoleCubit, UserRoleState>(
      listener: (ctx, state) {
        if (state is UserRoleActionSuccess) showApiSnack(ctx, state.message);
      },
      builder: (context, state) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Users & Roles'),
          backgroundColor: AppColors.surface,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppColors.divider),
          ),
        ),
        body: Column(children: [
          // ── Action Buttons ──────────────────────────────────
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _openAddUser(context, state),
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Add User'),
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _openCreateRole(context),
                  icon: const Icon(Icons.add_moderator_outlined, size: 18),
                  label: const Text('Create Role'),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12)),
                ),
              ),
            ]),
          ),

          // ── Tabs ────────────────────────────────────────────
          Container(
            color: AppColors.surface,
            child: TabBar(
              controller: _tab,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicatorColor: AppColors.primary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 14),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.group_outlined, size: 16),
                      const SizedBox(width: 6),
                      const Text('Users'),
                      const SizedBox(width: 6),
                      _badge(
                          '${state is UserRoleLoaded ? state.users.length : 0}'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined, size: 16),
                      const SizedBox(width: 6),
                      const Text('Roles'),
                      const SizedBox(width: 6),
                      _badge(
                          '${state is UserRoleLoaded ? state.roles.length : 0}'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _UsersTab(
                  state: state,
                  onEditUser: (ctx, user) => _openEditUser(ctx, user, state),
                ),
                _RolesTab(
                  state: state,
                  onEditRole: (ctx, role) => _openCreateRole(ctx, role),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _badge(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
        decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(10)),
        child: Text(t,
            style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.w700)),
      );

  void _openAddUser(BuildContext ctx, UserRoleState state) {
    final roles = state is UserRoleLoaded ? state.roles : <AppRole>[];
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: ctx.read<UserRoleCubit>(),
        child: _AddUserModal(roles: roles),
      ),
    );
  }

  void _openEditUser(BuildContext ctx, AppUser user, UserRoleState state) {
    final roles = state is UserRoleLoaded ? state.roles : <AppRole>[];
    showModalBottomSheet(
      context: ctx,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BlocProvider.value(
        value: ctx.read<UserRoleCubit>(),
        child: _EditUserModal(user: user, roles: roles),
      ),
    );
  }

  void _openCreateRole(BuildContext ctx, [AppRole? role]) =>
      showModalBottomSheet(
        context: ctx,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BlocProvider.value(
          value: ctx.read<UserRoleCubit>(),
          child: _CreateRoleModal(role: role),
        ),
      );
}

// ─── Users Tab ────────────────────────────────────────────────
class _UsersTab extends StatefulWidget {
  final UserRoleState state;
  final void Function(BuildContext, AppUser) onEditUser;
  const _UsersTab({required this.state, required this.onEditUser});

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  int _page = 1;
  static const int _pageSize = 10;

  @override
  void didUpdateWidget(covariant _UsersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state is! UserRoleLoaded) return;
    final users = (widget.state as UserRoleLoaded).users;
    final totalPages = users.isEmpty ? 1 : (users.length / _pageSize).ceil();
    if (_page > totalPages) {
      setState(() => _page = totalPages);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final state = widget.state;
    if (state is UserRoleLoading) {
      return const LoadingState(message: 'Loading users...');
    }
    if (state is UserRoleError) {
      return ErrorState(
          message: state.message,
          onRetry: () => ctx.read<UserRoleCubit>().loadAll());
    }
    if (state is! UserRoleLoaded) {
      return const EmptyState(
          message: 'No users', icon: Icons.group_outlined);
    }

    final users = state.users;
    if (users.isEmpty) {
      return const EmptyState(
          message: 'No users yet. Add one!', icon: Icons.group_outlined);
    }

    final totalPages = (users.length / _pageSize).ceil();
    final safePage = _page.clamp(1, totalPages);
    final start = (safePage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, users.length);
    final visibleUsers = users.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => ctx.read<UserRoleCubit>().loadAll(),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visibleUsers.length,
              itemBuilder: (listCtx, i) => _UserCard(
                user: visibleUsers[i],
                roles: state.roles,
                onEdit: () => widget.onEditUser(listCtx, visibleUsers[i]),
                onDelete: () async {
                  final err =
                      await ctx.read<UserRoleCubit>().deleteUser(visibleUsers[i].id);
                  if (err != null && ctx.mounted) {
                    showApiSnack(ctx, err, isError: true);
                  }
                },
              ),
            ),
          ),
        ),
        _ListPaginationBar(
          page: safePage,
          totalPages: totalPages,
          totalItems: users.length,
          pageSize: _pageSize,
          onPrev: safePage > 1 ? () => setState(() => _page -= 1) : null,
          onNext: safePage < totalPages ? () => setState(() => _page += 1) : null,
        ),
      ],
    );
  }
}

class _UserCard extends StatelessWidget {
  final AppUser user;
  final List<AppRole> roles;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.roles,
    required this.onEdit,
    required this.onDelete,
  });

  // BUG FIX: role field is an ObjectId string — look up the display name
  // from the roles list. Falls back to the raw value if not found.
  String get _roleName {
    try {
      return roles.firstWhere((r) => r.id == user.role).name;
    } catch (_) {
      return user.role;
    }
  }

  @override
  Widget build(BuildContext ctx) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child: Row(children: [
          UserAvatar(user: user, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                  Text(user.email,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                          color: AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: Text(_roleName,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    StatusBadge(status: user.status),
                  ]),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (user.dob != null)
              Text(DateFormat('dd MMM yy').format(user.dob!),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Row(mainAxisSize: MainAxisSize.min, children: [
              GestureDetector(
                  onTap: onEdit,
                  child: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.textHint)),
              const SizedBox(width: 12),
              GestureDetector(
                  onTap: onDelete,
                  child: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.textHint)),
            ]),
          ]),
        ]),
      );
}

// ─── Roles Tab ────────────────────────────────────────────────
class _RolesTab extends StatefulWidget {
  final UserRoleState state;
  final void Function(BuildContext, AppRole) onEditRole;
  const _RolesTab({required this.state, required this.onEditRole});

  @override
  State<_RolesTab> createState() => _RolesTabState();
}

class _RolesTabState extends State<_RolesTab> {
  int _page = 1;
  static const int _pageSize = 10;

  @override
  void didUpdateWidget(covariant _RolesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state is! UserRoleLoaded) return;
    final roles = (widget.state as UserRoleLoaded).roles;
    final totalPages = roles.isEmpty ? 1 : (roles.length / _pageSize).ceil();
    if (_page > totalPages) {
      setState(() => _page = totalPages);
    }
  }

  @override
  Widget build(BuildContext ctx) {
    final state = widget.state;
    if (state is! UserRoleLoaded) {
      return const EmptyState(
          message: 'No roles', icon: Icons.shield_outlined);
    }

    final roles = state.roles;
    if (roles.isEmpty) {
      return const EmptyState(
          message: 'No roles yet. Create one!',
          icon: Icons.shield_outlined);
    }

    final totalPages = (roles.length / _pageSize).ceil();
    final safePage = _page.clamp(1, totalPages);
    final start = (safePage - 1) * _pageSize;
    final end = (start + _pageSize).clamp(0, roles.length);
    final visibleRoles = roles.sublist(start, end);

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: visibleRoles.length,
            itemBuilder: (listCtx, i) => _RoleCard(
              role: visibleRoles[i],
              onDelete: () async {
                final err =
                    await ctx.read<UserRoleCubit>().deleteRole(visibleRoles[i].id);
                if (err != null && ctx.mounted) {
                  showApiSnack(ctx, err, isError: true);
                }
              },
              onEdit: () => widget.onEditRole(listCtx, visibleRoles[i]),
            ),
          ),
        ),
        _ListPaginationBar(
          page: safePage,
          totalPages: totalPages,
          totalItems: roles.length,
          pageSize: _pageSize,
          onPrev: safePage > 1 ? () => setState(() => _page -= 1) : null,
          onNext: safePage < totalPages ? () => setState(() => _page += 1) : null,
        ),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  final AppRole role;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _RoleCard({
    required this.role,
    required this.onDelete,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext ctx) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ]),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.shield_outlined,
                  size: 20, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.name,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    Text('${role.permissions.length} permissions',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                  ]),
            ),
            GestureDetector(
                onTap: onEdit,
                child: const Icon(Icons.edit,
                    size: 18, color: AppColors.textHint)),
            const SizedBox(width: 8),
            GestureDetector(
                onTap: onDelete,
                child: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.textHint)),
          ]),
          if (role.permissions.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider, height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: role.permissions
                  .map((p) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                            color: AppColors.divider,
                            borderRadius: BorderRadius.circular(20)),
                        child: Text(p,
                            style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500)),
                      ))
                  .toList(),
            ),
          ],
        ]),
      );
}

class _ListPaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const _ListPaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = (page * pageSize) > totalItems ? totalItems : (page * pageSize);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            '$start-$end of $totalItems',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous page',
          ),
          Text(
            '$page / $totalPages',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED: Password field widget
// ══════════════════════════════════════════════════════════════
class _PasswordField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;

  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(TextSpan(
              text: label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
              children: const [
                TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger)),
              ])),
          const SizedBox(height: 6),
          TextFormField(
            controller: controller,
            obscureText: obscure,
            style:
                const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: const TextStyle(color: AppColors.textHint),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                child: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ],
      );
}

// ══════════════════════════════════════════════════════════════
// ADD USER MODAL
// ══════════════════════════════════════════════════════════════
class _AddUserModal extends StatefulWidget {
  final List<AppRole> roles;
  const _AddUserModal({required this.roles});

  @override
  State<_AddUserModal> createState() => _AddUserModalState();
}

class _AddUserModalState extends State<_AddUserModal> {
  final _fn  = TextEditingController();
  final _ln  = TextEditingController();
  final _ph  = TextEditingController();
  final _em  = TextEditingController();
  final _pw  = TextEditingController();
  final _cpw = TextEditingController();
  final _ad  = TextEditingController();  

  // BUG FIX: store the full AppRole object so we can send role.id to API
  AppRole?  _selectedRole;
  String?   _gender;
  DateTime? _dob;
  String    _status    = 'Active';
  bool      _saving    = false;
  bool      _pwObscure  = true;
  bool      _cpwObscure = true;

  String? _pickedImagePath; // Optional profile image
  Uint8List? _pickedImageBytes; // Optional preview source (path can be null)

  @override
  void dispose() {
    _fn.dispose(); _ln.dispose(); _ph.dispose();
    _em.dispose(); _pw.dispose(); _cpw.dispose(); _ad.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Validate all required fields
    for (final e in {
      'First Name':       _fn.text,
      'Last Name':        _ln.text,
      'Phone':            _ph.text,
      'Email':            _em.text,
      'Password':         _pw.text,
      'Confirm Password': _cpw.text,
      'Address':          _ad.text,
    }.entries) {
      if (e.value.trim().isEmpty) {
        showApiSnack(context, '${e.key} is required', isError: true);
        return;
      }
    }
    if (_pw.text != _cpw.text) {
      showApiSnack(context, 'Passwords do not match', isError: true);
      return;
    }
    if (_gender == null) {
      showApiSnack(context, 'Gender is required', isError: true);
      return;
    }
    if (_dob == null) {
      showApiSnack(context, 'Date of birth is required', isError: true);
      return;
    }
    if (_selectedRole == null) {
      showApiSnack(context, 'Role is required', isError: true);
      return;
    }

    setState(() => _saving = true);

    final user = AppUser(
      id:        '',
      firstName: _fn.text.trim(),
      lastName:  _ln.text.trim(),
      gender:    _gender!,
      dob:       _dob,
      phone:     _ph.text.trim(),
      email:     _em.text.trim(),
      role:      _selectedRole!.id,   // ✅ send ObjectId, not name
      status:    _status,
      address:   _ad.text.trim(),
    );

    final err = await context.read<UserRoleCubit>().createUser(
          user,
          password: _pw.text.trim(), // ✅ password correctly passed
          imagePath: _pickedImagePath,
        );

    setState(() => _saving = false);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      showApiSnack(context, err, isError: true);
    }
  }

  Future<void> _pickUserImage() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (res == null) return;
    final file = res.files.isNotEmpty ? res.files.first : null;
    if (file == null) return;

    final p = file.path;
    final b = file.bytes;

    if (p == null && b == null) {
      if (mounted) {
        showApiSnack(context, 'Image bytes/path not available', isError: true);
      }
      return;
    }

    setState(() {
      _pickedImagePath = (p != null && p.trim().isNotEmpty) ? p : null;
      _pickedImageBytes = b;
    });
  }

  Widget _userImageUploadWidget() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickUserImage,
            child: CircleAvatar(
              radius: 46,
              backgroundImage: _pickedImageBytes != null
                  ? MemoryImage(_pickedImageBytes!) as ImageProvider<Object>
                  : (_pickedImagePath != null
                      ? FileImage(File(_pickedImagePath!)) as ImageProvider<Object>
                      : null),
              child: (_pickedImageBytes == null && _pickedImagePath == null)
                  ? const Icon(Icons.person_outline, size: 40, color: AppColors.textHint)
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            (_pickedImageBytes == null && _pickedImagePath == null)
                ? 'Upload image (optional)'
                : 'Change image',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: (_pickedImageBytes == null && _pickedImagePath == null)
                  ? AppColors.textSecondary
                  : AppColors.primary,
            ),
          ),
          if (_pickedImageBytes != null || _pickedImagePath != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() {
                _pickedImagePath = null;
                _pickedImageBytes = null;
              }),
              child: const Text('Remove'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            _sheetHandle(),
            _sheetHeader(ctx, 'Add New User'),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _userImageUploadWidget(),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                          child: CrmTextField(
                              label: 'First Name',
                              required: true,
                              hint: 'Enter first name',
                              controller: _fn)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: CrmTextField(
                              label: 'Last Name',
                              required: true,
                              hint: 'Enter last name',
                              controller: _ln)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: CrmDropdown(
                          label: 'Gender',
                          required: true,
                          value: _gender,
                          items: AppConstants.genders,
                          hint: 'Select Gender',
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _dobPicker(ctx)),
                    ]),
                    const SizedBox(height: 16),
                    CrmTextField(
                        label: 'Phone Number',
                        required: true,
                        hint: 'enter phone number',
                        controller: _ph,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    CrmTextField(
                        label: 'Email',
                        required: true,
                        hint: 'Enter email address',
                        controller: _em,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: _PasswordField(
                          label: 'Password',
                          controller: _pw,
                          obscure: _pwObscure,
                          onToggle: () =>
                              setState(() => _pwObscure = !_pwObscure),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PasswordField(
                          label: 'Confirm Password',
                          controller: _cpw,
                          obscure: _cpwObscure,
                          onToggle: () =>
                              setState(() => _cpwObscure = !_cpwObscure),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 16),
                    CrmTextField(
                        label: 'Address',
                        hint: 'Enter address',
                        controller: _ad,
                        maxLines: 2),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        // BUG FIX: display role.name in dropdown but store
                        // the full AppRole so we can send role.id to API
                        child: CrmDropdown(
                          label: 'Role',
                          required: true,
                          value: _selectedRole?.name,
                          items: widget.roles.map((r) => r.name).toList(),
                          hint: 'Select Role',
                          onChanged: (v) {
                            setState(() {
                              _selectedRole = widget.roles
                                  .firstWhere((r) => r.name == v);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CrmDropdown(
                          label: 'Status',
                          value: _status,
                          items: AppConstants.userStatuses,
                          onChanged: (v) =>
                              setState(() => _status = v ?? 'Active'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    FormActionButtons(
                      onCancel: () => Navigator.pop(ctx),
                      onSubmit: _submit,
                      submitLabel: 'Create User',
                      isLoading: _saving,
                    ),
                    const SizedBox(height: 20),
                  ]),
            ),
          ]),
        ),
      );

  Widget _dobPicker(BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text.rich(TextSpan(
              text: 'Date of Birth',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary),
              children: [
                TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger))
              ])),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: _dob ?? DateTime(1995, 1, 1),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(
                      colorScheme: const ColorScheme.light(
                          primary: AppColors.primary)),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _dob = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  _dob != null
                      ? DateFormat('dd/MM/yy').format(_dob!)
                      : 'DD/MM/YY',
                  style: TextStyle(
                      fontSize: 13,
                      color: _dob != null
                          ? AppColors.textPrimary
                          : AppColors.textHint),
                ),
              ]),
            ),
          ),
        ],
      );
}

// ══════════════════════════════════════════════════════════════
// EDIT USER MODAL
// ══════════════════════════════════════════════════════════════
class _EditUserModal extends StatefulWidget {
  final AppUser user;
  final List<AppRole> roles;
  const _EditUserModal({required this.user, required this.roles});

  @override
  State<_EditUserModal> createState() => _EditUserModalState();
}

class _EditUserModalState extends State<_EditUserModal> {
  late final TextEditingController _fn;
  late final TextEditingController _ln;
  late final TextEditingController _ph;
  late final TextEditingController _em;
  late final TextEditingController _ad;

  String?   _gender;
  AppRole?  _selectedRole;
  DateTime? _dob;
  late String _status;
  bool _saving = false;

  String? _pickedImagePath; // Optional new profile image
  Uint8List? _pickedImageBytes; // Optional preview source (path can be null)

  @override
  void initState() {
    super.initState();
    _fn     = TextEditingController(text: widget.user.firstName);
    _ln     = TextEditingController(text: widget.user.lastName);
    _ph     = TextEditingController(text: widget.user.phone);
    _em     = TextEditingController(text: widget.user.email);
    _ad     = TextEditingController(text: widget.user.address);
    _gender = widget.user.gender.isEmpty ? null : widget.user.gender;
    _dob    = widget.user.dob;
    _status = widget.user.status;

    // BUG FIX: safe lookup — don't crash if roles list is empty or role not found
    if (widget.roles.isNotEmpty) {
      try {
        _selectedRole = widget.roles
            .firstWhere((r) => r.id == widget.user.role);
      } catch (_) {
        // role id not found in list — default to first role
        _selectedRole = widget.roles.first;
      }
    }
  }

  @override
  void dispose() {
    _fn.dispose(); _ln.dispose(); _ph.dispose();
    _em.dispose(); _ad.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    for (final e in {
      'First Name': _fn.text,
      'Last Name':  _ln.text,
      'Phone Number':      _ph.text,
      'Email':      _em.text,
      
    }.entries) {
      if (e.value.trim().isEmpty) {
        showApiSnack(context, '${e.key} is required', isError: true);
        return;
      }
    }
    if (_gender == null) {
      showApiSnack(context, 'Gender is required', isError: true);
      return;
    }
    if (_selectedRole == null) {
      showApiSnack(context, 'Role is required', isError: true);
      return;
    }

    setState(() => _saving = true);

    final updated = AppUser(
      id:        widget.user.id,
      firstName: _fn.text.trim(),
      lastName:  _ln.text.trim(),
      gender:    _gender!,
      dob:       _dob,
      phone:     _ph.text.trim(),
      email:     _em.text.trim(),
      role:      _selectedRole!.id,   // ✅ send ObjectId
      status:    _status,
      address:   _ad.text.trim(),
    );

    // BUG FIX: was hardcoded `final err = "err"` — now actually calls cubit
    final err = await context
        .read<UserRoleCubit>()
        .updateUser(widget.user.id, updated, imagePath: _pickedImagePath);

    setState(() => _saving = false);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      showApiSnack(context, err, isError: true);
    }
  }

  Future<void> _pickUserImage() async {
    final res = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    if (res == null) return;
    final file = res.files.isNotEmpty ? res.files.first : null;
    if (file == null) return;

    final p = file.path;
    final b = file.bytes;

    if (p == null && b == null) {
      if (mounted) {
        showApiSnack(context, 'Image bytes/path not available', isError: true);
      }
      return;
    }

    setState(() {
      _pickedImagePath = (p != null && p.trim().isNotEmpty) ? p : null;
      _pickedImageBytes = b;
    });
  }

  /// Backend often returns only a filename (e.g. `abc.png`) in `profileImage`.
  /// Convert it into a usable absolute URL.
  String? _safeNetworkAvatarUrl(String? rawInput) {
    final raw = rawInput?.trim() ?? '';
    if (raw.isEmpty) return null;

    var path = raw.replaceAll('\\', '/');

    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }

    // If it's only a filename (no `/`), it should map to `/uploads/users/<file>`
    if (!path.contains('/')) {
      path = '/uploads/users/$path';
    }

    if (!path.startsWith('/')) {
      path = '/$path';
    }

    return 'https://sales.stagingzar.com$path';
  }

  Widget _userImageUploadWidget() {
    final existingUrl = _safeNetworkAvatarUrl(widget.user.avatarUrl);
    ImageProvider<Object>? provider;
    if (_pickedImageBytes != null) {
      provider = MemoryImage(_pickedImageBytes!) as ImageProvider<Object>;
    } else if (_pickedImagePath != null) {
      provider =
          FileImage(File(_pickedImagePath!)) as ImageProvider<Object>;
    } else if (existingUrl != null) {
      provider = NetworkImage(existingUrl) as ImageProvider<Object>;
    }
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickUserImage,
            child: CircleAvatar(
              radius: 46,
              backgroundImage: provider,
              child: provider == null
                  ? const Icon(
                      Icons.person_outline,
                      size: 40,
                      color: AppColors.textHint,
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            (_pickedImageBytes != null || _pickedImagePath != null)
                ? 'Change image'
                : 'Upload image (optional)',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: (_pickedImageBytes != null || _pickedImagePath != null)
                  ? AppColors.primary
                  : AppColors.textSecondary,
            ),
          ),
          if (_pickedImageBytes != null || _pickedImagePath != null) ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => setState(() {
                _pickedImagePath = null;
                _pickedImageBytes = null;
              }),
              child: const Text('Remove'),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext ctx) => DraggableScrollableSheet(
        initialChildSize: 0.92,
        maxChildSize: 0.97,
        minChildSize: 0.5,
        builder: (_, ctrl) => Container(
          decoration: const BoxDecoration(
              color: AppColors.surface,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            _sheetHandle(),
            _sheetHeader(ctx, 'Edit User', isEdit: true),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: ListView(
                  controller: ctrl,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _userImageUploadWidget(),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                          child: CrmTextField(
                              label: 'First Name',
                              required: true,
                              hint: 'Enter first name',
                              controller: _fn)),
                      const SizedBox(width: 12),
                      Expanded(
                          child: CrmTextField(
                              label: 'Last Name',
                              required: true,
                              hint: 'Enter last name',
                              controller: _ln)),
                    ]),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: CrmDropdown(
                          label: 'Gender',
                          required: true,
                          value: _gender,
                          items: AppConstants.genders,
                          hint: 'Select Gender',
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _dobPicker(ctx)),
                    ]),
                    const SizedBox(height: 16),
                    CrmTextField(
                        label: 'Phone',
                        required: true,
                        hint: 'enter phone number',
                        controller: _ph,
                        keyboardType: TextInputType.phone),
                    const SizedBox(height: 16),
                    CrmTextField(
                        label: 'Email',
                        required: true,
                        hint: 'Enter email address',
                        controller: _em,
                        keyboardType: TextInputType.emailAddress),
                    const SizedBox(height: 16),
                    CrmTextField(
                        label: 'Address',
                        hint: 'Enter address',
                        controller: _ad,
                        maxLines: 2),
                    const SizedBox(height: 16),
                    Row(children: [
                      Expanded(
                        child: CrmDropdown(
                          label: 'Role',
                          required: true,
                          value: _selectedRole?.name,
                          items:
                              widget.roles.map((r) => r.name).toList(),
                          hint: 'Select Role',
                          onChanged: (v) {
                            setState(() {
                              _selectedRole = widget.roles
                                  .firstWhere((r) => r.name == v);
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: CrmDropdown(
                          label: 'Status',
                          value: _status,
                          items: AppConstants.userStatuses,
                          onChanged: (v) =>
                              setState(() => _status = v ?? 'Active'),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 28),
                    FormActionButtons(
                      onCancel: () => Navigator.pop(ctx),
                      onSubmit: _submit,
                      submitLabel: 'Update User',
                      isLoading: _saving,
                    ),
                    const SizedBox(height: 20),
                  ]),
            ),
          ]),
        ),
      );

  Widget _dobPicker(BuildContext ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Date of Birth',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: ctx,
                initialDate: _dob ?? DateTime(1995, 1, 1),
                firstDate: DateTime(1950),
                lastDate: DateTime.now(),
                builder: (c, child) => Theme(
                  data: Theme.of(c).copyWith(
                      colorScheme: const ColorScheme.light(
                          primary: AppColors.primary)),
                  child: child!,
                ),
              );
              if (picked != null) setState(() => _dob = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  _dob != null
                      ? DateFormat('dd/MM/yy').format(_dob!)
                      : 'DD/MM/YY',
                  style: TextStyle(
                      fontSize: 13,
                      color: _dob != null
                          ? AppColors.textPrimary
                          : AppColors.textHint),
                ),
              ]),
            ),
          ),
        ],
      );
}

// ══════════════════════════════════════════════════════════════
// CREATE / EDIT ROLE MODAL
// ══════════════════════════════════════════════════════════════
class _CreateRoleModal extends StatefulWidget {
  final AppRole? role;
  const _CreateRoleModal({this.role});

  @override
  State<_CreateRoleModal> createState() => _CreateRoleModalState();
}

class _CreateRoleModalState extends State<_CreateRoleModal> {
  final _nameCtrl = TextEditingController();
  final Set<String> _perms = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.role != null) {
      _nameCtrl.text = widget.role!.name;
      _perms.addAll(widget.role!.permissions);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_nameCtrl.text.trim().isEmpty) {
      showApiSnack(context, 'Role name is required', isError: true);
      return;
    }
    setState(() => _saving = true);
    final cubit = context.read<UserRoleCubit>();
    final role = AppRole(
      id:          widget.role?.id ?? '',
      name:        _nameCtrl.text.trim(),
      permissions: _perms.toList(),
    );
    final err = widget.role == null
        ? await cubit.createRole(role)
        : await cubit.updateRole(widget.role!.id, role);
    setState(() => _saving = false);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context);
    } else {
      showApiSnack(context, err, isError: true);
    }
  }

  @override
  Widget build(BuildContext ctx) => Container(
        decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24))),
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _sheetHandle(),
          _sheetHeader(
            ctx,
            widget.role == null ? 'Create Role' : 'Edit Role',
            isEdit: widget.role != null,
          ),
          const Divider(height: 1, color: AppColors.divider),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CrmTextField(
                        label: 'Role Name',
                        required: true,
                        hint: 'e.g. Sales Manager',
                        controller: _nameCtrl),
                    const SizedBox(height: 20),
                    const Text('Permissions',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Select modules this role can access',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary)),
                    const SizedBox(height: 14),
                    Container(
                      decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.border)),
                      child: Column(
                        children: AppConstants.permissions
                            .asMap()
                            .entries
                            .map((entry) {
                          final isLast = entry.key ==
                              AppConstants.permissions.length - 1;
                          final perm    = entry.value;
                          final checked = _perms.contains(perm);
                          return Column(children: [
                            InkWell(
                              onTap: () => setState(() => checked
                                  ? _perms.remove(perm)
                                  : _perms.add(perm)),
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 12),
                                child: Row(children: [
                                  _permIcon(perm),
                                  const SizedBox(width: 12),
                                  Expanded(
                                      child: Text(perm,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color:
                                                  AppColors.textPrimary))),
                                  Checkbox(
                                    value: checked,
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(4)),
                                    onChanged: (v) => setState(() => v!
                                        ? _perms.add(perm)
                                        : _perms.remove(perm)),
                                  ),
                                ]),
                              ),
                            ),
                            if (!isLast)
                              const Divider(
                                  height: 1,
                                  color: AppColors.divider,
                                  indent: 16,
                                  endIndent: 16),
                          ]);
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 28),
                    FormActionButtons(
                      onCancel: () => Navigator.pop(ctx),
                      onSubmit: _submit,
                      submitLabel: widget.role == null
                          ? 'Create Role'
                          : 'Update Role',
                      isLoading: _saving,
                    ),
                    const SizedBox(height: 16),
                  ]),
            ),
          ),
        ]),
      );

  Widget _permIcon(String perm) {
    final d = switch (perm) {
      'Dashboard'     => (Icons.dashboard_outlined,       AppColors.primary),
      'Leads'         => (Icons.people_outline,           AppColors.success),
      'Deals'         => (Icons.handshake_outlined,       AppColors.purple),
      'Invoices'      => (Icons.receipt_outlined,         AppColors.warning),
      'Users & Roles' => (Icons.manage_accounts_outlined, AppColors.danger),
      _               => (Icons.circle_outlined,          AppColors.textSecondary),
    };
    return Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
          color: d.$2.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Icon(d.$1, size: 16, color: d.$2),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHARED SHEET HELPERS
// ══════════════════════════════════════════════════════════════
Widget _sheetHandle() => Container(
      margin: const EdgeInsets.only(top: 12),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
          color: AppColors.border, borderRadius: BorderRadius.circular(2)),
    );

Widget _sheetHeader(BuildContext ctx, String title,
        {bool isEdit = false}) =>
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(children: [
        Text(title,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
        const SizedBox(width: 8),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: isEdit
                  ? AppColors.warningLight
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(6)),
        ),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.pop(ctx),
          icon: const Icon(Icons.close),
          style: IconButton.styleFrom(
              backgroundColor: AppColors.divider,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8))),
        ),
      ]),
    );