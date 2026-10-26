// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/widgets/                ║
// ║                            hub_document_sheet.dart            ║
// ║  DETAIL SHEET — opened from a card. Swipe between the visible ║
// ║  documents; each page shows source, upload date, file type,   ║
// ║  Download / Preview / Delete and the Activity & Replies trail ║
// ║  (not shown for invoices).                                    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:crm_app/screen/documents_hub/presentation/cubit/documents_hub_cubit.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_document_card.dart';
import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

/// Opens the sheet on [documents][initialIndex]. A delete closes the
/// sheet with the backend's message, shown here on the screen below.
Future<void> showHubDocumentSheet(
  BuildContext context, {
  required List<HubDocument> documents,
  required int initialIndex,
}) async {
  final cubit = context.read<DocumentsHubCubit>();
  final messenger = ScaffoldMessenger.maybeOf(context);

  final deleted = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: HubDocumentSheet(
        documents: documents,
        initialIndex: initialIndex,
      ),
    ),
  );

  if (deleted != null) {
    messenger?.showSnackBar(SnackBar(content: Text(deleted)));
  }
}

/// "lead document", "invoice document" … — "document" when the source
/// is unknown.
String _sourceNoun(HubDocument document) {
  final source = document.sourceType.trim().toLowerCase();
  return source.isEmpty ? 'document' : '$source document';
}

bool _isInvoice(HubDocument document) =>
    document.sourceType.trim().toLowerCase() == 'invoice';

class HubDocumentSheet extends StatefulWidget {
  final List<HubDocument> documents;
  final int initialIndex;

  const HubDocumentSheet({
    super.key,
    required this.documents,
    required this.initialIndex,
  });

  @override
  State<HubDocumentSheet> createState() => _HubDocumentSheetState();
}

class _HubDocumentSheetState extends State<HubDocumentSheet> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  /// Back goes to the previous document; on the first one it closes.
  void _back() {
    if (_index > 0) {
      _pages.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.documents[_index];

    return FractionallySizedBox(
      heightFactor: 0.92,
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        // Own messenger so snackbars show above the sheet, not under it.
        child: ScaffoldMessenger(
          child: Scaffold(
            backgroundColor: Colors.white,
            body: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: HubPalette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _back,
                        icon: const Icon(Icons.arrow_back_rounded),
                        color: HubPalette.ink,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Document ${_index + 1} of '
                              '${widget.documents.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: HubPalette.muted,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              doc.fileName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: HubPalette.ink,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: HubPalette.ink,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: HubPalette.border),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: widget.documents.length,
                    onPageChanged: (i) => setState(() => _index = i),
                    itemBuilder: (_, i) =>
                        _DocumentPage(document: widget.documents[i]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ONE DOCUMENT
// ══════════════════════════════════════════════════════════════

class _DocumentPage extends StatefulWidget {
  final HubDocument document;

  const _DocumentPage({required this.document});

  @override
  State<_DocumentPage> createState() => _DocumentPageState();
}

class _DocumentPageState extends State<_DocumentPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// After a reply, bring the newest message and the field into view.
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // Latest copy from the cubit so a sent reply shows up here; falls
    // back to the snapshot the sheet was opened with.
    final document = context.select<DocumentsHubCubit, HubDocument>((c) {
      final state = c.state;
      if (state is! DocumentsHubLoaded) return widget.document;
      return state.findDocument(widget.document.id) ?? widget.document;
    });
    final myId = context.select<DocumentsHubCubit, String>((c) {
      final state = c.state;
      return state is DocumentsHubLoaded
          ? state.myIdFor(document)
          : document.assignedTo?.id ?? '';
    });

    return Scrollbar(
      controller: _scroll,
      thumbVisibility: true,
      radius: const Radius.circular(8),
      child: ListView(
        controller: _scroll,
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        children: [
          _SourceCard(document: document),
          // Invoices have no Activity & Replies trail.
          if (!_isInvoice(document)) ...[
            const SizedBox(height: 14),
            _ActivityCard(
              document: document,
              myId: myId,
              onReplied: _scrollToBottom,
            ),
          ],
        ],
      ),
    );
  }
}

class _SourceCard extends StatefulWidget {
  final HubDocument document;

  const _SourceCard({required this.document});

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<_SourceCard> {
  bool _downloading = false;
  bool _previewing = false;
  bool _deleting = false;

  /// Asks first, then moves the assignment to the recycle bin and closes
  /// the sheet with the backend's message. A raw lead / deal file has
  /// no assignment to delete — that just explains why.
  Future<void> _delete() async {
    final messenger = ScaffoldMessenger.of(context);
    final document = widget.document;

    if (!document.isHubAssignment) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'This ${_sourceNoun(document)} is not assigned yet, '
              'so it can\'t be deleted.',
            ),
          ),
        );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete document?'),
        content: Text(
          '"${document.fileName}" will be moved to the recycle bin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);
    final result = await context.read<DocumentsHubCubit>().delete(document);

    if (!mounted) return;
    setState(() => _deleting = false);

    final error = result.error;
    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }
    Navigator.of(context).pop(result.message);
  }

  Future<void> _download() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _downloading = true);

    final result =
        await context.read<DocumentsHubCubit>().download(widget.document);

    if (!mounted) return;
    setState(() => _downloading = false);

    final savedPath = result.savedPath;
    messenger.showSnackBar(
      savedPath != null
          ? SnackBar(
              content: Text('Downloaded ${widget.document.fileName}'),
              // Success green, pairing with the red used for failures.
              backgroundColor: const Color(0xFF10B981),
              action: SnackBarAction(
                label: 'OPEN',
                textColor: Colors.white,
                onPressed: () => OpenFile.open(savedPath),
              ),
            )
          : SnackBar(
              content: Text(result.error ?? 'Download failed'),
              backgroundColor: const Color(0xFFDC2626),
            ),
    );
  }

  /// Fetches the file into the app's temp folder and opens it in the
  /// device's viewer.
  Future<void> _preview() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _previewing = true);

    final result = await context
        .read<DocumentsHubCubit>()
        .download(widget.document, forPreview: true);

    if (!mounted) return;
    setState(() => _previewing = false);

    final savedPath = result.savedPath;
    final error = savedPath == null
        ? result.error ?? 'Preview failed'
        : await _open(savedPath);

    if (!mounted || error == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(error),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  /// Null on success, otherwise the reason it couldn't be opened.
  Future<String?> _open(String path) async {
    final opened = await OpenFile.open(path);
    return opened.type == ResultType.done
        ? null
        : 'No app found to preview this file';
  }

  @override
  Widget build(BuildContext context) {
    final doc = widget.document;
    final uploaded = doc.uploadedAt?.toLocal();

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Source',
                  style: TextStyle(fontSize: 13, color: HubPalette.muted),
                ),
              ),
              HubStatusPill(status: doc.status),
            ],
          ),
          Text(
            doc.sourceName,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: HubPalette.ink,
            ),
          ),
          const SizedBox(height: 14),
          if (uploaded != null)
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              text: DateFormat('MMM d, y h:mm a').format(uploaded),
            ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.insert_drive_file_outlined,
            text: fileTypeLabel(doc),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Download',
                  icon: Icons.download_rounded,
                  background: const Color(0xFFEEF4FF),
                  border: const Color(0xFFBFD3FE),
                  foreground: const Color(0xFF1D4ED8),
                  busy: _downloading,
                  onPressed: _downloading ? null : _download,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Preview',
                  icon: Icons.visibility_outlined,
                  background: const Color(0xFFECFDF3),
                  border: const Color(0xFFA7F3D0),
                  foreground: const Color(0xFF15803D),
                  busy: _previewing,
                  onPressed: _previewing ? null : _preview,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
                  background: const Color(0xFFFEF2F2),
                  border: const Color(0xFFFECACA),
                  foreground: const Color(0xFFDC2626),
                  busy: _deleting,
                  // Not assigned: looks disabled, a tap says why.
                  dimmed: !doc.isHubAssignment,
                  onPressed: _deleting ? null : _delete,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatefulWidget {
  final HubDocument document;

  /// Activity performed by this id is "mine" and sits on the right.
  final String myId;
  final VoidCallback onReplied;

  const _ActivityCard({
    required this.document,
    required this.myId,
    required this.onReplied,
  });

  @override
  State<_ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<_ActivityCard> {
  /// The trail scrolls inside this height; the reply field stays below.
  static const _maxTrailHeight = 340.0;

  final _trail = ScrollController();

  @override
  void initState() {
    super.initState();
    // Open on the newest message, like a chat.
    _toLatest(animate: false);
  }

  @override
  void dispose() {
    _trail.dispose();
    super.dispose();
  }

  void _toLatest({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_trail.hasClients) return;
      final end = _trail.position.maxScrollExtent;
      animate
          ? _trail.animateTo(
              end,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            )
          : _trail.jumpTo(end);
    });
  }

  void _replied() {
    _toLatest();
    widget.onReplied();
  }

  @override
  Widget build(BuildContext context) {
    final document = widget.document;
    final activity = document.activity;
    final myId = widget.myId;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.chat_outlined,
                size: 22,
                color: HubPalette.accent,
              ),
              const SizedBox(width: 10),
              Text(
                'Activity & Replies (${activity.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: HubPalette.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (activity.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                // A raw lead / deal file has no hub record to hold a trail.
                document.isHubAssignment
                    ? 'No activity yet'
                    : 'Not assigned yet — activity and replies start once '
                        'this file is assigned.',
                style: const TextStyle(fontSize: 13, color: HubPalette.muted),
              ),
            ),
          if (activity.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxTrailHeight),
              child: Scrollbar(
                controller: _trail,
                thumbVisibility: true,
                radius: const Radius.circular(8),
                child: ListView.separated(
                  controller: _trail,
                  shrinkWrap: true,
                  // Room on the right so bubbles don't sit under the bar.
                  padding: const EdgeInsets.only(right: 10),
                  itemCount: activity.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 14),
                  itemBuilder: (_, i) {
                    final a = activity[i];
                    return a.note.trim().isEmpty
                        ? _SystemEvent(activity: a)
                        : _NoteBubble(
                            activity: a,
                            mine: myId.isNotEmpty && a.performedBy == myId,
                          );
                  },
                ),
              ),
            ),
          const SizedBox(height: 20),
          _ReplyField(document: document, onReplied: _replied),
        ],
      ),
    );
  }
}

/// "6 Oct 2026, 11:31 am"
String _activityTime(DateTime? date) {
  if (date == null) return '';
  return DateFormat('d MMM y, h:mm a')
      .format(date.toLocal())
      .replaceAll('AM', 'am')
      .replaceAll('PM', 'pm');
}

class _NoteBubble extends StatelessWidget {
  final DocumentActivity activity;
  final bool mine;

  const _NoteBubble({required this.activity, required this.mine});

  @override
  Widget build(BuildContext context) {
    const corner = Radius.circular(14);
    // Mine on the right, everyone else on the left; the tail corner
    // points at the sender's side.
    return Column(
      crossAxisAlignment:
          mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: mine ? HubPalette.accentBg : const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.only(
                topLeft: corner,
                topRight: corner,
                bottomLeft: mine ? corner : const Radius.circular(4),
                bottomRight: mine ? const Radius.circular(4) : corner,
              ),
            ),
            child: Text(
              activity.note,
              style: const TextStyle(fontSize: 14, color: HubPalette.ink),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          alignment: mine ? WrapAlignment.end : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              '${activity.role} · ${_activityTime(activity.createdAt)}',
              style: const TextStyle(fontSize: 12, color: HubPalette.hint),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: HubPalette.accentBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                activity.action.toLowerCase(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: HubPalette.accent,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SystemEvent extends StatelessWidget {
  final DocumentActivity activity;

  const _SystemEvent({required this.activity});

  IconData get _icon {
    switch (activity.action.toLowerCase()) {
      case 'viewed':
        return Icons.visibility_outlined;
      case 'replied':
        return Icons.reply_rounded;
      default:
        return Icons.inbox_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final (_, fg) = statusTone(activity.action);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_icon, size: 16, color: fg),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              '${activity.action} by ${activity.role} · '
              '${_activityTime(activity.createdAt)}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: HubPalette.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReplyField extends StatefulWidget {
  final HubDocument document;
  final VoidCallback onReplied;

  const _ReplyField({required this.document, required this.onReplied});

  @override
  State<_ReplyField> createState() => _ReplyFieldState();
}

class _ReplyFieldState extends State<_ReplyField> {
  final _text = TextEditingController();
  final _textScroll = ScrollController();
  bool _sending = false;

  /// Replies post to the hub record, which a raw lead / deal file
  /// doesn't have — send stays disabled for those.
  bool get _assigned => widget.document.isHubAssignment;

  bool get _canSend =>
      _assigned && !_sending && _text.text.trim().isNotEmpty;

  /// "This lead document is not assigned yet…" — names the source
  /// (lead, deal, invoice, external …) when there is one.
  void _showNotAssigned() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            'This ${_sourceNoun(widget.document)} is not assigned yet, '
            'so you can\'t reply to it.',
          ),
        ),
      );
  }

  @override
  void initState() {
    super.initState();
    // Rebuild so the send button enables / disables as the user types.
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _textScroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_canSend) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);

    final error = await context
        .read<DocumentsHubCubit>()
        .reply(widget.document, _text.text);

    if (!mounted) return;
    setState(() => _sending = false);

    if (error != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
      return;
    }

    _text.clear();
    widget.onReplied();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F7F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: HubPalette.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              // Grows to 4 lines, then scrolls inside with its own bar.
              child: Scrollbar(
                controller: _textScroll,
                child: TextField(
                  controller: _text,
                  scrollController: _textScroll,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 4,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14, color: HubPalette.ink),
                  decoration: const InputDecoration(
                    hintText: 'Type a reply...',
                    hintStyle: TextStyle(color: HubPalette.hint),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _canSend || _sending
                ? HubPalette.accent
                : const Color(0xFF93B4F8),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: !_assigned
                  ? _showNotAssigned
                  : _canSend
                      ? _send
                      : null,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: _sending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SMALL PIECES
// ══════════════════════════════════════════════════════════════

class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: HubPalette.border),
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: HubPalette.muted),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14, color: HubPalette.ink),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color background;
  final Color border;
  final Color foreground;
  final bool busy;

  /// Looks disabled but still takes taps (to explain why).
  final bool dimmed;

  /// Null = disabled (dimmed).
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.border,
    required this.foreground,
    this.busy = false,
    this.dimmed = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);

    return Opacity(
      opacity: dimmed || (onPressed == null && !busy) ? 0.5 : 1,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                busy
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
