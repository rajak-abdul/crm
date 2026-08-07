// ══════════════════════════════════════════════════════════════
// DEAL FORM MODAL
// ══════════════════════════════════════════════════════════════
import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/screen/deals/ui/deal_screen.dart';
import 'package:crm_app/screen/deals/ui/deals_shared_widget.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/intl_phone_field.dart';

import '../../../modals/modals.dart' hide Attachment;

class DealFormModal extends StatefulWidget {
  final List<String> users;
  final Deal? editDeal;
  const DealFormModal({required this.users, this.editDeal});
  @override
  State<DealFormModal> createState() => DealFormModalState();
}

class DealFormModalState extends State<DealFormModal> {
  final _name = TextEditingController();
  final _value = TextEditingController();
  final _phone = TextEditingController();
  final _altPhone = TextEditingController();
  final _email = TextEditingController();
  final _altEmail = TextEditingController();
  final _company = TextEditingController();
  final _address = TextEditingController();
  final _notes = TextEditingController();
  final _followUpComment = TextEditingController();

  String _currency = '₹ INR';
  String _countryCode = '+91 IN';
  String _altCountryCode = '+91 IN';
  String _stage = 'Qualification';
  String _industry = 'IT';
  String _source = 'Website';
  String _clientType = 'B2B';
  String _country = 'India';
  String? _assignTo;

  DateTime? _followUpDate;
  TimeOfDay? _followUpTime;

  /// Server-side files already on the deal (edit only); × removes from list
  /// and `retainedAttachmentPaths` on save.
  final List<Attachment> _existingAttachments = [];
  final List<PlatformFile> _attachments = [];
  static const int _maxBytes = 5 * 1024 * 1024; // 5 MB

  bool _saving = false;
  bool _fetching = false;
  final GlobalKey<ScaffoldMessengerState> _sheetMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  bool get _isEdit => widget.editDeal != null;

  ScaffoldMessengerState? _sheetMessenger() =>
      _sheetMessengerKey.currentState ?? ScaffoldMessenger.maybeOf(context);

  void _showSheetSnack(
    String message, {
    Color? backgroundColor,
  }) {
    final messenger = _sheetMessenger();
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: backgroundColor,
      ),
    );
  }

  int get _attachmentSlotsUsed =>
      _existingAttachments.length + _attachments.length;

  @override
  void initState() {
    super.initState();
    if (_isEdit) _prefillAndFetch(widget.editDeal!);
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _value,
      _phone,
      _altPhone,
      _email,
      _altEmail,
      _company,
      _address,
      _notes,
      _followUpComment
    ]) c.dispose();
    super.dispose();
  }

  Future<void> _prefillAndFetch(Deal cached) async {
    _prefill(cached);
    setState(() => _fetching = true);
    try {
      final fresh = await context.read<DealsCubit>().getDealById(cached.id);
      if (mounted && fresh != null) _prefill(fresh);
    } finally {
      if (mounted) setState(() => _fetching = false);
    }
  }

  void _prefill(Deal d) {
    _name.text = d.name;
    _value.text =
        d.value == 0 ? '' : d.value.toStringAsFixed(d.value % 1 == 0 ? 0 : 2);
    _phone.text = d.phone;
    _altPhone.text = d.alternativeNumber;
    _email.text = d.email;
    _altEmail.text = d.alternativeEmail;
    _company.text = d.companyName;
    _address.text = d.address;
    _notes.text = d.notes;
    _followUpComment.text = d.followUpComment ?? '';

    _currency = DealConstants.currencies.contains(d.currency)
        ? d.currency
        : DealConstants.currencies.first;
    _countryCode = DealConstants.countryCodes.contains(d.countryCode)
        ? d.countryCode
        : DealConstants.countryCodes.first;
    _stage =
        DealConstants.stages.contains(DealConstants.canonicalStage(d.stage))
            ? DealConstants.canonicalStage(d.stage)
            : DealConstants.stages.first;
    _industry = DealConstants.industries.contains(d.industry)
        ? d.industry
        : DealConstants.industries.first;
    _source = AppConstants.leadSources.contains(d.source)
        ? d.source
        : AppConstants.leadSources.first;
    _clientType =
        (d.clientType == 'B2B' || d.clientType == 'B2C') ? d.clientType : 'B2B';
    _country = AppConstants.countries.contains(d.country)
        ? d.country
        : AppConstants.countries.first;

    if (d.assignTo.isNotEmpty) {
      _assignTo = widget.users
          .where((u) =>
              userName(u).trim().toLowerCase() ==
              d.assignTo.trim().toLowerCase())
          .firstOrNull;
    }
    if (d.followUpDate != null && d.followUpDate!.isNotEmpty) {
      final dt = DateTime.tryParse(d.followUpDate!);
      if (dt != null) {
        final local = dt.isUtc ? dt.toLocal() : dt;
        _followUpDate = local;
        _followUpTime = TimeOfDay(hour: local.hour, minute: local.minute);
      }
    }

    _existingAttachments
      ..clear()
      ..addAll(d.attachments);

    if (mounted) setState(() {});
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year, now.month, now.day);
    final maxDate = firstDate.add(const Duration(days: 365 * 2));
    final current = _followUpDate ?? firstDate;
    final safeInitialDate = current.isBefore(firstDate) ? firstDate : current;

    final d = await showDatePicker(
        context: context,
        initialDate: safeInitialDate,
        firstDate: firstDate,
        lastDate: maxDate);
    if (d != null && mounted) setState(() => _followUpDate = d);
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(
        context: context, initialTime: _followUpTime ?? TimeOfDay.now());
    if (t != null && mounted) setState(() => _followUpTime = t);
  }

  Future<void> _pickFiles() async {
    if (_attachmentSlotsUsed >= 5) {
      _snack('Maximum 5 files allowed');
      return;
    }
    final result = await FilePicker.platform
        .pickFiles(allowMultiple: true, withData: true, type: FileType.any);
    if (result == null) return;
    final toAdd = <PlatformFile>[];
    for (final f in result.files) {
      if (_attachmentSlotsUsed + toAdd.length >= 5) {
        _snack('Maximum 5 files allowed');
        break;
      }
      if (f.size > _maxBytes) {
        _snack('${f.name} exceeds 5 MB');
        continue;
      }
      if (_existingAttachments.any((a) => a.name == f.name) ||
          _attachments.any((a) => a.name == f.name)) {
        continue;
      }
      toAdd.add(f);
    }
    if (toAdd.isNotEmpty && mounted) setState(() => _attachments.addAll(toAdd));
  }

  void _removeAttachment(int i) => setState(() => _attachments.removeAt(i));

  void _removeExistingAttachment(Attachment file) {
    setState(() => _existingAttachments.remove(file));
  }

  // ── SAVE ─────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('Deal Name is required');
      return;
    }
    if (_value.text.trim().isEmpty) {
      _snack('Deal Value is required');
      return;
    }
    final phoneDigits = _phone.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    if (phoneDigits.isEmpty) {
      _snack('Phone Number is required');
      return;
    }

    if (phoneDigits.length > 12) {
      _snack('Phone Number must not exceed 12 digits');
      return;
    }
    if (_email.text.trim().isEmpty) {
      _snack('Email is required');
      return;
    }
    if (_company.text.trim().isEmpty) {
      _snack('Company Name is required');
      return;
    }

    setState(() => _saving = true);
    final cubit = context.read<DealsCubit>();

    final selectedUser =
        _assignTo ?? (widget.users.isNotEmpty ? widget.users.first : null);
    final assignToId = (selectedUser != null && selectedUser.isNotEmpty)
        ? userId(selectedUser)
        : null;

    final payload = <String, dynamic>{
      'dealName': _name.text.trim(),
      'companyName': _company.text.trim(),
      'phoneNumber': _phone.text.trim(),
      'email': _email.text.trim(),
      'alternativeNumber': _altPhone.text.trim(),
      'alternativeEmail': _altEmail.text.trim(),
      'stage': _stage,
      'industry': _industry,
      'source': _source,
      'clientType': _clientType,
      'country': _country,
      'address': _address.text.trim(),
      'notes': _notes.text.trim(),
      'currency': _currency.split(' ').last, // "₹ INR" → "INR"
      'countryCode': _countryCode,
      'dealValue':
          (double.tryParse(_value.text.replaceAll(',', '')) ?? 0).toString(),
      if (assignToId != null) 'assignTo': assignToId,
    };

    String? dealId;

    if (_isEdit) {
      // ── EDIT FLOW ───────────────────────────────────────────
      // Keep/remove server files (same idea as lead update).
      payload['retainedAttachmentPaths'] = _existingAttachments
          .map((a) => a.path)
          .where((p) => p.isNotEmpty)
          .toList();

      
      dealId = widget.editDeal!.id;

      if (!mounted) return;

      await cubit.updateDeal(
  widget.editDeal!.id,
  payload,
  attachments: _attachments,
);
    } else {
      // ── CREATE FLOW ─────────────────────────────────────────
      // FIX: Attachments are sent INSIDE createDeal as multipart.
      // Do NOT call uploadAttachments again after create — that
      // would double-upload and may fail if the endpoint differs.
      dealId = await cubit.createDeal(payload, _attachments);
    }

    if (!mounted) return;

    // ── Schedule follow-up (both create + edit) ───────────────
    if (_followUpDate != null && dealId != null) {
  final tod = _followUpTime ?? const TimeOfDay(hour: 9, minute: 0);

  final dt = DateTime(
    _followUpDate!.year,
    _followUpDate!.month,
    _followUpDate!.day,
    tod.hour,
    tod.minute,
  );

  final ok = await cubit.scheduleFollowUp(
    dealId,
    followUpDate: dt,
    comment: _followUpComment.text,
  );

  if (!ok && mounted) {
    _showSheetSnack(
      'Deal saved — follow-up scheduling failed',
      backgroundColor: AppColors.warning,
    );
  }
}
    await cubit.loadDeals();
  
    if (!mounted) return;
    setState(() => _saving = false);

    // Show success snack and close modal
    if (mounted) {
      _showSheetSnack(
        _isEdit ? 'Deal updated successfully' : 'Deal created successfully',
        backgroundColor: AppColors.success,
      );
      Navigator.pop(context);
    }
  }

  void _snack(String msg) =>
      _showSheetSnack(msg, backgroundColor: AppColors.danger);

  // ── BUILD ─────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => ScaffoldMessenger(
        key: _sheetMessengerKey,
        child: Scaffold(
          backgroundColor: AppColors.background,
          body: DraggableScrollableSheet(
              initialChildSize: 0.96,
              maxChildSize: 0.98,
              minChildSize: 0.5,
              builder: (_, ctrl) => Container(
                  decoration: const BoxDecoration(
                      color: AppColors.background,
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24))),
                  child: Padding(
                      padding: EdgeInsets.zero,
                      child: Column(children: [
                        Container(
                            margin: const EdgeInsets.only(top: 10),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: AppColors.border,
                                borderRadius: BorderRadius.circular(2))),
                        Container(
                            color: AppColors.surface,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            child: Row(children: [
                              Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                      color: _isEdit
                                          ? AppColors.warningLight
                                          : AppColors.primaryLight,
                                      borderRadius: BorderRadius.circular(10)),
                                  child: Icon(
                                      _isEdit
                                          ? Icons.edit_outlined
                                          : Icons.handshake_outlined,
                                      color: _isEdit
                                          ? AppColors.warning
                                          : AppColors.primary,
                                      size: 20)),
                              const SizedBox(width: 12),
                              Expanded(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(
                                        _isEdit
                                            ? 'Edit Deal'
                                            : 'Create New Deal',
                                        style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.w800,
                                            color: AppColors.textPrimary)),
                                    Text(
                                        _isEdit
                                            ? 'Update deal details below'
                                            : 'Fill in deal details below',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary)),
                                  ])),
                              if (_fetching)
                                const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary)),
                              const SizedBox(width: 8),
                              IconButton(
                                  onPressed: _saving
                                      ? null
                                      : () => Navigator.pop(context),
                                  icon: const Icon(Icons.close),
                                  style: IconButton.styleFrom(
                                      backgroundColor: AppColors.divider,
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8)))),
                            ])),
                        const Divider(height: 1, color: AppColors.divider),
                        Expanded(
                            child: ListView(
                                controller: ctrl,
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: EdgeInsets.fromLTRB(
                                  18,
                                  18,
                                  18,
                                  18 + MediaQuery.of(context).viewInsets.bottom,
                                ),
                                children: [
                              // ── § 1 Deal Information ──────────────────────────
                              const SecHeader(
                                  title: 'Deal Information',
                                  icon: Icons.info_outline),
                              const SizedBox(height: 14),
                              const FieldLabel('Deal Name', required: true),
                              const SizedBox(height: 6),
                              _tf(_name, 'e.g. Enterprise CRM Setup'),
                              const SizedBox(height: 16),

                              const FieldLabel('Deal Value', required: true),
                              const SizedBox(height: 6),
                              Row(children: [
                                CompactDrop(
                                    value: _currency,
                                    items: DealConstants.currencies,
                                    width: 110,
                                    onChanged: (v) =>
                                        setState(() => _currency = v)),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: _tf(_value, '0.00',
                                        type: TextInputType.number)),
                              ]),
                              const SizedBox(height: 16),

                              const FieldLabel('Phone Number', required: true),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(
                                  child: IntlPhoneField(
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(12),
                                    ],
                                    controller: _phone,
                                    initialCountryCode: 'IN',
                                    disableLengthCheck: true,
                                    decoration: const InputDecoration(
                                      hintText: '9876543210',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (phone) {
                                      _phone.text = phone.number;
                                      _countryCode =
                                          '${phone.countryCode} ${phone.countryISOCode}';
                                    },
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),

                              const FieldLabel('Alternative Number'),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(
                                  child: IntlPhoneField(
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(12),
                                    ],
                                    controller: _altPhone,
                                    initialCountryCode: 'IN',
                                    disableLengthCheck: true,
                                    decoration: const InputDecoration(
                                      hintText: '9876543210',
                                      border: OutlineInputBorder(),
                                    ),
                                    onChanged: (phone) {
                                      _altPhone.text = phone.number;
                                      _altCountryCode =
                                          '${phone.countryCode} ${phone.countryISOCode}';
                                    },
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),

                              const FieldLabel('Email', required: true),
                              const SizedBox(height: 6),
                              _tf(_email, 'deal@company.com',
                                  type: TextInputType.emailAddress),
                              const SizedBox(height: 16),

                              const FieldLabel('Alternative Email'),
                              const SizedBox(height: 6),
                              _tf(_altEmail, 'alt@example.com',
                                  type: TextInputType.emailAddress),
                              const SizedBox(height: 16),

                              const FieldLabel('Stage'),
                              const SizedBox(height: 6),
                              FullDrop(
                                  value: _stage,
                                  items: DealConstants.stages,
                                  icon: Icons.flag_outlined,
                                  onChanged: (v) => setState(() => _stage = v)),
                              const SizedBox(height: 16),

                              const FieldLabel('Company Name', required: true),
                              const SizedBox(height: 6),
                              _tf(_company, 'Organisation name'),
                              const SizedBox(height: 16),

                              const SecHeader(
                                  title: 'Business Details',
                                  icon: Icons.business_outlined),
                              const SizedBox(height: 14),
                              const FieldLabel('Industry'),
                              const SizedBox(height: 6),
                              FullDrop(
                                  value: _industry,
                                  items: DealConstants.industries,
                                  icon: Icons.business_outlined,
                                  onChanged: (v) =>
                                      setState(() => _industry = v)),
                              const SizedBox(height: 16),

                              const FieldLabel('Source'),
                              const SizedBox(height: 6),
                              FullDrop(
                                  value: _source,
                                  items: AppConstants.leadSources,
                                  icon: Icons.radar_outlined,
                                  onChanged: (v) =>
                                      setState(() => _source = v)),
                              const SizedBox(height: 16),
                              const FieldLabel('Client Type'),
                              const SizedBox(height: 6),
                              FullDrop(
                                  value: _clientType,
                                  items: const ['B2B', 'B2C'],
                                  icon: Icons.corporate_fare_outlined,
                                  onChanged: (v) =>
                                      setState(() => _clientType = v)),
                              const SizedBox(height: 16),

                              const FieldLabel('Address'),
                              const SizedBox(height: 6),
                              _tf(_address, 'Street, City, Zip', maxLines: 2),
                              const SizedBox(height: 16),

                              const FieldLabel('Country'),
                              const SizedBox(height: 6),
                              FullDrop(
                                  value: _country,
                                  items: AppConstants.countries,
                                  icon: Icons.public_outlined,
                                  onChanged: (v) =>
                                      setState(() => _country = v)),
                              const SizedBox(height: 24),

                              // ── § 2 Follow-up ─────────────────────────────────
                              const SecHeader(
                                  title: 'Follow-up',
                                  icon: Icons.alarm_outlined),
                              const SizedBox(height: 14),

                              Row(children: [
                                Expanded(
                                    child: GestureDetector(
                                        onTap: _pickDate,
                                        child: _pickerBox(
                                            icon: Icons.calendar_today_outlined,
                                            label: _followUpDate != null
                                                ? DateFormat('dd MMM yyyy')
                                                    .format(_followUpDate!)
                                                : 'Select date',
                                            active: _followUpDate != null))),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: GestureDetector(
                                        onTap: _pickTime,
                                        child: _pickerBox(
                                            icon: Icons.access_time_outlined,
                                            label: _followUpTime != null
                                                ? _followUpTime!.format(context)
                                                : 'Select time',
                                            active: _followUpTime != null))),
                              ]),

                              if (_followUpDate == null &&
                                  _followUpTime == null)
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Row(children: [
                                      const Icon(Icons.info_outline,
                                          size: 13, color: AppColors.textHint),
                                      const SizedBox(width: 6),
                                      Expanded(
                                          child: Text(
                                              'Optional: Set a reminder for follow-up',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.textHint
                                                      .withOpacity(0.8)))),
                                    ]))
                              else
                                Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: GestureDetector(
                                        onTap: () => setState(() {
                                              _followUpDate = null;
                                              _followUpTime = null;
                                            }),
                                        child: const Row(children: [
                                          Icon(Icons.close_rounded,
                                              size: 13,
                                              color: AppColors.danger),
                                          SizedBox(width: 4),
                                          Text('Clear follow-up',
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.danger)),
                                        ]))),

                              const SizedBox(height: 16),
                              const FieldLabel('Follow-up Comment'),
                              const SizedBox(height: 6),
                              _tf(_followUpComment,
                                  'Add a note about this follow-up…',
                                  maxLines: 3),
                              const SizedBox(height: 24),

                              // ── § 3 Management ────────────────────────────────
                              const SecHeader(
                                  title: 'Management',
                                  icon: Icons.tune_outlined),
                              const SizedBox(height: 14),

                              const FieldLabel('Assign To'),
                              const SizedBox(height: 6),
                              widget.users.isEmpty
                                  ? Container(
                                      height: 48,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14),
                                      decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppColors.border)),
                                      alignment: Alignment.centerLeft,
                                      child: const Text('No users available',
                                          style: TextStyle(
                                              fontSize: 14,
                                              color: AppColors.textHint)))
                                  : FullDrop(
                                      value: _assignTo ?? widget.users.first,
                                      items: widget.users,
                                      icon: Icons.person_outline,
                                      labelBuilder: userName,
                                      onChanged: (v) =>
                                          setState(() => _assignTo = v)),
                              const SizedBox(height: 16),

                              const FieldLabel('Notes'),
                              const SizedBox(height: 6),
                              _tf(_notes, 'Any additional context…',
                                  maxLines: 4),
                              const SizedBox(height: 24),

                              // ── § 4 Attachments ───────────────────────────────
                              const SecHeader(
                                  title: 'Attachments',
                                  icon: Icons.attach_file_rounded),
                              const SizedBox(height: 14),

                              GestureDetector(
                                  onTap: _attachmentSlotsUsed < 5
                                      ? _pickFiles
                                      : null,
                                  child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18),
                                      decoration: BoxDecoration(
                                          color: AppColors.surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: _attachmentSlotsUsed < 5
                                                  ? AppColors.primary
                                                      .withOpacity(0.4)
                                                  : AppColors.border)),
                                      child: Column(children: [
                                        Icon(Icons.cloud_upload_outlined,
                                            size: 32,
                                            color: _attachmentSlotsUsed < 5
                                                ? AppColors.primary
                                                : AppColors.textHint),
                                        const SizedBox(height: 8),
                                        Text(
                                            _attachmentSlotsUsed < 5
                                                ? 'Tap to upload files'
                                                : 'Maximum 5 files reached',
                                            style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: _attachmentSlotsUsed < 5
                                                    ? AppColors.primary
                                                    : AppColors.textHint)),
                                        const SizedBox(height: 4),
                                        const Text(
                                            'Any file type · Max 5 MB per file · Up to 5 files',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textHint)),
                                      ]))),
                              const SizedBox(height: 12),

                              if (_isEdit &&
                                  _existingAttachments.isNotEmpty) ...[
                                const Text(
                                  'Current attachments',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ..._existingAttachments.map((file) => Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: AppColors.surface,
                                        borderRadius: BorderRadius.circular(10),
                                        border:
                                            Border.all(color: AppColors.border),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryLight,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Icon(
                                              fileIcon(file.name),
                                              size: 16,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  file.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600,
                                                    color:
                                                        AppColors.textPrimary,
                                                  ),
                                                ),
                                                Text(
                                                  fileSize(file.size),
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () =>
                                                _removeExistingAttachment(file),
                                            child: Container(
                                              padding: const EdgeInsets.all(4),
                                              decoration: BoxDecoration(
                                                color: AppColors.dangerLight,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Icon(
                                                Icons.close_rounded,
                                                size: 14,
                                                color: AppColors.danger,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                const SizedBox(height: 8),
                              ],

                              if (_attachments.isNotEmpty) ...[
                                if (_isEdit)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Text(
                                      'New attachments',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ),
                                ..._attachments.asMap().entries.map((e) =>
                                    Container(
                                        margin:
                                            const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                            color: AppColors.surface,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                                color: AppColors.border)),
                                        child: Row(children: [
                                          Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                  color: AppColors.primaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(8)),
                                              child: Icon(
                                                  fileIcon(e.value.name),
                                                  size: 16,
                                                  color: AppColors.primary)),
                                          const SizedBox(width: 10),
                                          Expanded(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(e.value.name,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: AppColors
                                                            .textPrimary)),
                                                Text(fileSize(e.value.size),
                                                    style: const TextStyle(
                                                        fontSize: 11,
                                                        color: AppColors
                                                            .textSecondary)),
                                              ])),
                                          GestureDetector(
                                              onTap: () =>
                                                  _removeAttachment(e.key),
                                              child: Container(
                                                  padding:
                                                      const EdgeInsets.all(4),
                                                  decoration: BoxDecoration(
                                                      color:
                                                          AppColors.dangerLight,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              6)),
                                                  child: const Icon(
                                                      Icons.close_rounded,
                                                      size: 14,
                                                      color:
                                                          AppColors.danger))),
                                        ]))),
                              ],

                              const SizedBox(height: 28),

                              Row(children: [
                                Expanded(
                                    child: OutlinedButton(
                                        onPressed: _saving
                                            ? null
                                            : () => Navigator.pop(context),
                                        child: const Text('Cancel'))),
                                const SizedBox(width: 14),
                                Expanded(
                                    child: ElevatedButton.icon(
                                        onPressed: (_saving || _fetching)
                                            ? null
                                            : _save,
                                        style: _isEdit
                                            ? ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    AppColors.warning)
                                            : null,
                                        icon: _saving
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : Icon(
                                                _isEdit
                                                    ? Icons.check_outlined
                                                    : Icons.save_outlined,
                                                size: 16),
                                        label: Text(_saving
                                            ? (_isEdit
                                                ? 'Updating…'
                                                : 'Saving…')
                                            : (_isEdit
                                                ? 'Update Deal'
                                                : 'Save Deal')))),
                              ]),
                              const SizedBox(height: 24),
                            ])),
                      ])))),
        ),
      );

  Widget _pickerBox(
          {required IconData icon,
          required String label,
          required bool active}) =>
      Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
              color: active ? AppColors.primaryLight : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: active ? AppColors.primary : AppColors.border)),
          child: Row(children: [
            Icon(icon,
                size: 16,
                color: active ? AppColors.primary : AppColors.textHint),
            const SizedBox(width: 8),
            Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 13,
                        color:
                            active ? AppColors.primary : AppColors.textHint))),
          ]));

  Widget _tf(TextEditingController c, String hint,
          {TextInputType type = TextInputType.text, int maxLines = 1}) =>
      TextField(
          controller: c,
          keyboardType: type,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
          decoration: InputDecoration(
              hintText: hint,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: 14, vertical: maxLines > 1 ? 14 : 13),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5))));
}