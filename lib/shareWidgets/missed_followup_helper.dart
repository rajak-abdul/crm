
import '../modals/modals.dart';

class MissedFollowupHelper {
  static List<Lead> getMissedFollowups({
    required List<Lead> leads,
    required String loggedInUserId,
  }) {
    final today = DateTime.now();

    final currentDate = DateTime(
      today.year,
      today.month,
      today.day,
    );

    return leads.where((lead) {
      if (lead.followUpDate == null) {
        return false;
      }

      final followupDate = DateTime(
        lead.followUpDate!.year,
        lead.followUpDate!.month,
        lead.followUpDate!.day,
      );

      return followupDate.isBefore(currentDate) &&
          lead.followUpNotes.isEmpty &&
          lead.status != "Converted" &&
          lead.status != "Rejected" &&
          lead.assignedToId == loggedInUserId;
    }).toList();
  }
}