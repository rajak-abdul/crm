// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/presentation/widgets/hub_styles.dart ║
// ║  STYLES — colours and label mappings for file type, source    ║
// ║  and status, shared by the hub widgets.                       ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';
import 'package:flutter/material.dart';

class HubPalette {
  static const background = Color(0xFFF5F7FB);
  static const ink = Color(0xFF0F172A);
  static const muted = Color(0xFF64748B);
  static const hint = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);
  static const track = Color(0xFFEDF1F7);
  static const accent = Color(0xFF2563EB);
  static const accentBg = Color(0xFFDBEAFE);
}

/// (background, foreground) pair for a pill or badge.
typedef HubTone = (Color, Color);

/// Short label for the file badge: PDF, DOC, XLSX, PPT, JPG …
String fileBadgeLabel(HubDocument d) {
  const aliases = {
    'docx': 'DOC',
    'pptx': 'PPT',
    'jpeg': 'JPG',
  };
  final ext = d.extension;
  if (ext.isEmpty) return 'FILE';
  return aliases[ext] ?? ext.toUpperCase();
}

HubTone fileBadgeTone(HubDocument d) {
  switch (d.extension) {
    case 'pdf':
      return (const Color(0xFFFDECEC), const Color(0xFFDC2626));
    case 'xls':
    case 'xlsx':
    case 'csv':
      return (const Color(0xFFE7F6EE), const Color(0xFF15803D));
    case 'doc':
    case 'docx':
      return (const Color(0xFFE8F0FE), const Color(0xFF1D4ED8));
    case 'ppt':
    case 'pptx':
      return (const Color(0xFFFFF1E6), const Color(0xFFC2410C));
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
      return (const Color(0xFFE6F6FA), const Color(0xFF0E7490));
    default:
      return (const Color(0xFFEFF2F7), const Color(0xFF475569));
  }
}

/// Human file type for the detail sheet: "Excel spreadsheet", "PDF document" …
String fileTypeLabel(HubDocument d) {
  switch (d.extension) {
    case 'pdf':
      return 'PDF document';
    case 'xls':
    case 'xlsx':
      return 'Excel spreadsheet';
    case 'csv':
      return 'CSV file';
    case 'doc':
    case 'docx':
      return 'Word document';
    case 'ppt':
    case 'pptx':
      return 'PowerPoint presentation';
    case 'png':
    case 'jpg':
    case 'jpeg':
    case 'gif':
    case 'webp':
      return 'Image';
    case 'txt':
      return 'Text file';
    case 'zip':
      return 'ZIP archive';
    default:
      return d.extension.isEmpty ? 'File' : '${d.extension.toUpperCase()} file';
  }
}

HubTone sourceTone(String sourceType) {
  switch (sourceType.toLowerCase()) {
    case 'lead':
      return (const Color(0xFFFFEDD5), const Color(0xFFC2410C));
    case 'deal':
      return (const Color(0xFFDBEAFE), const Color(0xFF1D4ED8));
    case 'invoice':
      return (const Color(0xFFDCFCE7), const Color(0xFF15803D));
    default:
      return (const Color(0xFFEFF2F7), const Color(0xFF334155));
  }
}

HubTone statusTone(String status) {
  switch (status.toLowerCase()) {
    case 'replied':
      return (const Color(0xFFF3E8FF), const Color(0xFF9333EA));
    case 'viewed':
      return (const Color(0xFFE0E7FF), const Color(0xFF4338CA));
    case 'not assigned':
      return (const Color(0xFFFEE2E2), const Color(0xFFDC2626));
    default: // Assigned
      return (const Color(0xFFFEF3C7), const Color(0xFFB45309));
  }
}
