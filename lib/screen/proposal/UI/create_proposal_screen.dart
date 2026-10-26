import 'dart:convert';

import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart' show Deal;
import 'package:crm_app/screen/proposal/modal/proposal_modal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:html_editor_enhanced/html_editor.dart';

import '../cubit/proposal_cubit.dart';

class CreateProposalScreen extends StatefulWidget {
  final Proposal? proposal;

  /// Pre-selects this deal (e.g. when opened from a deal's Proposals tab).
  final Deal? initialDeal;

  const CreateProposalScreen({
    super.key,
    this.proposal,
    this.initialDeal,
  });

  bool get isEditMode => proposal != null;

  /// Editing an already-sent proposal: "Update draft" would turn it
  /// back into a draft, so only "Update & Send" is offered.
  bool get isEditingSent =>
      proposal != null && proposal!.status.trim().toLowerCase() != 'draft';

  @override
  State<CreateProposalScreen> createState() =>
      _CreateProposalScreenState();
}
 

class _CreateProposalScreenState
    extends State<CreateProposalScreen> {
  final titleController = TextEditingController();
  final dealController = TextEditingController();
  final emailController = TextEditingController();
  final ccController = TextEditingController();
  final _titleFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _ccFocus = FocusNode();
final HtmlEditorController contentEditorController =
    HtmlEditorController();
    List<PlatformFile> selectedAttachments = [];

int wordCount = 0;
  String? selectedDealId;
  String selectedDealTitle = '';
  bool isEditorLoaded = false;

  bool detailsExpanded = true;
  bool contentExpanded = false;
  bool isSendingProposal = false;
  bool isSavingDraft = false;

  /// Latest editor HTML. Kept outside the editor because collapsing the
  /// Content section unmounts it.
  String _contentHtml = '';

  bool get _isBusy => isSavingDraft || isSendingProposal;

@override
void initState() {
  super.initState();

  final proposal = widget.proposal;
  _contentHtml = proposal?.content ?? '';

  for (final node in _fieldFocusNodes) {
    node.addListener(() {
      if (node.hasFocus) _blurEditor();
    });
  }

  if (proposal != null) {
    titleController.text = proposal.title;
    emailController.text = proposal.email;
    ccController.text = proposal.cc;

    // Some endpoints (e.g. /deals/:id/proposals) don't populate `deal`;
    // fall back to the deal the screen was opened from.
    final title = proposal.dealTitle.isNotEmpty
        ? proposal.dealTitle
        : (proposal.deal?.name ?? widget.initialDeal?.name ?? '');

    dealController.text = title;

    selectedDealTitle = title;

    selectedDealId = proposal.deal?.id ?? widget.initialDeal?.id;

    debugPrint(
      'EDIT PROPOSAL DEAL ID: ${proposal.deal?.id}',
    );

    debugPrint(
      'EDIT PROPOSAL DEAL TITLE: ${proposal.dealTitle}',
    );
  } else if (widget.initialDeal != null) {
    final deal = widget.initialDeal!;
    selectedDealId = deal.id;
    selectedDealTitle = deal.name;
    dealController.text = deal.name;
    emailController.text = deal.email.trim();
  }
}

  @override
  void dispose() {
    titleController.dispose();
    dealController.dispose();
    emailController.dispose();
    ccController.dispose();
    for (final node in _fieldFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  List<FocusNode> get _fieldFocusNodes =>
      [_titleFocus, _emailFocus, _ccFocus];

  // The editor is a WebView with its own focus, separate from Flutter's,
  // so without these both a Details field and the editor show a caret.

  /// Removes the editor's caret when a Details field takes focus.
  Future<void> _blurEditor() async {
    if (!isEditorLoaded) return;
    try {
      await contentEditorController.editorController?.evaluateJavascript(
        source: 'document.activeElement && document.activeElement.blur();',
      );
    } catch (_) {
      // Editor not ready — nothing to blur.
    }
  }

  /// Drops focus from the Details fields when the editor is touched.
  void _unfocusFields() {
    for (final node in _fieldFocusNodes) {
      if (node.hasFocus) node.unfocus();
    }
  }

/// Current editor HTML: the live editor when it is mounted, otherwise
/// the last content it reported.
Future<String> _readContent() async {
  if (contentExpanded && isEditorLoaded) {
    try {
      _contentHtml = await contentEditorController.getText();
    } catch (_) {
      // Editor not ready yet — keep the last known content.
    }
  }
  return _contentHtml;
}

/// Save draft / Update draft ([isDraft] true) or Send / Update & Send.
/// Title and deal are required for both; sending also needs
/// recipients and content.
Future<void> _submit({required bool isDraft}) async {
  if (_isBusy) return;

  final title = titleController.text.trim();
  final hasDeal =
      selectedDealId != null && selectedDealTitle.trim().isNotEmpty;

  if (title.isEmpty || !hasDeal) {
    _showMessage(
      title.isEmpty && !hasDeal
          ? 'Title and deal are required'
          : title.isEmpty
              ? 'Title is required'
              : 'Deal is required',
      isError: true,
    );
    return;
  }

  final content = await _readContent();
  if (!mounted) return;

  if (!isDraft) {
    if (emailController.text.trim().isEmpty) {
      _showMessage('Please enter customer email');
      return;
    }

    if (content
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim()
        .isEmpty) {
      _showMessage('Please enter proposal content');
      return;
    }
  }

  final cubit = context.read<ProposalCubit>();

  setState(() {
    if (isDraft) {
      isSavingDraft = true;
    } else {
      isSendingProposal = true;
    }
  });

  try {
    await cubit.createProposal(
      proposalId: widget.proposal?.id,
      title: title,
      selectedDealId: selectedDealId!,
      dealTitle: selectedDealTitle,
      cc: ccController.text.trim(),
      content: content,
      emails: emailController.text.trim(),
      isDraft: isDraft,
      attachments: selectedAttachments,
    );

    if (!mounted) return;

    _showMessage(
      isDraft
          ? (widget.isEditMode
              ? 'Draft updated successfully'
              : 'Draft saved successfully')
          : (widget.isEditMode
              ? 'Proposal updated and sent successfully'
              : 'Proposal sent successfully'),
      isSuccess: true,
    );
    Navigator.pop(context, true);
  } catch (e) {
    if (!mounted) return;

    _showMessage(
      e.toString().replaceFirst('Exception: ', ''),
    );
  } finally {
    if (mounted) {
      setState(() {
        isSavingDraft = false;
        isSendingProposal = false;
      });
    }
  }
}

  void _showMessage(
    String message, {
    bool isSuccess = false,
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isSuccess
            ? Colors.green
            : isError
                ? Colors.red
                : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xfff5f5f5),

      // =========================
      // HEADER
      // =========================

      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xfff1f1f1),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,

        title: Row(
          children: [
            IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(
                Icons.arrow_back,
                size: 20,
              ),
            ),

             Expanded(
              child: Text(
  widget.isEditMode
      ? 'Edit proposal'
      : 'New proposal',
  style: const TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w500,
  ),
),
            ),

            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.cloud_done_outlined,
                    size: 15,
                    color: Colors.grey,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Saved',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      // =========================
      // BODY
      // =========================

      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [

          // =========================
          // DETAILS
          // =========================

          _buildSection(
            title: 'Details',
            summary: 'Title, deal and recipients',
            expanded: detailsExpanded,
            onTap: () {
              setState(() {
                detailsExpanded = !detailsExpanded;
              });
            },
            child: _buildDetails(),
          ),

          const SizedBox(height: 8),

          // =========================
          // CONTENT
          // =========================

          _buildSection(
            title: 'Content',
            summary: 'Write the proposal and add files',
            expanded: contentExpanded,
            onTap: () {
              setState(() {
                contentExpanded = !contentExpanded;
                // Collapsing unmounts the editor; onInit sets this
                // again when it is reopened.
                if (!contentExpanded) isEditorLoaded = false;
              });
            },
            child: _buildContent(),
          ),

          const SizedBox(height: 100),
        ],
      ),

      // =========================
      // BOTTOM BUTTONS
      // =========================

      bottomNavigationBar: SafeArea(
  child: Container(
    padding: const EdgeInsets.fromLTRB(
      12,
      12,
      12,
      12,
    ),
    decoration: BoxDecoration(
      color: const Color(0xfff1f1f1),
      border: Border(
        top: BorderSide(
          color: Colors.grey.shade300,
        ),
      ),
    ),
    child: Row(
      children: [
        // =========================
        // SAVE AS DRAFT
        // =========================
        if (!widget.isEditingSent) ...[
        Expanded(
          child: OutlinedButton(
            onPressed: _isBusy
    ? null
    : () => _submit(isDraft: true),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            child: isSavingDraft
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                :  Text(
        widget.isEditMode
            ? 'Update draft'
            : 'Save as draft',
      ),
          ),
        ),

        const SizedBox(width: 10),
        ],

        // =========================
        // SEND PROPOSAL
        // =========================
        Expanded(
          child: ElevatedButton(
            onPressed: _isBusy
    ? null
    : () => _submit(isDraft: false),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
            ),
            child: isSendingProposal
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                :  Text(
        widget.isEditMode
            ? 'Update & Send'
            : 'Send proposal',
      ),
          ),
        ),
      ],
    ),
  ),
),
    );
  }

  // =========================
  // SECTION
  // =========================

  Widget _buildSection({
    required String title,
    required String summary,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: const Color(0xffdddddd),
          width: .5,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              child: Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey.shade400,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 13,
                      color: Colors.transparent,
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          summary,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (expanded)
            Container(
              padding: const EdgeInsets.fromLTRB(
                14,
                12,
                14,
                16,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade300,
                    width: .5,
                  ),
                ),
              ),
              child: child,
            ),
        ],
      ),
    );
  }

  // =========================
  // DETAILS BODY
  // =========================

  Widget _buildDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(
          'Proposal title',
          required: true,
        ),

        TextField(
          controller: titleController,
          focusNode: _titleFocus,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Type your proposal title',
            counterText: '',
          ),
        ),

        const SizedBox(height: 14),

        _label(
          'Select deal',
          required: true,
        ),

BlocBuilder<DealsCubit, DealsState>(
  builder: (context, state) {
    if (state is DealsLoading) {
      return  DropdownButtonFormField<String>(
        items: [],
        onChanged: null,
        decoration: const InputDecoration(
          hintText: 'Loading deals...',
        ),
      );
    }

    if (state is DealsError) {
      return DropdownButtonFormField<String>(
        items: const [],
        onChanged: null,
        decoration: InputDecoration(
          hintText: state.message,
        ),
      );
    }

if (state is DealsLoaded) {
  final availableDeals = state.allDeals.where((deal) {
    final stage = deal.stage.trim().toLowerCase();

    final isAllowedStage =
        stage != 'closed won' &&
        stage != 'closed lost';

    // Keep the existing deal visible while editing
    final isCurrentDeal =
        widget.isEditMode &&
        deal.id == selectedDealId;

    return isAllowedStage || isCurrentDeal;
  }).toList();

  return DropdownButtonFormField<String>(
    value: availableDeals.any(
      (deal) => deal.id == selectedDealId,
    )
        ? selectedDealId
        : null,

    isExpanded: true,

    decoration: const InputDecoration(
      hintText: 'Select deal',
    ),

    items: availableDeals.map((deal) {
      return DropdownMenuItem<String>(
        value: deal.id,
        child: Text(
          deal.name,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }).toList(),

    onChanged: (value) {
      if (value == null) return;

      final selectedDeal = availableDeals.firstWhere(
        (deal) => deal.id == value,
      );

      setState(() {
        selectedDealId = selectedDeal.id;
        selectedDealTitle = selectedDeal.name;

        dealController.text = selectedDeal.name;

        emailController.text =
            selectedDeal.email.trim();
      });
    },
  );
}

    return  DropdownButtonFormField<String>(
      items: [],
      onChanged: null,
      decoration: const InputDecoration(
        hintText: 'Select deal',
      ),
    );
  },
),        const SizedBox(height: 14),

        _label(
            
          'Customer emails',
          required: true,
        ),

        TextField(
          controller: emailController,
          focusNode: _emailFocus,
          keyboardType:
              TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText:
                'Enter multiple emails separated by commas',
          ),
        ),

        const SizedBox(height: 14),

        Row(
          children: [
            const Text(
              'CC email',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              '(optional)',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        TextField(
          controller: ccController,
          focusNode: _ccFocus,
          keyboardType:
              TextInputType.emailAddress,
          decoration: const InputDecoration(
            hintText: 'Enter CC email',
          ),
        ),
      ],
    );
  }

  // =========================
  // CONTENT BODY
  // =========================

  Widget _buildContent() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Proposal content',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          TextButton.icon(
            onPressed: _expandEditor,
            icon: const Icon(
              Icons.open_in_full,
              size: 15,
            ),
            label: const Text(
              'Expand',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),

      const SizedBox(height: 6),

      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: const Color(0xffdddddd),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            // =====================================================
            // TOOLBAR
            // =====================================================

            Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xfff5f5f5),
                border: Border(
                  bottom: BorderSide(
                    color: Colors.grey.shade300,
                    width: .5,
                  ),
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    _editorButton(
                      'B',
                      bold: true,
                      onTap: () {
                        contentEditorController.execCommand(
                          'bold',
                        );
                      },
                    ),

                    _editorButton(
                      'I',
                      italic: true,
                      onTap: () {
                        contentEditorController.execCommand(
                          'italic',
                        );
                      },
                    ),

                    _editorButton(
                      'U',
                      underline: true,
                      onTap: () {
                        contentEditorController.execCommand(
                          'underline',
                        );
                      },
                    ),

                    _editorButton(
                      'S',
                      strikethrough: true,
                      onTap: () {
                        contentEditorController.execCommand(
                          'strikeThrough',
                        );
                      },
                    ),

                    _toolbarDivider(),

                    _editorButton(
                      'H1',
                      onTap: () {
                        contentEditorController.execCommand(
                          'formatBlock',
                          argument: 'h1',
                        );
                      },
                    ),

                    _editorButton(
                      'H2',
                      onTap: () {
                        contentEditorController.execCommand(
                          'formatBlock',
                          argument: 'h2',
                        );
                      },
                    ),

                    _toolbarDivider(),

                    _iconEditorButton(
                      Icons.format_list_bulleted,
                      tooltip: 'Bullet list',
                      onTap: () {
                        contentEditorController.execCommand(
                          'insertUnorderedList',
                        );
                      },
                    ),

                    _iconEditorButton(
                      Icons.format_list_numbered,
                      tooltip: 'Numbered list',
                      onTap: () {
                        contentEditorController.execCommand(
                          'insertOrderedList',
                        );
                      },
                    ),

                    _toolbarDivider(),

                    _iconEditorButton(
                      Icons.horizontal_rule,
                      tooltip: 'Horizontal line',
                      onTap: () {
                        contentEditorController.execCommand(
                          'insertHorizontalRule',
                        );
                      },
                    ),

                    _editorButton(
                      'Quote',
                      onTap: () {
                        contentEditorController.execCommand(
                          'formatBlock',
                          argument: 'blockquote',
                        );
                      },
                    ),

                    _editorButton(
                      'Code',
                      onTap: () {
                        contentEditorController.execCommand(
                          'formatBlock',
                          argument: 'pre',
                        );
                      },
                    ),

                    _toolbarDivider(),

                    _iconEditorButton(
                      Icons.link,
                      tooltip: 'Insert link',
                      onTap: _insertLink,
                    ),

                    _iconEditorButton(
                      Icons.image_outlined,
                      tooltip: 'Insert image',
                      onTap: _insertImage,
                    ),

                    _toolbarDivider(),

                    _editorButton(
                      'App_Name',
                      onTap: () {
                        contentEditorController.insertHtml(
                          '<span>{{App_Name}}</span>',
                        );
                      },
                    ),

                    _editorButton(
                      'App_Logo',
                      onTap: () {
                        contentEditorController.insertHtml(
                          '<span>{{App_Logo}}</span>',
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

 // =====================================================
// HTML EDITOR
// =====================================================

Listener(
  // Pointer-down fires before the WebView takes the tap.
  onPointerDown: (_) => _unfocusFields(),
  child: SizedBox(
  height: 260,
  child: HtmlEditor(
    controller: contentEditorController,

    htmlEditorOptions: HtmlEditorOptions(
      initialText: _contentHtml,
      hint: 'Write your proposal...',
      shouldEnsureVisible: false,
      autoAdjustHeight: false,
      adjustHeightForKeyboard: true,
      spellCheck: true,
      darkMode: false,
    ),

    htmlToolbarOptions: const HtmlToolbarOptions(
      toolbarPosition: ToolbarPosition.custom,
    ),

    otherOptions: const OtherOptions(
      height: 260,
    ),

    callbacks: Callbacks(
      onInit: () {
        if (!mounted) return;

        setState(() {
          isEditorLoaded = true;
        });
      },

      onFocus: _unfocusFields,

      onChangeContent: (String? content) {
        _contentHtml = content ?? '';
        _updateWordCount(_contentHtml);
      },
    ),
  ),
),
),
            // =====================================================
            // FOOTER
            // =====================================================

            Container(
              height: 34,
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xfffafafa),
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade200,
                  ),
                ),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  Text(
                    '$wordCount words',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),

                  const Spacer(),

                  Icon(
                    Icons.cloud_done_outlined,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),

                  const SizedBox(width: 4),

                  Text(
                    'Saved',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),

      const SizedBox(height: 16),

      // ===========================================================
      // ATTACHMENTS
      // ===========================================================

      const Text(
        'Attachments',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),

      const SizedBox(height: 8),

Column(
  children: [
    GestureDetector(
      onTap: _pickAttachments,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 20,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.grey.shade400,
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 24,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 6),
            const Text(
              'Browse files',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Supports multiple files, max 10MB',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    ),

    if (selectedAttachments.isNotEmpty) ...[
      const SizedBox(height: 10),

      ...selectedAttachments.asMap().entries.map(
        (entry) {
          final index = entry.key;
          final file = entry.value;

          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 18,
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: Text(
                    file.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                    ),
                  ),
                ),

                IconButton(
                  onPressed: () {
                    setState(() {
                      selectedAttachments.removeAt(index);
                    });
                  },
                  icon: const Icon(
                    Icons.close,
                    size: 17,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        },
      ),
    ],
  ],
),
    ],
  );
}

Widget _editorButton(
  String text, {
  VoidCallback? onTap,
  bool bold = false,
  bool italic = false,
  bool underline = false,
  bool strikethrough = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(5),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(
            minWidth: 34,
          ),
          height: 34,
          padding: const EdgeInsets.symmetric(
            horizontal: 7,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(5),
            color: Colors.white,
          ),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  bold ? FontWeight.bold : FontWeight.w500,
              fontStyle:
                  italic ? FontStyle.italic : FontStyle.normal,
              decoration: underline
                  ? TextDecoration.underline
                  : strikethrough
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
            ),
          ),
        ),
      ),
    ),
  );
}

Widget _iconEditorButton(
  IconData icon, {
  required VoidCallback onTap,
  required String tooltip,
}) {
  return Padding(
    padding: const EdgeInsets.only(right: 4),
    child: Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(5),
          onTap: onTap,
          child: Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey.shade300,
              ),
              borderRadius: BorderRadius.circular(5),
              color: Colors.white,
            ),
            child: Icon(
              icon,
              size: 17,
              color: Colors.black87,
            ),
          ),
        ),
      ),
    ),
  );
}
Widget _toolbarDivider() {
  return Container(
    width: 1,
    height: 22,
    margin: const EdgeInsets.symmetric(
      horizontal: 4,
    ),
    color: Colors.grey.shade300,
  );
}
void _updateWordCount(String html) {
  final plainText = html
      .replaceAll(RegExp(r'<[^>]*>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();

  final words = plainText.isEmpty
      ? <String>[]
      : plainText.split(RegExp(r'\s+'));

  if (mounted) {
    setState(() {
      wordCount = words.length;
    });
  }
}
Future<void> _insertLink() async {
  String linkText = '';
  String linkUrl = '';

  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text(
          'Insert link',
          style: TextStyle(fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) {
                linkText = value;
              },
              decoration: const InputDecoration(
                labelText: 'Text',
                hintText: 'Visit our website',
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              onChanged: (value) {
                linkUrl = value;
              },
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            child: const Text('Cancel'),
          ),

          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            child: const Text('Insert'),
          ),
        ],
      );
    },
  );

  if (result != true) return;

  if (linkText.trim().isEmpty || linkUrl.trim().isEmpty) {
    _showMessage('Please enter text and URL');
    return;
  }

  contentEditorController.insertLink(
    linkText.trim(),
    linkUrl.trim(),
    true,
  );
}

Future<void> _insertImage() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;

    if (file.bytes == null) {
      _showMessage('Unable to read the selected image');
      return;
    }

    final extension = file.extension?.toLowerCase();

    final mimeType = switch (extension) {
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/png',
    };

    final base64Image = base64Encode(file.bytes!);

    final html = '''
      <p><br></p>
      <img
        src="data:$mimeType;base64,$base64Image"
        alt="${file.name}"
        width="120"
        style="
          width:120px;
          max-width:120px;
          height:auto;
          display:block;
          margin:8px 0;
        "
      />
      <p><br></p>
    ''';

    // Give the editor time to regain focus
    await Future.delayed(const Duration(milliseconds: 300));

    contentEditorController.insertHtml(html);

    // Update word count
    final updatedContent =
        await contentEditorController.getText();

    _updateWordCount(updatedContent);

    _showMessage('Image added');
  } catch (e) {
    _showMessage(
      'Failed to insert image: $e',
    );
  }
}

Future<void> _expandEditor() async {
  final currentHtml = await _readContent();

  if (!mounted) return;

  final expandedController = HtmlEditorController();

  final result = await Navigator.push<String>(
    context,
    MaterialPageRoute(
      builder: (context) {
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Proposal content',
              style: TextStyle(fontSize: 16),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  final html =
                      await expandedController.getText();

                  if (!context.mounted) return;

                  Navigator.pop(context, html);
                },
                child: const Text('Done'),
              ),
            ],
          ),
          body: SizedBox.expand(
            child: HtmlEditor(
              controller: expandedController,
              htmlEditorOptions: HtmlEditorOptions(
                initialText: currentHtml,
                hint: 'Write your proposal...',
                shouldEnsureVisible: false,
                autoAdjustHeight: false,
                adjustHeightForKeyboard: false,
                spellCheck: true,
                darkMode: false,
              ),
              htmlToolbarOptions: const HtmlToolbarOptions(
                toolbarType: ToolbarType.nativeScrollable,
              ),
              otherOptions: const OtherOptions(
                height: 500,
              ),
            ),
          ),
        );
      },
    ),
  );

  if (!mounted) return;

  if (result != null) {
    _contentHtml = result;
    if (isEditorLoaded) contentEditorController.setText(result);
    _updateWordCount(result);
  }
}

  Widget _label(
    String text, {
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 6,
      ),
      child: RichText(
        text: TextSpan(
          text: text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
          ],
        ),
      ),
    );
  }

 Future<void> _pickAttachments() async {
  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
      withData: false,
    );

    if (result == null) return;

    const maxSize = 10 * 1024 * 1024;

    final validFiles = <PlatformFile>[];

    for (final file in result.files) {
      if (file.size > maxSize) {
        _showMessage(
          '${file.name} is larger than 10MB',
        );
        continue;
      }

      if (file.path == null) {
        _showMessage(
          'Unable to access ${file.name}',
        );
        continue;
      }

      validFiles.add(file);
    }

    if (!mounted) return;

    setState(() {
      selectedAttachments = [
        ...selectedAttachments,
        ...validFiles,
      ];
    });
  } catch (e) {
    if (!mounted) return;

    _showMessage(
      'Failed to select files: $e',
    );
  }
}

}

class _InsertLinkDialog extends StatefulWidget {
  const _InsertLinkDialog();

  @override
  State<_InsertLinkDialog> createState() =>
      _InsertLinkDialogState();
}

class _InsertLinkDialogState extends State<_InsertLinkDialog> {
  late final TextEditingController textController;
  late final TextEditingController urlController;

  @override
  void initState() {
    super.initState();

    textController = TextEditingController();
    urlController = TextEditingController();
  }

  @override
  void dispose() {
    textController.dispose();
    urlController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        'Insert link',
        style: TextStyle(fontSize: 16),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: textController,
            decoration: const InputDecoration(
              labelText: 'Text',
              hintText: 'Example: Visit our website',
            ),
          ),

          const SizedBox(height: 12),

          TextField(
            controller: urlController,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
          },
          child: const Text('Cancel'),
        ),

        ElevatedButton(
          onPressed: () {
            Navigator.pop(
              context,
              {
                'text': textController.text.trim(),
                'url': urlController.text.trim(),
              },
            );
          },
          child: const Text('Insert'),
        ),
      ],
    );
  }
}