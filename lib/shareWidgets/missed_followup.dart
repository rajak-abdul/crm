import 'package:crm_app/modals/modals.dart';
import 'package:crm_app/thems/app_themes.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class MissedFollowupDialog extends StatelessWidget {
  final List<Lead> missedLeads;
  final ValueChanged<Lead> onViewLead;

  const MissedFollowupDialog({
    super.key,
    required this.missedLeads,
    required this.onViewLead,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        width: 420,
        height: MediaQuery.of(context).size.height * .72,
        child: Column(
          children: [

            /// HEADER
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                ),
              ),
              child: Row(
                children: [

                  const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 28,
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      "Missed Follow-ups (${missedLeads.length})",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              child: Text(
                "The following follow-ups are overdue. "
                "Please update them as soon as possible.",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 13,
                ),
              ),
            ),

            const Divider(height: 1),

            /// LIST
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: missedLeads.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: 12),
                itemBuilder: (_, index) {
                  final lead = missedLeads[index];

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.border,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [

                        Row(
                          children: [

                            CircleAvatar(
                              radius: 18,
                              backgroundColor:
                                  Colors.orange.shade100,
                              child: Text(
                                lead.name.isEmpty
                                    ? "?"
                                    : lead.name[0]
                                        .toUpperCase(),
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),

                            const SizedBox(width: 10),

                            Expanded(
                              child: Text(
                                lead.name,
                                style:
                                    const TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                      FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        if (lead.companyName.isNotEmpty)
                          Row(
                            children: [

                              const Icon(
                                Icons.business,
                                size: 17,
                                color: Colors.grey,
                              ),

                              const SizedBox(width: 6),

                              Expanded(
                                child: Text(
                                  lead.companyName,
                                ),
                              ),
                            ],
                          ),

                        const SizedBox(height: 8),

                        Row(
                          children: [

                            const Icon(
                              Icons.calendar_today,
                              size: 17,
                              color: Colors.red,
                            ),

                            const SizedBox(width: 6),

                            Text(
                              lead.followUpDate == null
                                  ? "-"
                                  : DateFormat(
                                      "dd MMM yyyy",
                                    ).format(
                                      lead.followUpDate!,
                                    ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        Align(
                          alignment:
                              Alignment.centerRight,
                          child: TextButton.icon(
                            onPressed: () {

                              onViewLead(lead);
                            },
                            icon: const Icon(
                              Icons.visibility,
                            ),
                            label: const Text(
                              "View Lead",
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),

            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Dismiss"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}