import 'package:crm_app/screen/email/modal/scheduled_email_modal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void showEmailTimingDetails(
  BuildContext context,
  ScheduledEmail email,
) {
  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 24,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Timing Details',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Delivery and schedule records',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF667085),
                          ),
                        ),
                      ],
                    ),
                  ),

                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const Divider(),

              const SizedBox(height: 12),

              _compactTimingCard(
                icon: Icons.calendar_today_outlined,
                title: 'CREATED DATE',
                date: formatEmailDate(email.createdAt),
              ),

              const SizedBox(height: 10),

              _compactTimingCard(
                icon: Icons.access_time_outlined,
                title: 'SENT DATE',
                date: formatEmailDate(email.updatedAt),
                isSent: true,
                status: 'Delivered',
              ),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF101828),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _compactTimingCard({
  required IconData icon,
  required String title,
  required String date,
  bool isSent = false,
  String? status,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(
      horizontal: 12,
      vertical: 12,
    ),
    decoration: BoxDecoration(
      color: const Color(0xFFFCFCFD),
      border: Border.all(
        color: const Color(0xFFE1E7EF),
      ),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: isSent
                ? const Color(0xFFECFDF3)
                : const Color(0xFFF0F2FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            size: 22,
            color: isSent
                ? const Color(0xFF039855)
                : const Color(0xFF5946D2),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                  color: Color(0xFF98A2B3),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF101828),
                ),
              ),
            ],
          ),
        ),

        if (status != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 5,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF039855),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

String formatEmailDate(DateTime? dateTime) {
  if (dateTime == null) return '-';

  return DateFormat(
    'MMM d, yyyy, h:mm a',
  ).format(dateTime.toLocal());
}