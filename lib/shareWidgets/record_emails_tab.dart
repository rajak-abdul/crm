// lib/shareWidgets/record_emails_tab.dart
//
// "Emails" tab for the lead and deal detail sheets: the emails sent to /
// logged against one record.
//
// Data: GET /{tenant}/api/leads/:id/emails (deals: /deals/:id/emails, same
// pattern). The response shape wasn't shared yet, so parsing is tolerant:
// a bare list or { data | emails | result | items: [...] }, and the usual
// field-name variants per email.

import 'package:crm_app/screen/email/cubit/email_history_cubit.dart';
import 'package:crm_app/screen/email/cubit/email_template_cubit.dart';
import 'package:crm_app/screen/email/cubit/scheduled_email_cubit.dart';
import 'package:crm_app/screen/email/modal/email_modal.dart';
import 'package:crm_app/screen/email/ui/create_email_screen.dart';
import 'package:crm_app/screen/email/ui/view_email_screen.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:crm_app/shareWidgets/linked_work_index.dart'
    show LinkedWorkKind;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ══════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════

class RecordEmail {
  final String id;
  final String subject;
  final String body; // plain text (HTML stripped)
  final String from;
  final List<String> to;
  final List<String> cc;
  final String status;
  final DateTime? date;
  final String sentBy;
  final List<String> attachments; // file names

  const RecordEmail({
    required this.id,
    required this.subject,
    required this.body,
    required this.from,
    required this.to,
    required this.cc,
    required this.status,
    required this.date,
    required this.sentBy,
    required this.attachments,
  });

  factory RecordEmail.fromJson(Map<String, dynamic> j) {
    String str(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v == null) continue;
        final s = v is Map
            ? (v['email'] ?? v['address'] ?? v['name'] ?? '').toString()
            : v.toString();
        if (s.trim().isNotEmpty) return s.trim();
      }
      return '';
    }

    List<String> addresses(List<String> keys) {
      for (final k in keys) {
        final v = j[k];
        if (v is List && v.isNotEmpty) {
          return [
            for (final e in v)
              if (e is Map)
                (e['email'] ?? e['address'] ?? e['name'] ?? '').toString()
              else
                e.toString(),
          ].where((s) => s.trim().isNotEmpty).toList();
        }
        if (v is String && v.trim().isNotEmpty) {
          return v.split(RegExp(r'[,;]')).map((s) => s.trim()).toList()
            ..removeWhere((s) => s.isEmpty);
        }
      }
      return const [];
    }

    DateTime? date() {
      for (final k in const [
        'sentAt',
        'sentDate',
        'scheduledFor',
        'date',
        'createdAt',
      ]) {
        final d = DateTime.tryParse(j[k]?.toString() ?? '');
        if (d != null) return d;
      }
      return null;
    }

    String person(dynamic v) {
      if (v is Map) {
        final name =
            '${v['firstName'] ?? ''} ${v['lastName'] ?? ''}'.trim();
        if (name.isNotEmpty) return name;
        return (v['name'] ?? v['email'] ?? '').toString();
      }
      return '';
    }

    final rawAttachments = j['attachments'];
    return RecordEmail(
      id: str(const ['_id', 'id']),
      subject: str(const ['subject', 'title', 'templateTitle']),
      body: _plainText(str(const ['content', 'body', 'html', 'text', 'message'])),
      from: str(const ['from', 'sender', 'fromEmail']),
      to: addresses(const ['recipients', 'to', 'toEmails', 'email']),
      cc: addresses(const ['cc']),
      status: str(const ['status', 'deliveryStatus']),
      date: date(),
      sentBy: person(j['createdBy'] ?? j['sentBy'] ?? j['user']),
      attachments: rawAttachments is List
          ? [
              for (final a in rawAttachments)
                if (a is Map)
                  (a['filename'] ?? a['originalName'] ?? a['name'] ?? '')
                      .toString()
                else
                  a.toString(),
            ].where((s) => s.trim().isNotEmpty).toList()
          : const [],
    );
  }

  /// Same approach the Email module uses — the app has no HTML renderer.
  static String _plainText(String html) => html
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]*>'), '')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}

// ══════════════════════════════════════════════════════════════
// API
// ══════════════════════════════════════════════════════════════

Future<List<RecordEmail>> _fetchRecordEmails(
  LinkedWorkKind kind,
  String id,
) async {
  final prefs = await SharedPreferences.getInstance();
  final slug = (prefs.getString('tenant_slug') ??
          prefs.getString('tenantSlug') ??
          '')
      .trim();
  if (slug.isEmpty) throw Exception('Tenant slug not found');
  final token = prefs.getString('token') ?? '';

  final dio = Dio(BaseOptions(
    baseUrl: 'https://crm-backend-api.techzarinfo.cloud/$slug/api',
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Accept': 'application/json',
      if (token.isNotEmpty) 'Authorization': 'Bearer $token',
    },
  ))
    ..interceptors.add(AuthInterceptor());

  try {
    // leads/:id/emails · deals/:id/emails
    final res = await dio.get('/${kind.path}s/$id/emails');
    final data = res.data;

    List<dynamic> raw = const [];
    if (data is List) {
      raw = data;
    } else if (data is Map) {
      for (final k in const ['data', 'emails', 'result', 'items']) {
        final v = data[k];
        if (v is List) {
          raw = v;
          break;
        }
        if (v is Map && v['emails'] is List) {
          raw = v['emails'] as List;
          break;
        }
      }
    }

    final emails = [
      for (final e in raw)
        if (e is Map) RecordEmail.fromJson(Map<String, dynamic>.from(e)),
    ];
    // Newest first.
    emails.sort((a, b) =>
        (b.date ?? DateTime(0)).compareTo(a.date ?? DateTime(0)));
    return emails;
  } on DioException catch (e) {
    final body = e.response?.data;
    throw Exception(body is Map && body['message'] != null
        ? body['message'].toString()
        : (e.message ?? 'Failed to load emails'));
  }
}

// ══════════════════════════════════════════════════════════════
// TAB
// ══════════════════════════════════════════════════════════════

/// Emails for one lead or deal: rail cards (orange = scheduled, green =
/// sent), pull-to-refresh, kept alive across tab switches. Tapping a card
/// opens the Email module on its Scheduled / Sent tab; the send button
/// composes a new email to this record.
class RecordEmailsTab extends StatefulWidget {
  final LinkedWorkKind kind;
  final String id;

  /// The record's own name / address — the compose screen's recipient.
  final String recipientName;
  final String recipientEmail;

  const RecordEmailsTab({
    super.key,
    required this.kind,
    required this.id,
    required this.recipientName,
    required this.recipientEmail,
  });

  @override
  State<RecordEmailsTab> createState() => _RecordEmailsTabState();
}

class _RecordEmailsTabState extends State<RecordEmailsTab>
    with AutomaticKeepAliveClientMixin {
  bool _loading = true;
  String? _error;
  List<RecordEmail> _emails = const [];

  String get _noun => widget.kind == LinkedWorkKind.lead ? 'lead' : 'deal';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// [silent] (pull-to-refresh, back from another screen) keeps the
  /// current list instead of a spinner.
  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final emails = await _fetchRecordEmails(widget.kind, widget.id);
      if (!mounted) return;
      setState(() {
        _emails = emails;
        _error = null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  /// Send button → compose screen with this record as the recipient.
  Future<void> _compose() async {
    final email = widget.recipientEmail.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('This $_noun has no email address'),
      ));
      return;
    }
    final sent = await Navigator.of(context, rootNavigator: true).push<bool>(
      MaterialPageRoute(
        builder: (_) => BlocProvider<EmailTemplateCubit>(
          create: (_) => EmailTemplateCubit()..getEmailTemplates(),
          child: CreateEmailScreen(
            recipients: [
              EmailContact.fromJson({
                'id': widget.id,
                'name': widget.recipientName,
                'email': email,
                'type': widget.kind.path,
              }),
            ],
          ),
        ),
      ),
    );
    if (sent == true && mounted) _load(silent: true);
  }

  /// Card tap → Email module, on the Scheduled (0) or Sent history (1) tab.
  Future<void> _openInEmailModule(RecordEmail e) async {
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => EmailHistoryCubit()),
            BlocProvider(
              create: (_) => ScheduledEmailCubit()..getScheduledEmails(),
            ),
          ],
          child: ViewEmailScreen(
            initialTab: _EmailStatus.of(e.status).isScheduled ? 0 : 1,
          ),
        ),
      ),
    );
    // A scheduled email may have been edited, sent or cancelled there.
    if (mounted) _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Stack(
      children: [
        Positioned.fill(child: _list()),
        Positioned(
          right: 20,
          bottom: 20,
          child: FloatingActionButton(
            heroTag: 'record-emails-${widget.kind.path}-${widget.id}',
            tooltip: 'Compose email',
            onPressed: _compose,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 6,
            shape: const CircleBorder(),
            child: const Icon(Icons.send_outlined, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _list() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _load(silent: true),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Bottom room so the last card clears the send button.
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 96),
        children: [
          if (_error != null)
            _StateMessage(
              icon: Icons.error_outline_rounded,
              text: "Couldn't load emails: $_error",
              isError: true,
              onRetry: () => _load(),
            )
          else if (_emails.isEmpty)
            _StateMessage(
              icon: Icons.mark_email_unread_outlined,
              text: 'No emails for this $_noun yet',
            )
          else
            for (final e in _emails)
              _EmailCard(email: e, onTap: () => _openInEmailModule(e)),
        ],
      ),
    );
  }
}

// ── Status → colour / icon / label ────────────────────────────────
class _EmailStatus {
  final String label;
  final Color color;
  final Color tint;
  final IconData icon;
  final bool isScheduled;

  const _EmailStatus(
    this.label,
    this.color,
    this.tint,
    this.icon, {
    this.isScheduled = false,
  });

  factory _EmailStatus.of(String raw) {
    final s = raw.toLowerCase();
    final t = raw.trim();
    String label(String fallback) => t.isEmpty
        ? fallback
        : t[0].toUpperCase() + t.substring(1).toLowerCase();

    if (s.contains('fail') || s.contains('bounce') || s.contains('cancel')) {
      return _EmailStatus(label('Failed'), AppColors.danger,
          AppColors.dangerLight, Icons.error_outline_rounded);
    }
    if (s.contains('schedul') || s.contains('pending') || s.contains('queue')) {
      return _EmailStatus(label('Scheduled'), const Color(0xFFD97706),
          const Color(0xFFFFF7ED), Icons.schedule_rounded,
          isScheduled: true);
    }
    if (s.contains('open') || s.contains('read') || s.contains('repl')) {
      return _EmailStatus(label('Opened'), AppColors.purple,
          AppColors.purpleLight, Icons.drafts_outlined);
    }
    return _EmailStatus(label('Sent'), const Color(0xFF16A34A),
        const Color(0xFFECFDF5), Icons.check_rounded);
  }
}

// ── Card (rail + icon tile + subject + date + status) ─────────────
class _EmailCard extends StatelessWidget {
  final RecordEmail email;
  final VoidCallback onTap;
  const _EmailCard({required this.email, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final e = email;
    final st = _EmailStatus.of(e.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: st.color), // left rail
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: st.tint,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.mail_outline_rounded,
                            size: 21,
                            color: st.color,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                e.subject.isEmpty ? '(No subject)' : e.subject,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 14,
                                    color: AppColors.textHint,
                                  ),
                                  const SizedBox(width: 5),
                                  Expanded(
                                    child: Text(
                                      e.date == null
                                          ? 'No date'
                                          : DateFormat('MMM d, y, hh:mm a')
                                              .format(e.date!.toLocal()),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _StatusPill(st),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
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

class _StatusPill extends StatelessWidget {
  final _EmailStatus st;
  const _StatusPill(this.st);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: st.tint,
          borderRadius: BorderRadius.circular(99),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(st.icon, size: 13, color: st.color),
            const SizedBox(width: 4),
            Text(
              st.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: st.color,
              ),
            ),
          ],
        ),
      );
}

class _StateMessage extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isError;
  final VoidCallback? onRetry;
  const _StateMessage({
    required this.icon,
    required this.text,
    this.isError = false,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 48),
        child: Column(
          children: [
            Icon(
              icon,
              size: 44,
              color: isError ? AppColors.danger : AppColors.textHint,
            ),
            const SizedBox(height: 10),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isError ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      );
}
