import 'package:crm_app/screen/deals/cubit/attachment_deals_cubit.dart';
import 'package:crm_app/screen/deals/cubit/deals_attachment_state.dart';
import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/screen/deals/ui/deal_form_modal.dart';
import 'package:crm_app/screen/deals/ui/deal_screen.dart';
import 'package:crm_app/screen/deals/ui/deals_shared_widget.dart';
import 'package:crm_app/screen/invoice/cubit/invoice_cubit.dart';
import 'package:crm_app/screen/invoice/modal/invoice_model.dart';
import 'package:crm_app/screen/invoice/ui/invoice_details_screen.dart';
import 'package:crm_app/screen/invoice/ui/invoice_screen.dart';
import 'package:crm_app/screen/leads/ui/meeting.dart' show MeetingCard;
import 'package:crm_app/screen/meeting/UI/meeting.dart' show CreateMeetingSheet;
import 'package:crm_app/screen/meeting/cubit/meeting_cubit.dart';
import 'package:crm_app/screen/meeting/cubit/meeting_state.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../thems/app_themes.dart';

const List<String> _followUpOutcomeOptions = [
  'Completed',
  'Missed / No Response',
  'Rescheduled',
  'Client No-Show',
  'Cancelled',
];

class FollowUpPair {
  final FollowUpHistoryItem scheduled;
  final FollowUpHistoryItem? completed;

  const FollowUpPair({
    required this.scheduled,
    this.completed,
  });

  bool get isPast => completed != null;

  bool get isUpcoming => completed == null;
}

// CHANGED: StatelessWidget -> StatefulWidget
class DealDetailSheet extends StatefulWidget {
  final Deal deal;
  const DealDetailSheet({super.key, required this.deal});

  @override
  State<DealDetailSheet> createState() => _DealDetailSheetState();
}

class _DealDetailSheetState extends State<DealDetailSheet> {
  // CHANGED: mutable local copy of the deal, updated after schedule/complete
  late Future<List<Invoice>> _invoiceFuture;
  late Deal _deal;
   String displayFileName(String fileName) {
    final parts = fileName.split('.');

    if (parts.length >= 3) {
      return '${parts.sublist(0, parts.length - 2).join('.')}.${parts.last}';
    }

    return fileName;
  }
  int _followUpHistoryPage = 1;
static const int _followUpHistoryPageSize = 5;
  final GlobalKey<ScaffoldMessengerState> _detailMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _deal = widget.deal; // CHANGED
    _invoiceFuture =
      context.read<DealsCubit>().getDealInvoices(_deal.id);

  }

  DateTime? _followUpLocal(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(raw.trim());
    if (parsed == null) return null;
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }
  

  ScaffoldMessengerState? _snackMessenger(BuildContext context) {
    if (!context.mounted) return null;
    final localSheet = _detailMessengerKey.currentState;
    if (localSheet != null) return localSheet;
    final local = ScaffoldMessenger.maybeOf(context);
    if (local != null) return local;
    final rootNav = Navigator.maybeOf(context, rootNavigator: true);
    if (rootNav == null) return null;
    if (!rootNav.context.mounted) return null;
    return ScaffoldMessenger.maybeOf(rootNav.context);
  }

  void _showSnack(BuildContext context, SnackBar snackBar) {
    final messenger = _snackMessenger(context);
    if (messenger == null) return;
    try {
      messenger.showSnackBar(snackBar);
    } catch (_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final retry = _snackMessenger(context);
        retry?.showSnackBar(snackBar);
      });
    }
  }

  void _hideSnack(BuildContext context) {
    final messenger = _snackMessenger(context);
    if (messenger == null) return;
    try {
      messenger.hideCurrentSnackBar();
    } catch (_) {}
  }

  // CHANGED: helper to re-fetch the deal and push it into local state
  Future<void> _refreshDeal(DealsCubit dealsCubit) async {
      debugPrint("===== REFRESH START =====");

    try {
      final updated = await dealsCubit.getDealById(_deal.id);
      if (updated != null && mounted) {
        setState(() => _deal = updated);
      }

debugPrint(
  "History Count: ${updated?.followUpHistory.length}",
);

debugPrint(
  updated?.followUpHistory.toString(),
);
for (final item in updated!.followUpHistory) {
  debugPrint(
    'Action=${item.action}, '
    'Outcome=${item.outcome}, '
    'Date=${item.followUpDate}',
  );
}
  debugPrint("===== REFRESH END =====");

    } catch (e) {
      debugPrint('[DealDetailSheet] refresh failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) => BlocListener<DealsAttachmentCubit, DealsAttachmentState>(
  listener: (context, state) {
    switch (state.status) {
      case DealsAttachmentStatus.loading:
        _showSnack(
          context,
          const SnackBar(
            duration: Duration(seconds: 60),
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Please wait...'),
              ],
            ),
          ),
        );
        break;

      case DealsAttachmentStatus.previewSuccess:
        _hideSnack(context);
        break;

      case DealsAttachmentStatus.downloadSuccess:
        _hideSnack(context);
        _showSnack(
          context,
          SnackBar(
            content: Text(state.message ?? 'Download completed'),
            backgroundColor: Colors.green,
          ),
        );
        break;

      case DealsAttachmentStatus.error:
        _hideSnack(context);
        _showSnack(
          context,
          SnackBar(
            content: Text(state.message ?? 'Something went wrong'),
            backgroundColor: Colors.red,
          ),
        );
        break;

      case DealsAttachmentStatus.initial:
        break;
      
      case DealsAttachmentStatus.uploadSuccess:
  _hideSnack(context);

  _showSnack(
    context,
    SnackBar(
      content: Text(
        state.message ?? 'Attachment uploaded successfully',
      ),
      backgroundColor: Colors.green,
    ),
  );
  break;
    }
  },
  child: ScaffoldMessenger(
    key: _detailMessengerKey,
    child: DefaultTabController(
  length: 7,
  child: Scaffold(
    backgroundColor: Colors.transparent,
    floatingActionButton: Builder(
    
      builder: (fabCtx) {
        final tabController = DefaultTabController.of(fabCtx);
        return AnimatedBuilder(
          animation: tabController,
          builder: (_, __) {
            if (tabController.index != 2) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(bottom: 60),
            child: FloatingActionButton(
              heroTag: 'dealDetailFab',
  backgroundColor: Colors.purple[100],
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16), // adjust for more/less rounding
    side: const BorderSide(color: Colors.purpleAccent, width: 0.8),
  ),
  onPressed: () {
      debugPrint("Current Deal FollowUp = ${_deal.followUpDate}");
   _showScheduleFollowUpDialog(fabCtx, _deal); 
  },
  child: const Icon(Icons.add, color: Colors.purple,size: 25,),
));
          },
        );
      },
    ),
          body: DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.4,
              maxChildSize: 0.95,
              builder: (_, ctrl) => Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(children: [
                  Container(
                      margin: const EdgeInsets.only(top: 12),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(2))),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                    child: Row(children: [
                      Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [
                                AppColors.primary,
                                AppColors.accent
                              ]),
                              borderRadius: BorderRadius.circular(14)),
                          child: Center(
                              child: Text(
                            _deal.name.isNotEmpty
                                ? _deal.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20),
                          ))),
                      const SizedBox(width: 12),
                      Expanded(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              _deal.name,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () async {
              // Close the detail bottom sheet
              final dealsCubit = context.read<DealsCubit>();
final rootContext = Navigator.of(context, rootNavigator: true).context;

Navigator.pop(context);

Future.delayed(const Duration(milliseconds: 200), () {
  showModalBottomSheet(
    context: rootContext,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: dealsCubit,
      child: DealFormModal(
        editDeal: _deal,
        users: const [],
      ),
    ),
  );
});
            },
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.edit_outlined,
                size: 16,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 2),
      Text(
        _deal.companyName,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
    ],
  ),
),
                      Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: stageColor(_deal.stage).withOpacity(0.12),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(DealConstants.canonicalStage(_deal.stage),
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: stageColor(_deal.stage)))),
                    ]),
                  ),
                  const SizedBox(height: 10),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      indicatorColor: AppColors.primary,
                      tabs: [
                        Tab(text: 'Details'),
                        Tab(text: 'Activity'),
                        Tab(text: 'Follow-up history'),
                        Tab(text:'Attachments'),
                        Tab(text:'Invoice'),
                        Tab(text:'Notes'),
                        Tab(text:'Meetings'),
                      ],
                    ),
                  ),
                  const Divider(height: 16, color: AppColors.divider),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDetailsTab(ctrl),
                        _buildActivityTab(ctrl),
                        _buildFollowupHistoryTab(ctrl),
                         _buildAttachements(ctrl), // new
                         _buildInvoiceTab(ctrl), // new
                         _buildNewTab3(ctrl), // new
                         _buildMeetingsTab(),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      )
  );

  Widget _buildDetailsTab(ScrollController ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        children: [
          _row(Icons.payments_outlined, 'Deal Value',
              fmtVal(_deal.currency, _deal.value)),
          if (_followUpLocal(_deal.followUpDate) != null)
            _row(
              Icons.event_outlined,
              'Follow Up',
              DateFormat('dd MMM yyyy, hh:mm a')
                  .format(_followUpLocal(_deal.followUpDate)!),
            ),
          _row(
              Icons.person_outline,
              'Assigned To',
              _deal.assignTo.trim().isEmpty
                  ? 'Unassigned'
                  : _deal.assignTo.trim()),
          _row(
            Icons.phone_outlined,
            'Phone',
            _deal.phone.trim().isEmpty
                ? '-'
                : _formatPhone(_deal.phone, _deal.countryCode),
          ),
          if (_deal.alternativeNumber.trim().isNotEmpty)
            _row(Icons.phone_forwarded_outlined, 'Alternative Number',
                _deal.alternativeNumber.trim()),
          _row(Icons.email_outlined, 'Email',
              _deal.email.trim().isEmpty ? '-' : _deal.email),
          if (_deal.alternativeEmail.trim().isNotEmpty)
            _row(Icons.alternate_email_outlined, 'Alternative Email',
                _deal.alternativeEmail.trim()),
          _row(Icons.public_outlined, 'Country',
              _deal.country.trim().isEmpty ? '-' : _deal.country),
          if (_deal.industry.isNotEmpty)
            _row(Icons.business_outlined, 'Industry', _deal.industry),
          if (_deal.source.isNotEmpty)
            _row(Icons.radar_outlined, 'Source', _deal.source),
          if (_deal.address.isNotEmpty)
            _row(Icons.location_on_outlined, 'Address', _deal.address),
          if (_deal.notes.isNotEmpty)
            _row(Icons.notes_outlined, 'Notes', _deal.notes),
          if (_deal.attachments.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Attachments',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ..._deal.attachments.map(
              (a) => Builder(
                builder: (tileCtx) => Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              a.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${(a.size / 1024).toStringAsFixed(1)} KB',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textHint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.visibility,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Preview',
onPressed: () {
  tileCtx.read<DealsAttachmentCubit>().previewAttachment(
    a.path,
  );
},                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.download,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        tooltip: 'Download',
onPressed: () {
 tileCtx.read<DealsAttachmentCubit>().downloadAttachment(
  rawPath: a.path,
  fileName: a.name,
);
},                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      );

  String _formatPhone(String phone, String countryCode) {
    if (phone.trim().isEmpty) return '-';

    try {
      final cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');

      final parsedPhone = PhoneNumber.parse(
        '+$cleaned',
      );

      final code = parsedPhone.countryCode;
      final nationalNumber = parsedPhone.nsn;

      return '+$code $nationalNumber';
    } catch (e) {
      return phone;
    }
  }

  Widget _buildActivityTab(ScrollController ctrl) {
  return FutureBuilder<List<DealActivityItem>>(
    future: context.read<DealsCubit>().getDealActivity(_deal.id), // ← method name TBD, see note below
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return Center(
          child: Text('Failed to load activity: ${snapshot.error}',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        );
      }
      final activities = snapshot.data ?? [];
      if (activities.isEmpty) {
        return const Center(
          child: Text('No activity yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        );
      }

      IconData iconFor(String type) {
        switch (type) {
          case 'followup':
            return Icons.event_available_outlined;
          case 'stage_change':
            return Icons.swap_horiz_outlined;
          default:
            return Icons.circle_outlined;
        }
      }

      return ListView.separated(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final item = activities[i];
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(iconFor(item.type), size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.description,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(
                      DateFormat('dd MMM yyyy, hh:mm a').format(item.timestamp.toLocal()) +
                          (item.performedByName.isNotEmpty ? '  ·  ${item.performedByName}' : ''),
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            ]),
          );
        },
      );
    },
  );
}
  void _showCompleteFollowUpDialog(BuildContext context, Deal deal) {
    String? outcome;
    final notesController = TextEditingController();
    final dealsCubit = context.read<DealsCubit>();

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE7F9EF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_outline, color: AppColors.success, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "Complete Follow-up",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Outcome",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: outcome,
                    hint: const Text('Select outcome'),
                    items: _followUpOutcomeOptions
                        .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                        .toList(),
                    onChanged: (v) => setState(() => outcome = v),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Notes",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'What happened on this follow-up?',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text("Cancel"),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.success,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () async {
                          if (outcome == null || outcome!.trim().isEmpty) {
                            _showSnack(context, const SnackBar(content: Text("Please select an outcome")));
                            return;
                          }
                          if (notesController.text.trim().isEmpty) {
                            _showSnack(context, const SnackBar(content: Text("Please enter notes")));
                            return;
                          }

                          final success = await dealsCubit.completeFollowUp(
                            deal.id,
                            outcome: outcome!,
                            notes: notesController.text.trim(),
                          );

                          if (success) {
                            if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                            _showSnack(
                              context,
                              const SnackBar(
                                content: Text("Follow-up marked as completed"),
                                backgroundColor: Colors.green,
                              ),
                            );
                            await _refreshDeal(dealsCubit); // CHANGED: updates _deal + rebuilds tabs
                          } else {
                            _showSnack(
                              context,
                              const SnackBar(
                                content: Text("Failed to complete follow-up"),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check, size: 20),
                        label: const Text("Complete", style: TextStyle(fontSize: 14,)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  void _showScheduleFollowUpDialog(BuildContext context, Deal deal) {
    DateTime? selectedDate;
    final notesController = TextEditingController();
    final previousNotesController = TextEditingController();
    String? previousOutcome;
    final dealsCubit = context.read<DealsCubit>();

    final bool isReschedule =
        deal.followUpDate != null && deal.followUpDate!.trim().isNotEmpty;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (dialogCtx, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF7E9FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.schedule, color: Color(0xFFD46BFF), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isReschedule ? "Reschedule Follow-up" : "Schedule First Follow-up",
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isReschedule) ...[
                    const Text(
                      "Previous Follow-up Outcome",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: previousOutcome,
                      hint: const Text('Select outcome'),
                      items: _followUpOutcomeOptions // CHANGED: was shadowed local list
                          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
                          .toList(),
                      onChanged: (v) => setState(() => previousOutcome = v),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "Previous Follow-up Notes",
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: previousNotesController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'What happened on the previous follow-up?',
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 8),
                  ],
                  const Text(
                    "Follow-up Date & Time",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: dialogCtx,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date == null) return;

                      final time = await showTimePicker(
                        context: dialogCtx,
                        initialTime: TimeOfDay.now(),
                      );
                      if (time == null) return;

                      setState(() {
                        selectedDate = DateTime(
                          date.year, date.month, date.day, time.hour, time.minute,
                        );
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE6C8FF)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, color: Color(0xFFD46BFF)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedDate == null
                                  ? 'Select date & time'
                                  : DateFormat('dd MMM yyyy hh:mm a').format(selectedDate!),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Follow-up Notes",
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'Enter meeting agenda...',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFD46BFF), width: 1.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFD46BFF), width: 2),
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text("Cancel"),
                    ),
                  ),
                  if (isReschedule) ...[
                    const SizedBox(width: 10),
                    Expanded(
  child: Tooltip(
    message: "Complete",
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.success,
        side: const BorderSide(color: AppColors.success),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () async {
        if (previousOutcome == null || previousOutcome!.trim().isEmpty) {
          _showSnack(context, const SnackBar(content: Text("Please select an outcome")));
          return;
        }
        if (previousNotesController.text.trim().isEmpty) {
          _showSnack(context, const SnackBar(content: Text("Please enter notes")));
          return;
        }

        final success = await dealsCubit.completeFollowUp(
          deal.id,
          outcome: previousOutcome!,
          notes: previousNotesController.text.trim(),
        );

        if (success) {
          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
          _showSnack(
            context,
            const SnackBar(
              content: Text("Follow-up marked as completed"),
              backgroundColor: Colors.green,
            ),
          );
          await _refreshDeal(dealsCubit);
        } else {
          _showSnack(
            context,
            const SnackBar(
              content: Text("Failed to complete follow-up"),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      child: const Icon(Icons.check, size: 20),
    ),
  ),
),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    flex: isReschedule ? 1 : 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD46BFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        if (isReschedule) {
                          if (previousOutcome == null || previousOutcome!.trim().isEmpty) {
                            _showSnack(context, const SnackBar(content: Text("Please select an outcome for the previous follow-up")));
                            return;
                          }
                          if (previousNotesController.text.trim().isEmpty) {
                            _showSnack(context, const SnackBar(content: Text("Please enter notes for the previous follow-up")));
                            return;
                          }
                        }

                        if (selectedDate == null) {
                          _showSnack(context, const SnackBar(content: Text("Please select a follow-up date & time")));
                          return;
                        }
                        if (notesController.text.trim().isEmpty) {
                          _showSnack(context, const SnackBar(content: Text("Please enter follow-up notes")));
                          return;
                        }
                        debugPrint("========== Schedule ==========");
debugPrint("deal.followUpDate = ${deal.followUpDate}");
debugPrint("isReschedule = $isReschedule");
debugPrint("previousFollowUpDate = ${_followUpLocal(deal.followUpDate)}");
debugPrint("previousOutcome = $previousOutcome");
debugPrint("previousNotes = ${previousNotesController.text}");
debugPrint("==============================");
                        final success = await dealsCubit.scheduleFollowUp(
                          deal.id,
                          followUpDate: selectedDate!,
                          comment: notesController.text.trim(),
                          previousFollowUpDate: _followUpLocal(deal.followUpDate),
                          previousNotes: isReschedule ? previousNotesController.text.trim() : '',
                          previousOutcome: isReschedule ? previousOutcome! : '',
                        );

                        if (success) {
                            debugPrint("===== SCHEDULE SUCCESS =====");

                          if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                          _showSnack(
                            context,
                            const SnackBar(
                              content: Text("Follow-up scheduled successfully"),
                              backgroundColor: Colors.green,
                            ),
                          );
                            debugPrint("===== BEFORE REFRESH =====");

                          await _refreshDeal(dealsCubit); // CHANGED

                            debugPrint("===== AFTER REFRESH =====");

                        } else {
                          _showSnack(
                            context,
                            const SnackBar(
                              content: Text("Failed to schedule follow-up"),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.event_available, size: 18),
                      label: Text(isReschedule ? "Rescheduled" : "Scheduled", style: const TextStyle(fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFollowupHistoryTab(ScrollController ctrl) {
    DateTime? pickDt(FollowUpHistoryItem h) => h.followUpDate ?? h.date;

final history = [..._deal.followUpHistory];

if (history.isEmpty &&
    _deal.followUpDate != null &&
    _deal.followUpDate!.trim().isNotEmpty) {
  history.add(
    FollowUpHistoryItem(
      action: 'Scheduled',
      followUpDate: _followUpLocal(_deal.followUpDate),
      notes: _deal.followUpComment ?? '',
      outcome: '',
      changedByName: _deal.assignTo,
      date: _followUpLocal(_deal.followUpDate)!, 
      comment: '',
    ),
  );
}

    final List<FollowUpPair> pairs = [];

    FollowUpHistoryItem? pendingScheduled;

    for (final item in history) {
      final action = item.action.trim().toLowerCase();

      if (action.contains("scheduled")|| action.contains("created")) {
        if (pendingScheduled != null) {
          pairs.add(
            FollowUpPair(
              scheduled: pendingScheduled,
            ),
          );
        }

        pendingScheduled = item;
      } else if (action.contains("completed")) {
        if (pendingScheduled != null) {
          pairs.add(
            FollowUpPair(
              scheduled: pendingScheduled,
              completed: item,
            ),
          );

          pendingScheduled = null;
        }
      }
    }

    if (pendingScheduled != null) {
      pairs.add(
        FollowUpPair(
          scheduled: pendingScheduled,
        ),
      );
    }

    final upcoming = pairs.where((e) => e.isUpcoming).toList();
    final past = pairs.where((e) => e.isPast).toList();

   final hasAny = upcoming.isNotEmpty || past.isNotEmpty;
    if (!hasAny) {
      return ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        children: const [
          Text(
            'No follow-up history yet.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      );
    }

    // CHANGED: paginate the combined, already-ordered list (upcoming first, then past)
    final allPairs = [...upcoming, ...past];
    final totalItems = allPairs.length;
    final totalPages = (totalItems / _followUpHistoryPageSize).ceil().clamp(1, 1 << 30);
    final safePage = _followUpHistoryPage.clamp(1, totalPages);
    final start = (safePage - 1) * _followUpHistoryPageSize;
    final end = (start + _followUpHistoryPageSize).clamp(0, totalItems);
    final pageItems = allPairs.sublist(start, end);

    final pageUpcoming = pageItems.where((p) => p.isUpcoming).toList();
    final pagePast = pageItems.where((p) => p.isPast).toList();

    List<Widget> cardsFor(List<FollowUpPair> items, {required bool upcoming}) {
  return items.map((pair) {
    final scheduled = pair.scheduled;
    final completed = pair.completed;

    final scheduledForDt = pickDt(scheduled)!.toLocal();
    final loggedDt = (upcoming
            ? (scheduled.date ?? scheduledForDt)
            : (completed?.date ?? scheduled.date ?? scheduledForDt))
        .toLocal();
    final agenda = (scheduled.notes ?? '').trim().isNotEmpty
    ? scheduled.notes!.trim()
    : scheduled.comment.trim();
    final summary = (completed?.notes ?? '').trim();
    final updatedBy = (upcoming ? scheduled.changedByName : (completed?.changedByName ?? scheduled.changedByName)).trim();

    final badgeColor = upcoming ? AppColors.purple : AppColors.success;
    final badgeBg = upcoming ? AppColors.purpleLight : AppColors.successLight;
    final icon = upcoming ? Icons.alarm_outlined : Icons.check_circle_outline;
    final title = upcoming ? 'Follow-up Scheduled' : 'Follow-up Completed';
    final badgeLabel = upcoming
        ? 'Scheduled'
        : ((completed?.outcome?.trim().isNotEmpty ?? false) ? completed!.outcome! : 'Completed');
    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: icon + title + status badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: badgeBg, shape: BoxShape.circle),
                child: Icon(icon, size: 18, color: badgeColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Text(badgeLabel,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: badgeColor)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Logged date/time
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text('Logged: ${DateFormat('MMM d, yyyy').format(loggedDt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              const SizedBox(width: 12),
              const Icon(Icons.access_time_outlined, size: 13, color: AppColors.textSecondary),
              const SizedBox(width: 4),
              Text(DateFormat('hh:mm a').format(loggedDt),
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Scheduled for: ${DateFormat('MMM d').format(scheduledForDt)}  at  ${DateFormat('hh:mm a').format(scheduledForDt)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textHint),
          ),

          if (agenda.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Agenda / Plan',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(agenda, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
          ],

          if (!upcoming && summary.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Text('Meeting Summary',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.purpleLight.withOpacity(0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(summary, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary)),
            ),
          ],

          if (updatedBy.isNotEmpty) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                const CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.border,
                  child: Icon(Icons.person, size: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 8),
                const Text('Updated by  ',
                    style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(updatedBy,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
              ],
            ),
          ],
        ],
      ),
    );
  }).toList();
}
    return Column(
      children: [
        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            children: [
              if (pageUpcoming.isNotEmpty) ...[
                const Text(
                  'Upcoming follow-ups',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                ...cardsFor(pageUpcoming, upcoming: true),
              ],
              if (pagePast.isNotEmpty) ...[
                if (pageUpcoming.isNotEmpty) const SizedBox(height: 6),
                const Text(
                  'Past follow-ups',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary),
                ),
                const SizedBox(height: 10),
                ...cardsFor(pagePast, upcoming: false),
              ],
            ],
          ),
        ),
        PaginationBar(
          page: safePage,
          totalPages: totalPages,
          totalItems: totalItems,
          pageSize: _followUpHistoryPageSize,
          onPrev: safePage > 1
              ? () => setState(() => _followUpHistoryPage -= 1)
              : null,
          onNext: safePage < totalPages
              ? () => setState(() => _followUpHistoryPage += 1)
              : null,
        ),
      ],
    );
  }

  Widget _row(IconData icon, String lbl, String val) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: AppColors.primary)),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(lbl,
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(val.isEmpty ? '-' : val,
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500)),
              ])),
        ]),
      );
      
Widget _buildAttachements(ScrollController ctrl) => ListView(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      children: [
        /// Upload Card
        InkWell(
          onTap: () async {
  final result = await FilePicker.platform.pickFiles(
    allowMultiple: true,
    withData: true,
    type: FileType.any,
  );

  if (result == null || result.files.isEmpty) return;

  final dealsCubit = context.read<DealsCubit>();

  final payload = {
    "dealName": _deal.name,
    "companyName": _deal.companyName,
    "phoneNumber": _deal.phone,
    "email": _deal.email,
    "stage": _deal.stage,
    "value": _deal.value,
    "currency": _deal.currency,

    // Keep existing attachments
    "retainedAttachmentPaths":
        _deal.attachments.map((e) => e.path).toList(),
  };

  await dealsCubit.updateDeal(
    _deal.id,
    payload,
    attachments: result.files,
  );

  if (!mounted) return;

  await _refreshDeal(dealsCubit);

  _showSnack(
    context,
    const SnackBar(
      content: Text("Attachments uploaded successfully"),
      backgroundColor: Colors.green,
    ),
  );
},
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AppColors.primary.withOpacity(.25),
              ),
            ),
            child: const Column(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  color: AppColors.primary,
                  size: 25,
                ),
                SizedBox(height: 8),
                Text(
                  "Upload Attachment",
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  "PDF, Image, Excel, Word, ZIP...",
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 22),

        const Text(
          "Existing Attachments",
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        if (_deal.attachments.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 50),
            child: const Column(
              children: [
                Icon(
                  Icons.folder_open,
                  size: 60,
                  color: Colors.grey,
                ),
                SizedBox(height: 12),
                Text(
                  "No attachments available",
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else
          ..._deal.attachments.map(
            (a) => Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(
                  color: AppColors.border,
                ),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Icon(
                    _fileIcon(a.name),
                    color: AppColors.primary,
                  ),
                ),
                title: Text(
                 displayFileName(a.name),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  "${(a.size / 1024).toStringAsFixed(1)} KB",
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: "Preview",
                      icon: const Icon(
                        Icons.visibility,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () {
                        context
                            .read<DealsAttachmentCubit>()
                            .previewAttachment(a.path);
                      },
                    ),
                    IconButton(
                      tooltip: "Download",
                      icon: const Icon(
                        Icons.download_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      onPressed: () {
                        context
                            .read<DealsAttachmentCubit>()
                            .downloadAttachment(
                              rawPath: a.path,
                              fileName: a.name,
                            );
                      },
                    ),
                    
                  ],
                ),
              ),
            ),
          ),
      ],
    );

IconData _fileIcon(String name) {
  final file = name.toLowerCase();

  if (file.endsWith(".pdf")) {
    return Icons.picture_as_pdf;
  }

  if (file.endsWith(".jpg") ||
      file.endsWith(".jpeg") ||
      file.endsWith(".png") ||
      file.endsWith(".gif")) {
    return Icons.image;
  }

  if (file.endsWith(".xls") ||
      file.endsWith(".xlsx")) {
    return Icons.table_chart;
  }

  if (file.endsWith(".doc") ||
      file.endsWith(".docx")) {
    return Icons.description;
  }

  if (file.endsWith(".zip") ||
      file.endsWith(".rar")) {
    return Icons.archive;
  }

  return Icons.insert_drive_file;
}

Widget _buildInvoiceTab(ScrollController ctrl) {
  return FutureBuilder<List<Invoice>>(
    future: _invoiceFuture,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      final invoices = snapshot.data ?? [];

      if (invoices.isEmpty) {
        return const Center(
          child: Text(
            'No invoices found',
            style: TextStyle(
              color: AppColors.textSecondary,
            ),
          ),
        );
      }

      return ListView.separated(
        controller: ctrl,
        padding: const EdgeInsets.all(16),
        itemCount: invoices.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, index) {
          final invoice = invoices[index];

          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(
                color: AppColors.border,
              ),
            ),
            child: ListTile(
onTap: () async {
  final cubit = context.read<InvoiceCubit>();

  if (cubit.state is! InvoiceLoaded) {
    await cubit.load();
  }

  final state = cubit.state;

  if (state is! InvoiceLoaded) return;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider.value(
      value: cubit,
      child: InvoiceFormModal(
        existing: invoice,
        salesUsers: state.salesUsers,
        deals: state.deals,
        onSave: (data) async {
          final err = await cubit.updateInvoice(
            invoice.id,
            data,
          );


          if (err != null) throw Exception(err);

          Navigator.pop(context);

          setState(() {
    _invoiceFuture =
        context.read<DealsCubit>().getDealInvoices(_deal.id);
  });

        },
      ),
    ),
  );
},  

leading: const CircleAvatar(
  radius: 20,
  backgroundColor: AppColors.primaryLight,
  child: Icon(
    Icons.receipt_long_rounded,
    color: AppColors.primary,
    size: 20,
  ),
),

title: Text(
  
  invoice.invoiceNo,
  style: const TextStyle(
    fontWeight: FontWeight.w700,
    fontSize: 12,
  ),
),



trailing: Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: invoice.status == "Paid"
            ? Colors.green.shade100
            : invoice.status == "Partially Paid"
                ? Colors.orange.shade100
                : Colors.red.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        invoice.status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: invoice.status == "Paid"
              ? Colors.green
              : invoice.status == "Partially Paid"
                  ? Colors.orange
                  : Colors.red,
        ),
      ),
    ),

    const SizedBox(width: 8),

    BlocBuilder<InvoiceCubit, InvoiceState>(
  buildWhen: (previous, current) => true,
  builder: (context, state) {
    final cubit = context.read<InvoiceCubit>();
    final loading = cubit.isSendingEmail(invoice.id);

    return InkWell(
      onTap: loading
          ? null
          : () async {
              final msg = await cubit.sendInvoiceEmail(invoice.id);

              if (!mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg ?? 'Email sent',)),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              )
            : const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.send_rounded,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  SizedBox(width: 4),
                  Text(
                    "Email",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  },
)
  ],
),)
          );
        },
      );
    },
  );
}
Widget _buildNewTab3(ScrollController ctrl) {
  return FutureBuilder<List<DealActivityItem>>(
    future: context.read<DealsCubit>().getDealActivity(_deal.id),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      final notes = (snapshot.data ?? [])
          .where((e) => e.type == "note_added")
          .toList();

      return Stack(
        children: [
          ListView.separated(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              90, // leave space for FAB
            ),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final note = notes[index];

              return Card(
                child: ListTile(
                  leading: const Icon(Icons.sticky_note_2_outlined),
                  title: Text(
                    note.description
                        .replaceFirst("Note added:", "")
                        .replaceAll('"', "")
                        .trim(),
                  ),
                  subtitle: Text(note.performedByName),
                ),
              );
            },
          ),

          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton(
              heroTag: "notesFab",
              child: const Icon(Icons.add),
              
              onPressed: () {
                _showAddNoteDialog();
              },
            ),
          ),
        ],
      );
    },
  );
}
Future<void> _showAddNoteDialog() async {
  final controller = TextEditingController();

  await showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text("Add Note"),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            hintText: "Write your note...",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () async {
              final text = controller.text.trim();
              if (text.isEmpty) return;

              final success = await context.read<DealsCubit>().addDealNote(
                    _deal.id,
                    text,
                  );

              if (!mounted) return;

              Navigator.pop(dialogContext);

              if (success) {
                setState(() {}); // reload FutureBuilder

                _showSnack(
                  context,
                  const SnackBar(
                    content: Text("Note added successfully"),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                _showSnack(
                  context,
                  const SnackBar(
                    content: Text("Failed to add note"),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Add"),
          ),
        ],
      );
    },
  );
}

Widget _buildMeetingsTab() {
  return Stack(
    children: [
      _buildDealMeetings(),

      Positioned(
        right: 20,
        bottom: 20,
        child: BlocBuilder<MeetingsCubit, MeetingsState>(
          builder: (context, state) {
            final connected = switch (state) {
              MeetingsLoaded(:final googleConnected) => googleConnected,
              MeetingsCreating(:final googleConnected) => googleConnected,
              _ => false,
            };

            return Opacity(
              opacity: connected ? 1 : 0.45,
              child: FloatingActionButton(
                heroTag: 'dealMeetingsFab',
                mini: true,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 4,
                tooltip: connected
                    ? 'Create meeting'
                    : 'Connect Google to create meetings',
                onPressed: connected ? _createMeetingForDeal : null,
                child: Icon(
                  connected ? Icons.add : Icons.lock_outline,
                  size: 20,
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
}

Widget _buildDealMeetings() {
  return BlocBuilder<MeetingsCubit, MeetingsState>(
    builder: (context, state) {
      if (state is MeetingsLoading) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      }

      if (state is MeetingsError) {
        return Center(
          child: Text(
            state.message,
            style: const TextStyle(
              color: Colors.red,
            ),
          ),
        );
      }

      if (state is MeetingsLoaded) {
        final dealMeetings = state.meetings.where((meeting) {
          return meeting.dealId == _deal.id;
        }).toList();

        if (dealMeetings.isEmpty) {
          return const Center(
            child: Text(
              'No meetings for this deal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            16,
            16,
            16,
            90,
          ),
          itemCount: dealMeetings.length,
          itemBuilder: (context, index) {
            final meeting = dealMeetings[index];

            return MeetingCard(
              meeting: meeting,
              meetingsCubit: context.read<MeetingsCubit>(),
              onMeetingUpdated: (message) async {
                _showSnack(
                  context,
                  SnackBar(
                    content: Text(message),
                    backgroundColor: Colors.green,
                  ),
                );
              },
            );
          },
        );
      }

      return const Center(
        child: Text(
          'No meetings for this deal',
          style: TextStyle(
            color: AppColors.textSecondary,
          ),
        ),
      );
    },
  );
}

void _createMeetingForDeal() {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return CreateMeetingSheet(
        dealId: _deal.id,
        checkZoomConnection: () =>
            context.read<MeetingsCubit>().checkZoomConnection(),
        onSubmit: ({
          required title,
          required description,
          required startDateTime,
          required endDateTime,
          required attendees,
          required reminderMinutes,
          required provider,
        }) async {
          final success = await context
              .read<MeetingsCubit>()
              .createMeeting(
                title: title,
                description: description,
                dealId: _deal.id,
                startDateTime: startDateTime,
                endDateTime: endDateTime,
                attendees: attendees,
                reminderMinutes: reminderMinutes,
                provider: provider,
              );

          if (!mounted) return;

          if (success) {
            Navigator.pop(context);

            await context
                .read<MeetingsCubit>()
                .loadMeetings();

            if (!mounted) return;

            _showSnack(
              context,
              const SnackBar(
                content: Text('Meeting created successfully'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      );
    },
  );
}
}
