// ╔══════════════════════════════════════════════════════════════╗
// ║       lib/screen/tasks/view/target_details_sheet.dart        ║
// ║  VIEW — "Records" bottom sheet for one target, in two tabs:   ║
// ║  Leads (linked leads + their issues) and Deals (linked and    ║
// ║  converted deals + their issues). Notes show in both.         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/view/issue_conversation.dart';
import 'package:crm_app/screen/tasks/view/linked_item_detail.dart';
import 'package:crm_app/screen/tasks/view/linked_items_sheet.dart'
    show LinkedItemCard, SheetHandle;
import 'package:crm_app/screen/tasks/view/target_widgets.dart'
    show TargetPalette;
import 'package:crm_app/screen/tasks/viewmodel/linked_items_state.dart';
import 'package:crm_app/screen/tasks/viewmodel/target_state.dart';
import 'package:crm_app/screen/tasks/viewmodel/target_view_model.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';

Future<void> showTargetDetailsSheet(
  BuildContext context, {
  required TargetCardData data,
  required TargetViewModel viewModel,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    // Own ScaffoldMessenger + Scaffold so snackbars show above the sheet
    // (same setup as the Task screen's Linked items sheet).
    builder: (sheetContext) => ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // Tap outside the sheet closes it, as before.
          onTap: () => Navigator.of(sheetContext).pop(),
          child: GestureDetector(
            // Swallow taps on the sheet itself.
            onTap: () {},
            child: DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              // Follow the ViewModel so a reported issue appears straight away.
              builder: (context, controller) =>
                  BlocBuilder<TargetViewModel, TargetState>(
                bloc: viewModel,
                builder: (context, state) {
                  final fresh = state.visibleTargets
                      .where((c) => c.target.id == data.target.id)
                      .firstOrNull;
                  return _TargetDetails(
                    data: fresh ?? data,
                    viewModel: viewModel,
                    controller: controller,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

enum _RecordsTab { leads, deals }

class _TargetDetails extends StatefulWidget {
  final TargetCardData data;
  final TargetViewModel viewModel;
  final ScrollController controller;

  const _TargetDetails({
    required this.data,
    required this.viewModel,
    required this.controller,
  });

  @override
  State<_TargetDetails> createState() => _TargetDetailsState();
}

class _TargetDetailsState extends State<_TargetDetails> {
  late _RecordsTab _tab;

  /// Index into [_items] of the card opened in detail; null = list.
  int? _openIndex;

  bool _reporting = false;

  Future<String?> _reportIssue(LinkedItemData item, String note) async {
    final targetId = widget.data.target.id;
    if (targetId == null) return 'Target not found';

    setState(() => _reporting = true);
    final error = await widget.viewModel.reportItemIssue(
      targetId: targetId,
      item: item,
      note: note,
    );
    if (mounted) setState(() => _reporting = false);
    return error;
  }

  TargetDetailsData get _d => widget.data.details;

  /// Cards of the current tab. Deals = linked deals, then deals from
  /// converted leads.
  List<LinkedItemData> get _items => _tab == _RecordsTab.leads
      ? _d.leadItems
      : [..._d.dealItems, ..._d.convertedDealItems];

  /// Issue conversation for one lead / deal — shown on its detail page.
  List<TargetIssueRow> _issuesFor(LinkedItemData item) => [
        for (final i in _d.issues)
          if (item.id != null && i.itemId == item.id) i,
      ];

  /// Issues not tied to a lead / deal in this target (about the target
  /// itself, or an item no longer linked) — listed under both tabs.
  List<TargetIssueRow> get _generalIssues {
    final ids = {
      for (final item in [
        ..._d.leadItems,
        ..._d.dealItems,
        ..._d.convertedDealItems,
      ])
        if (item.id != null) item.id!,
    };
    return [
      for (final i in _d.issues)
        if (i.itemId == null || !ids.contains(i.itemId)) i,
    ];
  }

  int get _leadCount => _d.leadItems.length;
  int get _dealCount => _d.dealItems.length + _d.convertedDealItems.length;

  @override
  void initState() {
    super.initState();
    // Open on deals only when there are deals but no leads.
    _tab = _leadCount == 0 && _dealCount > 0
        ? _RecordsTab.deals
        : _RecordsTab.leads;
  }

  void _selectTab(_RecordsTab tab) => setState(() {
        _tab = tab;
        _openIndex = null;
      });

  Widget _card(int index) => LinkedItemCard(
        item: _items[index],
        onTap: () => setState(() => _openIndex = index),
      );

  List<Widget> _tabContent() {
    final general = [
      _NotesPanel(
        notes: _d.notes,
        onSend: (text) {
          final targetId = widget.data.target.id;
          if (targetId == null) return Future.value('Target not found');
          return widget.viewModel.addNote(targetId: targetId, text: text);
        },
      ),
      if (_generalIssues.isNotEmpty)
        _Section(
          title: 'Target issues',
          count: _generalIssues.length,
          children: [
            IssueScrollBox(children: [
              for (final i in _generalIssues) _IssueRow(issue: i),
            ]),
          ],
        ),
    ];

    if (_tab == _RecordsTab.leads) {
      return [
        if (_leadCount == 0)
          const _EmptyTab(text: 'No leads linked to this target'),
        for (var i = 0; i < _leadCount; i++) _card(i),
        ...general,
      ];
    }

    final linked = _d.dealItems.length;
    return [
      if (_dealCount == 0)
        const _EmptyTab(text: 'No deals linked to this target'),
      for (var i = 0; i < linked; i++) _card(i),
      if (_d.convertedDealItems.isNotEmpty)
        _Section(
          title: 'Deals from converted leads',
          count: _d.convertedDealItems.length,
          children: [for (var i = linked; i < _dealCount; i++) _card(i)],
        ),
      ...general,
    ];
  }

  /// Underlined tabs with count pills — same as the Linked items sheet.
  Widget _buildTabs() {
    return Row(
      children: [
        _TabButton(
          label: 'Leads',
          count: _leadCount,
          selected: _tab == _RecordsTab.leads,
          onTap: () => _selectTab(_RecordsTab.leads),
        ),
        _TabButton(
          label: 'Deals',
          count: _dealCount,
          selected: _tab == _RecordsTab.deals,
          onTap: () => _selectTab(_RecordsTab.deals),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final open = _openIndex;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // Same list ↔ detail swap as the Task screen's Linked items sheet.
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: open == null || open >= items.length
            ? _buildList()
            : LinkedItemDetail(
                key: ValueKey('$_tab-$open'),
                item: items[open],
                position: open + 1,
                total: items.length,
                controller: widget.controller,
                onBack: () => setState(() => _openIndex = null),
                reporting: _reporting,
                onReportIssue: (note) => _reportIssue(items[open], note),
                belowSummary: IssueConversation(issues: [
                  for (final i in _issuesFor(items[open]))
                    ItemIssue(
                      note: i.note,
                      status: i.status,
                      adminReply: i.adminReply,
                      atText: i.atText,
                    ),
                ]),
              ),
      ),
    );
  }

  Widget _buildList() {
    return Column(
      key: const ValueKey('list'),
      children: [
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SheetHandle(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Records',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.data.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          size: 22, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _buildTabs(),
              const Divider(height: 1, color: AppColors.border),
            ],
          ),
        ),
        Expanded(
          child: Scrollbar(
            controller: widget.controller,
            child: ListView(
              controller: widget.controller,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
              children: _tabContent(),
            ),
          ),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? TargetPalette.accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE0F2FE)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? const Color(0xFF0369A1)
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String text;

  const _EmptyTab({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final int count;
  final List<Widget> children;

  const _Section({
    required this.title,
    required this.count,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              '$title ($count)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: child,
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;

  const _Badge({required this.text, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// Notes on the target: a scrollable list (newest at the bottom, like a
/// chat) with a text box and Send button underneath.
class _NotesPanel extends StatefulWidget {
  final List<TargetNoteRow> notes;

  /// Sends a note; returns an error message or null.
  final Future<String?> Function(String text) onSend;

  const _NotesPanel({required this.notes, required this.onSend});

  @override
  State<_NotesPanel> createState() => _NotesPanelState();
}

class _NotesPanelState extends State<_NotesPanel> {
  static const _maxListHeight = kScrollBoxHeight;

  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _scrollToEnd();
  }

  @override
  void didUpdateWidget(covariant _NotesPanel old) {
    super.didUpdateWidget(old);
    // A new note arrived (after Send + reload) — show it.
    if (widget.notes.length != old.notes.length) _scrollToEnd();
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.jumpTo(_scroll.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final error = await widget.onSend(text);
    if (!mounted) return;

    setState(() => _sending = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    _text.clear();
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final notes = widget.notes;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.sticky_note_2_outlined,
                  size: 18, color: TargetPalette.accent),
              const SizedBox(width: 8),
              Text(
                'Notes (${notes.length})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (notes.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: Text(
                'No notes yet. Tell your admin what is holding you up.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: _maxListHeight),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: ListView.builder(
                  controller: _scroll,
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(right: 10),
                  itemCount: notes.length,
                  itemBuilder: (_, i) => _NoteRow(note: notes[i]),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _text,
                  enabled: !_sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add a note…',
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textHint,
                    ),
                    isDense: true,
                    filled: true,
                    fillColor: AppColors.background,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 11),
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
                      borderSide: const BorderSide(color: TargetPalette.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _text,
                builder: (_, value, __) {
                  final canSend = value.text.trim().isNotEmpty && !_sending;
                  return Material(
                    color: canSend
                        ? TargetPalette.accent
                        : TargetPalette.accent.withValues(alpha: 0.4),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: canSend ? _send : null,
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded,
                                size: 18, color: Colors.white),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NoteRow extends StatelessWidget {
  final TargetNoteRow note;

  const _NoteRow({required this.note});

  @override
  Widget build(BuildContext context) {
    final meta = [note.byText, note.atText].whereType<String>().join(' · ');

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColors.textPrimary,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              meta,
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
        ],
      ),
    );
  }
}

class _IssueRow extends StatelessWidget {
  final TargetIssueRow issue;

  const _IssueRow({required this.issue});

  (Color, Color) get _statusColors {
    switch (issue.status.toLowerCase()) {
      case 'resolved':
        return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
      case 'pending':
        return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
      case 'reactivated':
        return (TargetPalette.indigoBg, TargetPalette.indigo);
      default:
        return (const Color(0xFFF1F5F9), const Color(0xFF475569));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _statusColors;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  issue.note,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Badge(text: issue.status, bg: bg, fg: fg),
            ],
          ),
          if (issue.itemText != null || issue.atText != null) ...[
            const SizedBox(height: 4),
            Text(
              [issue.itemText, issue.atText].whereType<String>().join(' · '),
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
            ),
          ],
          if (issue.adminReply != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0F7FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Admin: ',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: issue.adminReply),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
