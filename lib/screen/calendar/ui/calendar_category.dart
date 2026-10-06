import 'package:flutter/material.dart';

/// Buckets a raw [CalendarEvent.type] string into one of the fixed
/// legend categories shown on the calendar (matches the desktop legend:
/// Tasks, Targets, Lead Follow-ups, Deal Follow-ups, Invoices, Proposals,
/// Meetings, Emails, My Notes).
enum CalendarCategory {
  task,
  target,
  leadFollowup,
  dealFollowup,
  invoice,
  proposal,
  meeting,
  email,
  note,
  other,
}

class CalendarCategoryInfo {
  final CalendarCategory category;
  final String label;
  final Color color;
  final IconData icon;

  const CalendarCategoryInfo({
    required this.category,
    required this.label,
    required this.color,
    required this.icon,
  });
}

const Map<CalendarCategory, CalendarCategoryInfo> kCalendarCategories = {
  CalendarCategory.task: CalendarCategoryInfo(
    category: CalendarCategory.task,
    label: 'Tasks',
    color: Color(0xFF6366F1),
    icon: Icons.check_circle_outline,
  ),
  CalendarCategory.target: CalendarCategoryInfo(
    category: CalendarCategory.target,
    label: 'Targets',
    color: Color(0xFF8B5CF6),
    icon: Icons.flag_outlined,
  ),
  CalendarCategory.leadFollowup: CalendarCategoryInfo(
    category: CalendarCategory.leadFollowup,
    label: 'Lead Follow-ups',
    color: Color(0xFFEF4444),
    icon: Icons.person_outline,
  ),
  CalendarCategory.dealFollowup: CalendarCategoryInfo(
    category: CalendarCategory.dealFollowup,
    label: 'Deal Follow-ups',
    color: Color(0xFFF59E0B),
    icon: Icons.handshake_outlined,
  ),
  CalendarCategory.invoice: CalendarCategoryInfo(
    category: CalendarCategory.invoice,
    label: 'Invoices',
    color: Color(0xFF0EA5E9),
    icon: Icons.receipt_long_outlined,
  ),
  CalendarCategory.proposal: CalendarCategoryInfo(
    category: CalendarCategory.proposal,
    label: 'Proposals',
    color: Color(0xFF10B981),
    icon: Icons.description_outlined,
  ),
  CalendarCategory.meeting: CalendarCategoryInfo(
    category: CalendarCategory.meeting,
    label: 'Meetings',
    color: Color(0xFFEC4899),
    icon: Icons.groups_outlined,
  ),
  CalendarCategory.email: CalendarCategoryInfo(
    category: CalendarCategory.email,
    label: 'Emails',
    color: Color(0xFF3B82F6),
    icon: Icons.mail_outline,
  ),
  CalendarCategory.note: CalendarCategoryInfo(
    category: CalendarCategory.note,
    label: 'My Notes',
    color: Color(0xFF14B8A6),
    icon: Icons.sticky_note_2_outlined,
  ),
  CalendarCategory.other: CalendarCategoryInfo(
    category: CalendarCategory.other,
    label: 'Other',
    color: Color(0xFF64748B),
    icon: Icons.event_note_outlined,
  ),
};

CalendarCategory categorizeEventType(String rawType) {
  final t = rawType.toLowerCase().replaceAll(RegExp(r'[\s_\-]'), '');

  if (t.contains('task')) return CalendarCategory.task;
  if (t.contains('target')) return CalendarCategory.target;
  if (t.contains('lead') && t.contains('follow')) {
    return CalendarCategory.leadFollowup;
  }
  // Deal follow-ups may arrive from the API as a bare "followup" type
  // (no "deal" prefix) rather than "deal_followup" — any follow-up that
  // isn't a lead follow-up is treated as a deal follow-up.
  if (t.contains('follow')) {
    return CalendarCategory.dealFollowup;
  }
  if (t.contains('invoice')) return CalendarCategory.invoice;
  if (t.contains('proposal')) return CalendarCategory.proposal;
  if (t.contains('meeting')) return CalendarCategory.meeting;
  if (t.contains('email')) return CalendarCategory.email;
  if (t.contains('note')) return CalendarCategory.note;

  return CalendarCategory.other;
}

CalendarCategoryInfo categoryInfoOf(String rawType) =>
    kCalendarCategories[categorizeEventType(rawType)]!;
