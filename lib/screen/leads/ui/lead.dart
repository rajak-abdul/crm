import 'package:crm_app/screen/leads/cubit/lead_cubit.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

Future<void> showExportFollowUpsDialog(
  BuildContext context,
  LeadCubit cubit,
) async {
  DateTime? startDate;
  DateTime? endDate;

  final startController = TextEditingController();
  final endController = TextEditingController();
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
              initialDate:
                  (isStart ? startDate : endDate) ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime(2100),
            );

            if (picked == null) return;

            setState(() {
              if (isStart) {
                startDate = picked;
                startController.text =
                    DateFormat('MM/dd/yyyy').format(picked);
              } else {
                endDate = picked;
                endController.text =
                    DateFormat('MM/dd/yyyy').format(picked);
              }
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            child: SizedBox(
              width: 560,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    /// Header
                    Row(
                      children: [
                        const Icon(
                          Icons.download_outlined,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Export Follow-ups",
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        )
                      ],
                    ),

                    const SizedBox(height: 8),

                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Exports Lead, Company, Assign To, Follow-up Date and Follow-up History. Leave both dates blank to export all leads, or pick a start and end date to export leads whose follow-up date is in that range.",
                        style: TextStyle(
                          color: Colors.grey,
                          height: 1.5,
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),

                    Row(
                      children: [

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Start Date",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),

                              TextField(
                                controller: startController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  hintText: "mm/dd/yyyy",
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        pickDate(true),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 18),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "End Date",
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 8),

                              TextField(
                                controller: endController,
                                readOnly: true,
                                decoration: InputDecoration(
                                  hintText: "mm/dd/yyyy",
                                  suffixIcon: IconButton(
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                      size: 18,
                                    ),
                                    onPressed: () =>
                                        pickDate(false),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius:
                                        BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (dateError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            dateError!,
                            style: const TextStyle(
                                fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [

                        OutlinedButton(
                          onPressed: exporting
                              ? null
                              : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize:
                                const Size(100, 46),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text("Cancel"),
                        ),

                        const SizedBox(width: 12),

                        ElevatedButton.icon(
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
                                    ScaffoldMessenger.of(screenContext)
                                        .showSnackBar(SnackBar(
                                      content: Text(err ??
                                          'Follow-ups exported to Downloads'),
                                      backgroundColor:
                                          err != null ? Colors.red : null,
                                    ));
                                  }
                                },
                          icon: exporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.download),
                          label: Text(exporting ? "Exporting..." : "Export"),
                          style: ElevatedButton.styleFrom(
                            minimumSize:
                                const Size(120, 46),
                            backgroundColor:
                                const Color(0xff2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}