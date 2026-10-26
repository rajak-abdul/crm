// ╔══════════════════════════════════════════════════════════════╗
// ║  lib/screen/documents_hub/domain/entities/hub_document.dart   ║
// ║  ENTITIES — a document assigned to the user, who uploaded /   ║
// ║  received it, and its activity trail. Pure Dart: no Flutter,  ║
// ║  Dio or JSON here.                                            ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:equatable/equatable.dart';

class HubDocument extends Equatable {
  final String id;
  final String documentId;
  final String name;
  final String path;
  final String mimeType;
  final int sizeBytes;

  /// 'External' | 'Lead' | 'Deal' — where the file came from.
  final String sourceType;
  final String sourceId;
  final String sourceName;

  final HubUser? uploadedBy;
  final HubUser? assignedTo;

  /// 'Assigned' | 'Viewed' | 'Replied' — latest action on the document.
  final String status;
  final String note;
  final List<DocumentActivity> activity;

  final DateTime? uploadedAt;
  final DateTime? updatedAt;
  final DateTime? deletedAt;

  /// True for documents assigned through the hub (they have an activity
  /// trail and accept replies); false for files read straight off a
  /// lead / deal record.
  final bool isHubAssignment;

  const HubDocument({
    required this.id,
    required this.documentId,
    required this.name,
    required this.path,
    required this.mimeType,
    required this.sizeBytes,
    required this.sourceType,
    required this.sourceId,
    required this.sourceName,
    required this.status,
    this.uploadedBy,
    this.assignedTo,
    this.note = '',
    this.activity = const [],
    this.uploadedAt,
    this.updatedAt,
    this.deletedAt,
    this.isHubAssignment = true,
  });

  /// Lower-case file extension from the stored path ('' when none).
  String get extension {
    final file = path.split('/').last;
    final dot = file.lastIndexOf('.');
    return dot == -1 ? '' : file.substring(dot + 1).toLowerCase();
  }

  /// Name to save the file as — the display name, with the stored file's
  /// extension added when the name has none (e.g. "rrf" → "rrf.xlsx").
  String get fileName {
    final base = name.trim().isNotEmpty ? name.trim() : path.split('/').last;
    if (extension.isEmpty || base.toLowerCase().endsWith('.$extension')) {
      return base;
    }
    return '$base.$extension';
  }

  HubDocument copyWith({
    String? status,
    List<DocumentActivity>? activity,
  }) {
    return HubDocument(
      id: id,
      documentId: documentId,
      name: name,
      path: path,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      sourceType: sourceType,
      sourceId: sourceId,
      sourceName: sourceName,
      status: status ?? this.status,
      uploadedBy: uploadedBy,
      assignedTo: assignedTo,
      note: note,
      activity: activity ?? this.activity,
      uploadedAt: uploadedAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      isHubAssignment: isHubAssignment,
    );
  }

  /// Replies the user sent on this document, oldest first.
  List<DocumentActivity> get replies =>
      [for (final a in activity) if (a.action == 'Replied') a];

  @override
  List<Object?> get props => [
        id,
        documentId,
        name,
        path,
        mimeType,
        sizeBytes,
        sourceType,
        sourceId,
        sourceName,
        uploadedBy,
        assignedTo,
        status,
        note,
        activity,
        uploadedAt,
        updatedAt,
        deletedAt,
        isHubAssignment,
      ];
}

class HubUser extends Equatable {
  final String id;
  final String firstName;
  final String lastName;

  const HubUser({
    required this.id,
    required this.firstName,
    required this.lastName,
  });

  String get fullName =>
      [firstName, lastName].where((s) => s.trim().isNotEmpty).join(' ');

  @override
  List<Object?> get props => [id, firstName, lastName];
}

class DocumentActivity extends Equatable {
  final String id;

  /// 'Assigned' | 'Viewed' | 'Replied'.
  final String action;

  /// User id only — the backend does not populate it.
  final String performedBy;
  final String role;
  final String note;
  final DateTime? createdAt;

  const DocumentActivity({
    required this.id,
    required this.action,
    required this.performedBy,
    required this.role,
    this.note = '',
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, action, performedBy, role, note, createdAt];
}

/// One page of documents plus the backend's pagination info.
class HubDocumentPage extends Equatable {
  final List<HubDocument> documents;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  const HubDocumentPage({
    required this.documents,
    required this.page,
    required this.limit,
    required this.total,
    required this.totalPages,
  });

  bool get hasMore => page < totalPages;

  @override
  List<Object?> get props => [documents, page, limit, total, totalPages];
}
