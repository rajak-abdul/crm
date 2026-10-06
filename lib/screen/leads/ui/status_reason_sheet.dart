import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════
// "Reason for moving to {status}" bottom sheet
// Returns the final reason (the typed text when "Other" is picked),
// or null when cancelled. Does not touch any cubit — the caller
// handles the API call.
// ══════════════════════════════════════════════════════════════

const kLeadRejectionReasons = [
  'Price too high',
  'Chose a competitor',
  'Missing features',
  'No budget',
  'Timing is not right',
  'Not interested',
  'Poor fit',
  'Other',
];

Future<String?> showStatusReasonSheet(
  BuildContext context, {
  required String status,
  required String leadName,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => _StatusReasonSheet(status: status, leadName: leadName),
  );
}

class _StatusReasonSheet extends StatefulWidget {
  final String status;
  final String leadName;
  const _StatusReasonSheet({required this.status, required this.leadName});

  @override
  State<_StatusReasonSheet> createState() => _StatusReasonSheetState();
}

class _StatusReasonSheetState extends State<_StatusReasonSheet> {
  static const _red = Color(0xFFE50914);
  static const _border = Color(0xFFE5E7EB);
  static const _textDark = Color(0xFF1F2937);
  static const _textLabel = Color(0xFF374151);
  static const _textMuted = Color(0xFF6B7280);
  static const _hint = Color(0xFF9CA3AF);

  final _otherCtrl = TextEditingController();
  String? _reason;
  bool _showErrors = false;

  bool get _isOther => _reason == 'Other';
  bool get _reasonMissing => _reason == null;
  bool get _otherMissing => _isOther && _otherCtrl.text.trim().isEmpty;
  bool get _valid => !_reasonMissing && !_otherMissing;

  @override
  void dispose() {
    _otherCtrl.dispose();
    super.dispose();
  }

  void _confirm() {
    if (!_valid) {
      setState(() => _showErrors = true);
      return;
    }
    Navigator.pop(context, _isOther ? _otherCtrl.text.trim() : _reason);
  }

  OutlineInputBorder _outline(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );

  InputDecoration _decoration({
    required String hint,
    required bool hasError,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _hint, fontSize: 15),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _outline(hasError ? _red : _border),
        enabledBorder: _outline(hasError ? _red : _border),
        focusedBorder: _outline(hasError ? _red : _hint),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: RichText(
          text: TextSpan(
            text: text,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500, color: _textLabel),
            children: const [
              TextSpan(text: ' *', style: TextStyle(color: _red)),
            ],
          ),
        ),
      );

  Widget _error(String text) => Padding(
        padding: const EdgeInsets.only(top: 6, left: 2),
        child: Text(text, style: const TextStyle(fontSize: 12, color: _red)),
      );

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
              Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 8, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  border: Border(bottom: BorderSide(color: _border)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1D5DB),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reason for moving to ${widget.status}',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: _textDark),
                              ),
                              const SizedBox(height: 4),
                              Text.rich(
                                TextSpan(
                                  text: 'Lead: ',
                                  style: const TextStyle(
                                      fontSize: 13, color: _textMuted),
                                  children: [
                                    TextSpan(
                                      text: widget.leadName.toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _textLabel),
                                    ),
                                  ],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close,
                              size: 22, color: _textMuted),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ── Body ──
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label('Reason for Downgrade'),
                    DropdownButtonFormField<String>(
                      value: _reason,
                      isExpanded: true,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: _textMuted),
                      borderRadius: BorderRadius.circular(12),
                      style: const TextStyle(fontSize: 15, color: _textDark),
                      decoration: _decoration(
                        hint: 'Select a reason',
                        hasError: _showErrors && _reasonMissing,
                      ),
                      items: kLeadRejectionReasons
                          .map((r) =>
                              DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (v) => setState(() => _reason = v),
                    ),
                    if (_showErrors && _reasonMissing)
                      _error('Please select a reason'),

                    // "Other" → free-text reason
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: _isOther
                          ? Padding(
                              padding: const EdgeInsets.only(top: 18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _label('Please specify'),
                                  TextField(
                                    controller: _otherCtrl,
                                    autofocus: true,
                                    minLines: 3,
                                    maxLines: 5,
                                    maxLength: 250,
                                    style: const TextStyle(
                                        fontSize: 15, color: _textDark),
                                    decoration: _decoration(
                                      hint: 'Type the exact reason here...',
                                      hasError: _showErrors && _otherMissing,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                  if (_showErrors && _otherMissing)
                                    _error('Please enter the reason'),
                                ],
                              ),
                            )
                          : const SizedBox(width: double.infinity),
                    ),
                  ],
                ),
              ),

              // ── Footer ──
              Container(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 22 + safeBottom),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: _border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            backgroundColor: const Color(0xFFF1F3F5),
                            foregroundColor: _textLabel,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _valid
                              ? [
                                  BoxShadow(
                                    color: _red.withOpacity(0.3),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: TextButton(
                          onPressed: _confirm,
                          style: TextButton.styleFrom(
                            backgroundColor:
                                _valid ? _red : _red.withOpacity(0.5),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            textStyle: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          child: const Text('Confirm'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
