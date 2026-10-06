// ╔══════════════════════════════════════════════════════════════╗
// ║       lib/screen/tasks/view/report_activity_sheet.dart       ║
// ║  VIEW — "Report Call Made" / "Report Meeting Done" bottom     ║
// ║  sheets. Collects the form and hands it to TargetViewModel.   ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/tasks/viewmodel/target_view_model.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Opens the call sheet; resolves to true once a call was reported.
Future<bool> showReportCallSheet(
  BuildContext context, {
  required TargetViewModel viewModel,
  required String targetId,
}) =>
    _showReportSheet(
      context,
      config: _ReportConfig.call,
      submit: (form) => viewModel.reportCall(
        targetId: targetId,
        companyName: form.companyName,
        callSummary: form.summary,
        companyUrl: form.companyUrl,
        recordingPath: form.filePath,
        recordingBytes: form.fileBytes,
        recordingName: form.fileName,
      ),
    );

/// Opens the meeting sheet; resolves to true once a meeting was reported.
Future<bool> showReportMeetingSheet(
  BuildContext context, {
  required TargetViewModel viewModel,
  required String targetId,
}) =>
    _showReportSheet(
      context,
      config: _ReportConfig.meeting,
      submit: (form) => viewModel.reportMeeting(
        targetId: targetId,
        companyName: form.companyName,
        meetingSummary: form.summary,
        companyUrl: form.companyUrl,
        screenshotPath: form.filePath,
        screenshotBytes: form.fileBytes,
        screenshotName: form.fileName,
      ),
    );

Future<bool> _showReportSheet(
  BuildContext context, {
  required _ReportConfig config,
  required Future<String?> Function(_ReportForm form) submit,
}) async {
  final reported = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(config: config, submit: submit),
  );
  return reported == true;
}

// ══════════════════════════════════════════════════════════════
// CONFIG — what differs between the call and meeting sheets
// ══════════════════════════════════════════════════════════════
class _ReportConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final String summaryLabel;
  final String fileLabel;
  final String uploadTitle;
  final String uploadHint;
  final IconData fileIcon;
  final List<String> extensions;
  final int maxBytes;

  final Color accent;
  final Color accentDark;
  final Color accentSoft;
  final Color headerBg;

  const _ReportConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.summaryLabel,
    required this.fileLabel,
    required this.uploadTitle,
    required this.uploadHint,
    required this.fileIcon,
    required this.extensions,
    required this.maxBytes,
    required this.accent,
    required this.accentDark,
    required this.accentSoft,
    required this.headerBg,
  });

  int get maxMb => maxBytes ~/ (1024 * 1024);

  static const call = _ReportConfig(
    title: 'Report Call Made',
    subtitle: 'Log a new call for this target',
    icon: Icons.phone_outlined,
    summaryLabel: 'Call Summary',
    fileLabel: 'Call Recording',
    uploadTitle: 'Click to upload recording',
    uploadHint: 'Audio/Video up to 10MB',
    fileIcon: Icons.audio_file_outlined,
    extensions: [
      'mp3', 'm4a', 'aac', 'wav', 'ogg', 'amr', //
      'mp4', 'mov', 'webm', 'mkv', '3gp',
    ],
    maxBytes: 10 * 1024 * 1024,
    accent: Color(0xFFF97316),
    accentDark: Color(0xFFEA580C),
    accentSoft: Color(0xFFFFEDD5),
    headerBg: Color(0xFFFFF7ED),
  );

  static const meeting = _ReportConfig(
    title: 'Report Meeting Done',
    subtitle: 'Log a new meeting for this target',
    icon: Icons.event_outlined,
    summaryLabel: 'Meeting Summary',
    fileLabel: 'Meeting Screenshot',
    uploadTitle: 'Click to upload screenshot',
    uploadHint: 'PNG, JPG up to 5MB',
    fileIcon: Icons.image_outlined,
    extensions: ['png', 'jpg', 'jpeg'],
    maxBytes: 5 * 1024 * 1024,
    accent: Color(0xFF9333EA),
    accentDark: Color(0xFF9810FA),
    accentSoft: Color(0xFFF3E8FF),
    headerBg: Color(0xFFFAF5FF),
  );
}

/// Values handed to the ViewModel on submit.
class _ReportForm {
  final String companyName;
  final String summary;
  final String companyUrl;
  final String? filePath;
  final List<int>? fileBytes;
  final String? fileName;

  const _ReportForm({
    required this.companyName,
    required this.summary,
    required this.companyUrl,
    this.filePath,
    this.fileBytes,
    this.fileName,
  });
}

/// Type scale shared with the other Tasks / Target sheets.
class _ReportText {
  static const title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const subtitle = TextStyle(
    fontSize: 12,
    color: AppColors.textSecondary,
  );
  static const label = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  static const input = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );
  static const hint = TextStyle(
    fontSize: 14,
    color: AppColors.textHint,
  );
  static const caption = TextStyle(
    fontSize: 11,
    color: AppColors.textHint,
  );
  static const fileName = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const uploadTitle = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  static const button = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
}

// ══════════════════════════════════════════════════════════════
// SHEET
// ══════════════════════════════════════════════════════════════
class _ReportSheet extends StatefulWidget {
  final _ReportConfig config;
  final Future<String?> Function(_ReportForm form) submit;

  const _ReportSheet({required this.config, required this.submit});

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _maxSummary = 500;

  final _formKey = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _url = TextEditingController();
  final _summary = TextEditingController();

  PlatformFile? _file;
  bool _submitting = false;

  _ReportConfig get _c => widget.config;

  @override
  void dispose() {
    _company.dispose();
    _url.dispose();
    _summary.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _c.extensions,
      withData: kIsWeb,
    );
    final file = result?.files.single;
    if (file == null || !mounted) return;

    if (file.size > _c.maxBytes) {
      _toast('${_c.fileLabel} must be ${_c.maxMb}MB or smaller');
      return;
    }
    setState(() => _file = file);
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);
    final error = await widget.submit(_ReportForm(
      companyName: _company.text,
      summary: _summary.text,
      companyUrl: _url.text,
      filePath: kIsWeb ? null : _file?.path,
      fileBytes: kIsWeb ? _file?.bytes : null,
      fileName: _file?.name,
    ));
    if (!mounted) return;

    if (error != null) {
      setState(() => _submitting = false);
      _toast(error);
      return;
    }
    Navigator.of(context).pop(true);
  }

  String? _validateUrl(String? value) {
    final v = (value ?? '').trim();
    if (v.isEmpty) return null;
    final uri = Uri.tryParse(v);
    final ok = uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
    return ok ? null : 'Enter a valid URL (https://...)';
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _Label('Company Name', required: true),
                      _field(
                        controller: _company,
                        hint: 'e.g. Acme Corp',
                        icon: Icons.apartment_rounded,
                        textInputAction: TextInputAction.next,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Company name is required'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      const _Label('Company URL'),
                      _field(
                        controller: _url,
                        hint: 'https://example.com',
                        icon: Icons.link_rounded,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.next,
                        validator: _validateUrl,
                      ),
                      const SizedBox(height: 20),
                      _Label(_c.summaryLabel, required: true),
                      _field(
                        controller: _summary,
                        hint: 'What was discussed?',
                        icon: Icons.description_outlined,
                        maxLines: 4,
                        maxLength: _maxSummary,
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? '${_c.summaryLabel} is required'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _Label(_c.fileLabel, optional: true),
                      _buildUpload(),
                    ],
                  ),
                ),
              ),
              _buildActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: _c.headerBg,
      padding: const EdgeInsets.fromLTRB(20, 10, 16, 20),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD9D9D9),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _c.accentSoft,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(_c.icon, color: _c.accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_c.title, style: _ReportText.title),
                    const SizedBox(height: 2),
                    Text(_c.subtitle, style: _ReportText.subtitle),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    int? maxLength,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c),
        );

    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
      textInputAction: textInputAction,
      enabled: !_submitting,
      validator: validator,
      style: _ReportText.input,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: _ReportText.hint,
        errorStyle: const TextStyle(fontSize: 11),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        prefixIcon: maxLines > 1
            ? Padding(
                padding: EdgeInsets.only(bottom: (maxLines - 1) * 20.0),
                child: Icon(icon, color: AppColors.textHint),
              )
            : Icon(icon, color: AppColors.textHint),
        counterStyle: _ReportText.caption,
        border: border(AppColors.border),
        enabledBorder: border(AppColors.border),
        disabledBorder: border(AppColors.border),
        focusedBorder: border(_c.accent),
        errorBorder: border(Colors.red.shade300),
        focusedErrorBorder: border(Colors.red.shade400),
      ),
    );
  }

  Widget _buildUpload() {
    final file = _file;

    if (file != null) {
      final mb = file.size / (1024 * 1024);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _c.headerBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _c.accentSoft),
        ),
        child: Row(
          children: [
            Icon(_c.fileIcon, color: _c.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _ReportText.fileName,
                  ),
                  Text(
                    '${mb.toStringAsFixed(mb < 1 ? 2 : 1)} MB',
                    style: _ReportText.caption,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Remove',
              onPressed:
                  _submitting ? null : () => setState(() => _file = null),
              icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: _submitting ? null : _pickFile,
      borderRadius: BorderRadius.circular(16),
      child: CustomPaint(
        painter: _DashedBorderPainter(),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: _c.headerBg,
                child: Icon(Icons.upload_rounded, color: _c.accent, size: 26),
              ),
              const SizedBox(height: 12),
              Text(_c.uploadTitle, style: _ReportText.uploadTitle),
              const SizedBox(height: 4),
              Text(_c.uploadHint, style: _ReportText.caption),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: TextButton(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).pop(false),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.divider,
                  foregroundColor: AppColors.textPrimary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Cancel', style: _ReportText.button),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _c.accentDark,
                  disabledBackgroundColor:
                      _c.accentDark.withValues(alpha: 0.6),
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: _c.accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.4, color: Colors.white),
                      )
                    : const Text('Submit Report', style: _ReportText.button),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  final bool required;
  final bool optional;

  const _Label(this.text, {this.required = false, this.optional = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text.rich(
        TextSpan(
          text: text,
          style: _ReportText.label,
          children: [
            if (required)
              const TextSpan(
                text: '  *',
                style: TextStyle(color: Colors.red),
              ),
            if (optional)
              const TextSpan(
                text: ' (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textHint,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(16),
      ));

    for (final metric in path.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 6), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
