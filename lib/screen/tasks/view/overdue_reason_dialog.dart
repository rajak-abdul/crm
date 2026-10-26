// ╔══════════════════════════════════════════════════════════════╗
// ║       lib/screen/tasks/view/overdue_reason_dialog.dart        ║
// ║  VIEW — "Task overdue" popup. The user must explain the delay ║
// ║  before carrying on; sending goes through the ViewModel.      ║
// ╚══════════════════════════════════════════════════════════════╝

import 'dart:ui' show ImageFilter;

import 'package:crm_app/screen/tasks/model/task/task_modal.dart';
import 'package:crm_app/screen/tasks/view/task_widgets.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';

/// Shows the popup for [task]. [onSubmit] sends the reason and returns
/// an error message (or null on success).
///
/// Completes with true once a reason was sent, false when the user
/// backed out (system back) instead.
Future<bool> showOverdueReasonDialog(
  BuildContext context, {
  required TaskModel task,
  required Future<String?> Function(String reason) onSubmit,
}) async {
  final sent = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0x8C0F172A),
    builder: (_) => _OverdueReasonDialog(task: task, onSubmit: onSubmit),
  );
  return sent ?? false;
}

class _OverdueReasonDialog extends StatefulWidget {
  final TaskModel task;
  final Future<String?> Function(String reason) onSubmit;

  const _OverdueReasonDialog({required this.task, required this.onSubmit});

  @override
  State<_OverdueReasonDialog> createState() => _OverdueReasonDialogState();
}

class _OverdueReasonDialogState extends State<_OverdueReasonDialog> {
  static const _blue = Color(0xFF1D4ED8);
  static const _blueDisabled = Color(0xFFC7D7FD);
  static const _border = Color(0xFFE2E8F0);

  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _sending = false;
  String? _error;

  bool get _canSend => !_sending && _text.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Rebuild for the button state and the field's focused look.
    _text.addListener(() => setState(() => _error = null));
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSend) return;
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);

    final error = await widget.onSubmit(_text.text);

    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _sending = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.task.title ?? '').trim();
    final active = _focus.hasFocus || _text.text.isNotEmpty;

    // No close button — a reason is required. System back leaves the
    // Tasks screen instead (handled by the caller).
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_sending) Navigator.of(context).pop(false);
      },
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFDECEC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.error_outline_rounded,
                        color: TaskPalette.red,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Task overdue',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Your task '),
                      TextSpan(
                        text: title.isEmpty ? 'this task' : '"$title"',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const TextSpan(
                        text: ' is overdue. Add a reason to continue.',
                      ),
                    ],
                  ),
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _text,
                  focusNode: _focus,
                  enabled: !_sending,
                  minLines: 4,
                  maxLines: 6,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Explain why this task is delayed...',
                    hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor:
                        active ? Colors.white : const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.all(14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: _text.text.isNotEmpty ? _blue : _border,
                      ),
                    ),
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: _blue, width: 1.5),
                    ),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: TaskPalette.red,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: FilledButton(
                    onPressed: _canSend ? _submit : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue,
                      // Keep the blue while sending; pale blue when empty.
                      disabledBackgroundColor:
                          _sending ? _blue : _blueDisabled,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Reason',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
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
