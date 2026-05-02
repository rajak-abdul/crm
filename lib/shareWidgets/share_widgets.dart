// lib/widgets/shared_widgets.dart
import 'package:crm_app/modals/modals.dart' show AppUser;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─── Local-only indicator ──────────────────────────────────────
class LocalBadge extends StatelessWidget {
  const LocalBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: AppColors.warningLight,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppColors.warning.withOpacity(0.4)),
    ),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.offline_bolt_outlined, size: 10, color: AppColors.warning),
      SizedBox(width: 3),
      Text('Local', style: TextStyle(
          color: AppColors.warning, fontSize: 10, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─── Status Badge ──────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge({super.key, required this.status});

  Color get bg => switch (status) {
    'Hot' => AppColors.hotBg, 'Cold' => AppColors.coldBg,
    'Warm' => AppColors.warmBg, 'Junk' => AppColors.junkBg,
    'Converted' => AppColors.convertedBg,
    'Active' => AppColors.successLight, 'Inactive' => AppColors.junkBg,
    _ => AppColors.junkBg,
  };
  Color get fg => switch (status) {
    'Hot' => AppColors.hot, 'Cold' => AppColors.cold,
    'Warm' => AppColors.warm, 'Junk' => AppColors.junk,
    'Converted' => AppColors.converted,
    'Active' => AppColors.success, 'Inactive' => AppColors.junk,
    _ => AppColors.junk,
  };

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 7, height: 7, decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(status, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );
}

// ─── Section Header ────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title; final IconData icon;
  const SectionHeader({super.key, required this.title, required this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14, top: 4),
    child: Row(children: [
      Container(padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, size: 16, color: AppColors.primary)),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
      const SizedBox(width: 10),
      const Expanded(child: Divider(color: AppColors.divider, thickness: 1.5)),
    ]),
  );
}

// ─── CRM Text Field ────────────────────────────────────────────
class CrmTextField extends StatelessWidget {
  final String label; final bool required; final String? hint;
  final TextEditingController? controller; final TextInputType? keyboardType;
  final int maxLines; final Widget? suffixIcon; final bool obscureText;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;

  const CrmTextField({
    super.key, required this.label, this.required = false, this.hint,
    this.controller, this.keyboardType, this.maxLines = 1,
    this.suffixIcon, this.obscureText = false, this.onChanged,  this.inputFormatters, // 👈 ADD THIS

  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    RichText(text: TextSpan(
      text: label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      children: required ? [const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger))] : [],
    )),
    const SizedBox(height: 6),
    TextField(
      controller: controller, keyboardType: keyboardType,  inputFormatters: inputFormatters, // 👈 ADD THIS LINE

      maxLines: maxLines, obscureText: obscureText, onChanged: onChanged,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(hintText: hint, suffixIcon: suffixIcon),
    ),
  ]);
}

// ─── CRM Dropdown ──────────────────────────────────────────────
class CrmDropdown extends StatelessWidget {
  final String label; final bool required; final String? value;
  final List<String> items; final void Function(String?) onChanged; final String hint;

  const CrmDropdown({
    super.key, required this.label, this.required = false, this.value,
    required this.items, required this.onChanged, this.hint = 'Select',
  });

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    RichText(text: TextSpan(
      text: label,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      children: required ? [const TextSpan(text: ' *', style: TextStyle(color: AppColors.danger))] : [],
    )),
    const SizedBox(height: 6),
     DropdownButtonFormField<String>(
      initialValue: value, isExpanded: true,
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
        filled: true, fillColor: AppColors.surface,
      ),
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.textSecondary),
      items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
      onChanged: onChanged,
    ),
  ]);
}

// ─── User Avatar ───────────────────────────────────────────────
class UserAvatar extends StatelessWidget {
  final AppUser user;
  final double size;

  const UserAvatar({super.key, required this.user, this.size = 40});

  Color get color {
    final list = [AppColors.primary, AppColors.accent, AppColors.success, AppColors.purple, AppColors.warning];
    return list[user.id.hashCode.abs() % list.length];
  }

  String? _safeNetworkAvatarUrl(String? raw) {
    if (raw == null) return null;
    final v = raw.trim();
    if (v.isEmpty) return null;

    // Only allow fully-qualified web URLs for Image.network.
    final uri = Uri.tryParse(v);
    if (uri == null) return null;
    final isWeb = uri.scheme == 'http' || uri.scheme == 'https';
    if (!isWeb || !uri.hasAuthority) return null;
    return uri.toString();
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _safeNetworkAvatarUrl(user.avatarUrl);
    if (avatarUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: Image.network(avatarUrl, width: size, height: size, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _initials()),
      );
    }
    return _initials();
  }

  Widget _initials() => Container(
    width: size, height: size,
    decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle,
        border: Border.all(color: color.withOpacity(0.3), width: 1.5)),
    child: Center(child: Text(user.initials,
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: size * 0.35))),
  );
}

// ─── Empty State ───────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String message; final IconData icon;
  const EmptyState({super.key, required this.message, required this.icon});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
        child: Icon(icon, size: 48, color: AppColors.primary.withOpacity(0.5))),
    const SizedBox(height: 16),
    Text(message, style: const TextStyle(color: AppColors.textSecondary, fontSize: 15, fontWeight: FontWeight.w500)),
  ]));
}

// ─── Loading State ─────────────────────────────────────────────
class LoadingState extends StatelessWidget {
  final String? message;
  const LoadingState({super.key, this.message});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
    if (message != null) ...[const SizedBox(height: 14),
      Text(message!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))],
  ]));
}

// ─── Error State ───────────────────────────────────────────────
class ErrorState extends StatelessWidget {
  final String message; final VoidCallback? onRetry;
  const ErrorState({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(24),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(color: AppColors.dangerLight, shape: BoxShape.circle),
          child: const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.danger)),
      const SizedBox(height: 16),
      Text(message, textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)),
      if (onRetry != null) ...[
        const SizedBox(height: 20),
        ElevatedButton.icon(onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16), label: const Text('Retry')),
      ],
    ]),
  ));
}

// ─── Form Action Buttons ───────────────────────────────────────
class FormActionButtons extends StatelessWidget {
  final VoidCallback onCancel, onSubmit;
  final String submitLabel; final bool isLoading;

  const FormActionButtons({
    super.key, required this.onCancel, required this.onSubmit,
    this.submitLabel = 'Submit', this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(child: OutlinedButton(
      onPressed: isLoading ? null : onCancel,
      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      child: const Text('Cancel'),
    )),
    const SizedBox(width: 12),
    Expanded(child: ElevatedButton(
      onPressed: isLoading ? null : onSubmit,
      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
      child: isLoading
          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(submitLabel),
    )),
  ]);
}

// ─── Snack helper ──────────────────────────────────────────────
void showApiSnack(BuildContext ctx, String msg, {bool isError = false}) {
  final snackBar = SnackBar(
    content: Row(children: [
      Icon(isError ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(msg, style: const TextStyle(fontSize: 13))),
    ]),
    backgroundColor: isError ? AppColors.danger : AppColors.success,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    margin: const EdgeInsets.all(12),
  );

  ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(ctx);
  if (messenger == null) {
    final rootNav = Navigator.maybeOf(ctx, rootNavigator: true);
    if (rootNav != null) messenger = ScaffoldMessenger.maybeOf(rootNav.context);
  }
  if (messenger == null) return;

  try {
    messenger.showSnackBar(snackBar);
  } catch (_) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ScaffoldMessengerState? retry = ScaffoldMessenger.maybeOf(ctx);
      if (retry == null) {
        final rootNav = Navigator.maybeOf(ctx, rootNavigator: true);
        if (rootNav != null) retry = ScaffoldMessenger.maybeOf(rootNav.context);
      }
      retry?.showSnackBar(snackBar);
    });
  }
}