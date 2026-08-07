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

  await showDialog(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          Future<void> pickDate(bool isStart) async {
            final picked = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
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
                        "Exports Lead, Company, Assign To, Follow-up Date and Follow-up History for leads matching the current filters.",
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

                    const SizedBox(height: 32),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [

                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
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
                          onPressed: () async {
                            Navigator.pop(context);

                            await cubit.exportFollowUps(
                              startDate: startDate,
                              endDate: endDate,
                            );
                          },
                          icon: const Icon(Icons.download),
                          label: const Text("Export"),
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