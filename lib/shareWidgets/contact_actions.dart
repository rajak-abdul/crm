// lib/shareWidgets/contact_actions.dart
//
// Tappable phone numbers and email addresses: a tap opens a small sheet
// asking what to do — call / copy, or send email / copy. Call opens the
// phone's dialer (tel:); Send email opens the mail app (mailto:), and
// Android shows its app picker (Gmail, Outlook, …) when several are
// installed.

import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Phone number in a dialable form: keeps a leading "+" and digits only.
/// A number without "+" gets [countryCode] (e.g. "+91" or "91") in front
/// when one is given.
String dialableNumber(String raw, {String? countryCode}) {
  final trimmed = raw.trim();
  final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '';
  if (trimmed.startsWith('+')) return '+$digits';
  final cc = (countryCode ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (cc.isNotEmpty && !digits.startsWith(cc)) return '+$cc$digits';
  return digits;
}

/// Call / Copy sheet for [number] (already dialable); [display] is the
/// text shown, e.g. "+91 98765 43210".
Future<void> showPhoneActions(
  BuildContext context, {
  required String number,
  String? display,
}) {
  final label = (display ?? '').trim().isNotEmpty ? display!.trim() : number;
  return _showContactSheet(
    context,
    icon: Icons.phone_outlined,
    title: label,
    actions: [
      _ContactAction(
        icon: Icons.call_outlined,
        label: 'Call',
        color: AppColors.success,
        onTap: () => _launch(context, Uri(scheme: 'tel', path: number),
            failure: 'No dialer app found'),
      ),
      _ContactAction(
        icon: Icons.copy_rounded,
        label: 'Copy number',
        color: AppColors.textSecondary,
        onTap: () => _copy(context, label, 'Number copied'),
      ),
    ],
  );
}

/// Send email / Copy sheet for [email].
Future<void> showEmailActions(BuildContext context, {required String email}) {
  final address = email.trim();
  return _showContactSheet(
    context,
    icon: Icons.email_outlined,
    title: address,
    actions: [
      _ContactAction(
        icon: Icons.send_outlined,
        label: 'Send email',
        color: AppColors.primary,
        onTap: () => _launch(context, Uri(scheme: 'mailto', path: address),
            failure: 'No email app found'),
      ),
      _ContactAction(
        icon: Icons.copy_rounded,
        label: 'Copy email',
        color: AppColors.textSecondary,
        onTap: () => _copy(context, address, 'Email copied'),
      ),
    ],
  );
}

Future<void> _launch(
  BuildContext context,
  Uri uri, {
  required String failure,
}) async {
  var ok = false;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(failure)));
  }
}

Future<void> _copy(BuildContext context, String text, String done) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)
        ?.showSnackBar(SnackBar(content: Text(done)));
  }
}

class _ContactAction {
  final IconData icon;
  final String label;
  final Color color;
  final Future<void> Function() onTap;
  const _ContactAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
}

Future<void> _showContactSheet(
  BuildContext context, {
  required IconData icon,
  required String title,
  required List<_ContactAction> actions,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
              child: Row(children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ]),
            ),
            for (final a in actions)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: a.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(a.icon, size: 19, color: a.color),
                ),
                title: Text(
                  a.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  a.onTap();
                },
              ),
          ],
        ),
      ),
    ),
  );
}
