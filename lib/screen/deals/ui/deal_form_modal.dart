// ══════════════════════════════════════════════════════════════
// DEAL FORM MODAL
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:io';

import 'package:crm_app/screen/deals/cubit/deals_cubit.dart';
import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/screen/deals/ui/deal_screen.dart';
import 'package:crm_app/screen/deals/ui/deals_shared_widget.dart';
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl_phone_field/countries.dart' show countries;
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:phone_numbers_parser/phone_numbers_parser.dart';

import '../../../modals/modals.dart' hide Attachment;

/// Caps [number] at the real maximum digit length for the country
/// identified by [isoCode] (e.g. 'IN', 'US'). Numbering plans commonly
/// allow a range of valid lengths (e.g. Malaysia runs 8-11 digits), so
/// only the upper bound is enforced — any shorter number is accepted.
/// Falls back to a flat 12-digit cap when the country can't be resolved.
String? validatePhoneForCountry(String number, String isoCode, String label) {
  final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.isEmpty) return '$label is required';

  final country = countries.where((c) => c.code == isoCode).firstOrNull;
  final maxLen = country?.maxLength ?? 12;

  if (digits.length > maxLen) {
    return '$label must not exceed $maxLen digits';
  }
  return null;
}

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
  /// and is sent back as `existingAttachments`/`existingImages` on save.
  final List<Attachment> _existingAttachments = [];
  final List<PlatformFile> _attachments = [];
  final List<Attachment> _existingImages = [];
  final List<XFile> _selectedImages = [];
  static const int _maxBytes = 5 * 1024 * 1024; // 5 MB

  final _city = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincode = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  final _customIndustry = TextEditingController();

  List<CustomField> _customFields = [];

  static const _sectionTitles = [
    'Deal Information',
    'Business Details',
    'Location',
    'Follow-up',
    'Management',
    'Attachments',
  ];
  late final Map<String, bool> _sectionExpanded;

  void _toggleSection(String title) {
    setState(() => _sectionExpanded[title] = !(_sectionExpanded[title] ?? false));
  }

  bool _saving = false;
  bool _fetching = false;
  String _tenantCurrency = 'USD';

double? _exchangeRate;
double? _convertedValue;

bool _loadingConversionRate = false;

final Map<String, double> _exchangeRateCache = {};

int _conversionRequestId = 0;
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

  String get _dealInfoSubtitle {
    final name = _name.text.trim();
    final amount = _value.text.trim();
    final symbol = _currency.split(' ').first;
    final parts = [
      if (name.isNotEmpty) name,
      if (amount.isNotEmpty) '$symbol$amount',
    ];
    return parts.isEmpty ? 'Name, value, company, phone' : parts.join(' · ');
  }

  String get _businessDetailsSubtitle {
    final industry = _industry == 'Other'
        ? (_customIndustry.text.trim().isEmpty
            ? 'Other'
            : _customIndustry.text.trim())
        : _industry;
    return '$industry · $_source · $_clientType';
  }

  String get _locationSubtitle {
    final city = _city.text.trim();
    final pincode = _pincode.text.trim();
    if (city.isEmpty && pincode.isEmpty) return 'Not set';
    return [city, pincode].where((s) => s.isNotEmpty).join(', ');
  }

  String get _followUpSubtitle {
    if (_followUpDate == null) return 'Not scheduled';
    final datePart = DateFormat('dd MMM').format(_followUpDate!);
    final timePart = _followUpTime?.format(context) ?? '';
    return timePart.isEmpty ? datePart : '$datePart, $timePart';
  }

  String get _managementSubtitle {
    final assignee =
        _assignTo ?? (widget.users.isNotEmpty ? widget.users.first : null);
    final name = assignee != null ? userName(assignee) : 'Unassigned';
    final hasNote = _notes.text.trim().isNotEmpty;
    return hasNote ? '$name · 1 note' : name;
  }

  String get _attachmentsSubtitle {
    final count = _attachmentSlotsUsed;
    return count == 0 ? 'None added' : '$count file${count == 1 ? '' : 's'}';
  }

      String _currencyCode(String value) {
  return value.split(' ').last.trim().toUpperCase();
}

Future<void> _loadConversionRate() async {
  final fromCurrency = _currencyCode(_currency);
  final toCurrency = _tenantCurrency.toUpperCase();

  if (fromCurrency.isEmpty || toCurrency.isEmpty) {
    return;
  }

  final requestId = ++_conversionRequestId;

  if (fromCurrency == toCurrency) {
    if (!mounted) return;

    setState(() {
      _exchangeRate = 1.0;
      _loadingConversionRate = false;
    });

    _updateConvertedValue();
    return;
  }

  final cacheKey = '$fromCurrency->$toCurrency';

  final cachedRate = _exchangeRateCache[cacheKey];

  if (cachedRate != null) {
    if (!mounted || requestId != _conversionRequestId) return;

    setState(() {
      _exchangeRate = cachedRate;
      _loadingConversionRate = false;
    });

    _updateConvertedValue();
    return;
  }

  if (mounted) {
    setState(() {
      _loadingConversionRate = true;
      _exchangeRate = null;
      _convertedValue = null;
    });
  }

  final rate = await context.read<DealsCubit>().getExchangeRate(
        fromCurrency: fromCurrency,
        toCurrency: toCurrency,
      );

  if (!mounted || requestId != _conversionRequestId) {
    return;
  }

  if (rate != null) {
    _exchangeRateCache[cacheKey] = rate;
  }

  setState(() {
    _exchangeRate = rate;
    _loadingConversionRate = false;
  });

  _updateConvertedValue();
}

void _onDealValueChanged() {
  _updateConvertedValue();
}

void _refreshSubtitles() {
  if (mounted) setState(() {});
}

void _updateConvertedValue() {
  final raw = _value.text.replaceAll(',', '').trim();

  final value = double.tryParse(raw);

  if (value == null || value <= 0 || _exchangeRate == null) {
    if (_convertedValue != null && mounted) {
      setState(() {
        _convertedValue = null;
      });
    }

    return;
  }

  final converted = value * _exchangeRate!;

  if (mounted) {
    setState(() {
      _convertedValue = converted;
    });
  }
}


      Future<void> _initializeCurrencyConversion() async {
  try {
    final cubit = context.read<DealsCubit>();

    final tenantCurrency = await cubit.getTenantCurrency();

    if (!mounted) return;

    setState(() {
      _tenantCurrency = tenantCurrency;
    });

    await _loadConversionRate();
  } catch (e) {
    debugPrint(
      '[DealModal] currency initialization error: $e',
    );
  }
}

@override
void initState() {
  super.initState();

  _sectionExpanded = {for (final t in _sectionTitles) t: _isEdit};

  _value.addListener(_onDealValueChanged);

  // Refresh the collapsed-section subtitles as their source fields
  // change — the conversion listener above only rebuilds when a
  // converted value is actually available, which misses the common
  // case of typing before the exchange rate has loaded.
  for (final c in [_name, _value, _city, _pincode, _notes, _customIndustry]) {
    c.addListener(_refreshSubtitles);
  }

  if (_isEdit) {
    _prefillAndFetch(widget.editDeal!);
  }

  _initializeCurrencyConversion();
}



  @override
void dispose() {
  _value.removeListener(_onDealValueChanged);
  for (final c in [_name, _value, _city, _pincode, _notes, _customIndustry]) {
    c.removeListener(_refreshSubtitles);
  }

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
    _followUpComment,
    _city,
    _stateCtrl,
    _pincode,
    _latitude,
    _longitude,
    _customIndustry,
  ]) {
    c.dispose();
  }

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

  String _extractLocalNumber(String rawPhone) {
    try {
      final cleaned = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = PhoneNumber.parse('+$cleaned');
      return parsed.nsn;
    } catch (e) {
      return rawPhone;
    }
  }

  String _getInitialCountryCode(String rawPhone) {
    try {
      final cleaned = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
      final parsed = PhoneNumber.parse('+$cleaned');
      return parsed.isoCode.name;
    } catch (e) {
      return 'IN';
    }
  }

  /// Builds the "+<dial> <ISO>" string (matching `_countryCode`'s own
  /// format) from a raw phone number, or null if it can't be parsed.
  String? _dialCodeIsoFor(String rawPhone) {
    try {
      final cleaned = rawPhone.replaceAll(RegExp(r'[^0-9]'), '');
      if (cleaned.isEmpty) return null;
      final parsed = PhoneNumber.parse('+$cleaned');
      return '+${parsed.countryCode} ${parsed.isoCode.name}';
    } catch (e) {
      return null;
    }
  }

  void _prefill(Deal d) {
    _name.text = d.name;
    _value.text =
        d.value == 0 ? '' : d.value.toStringAsFixed(d.value % 1 == 0 ? 0 : 2);
    _phone.text = _extractLocalNumber(d.phone);
    _altPhone.text = _extractLocalNumber(d.alternativeNumber);
    _email.text = d.email;
    _altEmail.text = d.alternativeEmail;
    _company.text = d.companyName;
    _address.text = d.address;
    _notes.text = d.notes;
    _followUpComment.text = d.followUpComment ?? '';
    _city.text = d.city;
    _stateCtrl.text = d.state;
    _pincode.text = d.pincode;
    _latitude.text = d.latitude?.toString() ?? '';
    _longitude.text = d.longitude?.toString() ?? '';
    _customFields = d.customFields
        .whereType<Map>()
        .map((m) => CustomField.fromJson(Map<String, dynamic>.from(m)))
        .toList();

    _currency = DealConstants.currencies.contains(d.currency)
        ? d.currency
        : DealConstants.currencies.first;
    _countryCode = _dialCodeIsoFor(d.phone) ??
        (DealConstants.countryCodes.contains(d.countryCode)
            ? d.countryCode
            : DealConstants.countryCodes.first);
    _altCountryCode = _dialCodeIsoFor(d.alternativeNumber) ?? _altCountryCode;
    _stage =
        DealConstants.stages.contains(DealConstants.canonicalStage(d.stage))
            ? DealConstants.canonicalStage(d.stage)
            : DealConstants.stages.first;
    final customIndustryValue =
        (d.industry.isNotEmpty && !DealConstants.industries.contains(d.industry))
            ? d.industry
            : '';
    _customIndustry.text = customIndustryValue;
    _industry = DealConstants.industries.contains(d.industry)
        ? d.industry
        : (customIndustryValue.isNotEmpty
            ? 'Other'
            : DealConstants.industries.first);
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

    _existingImages
      ..clear()
      ..addAll(d.images);

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

  Future<void> _pickDealImage() async {
    if (_existingImages.length + _selectedImages.length >= 5) {
      _snack('Maximum 5 images allowed');
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Upload Image',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.camera_alt_outlined),
                  ),
                  title: const Text('Camera'),
                  subtitle: const Text('Take a new photo'),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.photo_library_outlined),
                  ),
                  title: const Text('Gallery'),
                  subtitle: const Text('Choose from gallery'),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (source == null || !mounted) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 85);
    if (image == null || !mounted) return;

    setState(() => _selectedImages.add(image));
  }

  void _removeSelectedImage(int i) => setState(() => _selectedImages.removeAt(i));

  void _removeExistingImage(Attachment file) {
    setState(() => _existingImages.remove(file));
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _snack('Please enable location services');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          _snack('Location permission denied');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _snack('Location permission permanently denied. Enable it from Settings.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      _latitude.text = position.latitude.toString();
      _longitude.text = position.longitude.toString();

      final placemarks =
          await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        final place = placemarks.first;

        final addressParts = <String>[
          if ((place.street ?? '').trim().isNotEmpty) place.street!.trim(),
          if ((place.subLocality ?? '').trim().isNotEmpty)
            place.subLocality!.trim(),
        ];
        _address.text = addressParts.join(', ');

        _city.text =
            (place.locality ?? place.subAdministrativeArea ?? '').trim();
        _stateCtrl.text = (place.administrativeArea ?? '').trim();
        _pincode.text = (place.postalCode ?? '').trim();

        final countryName = (place.country ?? '').trim();
        if (countryName.isNotEmpty &&
            AppConstants.countries.contains(countryName)) {
          _country = countryName;
        }
      }

      if (!mounted) return;
      setState(() {});
      _showSheetSnack('Current location added',
          backgroundColor: AppColors.success);
    } catch (e) {
      debugPrint('Location error: $e');
      if (!mounted) return;
      _snack('Unable to get current location');
    }
  }

  Future<void> _openCreateCustomField(String cardTitle) async {
    final nameController = TextEditingController();
    String fieldType = 'text';
    final List<TextEditingController> optionControllers = [];

    final result = await showDialog<CustomField>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Create Custom Field"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Field Name"),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: fieldType,
                      decoration: const InputDecoration(
                        labelText: "Field Type",
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'text', child: Text("Text")),
                        DropdownMenuItem(value: 'number', child: Text("Number")),
                        DropdownMenuItem(value: 'date', child: Text("Date")),
                        DropdownMenuItem(
                            value: 'dropdown', child: Text("Dropdown")),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setDialogState(() {
                          fieldType = v;
                          if (fieldType != 'dropdown') {
                            for (final c in optionControllers) {
                              c.dispose();
                            }
                            optionControllers.clear();
                          }
                        });
                      },
                    ),
                    if (fieldType == 'dropdown') ...[
                      const SizedBox(height: 16),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Dropdown Options',
                            style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                      const SizedBox(height: 8),
                      ...List.generate(optionControllers.length, (index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: optionControllers[index],
                                  decoration: InputDecoration(
                                    labelText: 'Option ${index + 1}',
                                    border: const OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, color: Colors.red),
                                onPressed: () {
                                  setDialogState(() {
                                    final c = optionControllers.removeAt(index);
                                    c.dispose();
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                      OutlinedButton.icon(
                        onPressed: () {
                          setDialogState(() {
                            optionControllers.add(TextEditingController());
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Add Option'),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    final fieldName = nameController.text.trim();
                    if (fieldName.isEmpty) return;

                    final options = optionControllers
                        .map((c) => c.text.trim())
                        .where((v) => v.isNotEmpty)
                        .toList();

                    Navigator.pop(
                      dialogContext,
                      CustomField(
                        id: '',
                        cardTitle: cardTitle,
                        name: fieldName,
                        type: fieldType,
                        options: options,
                        value: fieldType == 'dropdown' && options.isNotEmpty
                            ? options.first
                            : '',
                      ),
                    );
                  },
                  child: const Text("Create"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() => _customFields.add(result));
    }
  }

  Widget _buildCustomField(CustomField field) {
    Widget fieldWidget;

    switch (field.type) {
      case 'text':
        fieldWidget = TextFormField(
          initialValue: field.value,
          decoration: InputDecoration(
            labelText: field.name,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => field.value = value,
        );
        break;

      case 'number':
        fieldWidget = TextFormField(
          initialValue: field.value,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: field.name,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => field.value = value,
        );
        break;

      case 'dropdown':
      case 'select':
        fieldWidget = DropdownButtonFormField<String>(
          value: field.options.contains(field.value) ? field.value : null,
          decoration: InputDecoration(
            labelText: field.name,
            border: const OutlineInputBorder(),
          ),
          items: field.options
              .map((option) =>
                  DropdownMenuItem<String>(value: option, child: Text(option)))
              .toList(),
          onChanged: (selectedValue) {
            if (selectedValue == null) return;
            field.value = selectedValue;
            setState(() {});
          },
        );
        break;

      case 'date':
        fieldWidget = InkWell(
          onTap: () async {
            DateTime initialDate = DateTime.now();
            if (field.value.isNotEmpty) {
              try {
                initialDate = DateTime.parse(field.value);
              } catch (_) {}
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initialDate,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (picked == null || !mounted) return;
            final formatted = DateFormat('yyyy-MM-dd').format(picked);
            setState(() => field.value = formatted);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: field.name,
              border: const OutlineInputBorder(),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(field.value.isEmpty ? 'Select date' : field.value),
          ),
        );
        break;

      default:
        fieldWidget = TextFormField(
          initialValue: field.value,
          decoration: InputDecoration(
            labelText: field.name,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) => field.value = value,
        );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: fieldWidget),
          const SizedBox(width: 4),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            icon: const Icon(Icons.close, size: 20, color: Colors.red),
            onPressed: () async {
              if (field.id.isNotEmpty) {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: const Text('Remove custom field?'),
                      content: Text('Remove "${field.name}" from this deal?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Remove'),
                        ),
                      ],
                    );
                  },
                );
                if (confirmed != true || !mounted) return;
              }
              setState(() => _customFields.remove(field));
            },
          ),
        ],
      ),
    );
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
    final phoneErr = validatePhoneForCountry(
        _phone.text, _countryCode.split(' ').last, 'Phone Number');
    if (phoneErr != null) {
      _snack(phoneErr);
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

    final followUpDateTime = _followUpDate == null
        ? null
        : DateTime(
            _followUpDate!.year,
            _followUpDate!.month,
            _followUpDate!.day,
            (_followUpTime ?? const TimeOfDay(hour: 9, minute: 0)).hour,
            (_followUpTime ?? const TimeOfDay(hour: 9, minute: 0)).minute,
          );

    final payload = <String, dynamic>{
      'dealName': _name.text.trim(),
      'companyName': _company.text.trim(),
      'phoneNumber': _phone.text.trim(),
      'email': _email.text.trim(),
      'alternativeNumber': _altPhone.text.trim(),
      'alternativeEmail': _altEmail.text.trim(),
      'stage': _stage,
      'industry':
          _industry == 'Other' ? _customIndustry.text.trim() : _industry,
      'source': _source,
      'clientType': _clientType,
      'country': _country,
      'address': _address.text.trim(),
      'city': _city.text.trim(),
      'state': _stateCtrl.text.trim(),
      'pincode': _pincode.text.trim(),
      if (_latitude.text.trim().isNotEmpty) 'latitude': _latitude.text.trim(),
      if (_longitude.text.trim().isNotEmpty)
        'longitude': _longitude.text.trim(),
      'notes': _notes.text.trim(),
      'currency': _currency.split(' ').last, // "₹ INR" → "INR"
      'countryCode': _countryCode,
      'dealValue':
          (double.tryParse(_value.text.replaceAll(',', '')) ?? 0).toString(),
      if (assignToId != null) 'assignTo': assignToId,
      if (followUpDateTime != null)
        'followUpDate': followUpDateTime.toUtc().toIso8601String(),
      'followUpComment': _followUpComment.text.trim(),
      // existing files kept on the deal — sent even empty on create,
      // matching the confirmed API contract.
      'existingAttachments': _existingAttachments
          .map((a) => a.path)
          .where((p) => p.isNotEmpty)
          .toList(),
      'existingImages': _existingImages
          .map((a) => a.path)
          .where((p) => p.isNotEmpty)
          .toList(),
      'customFields': jsonEncode(_customFields.map((f) {
        final data = <String, dynamic>{
          'cardTitle': f.cardTitle,
          'name': f.name,
          'type': f.type,
          'options': f.options,
          'value': f.value,
        };
        if (f.id.isNotEmpty) data['_id'] = f.id;
        return data;
      }).toList()),
    };

    if (_isEdit) {
      // ── EDIT FLOW ───────────────────────────────────────────
      if (!mounted) return;

      await cubit.updateDeal(
  widget.editDeal!.id,
  payload,
  attachments: _attachments,
  images: _selectedImages,
);
    } else {
      // ── CREATE FLOW ─────────────────────────────────────────
      // FIX: Attachments are sent INSIDE createDeal as multipart.
      // Do NOT call uploadAttachments again after create — that
      // would double-upload and may fail if the endpoint differs.
      await cubit.createDeal(payload, _attachments, images: _selectedImages);
    }

    if (!mounted) return;

    // Follow-up date/comment are sent directly in the payload above —
    // the backend applies them atomically with the create/update call,
    // so no separate schedule-followup request is needed here.
    await cubit.loadDeals();
  
    if (!mounted) return;
    setState(() => _saving = false);

    // Close the modal, returning the success message so the parent
    // screen can show it — a snackbar shown on this sheet's own
    // ScaffoldMessenger would be torn down the instant it's popped
    // and never actually become visible.
    if (mounted) {
      Navigator.pop(context,
          _isEdit ? 'Deal updated successfully' : 'Deal created successfully');
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
                              _collapsibleHeader(
                                  title: 'Deal Information',
                                  icon: Icons.info_outline,
                                  subtitle: _dealInfoSubtitle),
                              if (_sectionExpanded['Deal Information']!) ...[
                              const SizedBox(height: 14),
                              const FieldLabel('Deal Name', required: true),
                              const SizedBox(height: 6),
                              _tf(_name, 'e.g. Enterprise CRM Setup'),
                              const SizedBox(height: 16),

                              const FieldLabel('Deal Value', required: true),
                              const SizedBox(height: 6),
                              Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    CompactDrop(
      value: _currency,
      items: DealConstants.currencies,
      width: 110,
      onChanged: (v) async {
        setState(() {
          _currency = v;
          _convertedValue = null;
        });

        await _loadConversionRate();
      },
    ),

    const SizedBox(width: 10),

    Expanded(
      child: _tf(
        _value,
        '0.00',
        type: TextInputType.number,
      ),
    ),
  ],
),

if (_loadingConversionRate) ...[
  const SizedBox(height: 6),

  const Align(
    alignment: Alignment.centerLeft,
    child: Text(
      'Loading exchange rate...',
      style: TextStyle(
        fontSize: 11,
        color: AppColors.textSecondary,
      ),
    ),
  ),
],

if (_convertedValue != null &&
    _exchangeRate != null) ...[
  const SizedBox(height: 6),

  Align(
    alignment: Alignment.centerLeft,
    child: Text(
      '≈ ${_formatConvertedValue(
        _convertedValue!,
        _tenantCurrency,
      )}',
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    ),
  ),
],                              const SizedBox(height: 16),

                              const FieldLabel('Phone Number', required: true),
                              const SizedBox(height: 6),
                              Row(children: [
                                Expanded(
                                  child: IntlPhoneField(
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    controller: _phone,
                                    initialCountryCode: _getInitialCountryCode(
                                        widget.editDeal?.phone ?? ''),
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
                                    ],
                                    controller: _altPhone,
                                    initialCountryCode: _getInitialCountryCode(
                                        widget.editDeal?.alternativeNumber ??
                                            ''),
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
                              ..._customFields
                                  .where((f) => f.cardTitle == 'Deal Information')
                                  .map(_buildCustomField),
                              _addFieldButton('Deal Information'),
                              ], // Deal Information

                              _collapsibleHeader(
                                  title: 'Business Details',
                                  icon: Icons.business_outlined,
                                  subtitle: _businessDetailsSubtitle),
                              if (_sectionExpanded['Business Details']!) ...[
                              const SizedBox(height: 14),
                              const FieldLabel('Industry'),
                              const SizedBox(height: 6),
                              FullDrop(
                                  value: _industry,
                                  items: DealConstants.industries,
                                  icon: Icons.business_outlined,
                                  onChanged: (v) =>
                                      setState(() => _industry = v)),
                              if (_industry == 'Other') ...[
                                const SizedBox(height: 16),
                                const FieldLabel('Custom Industry'),
                                const SizedBox(height: 6),
                                _tf(_customIndustry, 'Enter custom industry'),
                              ],
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
                              ..._customFields
                                  .where((f) => f.cardTitle == 'Business Details')
                                  .map(_buildCustomField),
                              _addFieldButton('Business Details'),
                              ], // Business Details
                              const SizedBox(height: 24),

                              // ── § Location ─────────────────────────────────────
                              _collapsibleHeader(
                                  title: 'Location',
                                  icon: Icons.location_on_outlined,
                                  subtitle: _locationSubtitle),
                              if (_sectionExpanded['Location']!) ...[
                              const SizedBox(height: 14),

                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: _fetchCurrentLocation,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                        color: AppColors.primary),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 8),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: const Icon(Icons.my_location, size: 20),
                                  label: const Text(
                                    'Use Current Location',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),

                              const FieldLabel('Address'),
                              const SizedBox(height: 6),
                              _tf(_address, 'Enter address or use current location',
                                  maxLines: 2),
                              const SizedBox(height: 16),

                              Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const FieldLabel('City'),
                                      const SizedBox(height: 6),
                                      _tf(_city, 'Enter City'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const FieldLabel('State'),
                                      const SizedBox(height: 6),
                                      _tf(_stateCtrl, 'Enter State'),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),

                              Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const FieldLabel('Pincode'),
                                      const SizedBox(height: 6),
                                      _tf(_pincode, 'Enter Pincode'),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const FieldLabel('Country'),
                                      const SizedBox(height: 6),
                                      FullDrop(
                                          value: _country,
                                          items: AppConstants.countries,
                                          icon: Icons.public_outlined,
                                          onChanged: (v) =>
                                              setState(() => _country = v)),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),

                              Row(children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const FieldLabel('Latitude'),
                                      const SizedBox(height: 6),
                                      _tf(_latitude,
                                          'Auto-filled via current location, or enter manually',
                                          type: const TextInputType
                                              .numberWithOptions(
                                              decimal: true, signed: true)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const FieldLabel('Longitude'),
                                      const SizedBox(height: 6),
                                      _tf(_longitude,
                                          'Auto-filled via current location, or enter manually',
                                          type: const TextInputType
                                              .numberWithOptions(
                                              decimal: true, signed: true)),
                                    ],
                                  ),
                                ),
                              ]),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  const Text(
                                    'Images',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textSecondary),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: (_existingImages.length +
                                                _selectedImages.length) <
                                            5
                                        ? _pickDealImage
                                        : null,
                                    icon: const Icon(
                                        Icons.add_a_photo_outlined,
                                        size: 20),
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppColors.primaryLight,
                                      foregroundColor: AppColors.primary,
                                      padding: const EdgeInsets.all(6),
                                      minimumSize: Size.zero,
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              if (_existingImages.isNotEmpty ||
                                  _selectedImages.isNotEmpty)
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    ..._existingImages.map((img) => _ImageThumb(
                                        imageProvider:
                                            NetworkImage(_imageUrl(img.path)),
                                        onView: () =>
                                            _showImagePreview(NetworkImage(
                                                _imageUrl(img.path))),
                                        onRemove: () =>
                                            _removeExistingImage(img))),
                                    ..._selectedImages.asMap().entries.map(
                                        (e) => _ImageThumb(
                                            imageProvider:
                                                FileImage(File(e.value.path)),
                                            onView: () => _showImagePreview(
                                                FileImage(
                                                    File(e.value.path))),
                                            onRemove: () =>
                                                _removeSelectedImage(e.key))),
                                  ],
                                )
                              else
                                const Text(
                                  'No images uploaded',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                              ], // Location
                              const SizedBox(height: 24),

                              // ── § 2 Follow-up ─────────────────────────────────
                              _collapsibleHeader(
                                  title: 'Follow-up',
                                  icon: Icons.alarm_outlined,
                                  subtitle: _followUpSubtitle),
                              if (_sectionExpanded['Follow-up']!) ...[
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
                              const SizedBox(height: 16),
                              ..._customFields
                                  .where((f) => f.cardTitle == 'Follow-up')
                                  .map(_buildCustomField),
                              _addFieldButton('Follow-up'),
                              ], // Follow-up
                              const SizedBox(height: 24),

                              // ── § 3 Management ────────────────────────────────
                              _collapsibleHeader(
                                  title: 'Management',
                                  icon: Icons.tune_outlined,
                                  subtitle: _managementSubtitle),
                              if (_sectionExpanded['Management']!) ...[
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
                              const SizedBox(height: 16),
                              ..._customFields
                                  .where((f) => f.cardTitle == 'Management')
                                  .map(_buildCustomField),
                              _addFieldButton('Management'),
                              ], // Management
                              const SizedBox(height: 24),

                              // ── § 4 Attachments ───────────────────────────────
                              _collapsibleHeader(
                                  title: 'Attachments',
                                  icon: Icons.attach_file_rounded,
                                  subtitle: _attachmentsSubtitle),
                              if (_sectionExpanded['Attachments']!) ...[
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
                              ], // Attachments
                              const SizedBox(height: 24),

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

      String _formatConvertedValue(
  double value,
  String currency,
) {
  switch (currency.toUpperCase()) {
    case 'USD':
      return '\$${NumberFormat('#,##0.00').format(value)} USD';

    case 'EUR':
      return '€${NumberFormat('#,##0.00').format(value)} EUR';

    case 'INR':
      return '₹${NumberFormat('#,##0.00').format(value)} INR';

    case 'GBP':
      return '£${NumberFormat('#,##0.00').format(value)} GBP';

    case 'JPY':
      return '¥${NumberFormat('#,##0').format(value)} JPY';

    case 'AUD':
      return 'A\$${NumberFormat('#,##0.00').format(value)} AUD';

    case 'CAD':
      return 'C\$${NumberFormat('#,##0.00').format(value)} CAD';

    case 'CHF':
      return 'CHF ${NumberFormat('#,##0.00').format(value)}';

    case 'MYR':
      return 'RM ${NumberFormat('#,##0.00').format(value)} MYR';

    case 'AED':
      return 'د.إ ${NumberFormat('#,##0.00').format(value)} AED';

    case 'SGD':
      return 'S\$${NumberFormat('#,##0.00').format(value)} SGD';

    case 'ZAR':
      return 'R ${NumberFormat('#,##0.00').format(value)} ZAR';

    case 'SAR':
      return 'ر.س ${NumberFormat('#,##0.00').format(value)} SAR';

    default:
      return '$currency ${NumberFormat('#,##0.00').format(value)}';
  }
}

  Widget _addFieldButton(String cardTitle) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openCreateCustomField(cardTitle),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.add_circle_outline, size: 18),
            label: const Text(
              'Add Field',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      );

  Widget _collapsibleHeader({
    required String title,
    required IconData icon,
    String? subtitle,
  }) {
    final expanded = _sectionExpanded[title] ?? false;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, top: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => _toggleSection(title),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              expanded
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20,
              color: AppColors.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

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

  String _imageUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    final normalized = path.startsWith('/') ? path : '/$path';
    return 'https://crm-backend-api.techzarinfo.cloud$normalized';
  }

  void _showImagePreview(ImageProvider image) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(10),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Image(image: image, fit: BoxFit.contain),
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ImageThumb extends StatelessWidget {
  final ImageProvider imageProvider;
  final VoidCallback onView;
  final VoidCallback onRemove;

  const _ImageThumb({
    required this.imageProvider,
    required this.onView,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onView,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image(
                image: imageProvider,
                width: 90,
                height: 90,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Positioned(
            top: -7,
            right: -7,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 24,
                height: 24,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
}