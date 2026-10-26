import 'package:crm_app/screen/message/cubit/chat_cubit.dart';
import 'package:crm_app/screen/message/cubit/chat_state.dart';
import 'package:crm_app/screen/message/modal/message_modal.dart';
import 'package:crm_app/screen/message/ui/chat_avatar.dart';
import 'package:crm_app/screen/message/ui/chat_panel.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Wide-layout breakpoint: above this, list + chat show side by side.
const double _kWideBreakpoint = 760;

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  int _tab = 0; // 0 = Direct, 1 = Groups

  late final ChatCubit _chatCubit;

  ContactModel? _selectedContact;
  GroupModel? _selectedGroup;

  @override
  void initState() {
    super.initState();
    _chatCubit = ChatCubit()
      ..loadChatData()
      ..loadPinnedGroups()
      ..connectSocket();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _chatCubit.close();
    super.dispose();
  }

  List<ContactModel> _filteredContacts(List<ContactModel> contacts) {
    if (_query.isEmpty) return contacts;
    final q = _query.toLowerCase();
    return contacts
        .where((c) =>
            c.name.toLowerCase().contains(q) ||
            c.email.toLowerCase().contains(q))
        .toList();
  }

  List<GroupModel> _filteredGroups(List<GroupModel> groups) {
    if (_query.isEmpty) return groups;
    final q = _query.toLowerCase();
    return groups.where((g) => g.name.toLowerCase().contains(q)).toList();
  }

  void _openContact(ContactModel c, {required bool wide}) {
    _chatCubit.getMessages(c.id);
    if (wide) {
      setState(() {
        _selectedContact = c;
        _selectedGroup = null;
      });
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: _chatCubit,
        child: Scaffold(
          body: SafeArea(
            child: BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) => ChatPanel(
                title: c.name,
                subtitle: c.role.isEmpty ? 'Offline' : c.role,
                avatarColor: _colorFor(c.id),
                initials: _initials(c.name),
                imageUrl: resolveContactAvatarUrl(c.profileImage),
                contactId: c.id,
                messages: state.messagesResponse?.messages ?? const [],
                isLoadingMessages: state.messagesLoading,
                messagesError: state.messagesError,
                onRetryMessages: () => _chatCubit.getMessages(c.id),
                onBack: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    )).then((_) => _chatCubit.closeConversation());
  }

  void _openGroup(GroupModel g, {required bool wide}) {
    _chatCubit.getGroupMessages(g.id);
    if (wide) {
      setState(() {
        _selectedGroup = g;
        _selectedContact = null;
      });
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: _chatCubit,
        child: Scaffold(
          body: SafeArea(
            child: BlocBuilder<ChatCubit, ChatState>(
              builder: (context, state) => _groupPanel(
                g,
                state,
                onBack: () => Navigator.of(context).pop(),
                onLeftGroup: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ),
      ),
    )).then((_) => _chatCubit.closeConversation());
  }

  Widget _groupPanel(
    GroupModel g,
    ChatState state, {
    VoidCallback? onBack,
    VoidCallback? onLeftGroup,
  }) {
    return ChatPanel(
      title: g.name,
      subtitle: '${g.memberCount} members',
      avatarColor: _colorFor(g.id),
      initials: _initials(g.name),
      imageUrl: resolveChatAvatarUrl(g.avatar),
      groupId: g.id,
      messages: state.messagesResponse?.messages ?? const [],
      isLoadingMessages: state.messagesLoading,
      messagesError: state.messagesError,
      onRetryMessages: () => _chatCubit.getGroupMessages(g.id),
      showSenderNames: true,
      onBack: onBack,
      onLeftGroup: onLeftGroup,
    );
  }

  @override
  Widget build(BuildContext context) {
    // No chat is opened automatically: a chat only counts as read once the
    // user taps into it.
    return BlocProvider.value(
      value: _chatCubit,
      child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: AppColors.background,
            surfaceTintColor: Colors.transparent,
            titleSpacing: 4,
            title: Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded,
                      color: Colors.white, size: 18),
                ),
                const SizedBox(width: 10),
                const Text('Messages',
                    style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ],
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= _kWideBreakpoint;

              final listPane = _ListPane(
                searchController: _searchController,
                onSearchChanged: (v) => setState(() => _query = v),
                tab: _tab,
                onTabChanged: (v) => setState(() => _tab = v),
                filterContacts: _filteredContacts,
                filterGroups: _filteredGroups,
                selectedContactId: wide ? _selectedContact?.id : null,
                selectedGroupId: wide ? _selectedGroup?.id : null,
                onContactTap: (c) => _openContact(c, wide: wide),
                onGroupTap: (g) => _openGroup(g, wide: wide),
              );

              if (!wide) return listPane;

              Widget detail;
              if (_selectedContact != null) {
                final c = _selectedContact!;
                detail = BlocBuilder<ChatCubit, ChatState>(
                  key: ValueKey('contact-${c.id}'),
                  builder: (context, state) => ChatPanel(
                    title: c.name,
                    subtitle: c.role.isEmpty ? 'Offline' : 'Offline · ${c.role}',
                    avatarColor: _colorFor(c.id),
                    initials: _initials(c.name),
                    imageUrl: resolveContactAvatarUrl(c.profileImage),
                    contactId: c.id,
                    messages: state.messagesResponse?.messages ?? const [],
                    isLoadingMessages: state.messagesLoading,
                    messagesError: state.messagesError,
                    onRetryMessages: () => _chatCubit.getMessages(c.id),
                  ),
                );
              } else if (_selectedGroup != null) {
                final g = _selectedGroup!;
                detail = BlocBuilder<ChatCubit, ChatState>(
                  key: ValueKey('group-${g.id}'),
                  builder: (context, state) => _groupPanel(
                    g,
                    state,
                    onLeftGroup: () => setState(() => _selectedGroup = null),
                  ),
                );
              } else {
                detail = const ChatEmptyState();
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 340, child: listPane),
                  const VerticalDivider(width: 1, color: AppColors.divider),
                  Expanded(child: detail),
                ],
              );
            },
          ),
      ),
    );
  }
}

class _ListPane extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final int tab;
  final ValueChanged<int> onTabChanged;
  final List<ContactModel> Function(List<ContactModel>) filterContacts;
  final List<GroupModel> Function(List<GroupModel>) filterGroups;
  final String? selectedContactId;
  final String? selectedGroupId;
  final ValueChanged<ContactModel> onContactTap;
  final ValueChanged<GroupModel> onGroupTap;

  const _ListPane({
    required this.searchController,
    required this.onSearchChanged,
    required this.tab,
    required this.onTabChanged,
    required this.filterContacts,
    required this.filterGroups,
    required this.selectedContactId,
    required this.selectedGroupId,
    required this.onContactTap,
    required this.onGroupTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: searchController,
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textHint, size: 20),
                filled: true,
                fillColor: AppColors.background,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          BlocBuilder<ChatCubit, ChatState>(
            buildWhen: (a, b) =>
                a.contactsResponse != b.contactsResponse ||
                a.groupsResponse != b.groupsResponse,
            builder: (context, state) {
              final directUnread = (state.contactsResponse?.contacts ??
                      const <ContactModel>[])
                  .fold<int>(0, (sum, c) => sum + c.unreadCount);
              final groupUnread =
                  (state.groupsResponse?.groups ?? const <GroupModel>[])
                      .fold<int>(0, (sum, g) => sum + g.unreadCount);

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _TabToggle(
                  index: tab,
                  onChanged: onTabChanged,
                  directUnread: directUnread,
                  groupUnread: groupUnread,
                ),
              );
            },
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: tab == 0
                ? _ContactsList(
                    filterContacts: filterContacts,
                    selectedId: selectedContactId,
                    onTap: onContactTap,
                  )
                : _GroupsList(
                    filterGroups: filterGroups,
                    selectedId: selectedGroupId,
                    onTap: onGroupTap,
                  ),
          ),
        ],
      ),
    );
  }
}

String _unreadLabel(int count) => count > 99 ? '99+' : '$count';

class _TabToggle extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final int directUnread;
  final int groupUnread;
  const _TabToggle({
    required this.index,
    required this.onChanged,
    this.directUnread = 0,
    this.groupUnread = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TabItem(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Direct',
              selected: index == 0,
              unreadCount: directUnread,
              onTap: () => onChanged(0),
            ),
          ),
          Expanded(
            child: _TabItem(
              icon: Icons.groups_outlined,
              label: 'Groups',
              selected: index == 1,
              unreadCount: groupUnread,
              onTap: () => onChanged(1),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final int unreadCount;
  final VoidCallback onTap;
  const _TabItem(
      {required this.icon,
      required this.label,
      required this.selected,
      this.unreadCount = 0,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1)),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.primary : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        selected ? AppColors.primary : AppColors.textSecondary)),
            if (unreadCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10)),
                child: Text(_unreadLabel(unreadCount),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactsList extends StatelessWidget {
  final List<ContactModel> Function(List<ContactModel>) filterContacts;
  final String? selectedId;
  final ValueChanged<ContactModel> onTap;
  const _ContactsList(
      {required this.filterContacts,
      required this.selectedId,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        if (state.isLoading && state.contactsResponse == null) {
          return const _ListLoading();
        }
        if (state.errorMessage != null && state.contactsResponse == null) {
          return _ListError(
            message: state.errorMessage!,
            onRetry: () => context.read<ChatCubit>().getContacts(),
          );
        }

        final contacts =
            filterContacts(state.contactsResponse?.contacts ?? const []);

        if (contacts.isEmpty) {
          return const _EmptyList(text: 'No contacts found');
        }
        return ListView.separated(
          itemCount: contacts.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72, color: AppColors.divider),
          itemBuilder: (_, i) {
            final c = contacts[i];
            final preview = c.lastMessage?.message ?? c.email;
            final time = c.lastMessage != null
                ? _formatTime(c.lastMessage!.createdAt)
                : '';
            return _ConversationTile(
              selected: c.id == selectedId,
              avatarColor: _colorFor(c.id),
              initials: _initials(c.name),
              imageUrl: resolveContactAvatarUrl(c.profileImage),
              title: c.name,
              subtitle: preview,
              time: time,
              unreadCount: c.unreadCount,
              onTap: () => onTap(c),
              menu: _RowMenu(
                actions: const [
                  _RowAction('clear', 'Clear chat',
                      Icons.delete_outline_rounded),
                  _RowAction('delete', 'Delete chat',
                      Icons.delete_outline_rounded,
                      destructive: true),
                ],
                onSelected: (value) => value == 'delete'
                    ? _deleteChat(context, c)
                    : _clearChat(context, c),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _clearChat(BuildContext context, ContactModel c) async {
    final confirmed = await _confirm(
      context,
      title: 'Clear chat?',
      message: 'All messages with ${c.name} will be cleared.',
      action: 'Clear',
    );
    if (!confirmed || !context.mounted) return;

    final success = await context.read<ChatCubit>().clearChat(c.id);
    if (!context.mounted) return;
    _toast(context, success ? 'Chat cleared' : 'Failed to clear chat');
  }

  Future<void> _deleteChat(BuildContext context, ContactModel c) async {
    final confirmed = await _confirm(
      context,
      title: 'Delete chat?',
      message: 'This will permanently delete your conversation with '
          '${c.name}. This cannot be undone.',
      action: 'Delete',
    );
    if (!confirmed || !context.mounted) return;

    final success = await context.read<ChatCubit>().clearChat(c.id);
    if (!context.mounted) return;
    _toast(context, success ? 'Chat deleted' : 'Failed to delete chat');
  }
}

class _GroupsList extends StatelessWidget {
  final List<GroupModel> Function(List<GroupModel>) filterGroups;
  final String? selectedId;
  final ValueChanged<GroupModel> onTap;
  const _GroupsList(
      {required this.filterGroups,
      required this.selectedId,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        if (state.isLoading && state.groupsResponse == null) {
          return const _ListLoading();
        }
        if (state.errorMessage != null && state.groupsResponse == null) {
          return _ListError(
            message: state.errorMessage!,
            onRetry: () => context.read<ChatCubit>().getGroups(),
          );
        }

        final pinnedIds = state.pinnedGroupIds;
        // Copy: filterGroups returns the state's own list when not searching.
        final groups =
            List.of(filterGroups(state.groupsResponse?.groups ?? const []));
        // Pinned groups first (newest pin on top), the rest keep server order.
        final pinned = [
          for (final id in pinnedIds) ...groups.where((g) => g.id == id),
        ];
        groups
          ..removeWhere((g) => pinnedIds.contains(g.id))
          ..insertAll(0, pinned);

        if (groups.isEmpty) {
          return const _EmptyList(text: 'No groups found');
        }
        return ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72, color: AppColors.divider),
          itemBuilder: (_, i) {
            final g = groups[i];
            final preview = g.lastMessage != null
                ? '${g.lastMessage!.senderName ?? ''}${g.lastMessage!.senderName != null ? ': ' : ''}${g.lastMessage!.message}'
                : g.description;
            final time = g.lastMessage != null
                ? _formatTime(g.lastMessage!.createdAt)
                : '';
            final isPinned = pinnedIds.contains(g.id);
            return _ConversationTile(
              selected: g.id == selectedId,
              avatarColor: _colorFor(g.id),
              initials: _initials(g.name),
              imageUrl: resolveChatAvatarUrl(g.avatar),
              title: g.name,
              subtitle: preview,
              time: time,
              unreadCount: g.unreadCount,
              pinned: isPinned,
              onTap: () => onTap(g),
              menu: _RowMenu(
                actions: [
                  const _RowAction('clear', 'Clear chat',
                      Icons.delete_outline_rounded),
                  isPinned
                      ? const _RowAction(
                          'pin', 'Unpin chat', Icons.push_pin_outlined)
                      : const _RowAction(
                          'pin', 'Pin chat', Icons.push_pin_outlined),
                ],
                onSelected: (value) => value == 'pin'
                    ? context.read<ChatCubit>().toggleGroupChatPin(g.id)
                    : _clearGroupChat(context, g),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _clearGroupChat(BuildContext context, GroupModel g) async {
    final confirmed = await _confirm(
      context,
      title: 'Clear chat?',
      message: 'All messages in ${g.name} will be cleared.',
      action: 'Clear',
    );
    if (!confirmed || !context.mounted) return;

    final success = await context.read<ChatCubit>().clearGroupChat(g.id);
    if (!context.mounted) return;
    _toast(context, success ? 'Chat cleared' : 'Failed to clear chat');
  }
}

class _RowAction {
  final String value;
  final String label;
  final IconData icon;
  final bool destructive;
  const _RowAction(this.value, this.label, this.icon,
      {this.destructive = false});
}

/// ⋮ menu at the end of a conversation row.
class _RowMenu extends StatelessWidget {
  final List<_RowAction> actions;
  final ValueChanged<String> onSelected;
  const _RowMenu({required this.actions, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'More options',
      icon: const Icon(Icons.more_vert_rounded,
          color: AppColors.textSecondary, size: 20),
      padding: EdgeInsets.zero,
      splashRadius: 18,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final a in actions)
          PopupMenuItem(
            value: a.value,
            height: 42,
            child: Row(
              children: [
                Icon(a.icon,
                    size: 18,
                    color:
                        a.destructive ? Colors.red : AppColors.textSecondary),
                const SizedBox(width: 10),
                Text(a.label,
                    style: TextStyle(
                        fontSize: 13.5,
                        color: a.destructive
                            ? Colors.red
                            : AppColors.textPrimary)),
              ],
            ),
          ),
      ],
    );
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(action, style: const TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return confirmed == true;
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

class _ConversationTile extends StatelessWidget {
  final bool selected;
  final Color avatarColor;
  final String initials;
  final String? imageUrl;
  final String title;
  final String subtitle;
  final String time;
  final int unreadCount;
  final VoidCallback onTap;

  /// Shows a pin icon next to the time.
  final bool pinned;

  /// ⋮ menu at the end of the row.
  final Widget? menu;

  const _ConversationTile({
    required this.selected,
    required this.avatarColor,
    required this.initials,
    this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.unreadCount,
    required this.onTap,
    this.pinned = false,
    this.menu,
  });

  @override
  Widget build(BuildContext context) {
    final unread = unreadCount > 0;
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : Colors.transparent,
          border: Border(
            left: BorderSide(
                color: selected ? AppColors.primary : Colors.transparent,
                width: 3),
          ),
        ),
        padding: EdgeInsets.fromLTRB(13, 12, menu != null ? 4 : 13, 12),
        child: Row(
          children: [
            ChatAvatar(
              imageUrl: imageUrl,
              initials: initials,
              color: avatarColor,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                      ),
                      if (pinned) ...[
                        const Icon(Icons.push_pin_rounded,
                            size: 13, color: AppColors.textHint),
                        const SizedBox(width: 4),
                      ],
                      if (time.isNotEmpty)
                        Text(time,
                            style: TextStyle(
                                fontSize: 11.5,
                                color: unread
                                    ? AppColors.primary
                                    : AppColors.textHint,
                                fontWeight:
                                    unread ? FontWeight.w600 : FontWeight.w400)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 13,
                                color: unread
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight:
                                    unread ? FontWeight.w600 : FontWeight.w400)),
                      ),
                      if (unread) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('$unreadCount',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (menu != null) ...[
              const SizedBox(width: 2),
              SizedBox(width: 32, child: menu),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyList extends StatelessWidget {
  final String text;
  const _EmptyList({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text,
          style: const TextStyle(color: AppColors.textHint, fontSize: 13)),
    );
  }
}

class _ListLoading extends StatelessWidget {
  const _ListLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
            strokeWidth: 2.4, color: AppColors.primary),
      ),
    );
  }
}

class _ListError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ListError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                size: 32, color: AppColors.textHint),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

// ─── helpers ────────────────────────────────────────────────────

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

const List<Color> _avatarPalette = [
  AppColors.primary,
  AppColors.success,
  AppColors.warning,
  AppColors.purple,
  AppColors.accent,
  Color(0xFF64748B),
];

Color _colorFor(String id) => _avatarPalette[id.hashCode.abs() % _avatarPalette.length];

String _formatTime(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(dt.year, dt.month, dt.day);
  if (date == today) return DateFormat('hh:mm a').format(dt);
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
  if (now.difference(dt).inDays < 7) return DateFormat('EEE').format(dt);
  return DateFormat('MMM d').format(dt);
}

