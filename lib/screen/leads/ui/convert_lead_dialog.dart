import 'package:crm_app/screen/deals/modal/deal_modal.dart' show DealConstants;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ══════════════════════════════════════════════════════════════
// "Convert Lead to Deal" alert dialog
// The dialog never talks to a cubit: the caller passes [onConvert],
// which performs the API call and returns an error message or null.
// Resolves to the submitted result on success, null when cancelled.
// ══════════════════════════════════════════════════════════════

class ConvertDealResult {
  final double dealValue;
  final String currency; // ISO code, e.g. "USD"
  final String stage;
  final String? notes;

  const ConvertDealResult({
    required this.dealValue,
    required this.currency,
    required this.stage,
    this.notes,
  });
}

Future<ConvertDealResult?> showConvertLeadDialog(
  BuildContext context, {
  required String leadName,
  required String companyName,
  required String initialCurrency,
  required Future<String?> Function(ConvertDealResult) onConvert,
}) {
  return showDialog<ConvertDealResult>(
    context: context,
    barrierDismissible: false, // handled inside so it can be blocked while converting
    barrierColor: Colors.black.withOpacity(0.45),
    builder: (_) => _ConvertLeadDialog(
      leadName: leadName,
      companyName: companyName,
      initialCurrency: initialCurrency,
      onConvert: onConvert,
    ),
  );
}

class _ConvertLeadDialog extends StatefulWidget {
  final String leadName;
  final String companyName;
  final String initialCurrency;
  final Future<String?> Function(ConvertDealResult) onConvert;

  const _ConvertLeadDialog({
    required this.leadName,
    required this.companyName,
    required this.initialCurrency,
    required this.onConvert,
  });

  @override
  State<_ConvertLeadDialog> createState() => _ConvertLeadDialogState();
}

class _ConvertLeadDialogState extends State<_ConvertLeadDialog> {
  static const _green = Color(0xFF16A34A);
  static const _greenPressed = Color(0xFF15803D);
  static const _red = Color(0xFFDC2626);
  static const _border = Color(0xFFE5E7EB);
  static const _textDark = Color(0xFF1F2937);
  static const _textLabel = Color(0xFF374151);
  static const _textMuted = Color(0xFF6B7280);
  static const _hint = Color(0xFF9CA3AF);
  static const _stage = 'Qualification';

  final _valueCtrl = TextEditingController(text: '0');
  final _notesCtrl = TextEditingController();
  late String _currency; // dropdown item, e.g. "$ USD"
  bool _converting = false;
  String? _valueError;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _currency = _itemFor(widget.initialCurrency);
  }

  @override
  void dispose() {
    _valueCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  List<String> get _items {
    final items = [...DealConstants.currencies];
    if (!items.contains(_currency)) items.add(_currency);
    return items;
  }

  // "USD" → "$ USD" (or just "USD" when not in the known list)
  static String _itemFor(String code) {
    final c = code.trim().toUpperCase();
    return DealConstants.currencies.firstWhere(
      (e) => e.split(' ').last == c,
      orElse: () => c.isEmpty ? DealConstants.currencies.first : c,
    );
  }

  double? get _parsedValue {
    final raw = _valueCtrl.text.replaceAll(',', '').trim();
    final v = double.tryParse(raw);
    return (v == null || v < 0) ? null : v;
  }

  Future<void> _submit() async {
    final value = _parsedValue;
    if (value == null) {
      setState(() => _valueError = 'Enter a valid deal value');
      return;
    }
    FocusScope.of(context).unfocus();
    final notes = _notesCtrl.text.trim();
    final result = ConvertDealResult(
      dealValue: value,
      currency: _currency.split(' ').last,
      stage: _stage,
      notes: notes.isEmpty ? null : notes,
    );

    setState(() {
      _valueError = null;
      _submitError = null;
      _converting = true;
    });
    final err = await widget.onConvert(result);
    if (!mounted) return;
    if (err == null) {
      Navigator.pop(context, result);
    } else {
      setState(() {
        _converting = false;
        _submitError = err;
      });
    }
  }

  void _cancel() {
    if (!_converting) Navigator.pop(context);
  }

  OutlineInputBorder _outline(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: c, width: w),
      );

  InputDecoration _decoration({String? hint, bool hasError = false}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _hint, fontSize: 15),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: _outline(hasError ? _red : _border),
        enabledBorder: _outline(hasError ? _red : _border),
        disabledBorder: _outline(_border),
        focusedBorder: _outline(hasError ? _red : _green, 1.5),
      );

  Widget _label(String text, {bool optional = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text.rich(TextSpan(
          text: text,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: _textLabel),
          children: [
            if (optional)
              const TextSpan(
                text: ' (optional)',
                style: TextStyle(color: _hint, fontWeight: FontWeight.w400),
              ),
          ],
        )),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_converting,
      child: GestureDetector(
        // Tap on the dimmed backdrop = cancel
        behavior: HitTestBehavior.opaque,
        onTap: _cancel,
        child: Dialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: GestureDetector(
            onTap: () {}, // swallow taps inside the dialog
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(),
                    const SizedBox(height: 12),
                    _infoBanner(),
                    const SizedBox(height: 18),
                    _label('Deal Value'),
                    _valueRow(),
                    if (_valueError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 2),
                        child: Text(_valueError!,
                            style:
                                const TextStyle(fontSize: 12, color: _red)),
                      ),
                    const SizedBox(height: 16),
                    _label('Stage'),
                    _stageField(),
                    const SizedBox(height: 16),
                    _label('Notes', optional: true),
                    TextField(
                      controller: _notesCtrl,
                      enabled: !_converting,
                      minLines: 3,
                      maxLines: 5,
                      style: const TextStyle(fontSize: 15, color: _textDark),
                      decoration: _decoration(hint: 'Add any notes...'),
                    ),
                    if (_submitError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_submitError!,
                            style:
                                const TextStyle(fontSize: 12, color: _red)),
                      ),
                    const SizedBox(height: 20),
                    _footer(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF4FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.swap_horiz_rounded,
                size: 18, color: Color(0xFF2563EB)),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Convert Lead to Deal',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _green),
            ),
          ),
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              tooltip: 'Close',
              padding: EdgeInsets.zero,
              icon: Icon(Icons.close,
                  size: 22,
                  color: _converting ? const Color(0xFFD1D5DB) : _textMuted),
              onPressed: _converting ? null : _cancel,
            ),
          ),
        ],
      );

  Widget _infoBanner() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text.rich(
          TextSpan(
            text: 'Converting: ',
            style: const TextStyle(
                fontSize: 13, height: 1.45, color: Color(0xFF1D4ED8)),
            children: [
              TextSpan(
                text: widget.leadName,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: Color(0xFF1E3A8A)),
              ),
              if (widget.companyName.trim().isNotEmpty)
                TextSpan(text: ' from ${widget.companyName}'),
            ],
          ),
          maxLines: 2,
        ),
      );

  Widget _valueRow() => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _valueCtrl,
              enabled: !_converting,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [_ThousandsFormatter()],
              style: const TextStyle(fontSize: 15, color: _textDark),
              decoration:
                  _decoration(hint: '0', hasError: _valueError != null),
              onTap: () {
                // Clear the placeholder 0 so the user can type directly
                if (_valueCtrl.text == '0') _valueCtrl.clear();
              },
              onChanged: (_) {
                if (_valueError != null) setState(() => _valueError = null);
              },
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 104,
            child: DropdownButtonFormField<String>(
              value: _currency,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: _textMuted),
              borderRadius: BorderRadius.circular(10),
              style: const TextStyle(fontSize: 15, color: _textDark),
              decoration: _decoration().copyWith(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              ),
              items: _items
                  .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, overflow: TextOverflow.ellipsis),
                      ))
                  .toList(),
              onChanged: _converting
                  ? null
                  : (v) {
                      if (v == null) return;
                      setState(() => _currency = v);
                    },
            ),
          ),
        ],
      );

  Widget _stageField() => Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _border),
        ),
        child: const Row(
          children: [
            Expanded(
              child: Text(_stage,
                  style: TextStyle(fontSize: 15, color: Color(0xFF4B5563))),
            ),
            Icon(Icons.lock_outline, size: 14, color: _hint),
          ],
        ),
      );

  Widget _footer() => Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _converting ? null : _cancel,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textLabel,
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD1D5DB)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
                child: const Text('Cancel'),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: _converting ? null : _submit,
                style: ButtonStyle(
                  elevation: const WidgetStatePropertyAll(0),
                  shape: WidgetStatePropertyAll(RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
                  foregroundColor:
                      const WidgetStatePropertyAll(Colors.white),
                  backgroundColor: WidgetStateProperty.resolveWith((s) {
                    if (s.contains(WidgetState.disabled)) {
                      return _green.withOpacity(0.75);
                    }
                    if (s.contains(WidgetState.pressed)) return _greenPressed;
                    return _green;
                  }),
                  textStyle: const WidgetStatePropertyAll(
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                child: _converting
                    ? const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 8),
                          Text('Converting...'),
                        ],
                      )
                    : const Text('Convert'),
              ),
            ),
          ),
        ],
      );
}

/// Formats the integer part with thousands separators (25000 → 25,000)
/// and allows at most one decimal point with 2 decimals.
class _ThousandsFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat('#,##0', 'en_US');

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final raw = newValue.text.replaceAll(',', '');
    if (raw.isEmpty) return newValue.copyWith(text: '');
    if (!RegExp(r'^\d{0,15}(\.\d{0,2})?$').hasMatch(raw)) return oldValue;

    final parts = raw.split('.');
    final intPart = parts[0].isEmpty ? '0' : parts[0];
    var text = _fmt.format(int.parse(intPart));
    if (parts.length > 1) text += '.${parts[1]}';

    // Keep the cursor at the same distance from the end of the text
    final fromEnd = newValue.text.length - newValue.selection.end;
    final offset = (text.length - fromEnd).clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }
}
