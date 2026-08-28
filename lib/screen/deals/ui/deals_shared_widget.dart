import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import '../../../thems/app_themes.dart';

class PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final int totalItems;
  final int pageSize;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  const PaginationBar({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.pageSize,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0 ? 0 : ((page - 1) * pageSize) + 1;
    final end = (page * pageSize) > totalItems ? totalItems : (page * pageSize);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text(
            '$start-$end of $totalItems',
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Spacer(),
          IconButton(
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous page',
          ),
          Text(
            '$page / $totalPages',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next page',
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// FORMAT HELPERS
// ══════════════════════════════════════════════════════════════
String fmtVal(String currency, double v) {
  final symbol = DealConstants.currencySymbol(currency);
  if (v >= 10000000) return '$symbol${(v / 10000000).toStringAsFixed(1)}Cr';
  if (v >= 100000) return '$symbol${(v / 100000).toStringAsFixed(1)}L';
  if (v >= 1000) return '$symbol${(v / 1000).toStringAsFixed(1)}K';
  return '$symbol${v.toStringAsFixed(0)}';
}
// ======================
// Full Drop Down
// ======================
class FullDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final void Function(String) onChanged;
  final String Function(String)? labelBuilder;
  const FullDrop(
      {required this.value,
      required this.items,
      required this.icon,
      required this.onChanged,
      this.labelBuilder});
  @override
  Widget build(BuildContext context) => Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: AppColors.textSecondary),
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textPrimary),
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Row(children: [
                        Icon(icon, size: 14, color: AppColors.textHint),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(
                                labelBuilder != null ? labelBuilder!(e) : e,
                                overflow: TextOverflow.ellipsis))
                      ])))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              })));
}

// ==============
// compact Drop
// ==============

class CompactDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final double width;
  final void Function(String) onChanged;
  const CompactDrop(
      {required this.value,
      required this.items,
      required this.width,
      required this.onChanged});
  @override
  Widget build(BuildContext context) => Container(
      width: width,
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isDense: true,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16, color: AppColors.textSecondary),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary),
              selectedItemBuilder: (context) => items
                  .map((e) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(_currencyCompactLabel(e),
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Text(_currencyMenuLabel(e),
                          overflow: TextOverflow.ellipsis)))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              })));

  /// "₹ INR" → "🇮🇳 INR" for the closed field; falls back to the raw
  /// entry when it isn't one of the known currency codes.
  static String _currencyCompactLabel(String item) {
    final code = item.split(' ').last.trim().toUpperCase();
    final flag = DealConstants.currencyFlags[code];
    return flag != null ? '$flag $code' : item;
  }

  /// "₹ INR" → "🇮🇳 INR - Indian Rupee" for the open dropdown list.
  static String _currencyMenuLabel(String item) {
    final code = item.split(' ').last.trim().toUpperCase();
    final flag = DealConstants.currencyFlags[code];
    final name = DealConstants.currencyNames[code];
    if (flag == null || name == null) return item;
    return '$flag  $code - $name';
  }
}
// =============
// Field label
// =============

class FieldLabel extends StatelessWidget {
  final String text;
  final bool required;
  const FieldLabel(this.text, {this.required = false});
  @override
  Widget build(BuildContext context) => Text.rich(TextSpan(
      text: text,
      style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary),
      children: required
          ? [
              const TextSpan(
                  text: ' *', style: TextStyle(color: AppColors.danger))
            ]
          : []));
}

// ============
// Sec header
// ============
class SecHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  const SecHeader({required this.title, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.primary.withOpacity(0.2))),
      child: Row(children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.primary))
      ]));
}
// ====================
// dropdown for filter
// ====================
class FDrop extends StatelessWidget {
  final String value;
  final List<String> items;
  final IconData icon;
  final void Function(String) onChanged;
  final String Function(String)? labelBuilder;
  const FDrop(
      {required this.value,
      required this.items,
      required this.icon,
      required this.onChanged,
      this.labelBuilder});
  bool get _active => value != items.first;
  @override
  Widget build(BuildContext context) => Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: _active ? AppColors.primaryLight : AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: _active ? AppColors.primary : AppColors.border)),
      child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
              value: items.contains(value) ? value : items.first,
              isExpanded: true,
              isDense: true,
              icon: Icon(Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: _active ? AppColors.primary : AppColors.textSecondary),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: _active ? FontWeight.w600 : FontWeight.w400,
                  color: _active ? AppColors.primary : AppColors.textSecondary),
              items: items
                  .map((e) => DropdownMenuItem(
                      value: e,
                      child: Row(children: [
                        Icon(icon, size: 13, color: AppColors.textHint),
                        const SizedBox(width: 5),
                        Expanded(
                            child: Text(
                                labelBuilder != null ? labelBuilder!(e) : e,
                                overflow: TextOverflow.ellipsis))
                      ])))
                  .toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              })));
}

// ================
// search bar
// ================

class SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final void Function(String) onChanged;
  final VoidCallback onClear;
  const SearchBar(
      {required this.controller,
      required this.hint,
      required this.onChanged,
      required this.onClear});
  @override
  Widget build(BuildContext context) => SizedBox(
      height: 42,
      child: TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search,
                  size: 18, color: AppColors.textSecondary),
              suffixIcon: controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 16),
                      onPressed: () {
                        controller.clear();
                        onClear();
                      })
                  : null,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 14),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5)))));
}
// =====================================
// file size & file Icon for Attachments
// ======================================
 String fileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

   IconData fileIcon(String name) {
    final ext = name.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext))
      return Icons.image_outlined;
    if (ext == 'pdf') return Icons.picture_as_pdf_outlined;
    if (['doc', 'docx'].contains(ext)) return Icons.description_outlined;
    if (['xls', 'xlsx', 'csv'].contains(ext)) return Icons.table_chart_outlined;
    return Icons.attach_file_outlined;
  }