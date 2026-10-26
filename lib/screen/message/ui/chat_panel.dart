import 'package:crm_app/screen/message/cubit/chat_cubit.dart';
import 'package:crm_app/screen/message/modal/message_modal.dart';
import 'package:crm_app/screen/message/ui/chat_avatar.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatPanel extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color avatarColor;
  final String initials;
  final String? imageUrl;
  final String? contactId;
  final String? groupId;
  final List<ChatMessageModel> messages;
  final bool isLoadingMessages;
  final String? messagesError;
  final VoidCallback? onRetryMessages;
  final VoidCallback? onBack;
  final bool showSenderNames;

  /// Called after the user has successfully left this group.
  final VoidCallback? onLeftGroup;

  const ChatPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.avatarColor,
    required this.initials,
    this.imageUrl,
    this.contactId,
    this.groupId,
    required this.messages,
    this.isLoadingMessages = false,
    this.messagesError,
    this.onRetryMessages,
    this.onBack,
    this.showSenderNames = false,
    this.onLeftGroup,
  });

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final TextEditingController _controller = TextEditingController();
  late List<ChatMessageModel> _messages;
  bool _pinned = false;
  PlatformFile? _pendingFile;
  bool _uploadingFile = false;
  ChatMessageModel? _replyingTo;
  String? _selectedMessageId;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _searching = false;
  String _searchQuery = '';

  /// Message the ▲/▼ buttons are currently on.
  String? _currentMatchId;

  /// Keys for matched messages so search can scroll to them.
  final Map<String, GlobalKey> _matchKeys = {};

  @override
  void initState() {
    super.initState();
    _messages = List.of(widget.messages);
  }

  @override
  void didUpdateWidget(covariant ChatPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.messages, widget.messages)) {
      _messages = List.of(widget.messages);
    }
    if (oldWidget.title != widget.title) {
      _pinned = false;
      _closeSearch();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _openSearch() {
    setState(() => _searching = true);
  }

  void _closeSearch() {
    _searchController.clear();
    setState(() {
      _searching = false;
      _searchQuery = '';
      _currentMatchId = null;
      _matchKeys.clear();
    });
  }

  /// Text messages containing the query (case-insensitive), oldest first.
  List<ChatMessageModel> get _searchMatches {
    final q = _searchQuery.trim().toLowerCase();
    if (!_searching || q.isEmpty) return const [];
    return _messages
        .where((m) =>
            m.type != 'system' &&
            !m.isDeleted &&
            m.message.toLowerCase().contains(q))
        .toList();
  }

  int _currentMatchIndex(List<ChatMessageModel> matches) =>
      matches.indexWhere((m) => m.id == _currentMatchId);

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _matchKeys.clear();
      // Like WhatsApp, start from the most recent match.
      final matches = _searchMatches;
      _currentMatchId = matches.isEmpty ? null : matches.last.id;
    });
    _scrollToCurrentMatch();
  }

  /// [step] -1 moves to the older match (▲), +1 to the newer one (▼).
  void _moveMatch(int step) {
    final matches = _searchMatches;
    final next = _currentMatchIndex(matches) + step;
    if (next < 0 || next >= matches.length) return;
    setState(() => _currentMatchId = matches[next].id);
    _scrollToCurrentMatch();
  }

  void _scrollToCurrentMatch() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _matchKeys[_currentMatchId]?.currentContext;
      if (ctx == null || !mounted) return;
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.5,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty || !mounted) return;
    setState(() => _pendingFile = result.files.single);
  }

  void _removePendingFile() {
    setState(() => _pendingFile = null);
  }

  void _setReplyTo(ChatMessageModel message) {
    setState(() => _replyingTo = message);
  }

  void _clearReply() {
    setState(() => _replyingTo = null);
  }

  void _selectMessage(String id) {
    setState(() => _selectedMessageId = id);
  }

  void _clearSelection() {
    setState(() => _selectedMessageId = null);
  }

  bool get _selectedMessageIsMine {
    final id = _selectedMessageId;
    // Unsent messages still have a temp id the server doesn't know about.
    if (id == null || id.startsWith('temp-')) return false;
    final idx = _messages.indexWhere((m) => m.id == id);
    return idx >= 0 && _messages[idx].isMe;
  }

  void _replySelected() {
    final id = _selectedMessageId;
    if (id == null) return;
    final idx = _messages.indexWhere((m) => m.id == id);
    _clearSelection();
    if (idx >= 0) _setReplyTo(_messages[idx]);
  }

  ChatMessageModel? get _selectedMessage {
    final id = _selectedMessageId;
    if (id == null) return null;
    final idx = _messages.indexWhere((m) => m.id == id);
    return idx >= 0 ? _messages[idx] : null;
  }

  // Pinning is group-only, and only for messages the server has saved.
  bool get _canPinSelected {
    final m = _selectedMessage;
    return widget.groupId != null &&
        m != null &&
        !m.isDeleted &&
        !m.id.startsWith('temp-');
  }

  /// Pinned group messages, newest first.
  List<ChatMessageModel> get _pinnedMessages => widget.groupId == null
      ? const []
      : _messages.reversed
          .where((m) => m.isPinned && !m.isDeleted)
          .toList();

  Future<void> _pinSelected() async {
    final m = _selectedMessage;
    if (m == null) return;

    _clearSelection();
    await _togglePin(m);
  }

  Future<void> _togglePin(ChatMessageModel m) async {
    final groupId = widget.groupId;
    if (groupId == null) return;

    final success = await context.read<ChatCubit>().togglePinGroupMessage(
          groupId: groupId,
          messageId: m.id,
          isPinned: m.isPinned,
        );

    if (!mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to update pin')),
    );
  }

  Future<void> _deleteSelected() async {
    final id = _selectedMessageId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete message?'),
        content: const Text(
            'This message will be deleted for everyone in this chat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _clearSelection();

    final cubit = context.read<ChatCubit>();
    final groupId = widget.groupId;
    final success = groupId != null
        ? cubit.deleteGroupMessage(messageId: id, groupId: groupId)
        : await cubit.deleteMessageForEveryone(id);

    if (!mounted || success) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Failed to delete message')),
    );
  }

  Future<void> _clearChat() async {
    final contactId = widget.contactId;
    final groupId = widget.groupId;
    if (contactId == null && groupId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear chat?'),
        content: Text(groupId != null
            ? 'All messages in this group will be cleared.'
            : 'All messages in this chat will be cleared.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() {
      _selectedMessageId = null;
      _replyingTo = null;
    });

    final cubit = context.read<ChatCubit>();
    final success = groupId != null
        ? await cubit.clearGroupChat(groupId)
        : await cubit.clearChat(contactId!);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? 'Chat cleared' : 'Failed to clear chat'),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    final groupId = widget.groupId;
    if (groupId == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Leave ${widget.title}?'),
        content: const Text(
            'You will no longer receive messages from this group.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final error = await context.read<ChatCubit>().leaveGroup(groupId);

    if (!mounted) return;

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    messenger.showSnackBar(
      SnackBar(content: Text('You left ${widget.title}')),
    );
    widget.onLeftGroup?.call();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    final file = _pendingFile;
    if (text.isEmpty && file == null) return;

    final contactId = widget.contactId;
    final groupId = widget.groupId;
    if (contactId == null && groupId == null) return;

    String? fileUrl;
    String? fileName;
    String? fileType;

    if (file != null) {
      setState(() => _uploadingFile = true);

      final uploaded = await context.read<ChatCubit>().uploadChatFile(file);

      if (!mounted) return;
      setState(() => _uploadingFile = false);

      if (uploaded == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to upload attachment')),
        );
        return;
      }

      fileUrl = uploaded['fileUrl']?.toString() ?? uploaded['url']?.toString();
      fileName = uploaded['fileName']?.toString() ?? file.name;
      fileType = uploaded['fileType']?.toString() ?? file.extension;
    }

    final replyingTo = _replyingTo;
    final replyToMessage = replyingTo != null
        ? (replyingTo.message.isNotEmpty
            ? replyingTo.message
            : (replyingTo.fileName ?? 'Attachment'))
        : null;
    final replyToSenderName = replyingTo == null
        ? null
        : (replyingTo.isMe ? 'You' : replyingTo.senderName);

    final cubit = context.read<ChatCubit>();
    if (groupId != null) {
      cubit.sendGroupMessage(
        groupId: groupId,
        message: text,
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
        replyToId: replyingTo?.id,
        replyToMessage: replyToMessage,
        replyToSenderName: replyToSenderName,
      );
    } else {
      cubit.sendMessage(
        receiverId: contactId!,
        message: text,
        fileUrl: fileUrl,
        fileName: fileName,
        fileType: fileType,
        replyToId: replyingTo?.id,
        replyToMessage: replyToMessage,
        replyToSenderName: replyToSenderName,
      );
    }

    _controller.clear();
    setState(() {
      _pendingFile = null;
      _replyingTo = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          _selectedMessageId != null
              ? _SelectionToolbar(
                  onClose: _clearSelection,
                  onReply: _replySelected,
                  onPin: _canPinSelected ? _pinSelected : null,
                  pinned: _selectedMessage?.isPinned ?? false,
                  onDelete: _selectedMessageIsMine ? _deleteSelected : null,
                )
              : _searching
                  ? _buildSearchBar()
                  : _ChatHeader(
                      title: widget.title,
                      subtitle: widget.subtitle,
                      avatarColor: widget.avatarColor,
                      initials: widget.initials,
                      imageUrl: widget.imageUrl,
                      pinned: _pinned,
                      onBack: widget.onBack,
                      onTogglePin: () => setState(() => _pinned = !_pinned),
                      onClearChat: _clearChat,
                      onSearch: _openSearch,
                      onLeaveGroup:
                          widget.groupId != null ? _leaveGroup : null,
                    ),
          if (!_searching) const Divider(height: 1, color: AppColors.divider),
          if (_pinnedMessages.isNotEmpty)
            _PinnedMessageBar(
              messages: _pinnedMessages,
              onUnpin: _togglePin,
            ),
          Expanded(
            child: _buildBody(),
          ),
          // Hidden while searching to give the conversation more room.
          if (!_searching)
            _MessageInputBar(
              controller: _controller,
              hint: 'Message ${widget.title}...',
              onSend: _send,
              onAttach: _pickFile,
              pendingFile: _pendingFile,
              onRemoveFile: _removePendingFile,
              uploading: _uploadingFile,
              replyingTo: _replyingTo,
              onCancelReply: _clearReply,
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final matches = _searchMatches;
    final index = _currentMatchIndex(matches);
    return _ChatSearchBar(
      controller: _searchController,
      current: index < 0 ? null : index + 1,
      total: _searchQuery.trim().isEmpty ? null : matches.length,
      onChanged: _onSearchChanged,
      onUp: index > 0 ? () => _moveMatch(-1) : null,
      onDown: index >= 0 && index < matches.length - 1
          ? () => _moveMatch(1)
          : null,
      onClose: _closeSearch,
    );
  }

  Widget _buildBody() {
    if (_messages.isEmpty && widget.isLoadingMessages) {
      return const _MessagesLoading();
    }
    if (_messages.isEmpty && widget.messagesError != null) {
      return _MessagesError(
        message: widget.messagesError!,
        onRetry: widget.onRetryMessages,
      );
    }
    if (_messages.isEmpty) {
      return const _EmptyThread();
    }
    return ListView(
      controller: _scrollController,
      // While searching, build every message so ▲/▼ can scroll to
      // matches that are off screen.
      cacheExtent: _searching ? 1e7 : null,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: _buildMessageList(),
    );
  }

  List<Widget> _buildMessageList() {
    final query = _searching ? _searchQuery.trim() : '';
    final matchIds =
        query.isEmpty ? const <String>{} : _searchMatches.map((m) => m.id).toSet();
    final widgets = <Widget>[];
    DateTime? lastDay;
    for (final m in _messages) {
      final day = DateTime(m.createdAt.year, m.createdAt.month, m.createdAt.day);
      if (lastDay == null || day != lastDay) {
        widgets.add(_DateDivider(date: day));
        lastDay = day;
      }
      if (m.type == 'system') {
        widgets.add(_SystemNotice(text: m.message));
        continue;
      }
      final canReact = _reactionsEnabled &&
          !m.isDeleted &&
          !m.id.startsWith('temp-');
      final isMatch = matchIds.contains(m.id);
      Widget item = _SwipeToReply(
        alignEnd: m.isMe,
        onReply: () => _setReplyTo(m),
        child: GestureDetector(
          onLongPress: () => _selectMessage(m.id),
          child: _MessageBubble(
            message: m,
            selected: m.id == _selectedMessageId,
            showSenderName: widget.showSenderNames,
            highlight: isMatch ? query : null,
            isCurrentMatch: isMatch && m.id == _currentMatchId,
            currentUserId: context.read<ChatCubit>().currentUserId,
            onReact: canReact ? (emoji) => _react(m, emoji) : null,
            onMoreReactions: canReact ? () => _openEmojiPicker(m) : null,
          ),
        ),
      );
      if (isMatch) {
        item = KeyedSubtree(
          key: _matchKeys.putIfAbsent(m.id, () => GlobalKey()),
          child: item,
        );
      }
      widgets.add(item);
    }
    return widgets;
  }

  // Reactions API is direct-chat only for now.
  bool get _reactionsEnabled =>
      widget.contactId != null && widget.groupId == null;

  Future<void> _react(ChatMessageModel m, String emoji) async {
    _clearSelection();

    final error = await context
        .read<ChatCubit>()
        .reactToMessage(messageId: m.id, emoji: emoji);

    if (!mounted || error == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error)),
    );
  }

  Future<void> _openEmojiPicker(ChatMessageModel m) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: EmojiPicker(
            onEmojiSelected: (_, e) => Navigator.of(sheetContext).pop(e.emoji),
            config: const Config(
              height: 280,
              emojiViewConfig: EmojiViewConfig(
                columns: 8,
                emojiSizeMax: 26,
                backgroundColor: AppColors.surface,
              ),
              categoryViewConfig: CategoryViewConfig(
                tabBarHeight: 40,
                backgroundColor: AppColors.surface,
                indicatorColor: AppColors.primary,
                iconColor: AppColors.textHint,
                iconColorSelected: AppColors.primary,
              ),
              bottomActionBarConfig: BottomActionBarConfig(enabled: false),
              skinToneConfig: SkinToneConfig(enabled: false),
            ),
          ),
        ),
      ),
    );

    if (emoji == null || !mounted) return;
    await _react(m, emoji);
  }
}

class _QuickReactionBar extends StatelessWidget {
  static const quickEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

  final String? myEmoji;
  final ValueChanged<String> onReact;
  final VoidCallback? onMore;

  const _QuickReactionBar({
    required this.myEmoji,
    required this.onReact,
    this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in quickEmojis)
            InkWell(
              onTap: () => onReact(e),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: e == myEmoji ? AppColors.primaryLight : null,
                  shape: BoxShape.circle,
                ),
                child: Text(e, style: const TextStyle(fontSize: 20)),
              ),
            ),
          if (onMore != null)
            InkWell(
              onTap: onMore,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.add_rounded,
                    size: 20, color: AppColors.textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Reactions grouped by emoji, e.g. "👍 2  ❤️".
class _ReactionChips extends StatelessWidget {
  final List<ChatReactionModel> reactions;
  final String currentUserId;
  final ValueChanged<String>? onTap;

  const _ReactionChips({
    required this.reactions,
    required this.currentUserId,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final r in reactions) {
      counts[r.emoji] = (counts[r.emoji] ?? 0) + 1;
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: [
          for (final entry in counts.entries)
            _chip(
              entry.key,
              entry.value,
              mine: reactions.any(
                  (r) => r.emoji == entry.key && r.userId == currentUserId),
            ),
        ],
      ),
    );
  }

  Widget _chip(String emoji, int count, {required bool mine}) {
    return InkWell(
      // Tapping your own reaction removes it.
      onTap: onTap != null && mine ? () => onTap!(emoji) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: mine ? AppColors.primaryLight : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: mine ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 13)),
            if (count > 1) ...[
              const SizedBox(width: 3),
              Text('$count',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color avatarColor;
  final String initials;
  final String? imageUrl;
  final bool pinned;
  final VoidCallback? onBack;
  final VoidCallback onTogglePin;
  final VoidCallback onClearChat;

  /// Opens the in-conversation search bar.
  final VoidCallback onSearch;

  /// Only set for groups; groups get a shorter menu with "Leave group".
  final VoidCallback? onLeaveGroup;

  const _ChatHeader({
    required this.title,
    required this.subtitle,
    required this.avatarColor,
    required this.initials,
    this.imageUrl,
    required this.pinned,
    required this.onTogglePin,
    required this.onClearChat,
    required this.onSearch,
    this.onLeaveGroup,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppColors.textPrimary),
              splashRadius: 20,
            ),
          ChatAvatar(
            imageUrl: imageUrl,
            initials: initials,
            color: avatarColor,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2),
                Text(subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _PinnedButton(pinned: pinned, onTap: onTogglePin),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            splashRadius: 20,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            onSelected: (value) {
              if (value == 'search') onSearch();
              if (value == 'clear') onClearChat();
              if (value == 'leave') onLeaveGroup?.call();
            },
            itemBuilder: (_) => onLeaveGroup != null
                ? const [
                    PopupMenuItem(value: 'search', child: Text('Search chat')),
                    PopupMenuItem(value: 'clear', child: Text('Clear chat')),
                    PopupMenuItem(
                      value: 'leave',
                      child: Text('Leave group',
                          style: TextStyle(color: Colors.red)),
                    ),
                  ]
                : const [
                    PopupMenuItem(value: 'search', child: Text('Search chat')),
                    PopupMenuItem(value: 'clear', child: Text('Clear chat')),
                  ],
          ),
        ],
      ),
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onReply;
  final VoidCallback? onPin;
  final bool pinned;
  final VoidCallback? onDelete;

  const _SelectionToolbar({
    required this.onClose,
    required this.onReply,
    required this.onPin,
    required this.pinned,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, color: AppColors.textPrimary),
            splashRadius: 20,
          ),
          const Expanded(
            child: Text('1 selected',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ),
          IconButton(
            onPressed: onReply,
            tooltip: 'Reply',
            icon: const Icon(Icons.reply_rounded,
                color: AppColors.textSecondary),
            splashRadius: 20,
          ),
          if (onPin != null)
            IconButton(
              onPressed: onPin,
              tooltip: pinned ? 'Unpin' : 'Pin',
              icon: Icon(
                  pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: pinned ? AppColors.primary : AppColors.textSecondary),
              splashRadius: 20,
            ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.textSecondary),
              splashRadius: 20,
            ),
        ],
      ),
    );
  }
}

/// Shows one pinned message at a time; tap to step through the rest.
class _PinnedMessageBar extends StatefulWidget {
  final List<ChatMessageModel> messages;
  final ValueChanged<ChatMessageModel> onUnpin;

  const _PinnedMessageBar({required this.messages, required this.onUnpin});

  @override
  State<_PinnedMessageBar> createState() => _PinnedMessageBarState();
}

class _PinnedMessageBarState extends State<_PinnedMessageBar> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final count = widget.messages.length;
    final index = _index % count;
    final m = widget.messages[index];

    final text = m.message.isNotEmpty ? m.message : (m.fileName ?? 'Attachment');
    final sender = m.isMe ? 'You' : m.senderName;

    return Material(
      color: AppColors.primaryLight,
      child: InkWell(
        onTap: count > 1 ? () => setState(() => _index = index + 1) : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              const Icon(Icons.push_pin_rounded,
                  size: 16, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      count > 1
                          ? 'Pinned message ${index + 1} of $count'
                          : 'Pinned message',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sender.isNotEmpty ? '$sender: $text' : text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textPrimary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => widget.onUnpin(m),
                tooltip: 'Unpin',
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppColors.textSecondary),
                splashRadius: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinnedButton extends StatelessWidget {
  final bool pinned;
  final VoidCallback onTap;
  const _PinnedButton({required this.pinned, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: pinned ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: pinned ? AppColors.primary : AppColors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              pinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 14,
              color: pinned ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              'Pinned',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: pinned ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  final DateTime date;
  const _DateDivider({required this.date});

  String get _label {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';
    return DateFormat('MMM d, yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          const Expanded(child: Divider(color: AppColors.divider)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(_label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textHint)),
          ),
          const Expanded(child: Divider(color: AppColors.divider)),
        ],
      ),
    );
  }
}

class _SystemNotice extends StatelessWidget {
  final String text;
  const _SystemNotice({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessageModel message;
  final bool selected;
  final bool showSenderName;

  /// Search term to highlight inside the message text, if any.
  final String? highlight;

  /// The match the search ▲/▼ buttons are on; highlighted more strongly.
  final bool isCurrentMatch;

  const _MessageBubble({
    required this.message,
    this.selected = false,
    this.showSenderName = false,
    this.highlight,
    this.isCurrentMatch = false,
    this.currentUserId = '',
    this.onReact,
    this.onMoreReactions,
  });

  final String currentUserId;
  final ValueChanged<String>? onReact;
  final VoidCallback? onMoreReactions;

  String? get _myEmoji {
    for (final r in message.reactions) {
      if (r.userId == currentUserId) return r.emoji;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    final bubbleColor = isMe ? AppColors.primary : AppColors.background;
    final textColor = isMe ? Colors.white : AppColors.textPrimary;
    final hasFile = (message.fileUrl ?? '').isNotEmpty;
    final hasText = message.message.isNotEmpty;
    final replyTo = message.replyTo;
    final hasReply = replyTo != null &&
        (replyTo.senderName.isNotEmpty || replyTo.message.isNotEmpty);
    final resolvedFileUrl =
        hasFile ? (resolveChatAvatarUrl(message.fileUrl) ?? message.fileUrl!) : null;
    final isImageFile = hasFile &&
        (_isImageType(message.fileType) ||
            _isImageType(_extensionFromName(message.fileName)) ||
            _isImageType(_extensionFromName(message.fileUrl)));
    final isDeleted = message.isDeleted;

    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(14),
          topRight: const Radius.circular(14),
          bottomLeft: Radius.circular(isMe ? 14 : 2),
          bottomRight: Radius.circular(isMe ? 2 : 14),
        ),
      ),
      child: isDeleted
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.not_interested_rounded,
                    size: 15, color: textColor.withOpacity(0.7)),
                const SizedBox(width: 6),
                Text('This message was deleted',
                    style: TextStyle(
                        color: textColor.withOpacity(0.7),
                        fontSize: 13.5,
                        fontStyle: FontStyle.italic)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showSenderName &&
                    !isMe &&
                    message.senderName.isNotEmpty) ...[
                  Text(message.senderName,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const SizedBox(height: 4),
                ],
                if (hasReply) ...[
                  _ReplyQuote(replyTo: replyTo, foreground: textColor),
                  const SizedBox(height: 6),
                ],
                if (hasFile)
                  isImageFile
                      ? _ImageAttachmentPreview(url: resolvedFileUrl!)
                      : _FileAttachmentChip(
                          url: resolvedFileUrl!,
                          name: message.fileName ?? 'Attachment',
                          type: message.fileType,
                          foreground: textColor,
                        ),
                if (hasFile && hasText) const SizedBox(height: 8),
                if (hasText)
                  Text.rich(
                    TextSpan(
                      children: _highlightSpans(message.message, highlight,
                          current: isCurrentMatch),
                    ),
                    style: TextStyle(
                        color: textColor, fontSize: 14.5, height: 1.35),
                  ),
              ],
            ),
    );

    final meta = Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDeleted && message.isPinned) ...[
            const Icon(Icons.push_pin_rounded,
                size: 12, color: AppColors.textHint),
            const SizedBox(width: 4),
          ],
          Text(DateFormat('hh:mm a').format(message.createdAt),
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textHint)),
          if (!isDeleted && isMe) ...[
            const SizedBox(width: 4),
            Icon(Icons.done_all_rounded,
                size: 14,
                color: message.isRead
                    ? AppColors.primary
                    : AppColors.textHint),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.10) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (selected && onReact != null)
              _QuickReactionBar(
                myEmoji: _myEmoji,
                onReact: onReact!,
                onMore: onMoreReactions,
              ),
            bubble,
            if (!isDeleted && message.reactions.isNotEmpty)
              _ReactionChips(
                reactions: message.reactions,
                currentUserId: currentUserId,
                onTap: onReact,
              ),
            meta,
          ],
        ),
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  final ChatReplyModel replyTo;
  final Color foreground;
  const _ReplyQuote({required this.replyTo, required this.foreground});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: foreground.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border(
            left: BorderSide(color: foreground.withOpacity(0.6), width: 2.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyTo.senderName.isNotEmpty) ...[
            Text(replyTo.senderName,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: foreground)),
            const SizedBox(height: 2),
          ],
          Text(replyTo.message,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: foreground.withOpacity(0.85))),
        ],
      ),
    );
  }
}

class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onReply;
  final bool alignEnd;

  const _SwipeToReply({
    required this.child,
    required this.onReply,
    required this.alignEnd,
  });

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  static const double _maxDrag = 64;
  static const double _triggerDrag = 48;

  double _dragExtent = 0;
  bool _dragging = false;

  void _onDragStart(DragStartDetails details) {
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragExtent = (_dragExtent + details.delta.dx).clamp(-_maxDrag, _maxDrag);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() >= _triggerDrag) {
      widget.onReply();
    }
    setState(() {
      _dragging = false;
      _dragExtent = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_dragExtent.abs() / _triggerDrag).clamp(0.0, 1.0);
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        alignment: widget.alignEnd ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          if (progress > 0)
            Align(
              alignment: _dragExtent >= 0
                  ? Alignment.centerLeft
                  : Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Opacity(
                  opacity: progress,
                  child: const Icon(Icons.reply_rounded,
                      color: AppColors.textSecondary, size: 22),
                ),
              ),
            ),
          AnimatedContainer(
            duration: _dragging ? Duration.zero : const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            transform: Matrix4.translationValues(_dragExtent, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _ImageAttachmentPreview extends StatelessWidget {
  // Compact thumbnail; tap opens the full-size viewer.
  static const double _width = 150;
  static const double _height = 110;

  final String url;
  const _ImageAttachmentPreview({required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => _ImageViewerScreen(url: url)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: _width,
          height: _height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(
            width: _width,
            height: _height,
            color: AppColors.background,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_outlined,
                size: 20, color: AppColors.textHint),
          ),
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return Container(
              width: _width,
              height: _height,
              color: AppColors.background,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.primary),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ImageViewerScreen extends StatelessWidget {
  final String url;
  const _ImageViewerScreen({required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.8,
              maxScale: 4,
              child: Image.network(
                url,
                errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 48),
              ),
            ),
          ),
          SafeArea(
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _FileAttachmentChip extends StatelessWidget {
  final String url;
  final String name;
  final String? type;
  final Color foreground;

  const _FileAttachmentChip({
    required this.url,
    required this.name,
    required this.type,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () =>
          launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: foreground.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_iconForFileType(type), size: 20, color: foreground),
            const SizedBox(width: 8),
            Flexible(
              child: Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplyPreviewBar extends StatelessWidget {
  final ChatMessageModel message;
  final VoidCallback onCancel;

  const _ReplyPreviewBar({required this.message, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final label = message.isMe
        ? 'You'
        : (message.senderName.isEmpty ? 'Them' : message.senderName);
    final preview = message.message.isNotEmpty
        ? message.message
        : ((message.fileName ?? '').isNotEmpty
            ? message.fileName!
            : 'Attachment');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: const Border(
            left: BorderSide(color: AppColors.primary, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Replying to $label',
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary)),
                const SizedBox(height: 2),
                Text(preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onCancel,
            borderRadius: BorderRadius.circular(12),
            child: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textHint),
          ),
        ],
      ),
    );
  }
}

class _MessageInputBar extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final PlatformFile? pendingFile;
  final VoidCallback onRemoveFile;
  final bool uploading;
  final ChatMessageModel? replyingTo;
  final VoidCallback onCancelReply;

  const _MessageInputBar({
    required this.controller,
    required this.hint,
    required this.onSend,
    required this.onAttach,
    required this.pendingFile,
    required this.onRemoveFile,
    required this.uploading,
    required this.replyingTo,
    required this.onCancelReply,
  });

  @override
  State<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<_MessageInputBar> {
  final FocusNode _focusNode = FocusNode();
  bool _showEmoji = false;

  TextEditingController get controller => widget.controller;
  String get hint => widget.hint;
  VoidCallback get onSend => widget.onSend;
  VoidCallback get onAttach => widget.onAttach;
  PlatformFile? get pendingFile => widget.pendingFile;
  VoidCallback get onRemoveFile => widget.onRemoveFile;
  bool get uploading => widget.uploading;
  ChatMessageModel? get replyingTo => widget.replyingTo;
  VoidCallback get onCancelReply => widget.onCancelReply;

  bool get _focused => _focusNode.hasFocus;

  // Send lights up only when there is something to send.
  bool get _canSend =>
      !uploading &&
      (controller.text.trim().isNotEmpty || pendingFile != null);

  @override
  void initState() {
    super.initState();
    // Typing again (keyboard up) closes the emoji panel; focus also
    // drives the border highlight.
    _focusNode.addListener(() {
      setState(() {
        if (_focusNode.hasFocus) _showEmoji = false;
      });
    });
    controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(covariant _MessageInputBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_onTextChanged);
      controller.addListener(_onTextChanged);
    }
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _toggleEmoji() {
    if (_showEmoji) {
      // Back to the keyboard.
      _focusNode.requestFocus();
      setState(() => _showEmoji = false);
    } else {
      _focusNode.unfocus();
      setState(() => _showEmoji = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (replyingTo != null) ...[
            _ReplyPreviewBar(message: replyingTo!, onCancel: onCancelReply),
            const SizedBox(height: 8),
          ],
          if (pendingFile != null) ...[
            _AttachmentPreview(
              file: pendingFile!,
              uploading: uploading,
              onRemove: onRemoveFile,
            ),
            const SizedBox(height: 8),
          ],
          // Attach, emoji, text and send all live inside one bordered box.
          Container(
            padding: const EdgeInsets.fromLTRB(4, 4, 6, 4),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused || _showEmoji
                    ? AppColors.primary.withOpacity(0.6)
                    : AppColors.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: uploading ? null : onAttach,
                  tooltip: 'Attach',
                  icon: const Icon(Icons.attach_file_rounded,
                      color: AppColors.textSecondary, size: 20),
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  onPressed: _toggleEmoji,
                  tooltip: _showEmoji ? 'Keyboard' : 'Emoji',
                  icon: Icon(
                      _showEmoji
                          ? Icons.keyboard_alt_outlined
                          : Icons.emoji_emotions_outlined,
                      color: _showEmoji
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 20),
                  splashRadius: 18,
                  visualDensity: VisualDensity.compact,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                    style: const TextStyle(fontSize: 14),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: const TextStyle(
                          color: AppColors.textHint, fontSize: 14),
                      border: InputBorder.none,
                      isCollapsed: true,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: InkWell(
                    onTap: _canSend ? onSend : null,
                    customBorder: const CircleBorder(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _canSend
                            ? AppColors.primary
                            : AppColors.primary.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Transform.rotate(
                        angle: -0.45,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 2),
                          child: Icon(Icons.send_rounded,
                              color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_showEmoji) ...[
            const SizedBox(height: 10),
            // Inserts at the cursor and handles backspace on its own.
            EmojiPicker(
              textEditingController: controller,
              config: const Config(
                height: 260,
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 26,
                  backgroundColor: AppColors.surface,
                ),
                categoryViewConfig: CategoryViewConfig(
                  tabBarHeight: 40,
                  extraTab: CategoryExtraTab.BACKSPACE,
                  backgroundColor: AppColors.surface,
                  indicatorColor: AppColors.primary,
                  iconColor: AppColors.textHint,
                  iconColorSelected: AppColors.primary,
                  backspaceColor: AppColors.textSecondary,
                ),
                bottomActionBarConfig: BottomActionBarConfig(enabled: false),
                skinToneConfig: SkinToneConfig(enabled: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttachmentPreview extends StatelessWidget {
  final PlatformFile file;
  final bool uploading;
  final VoidCallback onRemove;

  const _AttachmentPreview({
    required this.file,
    required this.uploading,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final isImage = _isImageType(file.extension) && file.bytes != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(file.bytes!,
                  width: 36, height: 36, fit: BoxFit.cover),
            )
          else
            Icon(_iconForFileType(file.extension),
                size: 22, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 8),
          if (uploading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.primary),
            )
          else
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(12),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textHint),
            ),
        ],
      ),
    );
  }
}

IconData _iconForFileType(String? extOrType) {
  switch ((extOrType ?? '').toLowerCase()) {
    case 'jpg':
    case 'jpeg':
    case 'png':
    case 'gif':
    case 'webp':
      return Icons.image_outlined;
    case 'pdf':
      return Icons.picture_as_pdf_outlined;
    case 'doc':
    case 'docx':
      return Icons.description_outlined;
    case 'xls':
    case 'xlsx':
    case 'csv':
      return Icons.table_chart_outlined;
    case 'zip':
    case 'rar':
      return Icons.folder_zip_outlined;
    default:
      return Icons.insert_drive_file_outlined;
  }
}

bool _isImageType(String? extOrType) {
  final v = (extOrType ?? '').toLowerCase();
  if (v == 'image' || v.startsWith('image/')) return true;
  return const ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(v);
}

String? _extensionFromName(String? name) {
  if (name == null) return null;
  final idx = name.lastIndexOf('.');
  if (idx == -1 || idx == name.length - 1) return null;
  return name.substring(idx + 1);
}

class _MessagesLoading extends StatelessWidget {
  const _MessagesLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
            strokeWidth: 2.4, color: AppColors.primary),
      ),
    );
  }
}

class _MessagesError extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _MessagesError({required this.message, this.onRetry});

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
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}

/// Splits [text] so every case-insensitive match of [query] gets a
/// highlight; the rest inherits the surrounding style. [current] marks the
/// match the search ▲/▼ buttons are on with a stronger colour.
List<TextSpan> _highlightSpans(String text, String? query,
    {bool current = false}) {
  final q = query?.trim().toLowerCase() ?? '';
  if (q.isEmpty) return [TextSpan(text: text)];

  final matchStyle = TextStyle(
    backgroundColor:
        current ? const Color(0xFFFB923C) : const Color(0xFFFDE68A),
    color: AppColors.textPrimary,
    fontWeight: FontWeight.w600,
  );
  final lower = text.toLowerCase();
  final spans = <TextSpan>[];
  var start = 0;
  while (true) {
    final idx = lower.indexOf(q, start);
    if (idx < 0) break;
    if (idx > start) spans.add(TextSpan(text: text.substring(start, idx)));
    spans.add(TextSpan(
        text: text.substring(idx, idx + q.length), style: matchStyle));
    start = idx + q.length;
  }
  if (start < text.length) spans.add(TextSpan(text: text.substring(start)));
  return spans;
}

/// Floating search box that replaces the chat header while searching:
/// search icon, field, match counter, ▲ / ▼, divider, close. The parent
/// rebuilds it on every change, so it holds no state of its own.
class _ChatSearchBar extends StatelessWidget {
  final TextEditingController controller;

  /// 1-based position of the current match; null when there is none.
  final int? current;

  /// Number of matches; null while the query is empty.
  final int? total;
  final ValueChanged<String> onChanged;

  /// Older match; null when already on the oldest.
  final VoidCallback? onUp;

  /// Newer match; null when already on the newest.
  final VoidCallback? onDown;
  final VoidCallback onClose;

  const _ChatSearchBar({
    required this.controller,
    required this.current,
    required this.total,
    required this.onChanged,
    required this.onUp,
    required this.onDown,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final total = this.total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 48,
        padding: const EdgeInsets.only(left: 14, right: 4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onChanged: onChanged,
                // Keyboard search key steps to the older match, like ▲.
                onSubmitted: (_) => onUp?.call(),
                style: const TextStyle(fontSize: 14),
                decoration: const InputDecoration(
                  hintText: 'Search in this chat...',
                  hintStyle:
                      TextStyle(color: AppColors.textHint, fontSize: 14),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
              ),
            ),
            if (total != null) ...[
              const SizedBox(width: 6),
              Text(
                total == 0 ? 'No results' : '${current ?? 0} of $total',
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary),
              ),
            ],
            _navButton(Icons.keyboard_arrow_up_rounded, 'Older match', onUp),
            _navButton(
                Icons.keyboard_arrow_down_rounded, 'Newer match', onDown),
            Container(
              width: 1,
              height: 22,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              color: AppColors.border,
            ),
            IconButton(
              onPressed: onClose,
              tooltip: 'Close search',
              icon: const Icon(Icons.close_rounded,
                  color: AppColors.textSecondary, size: 20),
              splashRadius: 18,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, String tooltip, VoidCallback? onTap) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 24),
      color: AppColors.textSecondary,
      disabledColor: AppColors.textHint.withOpacity(0.5),
      splashRadius: 18,
      visualDensity: VisualDensity.compact,
    );
  }
}

class _EmptyThread extends StatelessWidget {
  const _EmptyThread();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline_rounded,
              size: 48, color: AppColors.textHint),
          SizedBox(height: 12),
          Text('No messages yet',
              style: TextStyle(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600)),
          SizedBox(height: 4),
          Text('Say hello to start the conversation',
              style: TextStyle(color: AppColors.textHint, fontSize: 12.5)),
        ],
      ),
    );
  }
}

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: AppColors.textHint),
            SizedBox(height: 16),
            Text('Select a conversation',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
            SizedBox(height: 6),
            Text('Pick a contact or group from the list to start chatting',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
