import 'package:crm_app/screen/leads/cubit/lead_cubit.dart';
import 'package:crm_app/shareWidgets/share_widgets.dart' show showApiSnack;
import 'package:crm_app/thems/app_themes.dart' show AppColors;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Export Follow-ups — same layout as the Export Leads dialog: title row,
/// hint, then Start Date / End Date stacked full width, Cancel + Export.
Future<void> showExportFollowUpsDialog(
  BuildContext context,
  LeadCubit cubit,
) async {
  DateTime? startDate;
  DateTime? endDate;
  bool exporting = false;
  String? dateError;
  final screenContext = context;

  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickDate(bool isStart) async {
            final picked = await showDatePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
              initialDate: (isStart ? startDate : endDate) ?? DateTime.now(),
            );
            if (picked == null) return;
            setState(() {
              if (isStart) {
                startDate = picked;
              } else {
                endDate = picked;
              }
              dateError = null;
            });
          }

          Widget dateField(String label, DateTime? value, bool isStart) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                InkWell(
                  onTap: exporting ? null : () => pickDate(isStart),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(
                      value == null
                          ? "Select $label"
                          : DateFormat("dd/MM/yyyy").format(value),
                    ),
                  ),
                ),
              ],
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            title: Row(
              children: [
                const Icon(
                  Icons.download,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Export Follow-ups",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: exporting ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                )
              ],
            ),
            content: SizedBox(
              width: 330,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Exports Lead, Company, Assign To, Follow-up Date and Follow-up History. Leave both dates blank to export all leads, or pick a start and end date to export leads whose follow-up date is in that range.",
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 20),
                    dateField("Start Date", startDate, true),
                    const SizedBox(height: 18),
                    dateField("End Date", endDate, false),
                    if (dateError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          dateError!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              OutlinedButton(
                onPressed: exporting ? null : () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton.icon(
                icon: exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.download, color: Colors.white),
                label: Text(exporting ? "Exporting..." : "Export"),
                onPressed: exporting
                    ? null
                    : () async {
                        if ((startDate == null) != (endDate == null)) {
                          setState(() => dateError =
                              'Please select both start and end date');
                          return;
                        }
                        if (startDate != null &&
                            endDate != null &&
                            startDate!.isAfter(endDate!)) {
                          setState(() => dateError =
                              'Start date must be before end date');
                          return;
                        }
                        setState(() {
                          dateError = null;
                          exporting = true;
                        });
                        final err = await cubit.exportFollowUps(
                          startDate: startDate,
                          endDate: endDate,
                        );
                        if (!context.mounted) return;
                        Navigator.pop(context);
                        if (screenContext.mounted) {
                          showApiSnack(
                            screenContext,
                            err ?? 'Follow-ups exported to Downloads',
                            isError: err != null,
                          );
                        }
                      },
              )
            ],
          );
        },
      );
    },
  );
}
