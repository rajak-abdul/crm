// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/widgets/                ║
// ║                            hub_search_field.dart              ║
// ║  SEARCH — rounded "Search documents" field with a clear (x)   ║
// ║  button while it has text.                                    ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/presentation/widgets/hub_styles.dart';
import 'package:flutter/material.dart';

class HubSearchField extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final String hint;

  const HubSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search documents',
  });

  @override
  State<HubSearchField> createState() => _HubSearchFieldState();
}

class _HubSearchFieldState extends State<HubSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    const border = OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(12)),
      borderSide: BorderSide(color: HubPalette.border),
    );

    return TextField(
      controller: _controller,
      onChanged: widget.onChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 14, color: HubPalette.ink),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: const TextStyle(fontSize: 14, color: HubPalette.hint),
        prefixIcon:
            const Icon(Icons.search_rounded, size: 20, color: HubPalette.hint),
        // Rebuilds with the text so the (x) shows only while there's some.
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  onPressed: _clear,
                  tooltip: 'Clear',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: HubPalette.muted,
                  ),
                ),
        ),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: HubPalette.accent),
        ),
      ),
    );
  }
}
