import 'package:crm_app/screen/email/cubit/email_template_cubit.dart';
import 'package:crm_app/screen/email/cubit/email_template_state.dart';
import 'package:crm_app/screen/email/cubit/scheduled_email_cubit.dart';
import 'package:crm_app/screen/email/modal/email_modal.dart';
import 'package:crm_app/screen/email/modal/email_template_modal.dart';
import 'package:crm_app/screen/email/modal/scheduled_email_modal.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CreateEmailScreen extends StatefulWidget {

  final List<EmailContact> recipients;
    final bool isEdit;
    final ScheduledEmail? scheduledEmail;
    
  /// Maps recipient email -> CRM deal/contact name, used to resolve
  /// names for [scheduledEmail] recipients (which are plain emails).
  final Map<String, String> recipientNames;

  const CreateEmailScreen({super.key,required this.recipients,
  this.isEdit = false,this.scheduledEmail,
  this.recipientNames = const {},
});

  @override
  State<CreateEmailScreen> createState() => _CreateEmailScreenState();
}

class _CreateEmailScreenState extends State<CreateEmailScreen> {
List<PlatformFile> _attachedFiles = [];
bool _isPickingFile = false;

static const int _maxAttachmentSize = 5 * 1024 * 1024;    final TextEditingController _subjectController =
      TextEditingController();

  final TextEditingController _contentController =
      TextEditingController();


  EmailTemplate? _selectedTemplate;
  String _editTemplateTitle = '';
  DateTime? _scheduledDateTime;
  late List<EmailContact> _editRecipients;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();

    // ADD THIS
    _editRecipients = widget.recipients;

    if (widget.isEdit && widget.scheduledEmail != null) {
      final email = widget.scheduledEmail!;

      // Subject
      _subjectController.text = email.subject;

      // Content
      _contentController.text = _removeHtml(email.content);

      // Template
      _editTemplateTitle = email.templateTitle;

      // Schedule date/time
      _scheduledDateTime = email.scheduledFor?.toLocal();

      // Recipients
      _editRecipients = email.recipients.map((recipient) {
        final name = widget.recipientNames[
            recipient.trim().toLowerCase()] ??
            '';

        return EmailContact.fromJson({
          'name': name,
          'email': recipient,
          'status': '',
        });
      }).toList();
    }
  }


  @override
  void dispose() {
    _subjectController.dispose();
    _contentController.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return BlocListener<EmailTemplateCubit, EmailTemplateState>(
    listener: (context, state) {
      if (state is BulkEmailSuccess) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(state.message),
      backgroundColor: Colors.green,
    ),
  );

  Navigator.of(
    context,
    rootNavigator: true,
  ).pop(true);
}
      if (state is BulkEmailError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    },
    child: Scaffold(
      backgroundColor: const Color(0xFFF8F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // =========================================================
            // HEADER
            // =========================================================
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF8F8FA),
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE5E5E7),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(
                        context,
                        rootNavigator: true,
                      ).pop();
                    },
                    icon: const Icon(
                      Icons.close,
                      size: 20,
                      color: Color(0xFF66666E),
                    ),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Create email',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF202124),
                    ),
                  ),
                ],
              ),
            ),

            // =========================================================
            // CONTENT
            // =========================================================
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    _buildTemplate(),
                    _buildSubject(),
                    _buildEmailContent(),
                    _buildAttachment(),
                    _buildRecipients(),
                  ],
                ),
              ),
            ),

            // =========================================================
            // BOTTOM ACTION BAR
            // =========================================================
            _buildBottomActions(),
          ],
        ),
      ),
    ),
  );
}  // =========================================================
  // TEMPLATE
  // =========================================================

  Widget _buildTemplate() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select template',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF66666E),
          ),
        ),

        const SizedBox(height: 6),

        GestureDetector(
          onTap: _showTemplateSheet,
          child: Container(
            height: 36,
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F5),
              border: Border.all(
                color: const Color(0xFFD9D9DE),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                   _selectedTemplate?.title ??
    (_editTemplateTitle.isNotEmpty
        ? _editTemplateTitle
        : 'Choose a template'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: _selectedTemplate == null
                          ? const Color(0xFF9999A1)
                          : const Color(0xFF303038),
                    ),
                  ),
                ),

                const Icon(
                  Icons.keyboard_arrow_down,
                  size: 17,
                  color: Color(0xFF77777F),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

  // =========================================================
  // SUBJECT
  // =========================================================

  Widget _buildSubject() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Subject',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF66666E),
                ),
              ),
              SizedBox(width: 3),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFE24B4A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          _buildTextField(
            controller: _subjectController,
            hintText: 'Enter email subject',
            height: 36,
          ),
        ],
      ),
    );
  }

  // =========================================================
  // EMAIL CONTENT
  // =========================================================

  Widget _buildEmailContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text(
                'Email content',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF66666E),
                ),
              ),
              SizedBox(width: 3),
              Text(
                '*',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFFE24B4A),
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          Container(
            height: 250,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F3F5),
              border: Border.all(
                color: const Color(0xFFD9D9DE),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TextField(
              controller: _contentController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF303038),
              ),
              decoration: const InputDecoration(
                hintText: 'Write your email here...',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF9999A1),
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // ATTACHMENT
  // =========================================================

Future<void> _pickAttachment() async {
  if (_isPickingFile) return;

  setState(() => _isPickingFile = true);

  try {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: false,
    );

    if (!mounted || result == null) return;

    final newFiles = result.files.where(
      (file) => !_attachedFiles.any(
        (existing) => existing.name == file.name,
      ),
    ).toList();

    final currentSize = _attachedFiles.fold<int>(
      0,
      (total, file) => total + file.size,
    );

    final addedFiles = <PlatformFile>[];
    int totalSize = currentSize;

    for (final file in newFiles) {
      if (totalSize + file.size <= _maxAttachmentSize) {
        addedFiles.add(file);
        totalSize += file.size;
      }
    }

    setState(() {
      _attachedFiles.addAll(addedFiles);
    });

    if (addedFiles.length < newFiles.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some files were not added because the combined attachment size cannot exceed 5 MB.',
          ),
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Unable to select files: $e')),
    );
  } finally {
    if (mounted) {
      setState(() => _isPickingFile = false);
    }
  }
}

void _removeAttachment(PlatformFile file) {
  setState(() {
    _attachedFiles.remove(file);
  });
}

String _formatFileSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
}

Widget _buildAttachment() {
  final totalSize = _attachedFiles.fold<int>(
    0,
    (total, file) => total + file.size,
  );

  final remainingSize = _maxAttachmentSize - totalSize;

  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: _isPickingFile ? null : _pickAttachment,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFB7B7BF),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.cloud_upload_outlined,
                  size: 18,
                  color: Color(0xFF625DCE),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _isPickingFile
                        ? 'Selecting files...'
                        : 'Tap to attach files',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF625DCE),
                    ),
                  ),
                ),
                Text(
                  '${_formatFileSize(remainingSize)} left',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF9999A1),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_attachedFiles.isNotEmpty) ...[
          const SizedBox(height: 8),
          ..._attachedFiles.map(
            (file) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F4FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFE0DDFB),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.attach_file,
                    size: 17,
                    color: Color(0xFF625DCE),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      file.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _formatFileSize(file.size),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF777780),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeAttachment(file),
                    tooltip: 'Remove attachment',
                    icon: const Icon(
                      Icons.close,
                      size: 17,
                      color: Colors.red,
                    ),
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          Text(
            '${_attachedFiles.length} file(s) · '
            '${_formatFileSize(totalSize)} of 5 MB used',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF777780),
            ),
          ),
        ],
      ],
    ),
  );
}
  // =========================================================
  // RECIPIENTS
  // =========================================================

Widget _buildRecipients() {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recipients',
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF66666E),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(
              color: const Color(0xFFD9D9DE),
              width: 0.5,
            ),
            borderRadius: BorderRadius.circular(10),
          ),
          child: _editRecipients.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'No recipients selected',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF77777F),
                    ),
                  ),
                )
              : Column(
                  children: _editRecipients.map((contact) {
                    return Row(
                      children: [
                        Expanded(
                          child: _buildDynamicRecipient(contact),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _editRecipients.remove(contact);
                            });
                          },
                          tooltip: 'Remove recipient',
                          icon: const Icon(
                            Icons.close,
                            size: 18,
                            color: Colors.red,
                          ),
                          visualDensity: VisualDensity.compact,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    );
                  }).toList(),
                ),
        ),
      ],
    ),
  );
}  // =========================================================
  // DYNAMIC RECIPIENT ITEM
  // ========================================================
  Widget _buildDynamicRecipient(EmailContact contact) {
  final String name = contact.name.trim().isEmpty
      ? 'Unnamed'
      : contact.name.trim();

  final String email = contact.email.trim();

  final String initial = name.isNotEmpty
      ? name[0].toUpperCase()
      : '?';

  final String status = contact.status.trim();

  final bool isConverted =
      status.toLowerCase() == 'converted';

  final Color avatarBackground = isConverted
      ? const Color(0xFFE8F5F0)
      : const Color(0xFFF3ECFF);

  final Color avatarText = isConverted
      ? const Color(0xFF1D9E75)
      : const Color(0xFF7F77DD);

  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 10,
    ),
    child: Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: avatarBackground,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: avatarText,
            ),
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF202124),
                ),
              ),

              const SizedBox(height: 2),

              Text(
                email.isEmpty ? 'No email' : email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF77777F),
                ),
              ),
            ],
          ),
        ),

        if (status.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 7,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: isConverted
                  ? const Color(0xFFE8F5F0)
                  : const Color(0xFFF3ECFF),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: avatarText,
              ),
            ),
          ),
      ],
    ),
  );
}

  
  
  // =========================================================
  // BOTTOM ACTIONS
  // =========================================================

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE5E5E7),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // CANCEL
          OutlinedButton(
            onPressed: () {
              Navigator.of(
                context,
                rootNavigator: true,
              ).pop();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              side: const BorderSide(
                color: Color(0xFFB7B7BF),
                width: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF303038),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // SCHEDULE
          OutlinedButton.icon(
            onPressed: _showScheduleDialog,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              side: BorderSide(
                color: _scheduledDateTime != null
                    ? const Color(0xFF625DCE)
                    : const Color(0xFFB7B7BF),
                width: 0.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(
              Icons.access_time,
              size: 15,
              color: _scheduledDateTime != null
                  ? const Color(0xFF625DCE)
                  : const Color(0xFF66666E),
            ),
            label: Text(
              _scheduledDateTime != null
                  ? _formatScheduledLabel(_scheduledDateTime!)
                  : 'Schedule',
              style: TextStyle(
                fontSize: 13,
                color: _scheduledDateTime != null
                    ? const Color(0xFF625DCE)
                    : const Color(0xFF66666E),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // SEND
          Expanded(
  child: BlocBuilder<EmailTemplateCubit, EmailTemplateState>(
    buildWhen: (previous, current) =>
        current is BulkEmailLoading ||
        current is BulkEmailSuccess ||
        current is BulkEmailError,
    builder: (context, state) {
      final bool isLoading =
          widget.isEdit ? _isUpdating : state is BulkEmailLoading;

      return ElevatedButton.icon(
       onPressed: isLoading
    ? null
    : widget.isEdit
        ? _updateScheduledEmail
        : _sendEmail,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, 38),
          backgroundColor: const Color(0xFF303030),
          disabledBackgroundColor: const Color(0xFF777777),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              )
            : Icon(
                widget.isEdit ? Icons.check : Icons.send,
                size: 15,
                color: Colors.white,
              ),
        label: Text(
          widget.isEdit
              ? (isLoading ? 'Updating...' : 'Update')
              : (isLoading ? 'Sending...' : 'Send'),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      );
    },
  ),
),
        ],
      ),
    );
  }
  

  // =========================================================
  // TEXT FIELD
  // =========================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    required double height,
  }) {
    return SizedBox(
      height: height,
      child: TextField(
        controller: controller,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF303038),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 13,
            color: Color(0xFF9999A1),
          ),
          filled: true,
          fillColor: const Color(0xFFF3F3F5),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFFD9D9DE),
              width: 0.5,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFFD9D9DE),
              width: 0.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
              color: Color(0xFFB7B7BF),
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TEMPLATE SHEET
  // =========================================================

  void _showTemplateSheet() {
  final cubit = context.read<EmailTemplateCubit>();

  if (cubit.state is! EmailTemplateSuccess) {
    cubit.getEmailTemplates();
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(20),
      ),
    ),
    builder: (sheetContext) {
      return BlocProvider.value(
        value: cubit,
        child: SafeArea(
          child: BlocBuilder<
              EmailTemplateCubit,
              EmailTemplateState>(
            builder: (context, state) {
              // ======================================================
              // LOADING
              // ======================================================

              if (state is EmailTemplateLoading) {
                return const SizedBox(
                  height: 220,
                  child: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              // ======================================================
              // ERROR
              // ======================================================

              if (state is EmailTemplateError) {
                return SizedBox(
                  height: 220,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 32,
                            color: Color(0xFFE24B4A),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF66666E),
                            ),
                          ),

                          const SizedBox(height: 12),

                          TextButton(
                            onPressed: () {
                              context
                                  .read<EmailTemplateCubit>()
                                  .getEmailTemplates();
                            },
                            child: const Text(
                              'Retry',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // ======================================================
              // SUCCESS
              // ======================================================

              if (state is EmailTemplateSuccess) {
                final templates = state.templates;

                if (templates.isEmpty) {
                  return const SizedBox(
                    height: 220,
                    child: Center(
                      child: Text(
                        'No email templates found',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF77777F),
                        ),
                      ),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(
                    top: 8,
                    bottom: 10,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // HEADER
                      const Padding(
                        padding: EdgeInsets.fromLTRB(
                          18,
                          10,
                          18,
                          14,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Choose a template',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF202124),
                            ),
                          ),
                        ),
                      ),

                      // TEMPLATE LIST
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          itemCount: templates.length,
                          separatorBuilder: (_, __) =>
                              const Divider(
                            height: 1,
                            color: Color(0xFFE5E5E7),
                          ),
                          itemBuilder: (context, index) {
                            final template =
                                templates[index];

                            final isSelected =
                                _selectedTemplate?.id ==
                                    template.id;

                            return ListTile(
                              dense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              title: Text(
                                template.title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      FontWeight.w500,
                                  color:
                                      Color(0xFF303038),
                                ),
                              ),
                              subtitle: Padding(
                                padding:
                                    const EdgeInsets.only(
                                  top: 3,
                                ),
                                child: Text(
                                  template.subject,
                                  maxLines: 1,
                                  overflow:
                                      TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color:
                                        Color(0xFF77777F),
                                  ),
                                ),
                              ),
                              trailing: isSelected
                                  ? const Icon(
                                      Icons.check_circle,
                                      size: 20,
                                      color:
                                          Color(0xFF625DCE),
                                    )
                                  : const Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color:
                                          Color(0xFF9999A1),
                                    ),
                              onTap: () {
                                setState(() {
                                  _selectedTemplate =
                                      template;

                                  // Automatically fill
                                  // subject
                                  _subjectController.text =
                                      template.subject;

                                  // Automatically fill
                                  // email content
                                  _contentController.text =
                                      _removeHtml(
                                    template.content,
                                  );
                                });

                                Navigator.pop(
                                  sheetContext,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              }
              

              return const SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    'No templates available',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF77777F),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    },
  );
  
}

  // =========================================================
  // SCHEDULE
  // =========================================================

  Future<void> _showScheduleDialog() async {
    final now = DateTime.now();

    final initialDateTime =
        _scheduledDateTime != null && _scheduledDateTime!.isAfter(now)
            ? _scheduledDateTime!
            : now.add(const Duration(minutes: 5));

    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDateTime,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );

    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );

    if (pickedTime == null || !mounted) return;

    setState(() {
      _scheduledDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  String _formatScheduledLabel(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    int hour = date.hour;
    final period = hour >= 12 ? 'PM' : 'AM';
    hour = hour % 12;
    if (hour == 0) hour = 12;

    final minute = date.minute.toString().padLeft(2, '0');

    return '${months[date.month - 1]} ${date.day}, $hour:$minute $period';
  }

  // =========================================================
  // SEND
  // =========================================================

void _sendEmail() {
  if (_subjectController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter email subject'),
      ),
    );
    return;
  }

  if (_contentController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter email content'),
      ),
    );
    return;
  }

  if (_editRecipients.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select at least one recipient'),
      ),
    );
    return;
  }

  context.read<EmailTemplateCubit>().sendBulkEmail(
    recipients: _editRecipients,
    subject: _subjectController.text.trim(),
    content: _contentController.text.trim(),
    templateTitle:
        _selectedTemplate?.title ?? _editTemplateTitle,
    scheduledFor: _scheduledDateTime,
  );
}

  String _removeHtml(String html) {
  return html
      .replaceAll(RegExp(r'<br\s*/?>'), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .trim();
}

// 
Future<void> _updateScheduledEmail() async {
  if (widget.scheduledEmail == null) {
    return;
  }

  if (_subjectController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter email subject'),
      ),
    );
    return;
  }

  if (_contentController.text.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please enter email content'),
      ),
    );
    return;
  }

  if (_editRecipients.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select at least one recipient'),
      ),
    );
    return;
  }

  if (_scheduledDateTime == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please select schedule date and time'),
      ),
    );
    return;
  }

  setState(() {
    _isUpdating = true;
  });

  try {
await context
    .read<ScheduledEmailCubit>()
    .updateScheduledEmail(
      id: widget.scheduledEmail!.id,
      recipients: _editRecipients
          .map((e) => e.email)
          .toList(),
      subject: _subjectController.text.trim(),
      content: _contentController.text.trim(),
      templateTitle:
          _selectedTemplate?.title ??
          _editTemplateTitle,
      scheduledFor: _scheduledDateTime!,
    );
    
        if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Scheduled email updated successfully'),
        backgroundColor: Colors.green,
      ),
    );

    Navigator.of(context).pop(true);
  } catch (e) {
    if (!mounted) return;

    setState(() {
      _isUpdating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst('Exception: ', ''),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }
}
}

