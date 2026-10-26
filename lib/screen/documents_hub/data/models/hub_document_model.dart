// ╔══════════════════════════════════════════════════════════════╗
// ║ lib/screen/documents_hub/data/models/hub_document_model.dart  ║
// ║  MODELS — JSON ⇄ entity. Each model extends its entity, so    ║
// ║  the repository can hand them straight to the domain.         ║
// ╚══════════════════════════════════════════════════════════════╝

import 'package:crm_app/screen/documents_hub/domain/entities/hub_document.dart';

String _s(dynamic v) => v == null ? '' : v.toString();

int _i(dynamic v, [int fallback = 0]) =>
    v is num ? v.toInt() : int.tryParse(_s(v)) ?? fallback;

DateTime? _date(dynamic v) => v == null ? null : DateTime.tryParse(_s(v));

/// An id that may arrive bare ("64f…") or populated ({_id, …}).
String _id(dynamic v) => v is Map ? _s(v['_id'] ?? v['id']) : _s(v);

class HubDocumentModel extends HubDocument {
  const HubDocumentModel({
    required super.id,
    required super.documentId,
    required super.name,
    required super.path,
    required super.mimeType,
    required super.sizeBytes,
    required super.sourceType,
    required super.sourceId,
    required super.sourceName,
    required super.status,
    super.uploadedBy,
    super.assignedTo,
    super.note,
    super.activity,
    super.uploadedAt,
    super.updatedAt,
    super.deletedAt,
    super.isHubAssignment,
  });

  /// One file from a lead's `attachments` / `images`, shown on the Lead
  /// tab. The lead supplies the source and assignee.
  factory HubDocumentModel.fromLeadFile(
    Map<String, dynamic> file, {
    required Map<String, dynamic> lead,
  }) =>
      HubDocumentModel._fromRecordFile(
        file,
        sourceType: 'Lead',
        sourceId: _s(lead['_id'] ?? lead['id']),
        sourceName: _s(lead['leadName']),
        assignedTo: lead['assignTo'],
      );

  /// One file from a deal's `attachments` / `images`, shown on the Deal
  /// tab. The deal supplies the source and assignee.
  factory HubDocumentModel.fromDealFile(
    Map<String, dynamic> file, {
    required Map<String, dynamic> deal,
  }) =>
      HubDocumentModel._fromRecordFile(
        file,
        sourceType: 'Deal',
        sourceId: _s(deal['_id'] ?? deal['id']),
        sourceName: _s(deal['dealName']),
        assignedTo: deal['assignedTo'],
      );

  factory HubDocumentModel._fromRecordFile(
    Map<String, dynamic> file, {
    required String sourceType,
    required String sourceId,
    required String sourceName,
    required dynamic assignedTo,
  }) {
    final uploadedAt = _date(file['uploadedAt']);

    return HubDocumentModel(
      id: _s(file['_id'] ?? file['id']),
      documentId: _s(file['_id'] ?? file['id']),
      name: _s(file['name']),
      path: _s(file['path']),
      mimeType: _s(file['type']),
      sizeBytes: _i(file['size']),
      sourceType: sourceType,
      sourceId: sourceId,
      sourceName: sourceName,
      uploadedBy: HubUserModel.tryParse(file['uploadedBy']),
      assignedTo: HubUserModel.tryParse(assignedTo),
      // A raw lead / deal file has no hub assignment yet; the record's own
      // status (New / Hot, Qualification …) is not a document status.
      status: 'Not assigned',
      uploadedAt: uploadedAt,
      // The record's own updatedAt moves with reminders; the file's upload
      // time is the meaningful date for the card.
      updatedAt: uploadedAt,
      isHubAssignment: false,
    );
  }

  factory HubDocumentModel.fromJson(Map<String, dynamic> json) {
    final rawActivity = json['activity'];

    return HubDocumentModel(
      id: _s(json['id'] ?? json['_id']),
      documentId: _id(json['documentId']),
      name: _s(json['name']),
      path: _s(json['path']),
      mimeType: _s(json['type']),
      sizeBytes: _i(json['size']),
      sourceType: _s(json['sourceType']),
      sourceId: _id(json['sourceId']),
      sourceName: _s(json['sourceName']),
      uploadedBy: HubUserModel.tryParse(json['uploadedBy']),
      assignedTo: HubUserModel.tryParse(json['assignedTo']),
      status: _s(json['status']),
      note: _s(json['note']),
      activity: [
        if (rawActivity is List)
          for (final a in rawActivity)
            if (a is Map<String, dynamic>) DocumentActivityModel.fromJson(a),
      ],
      uploadedAt: _date(json['uploadedAt']),
      updatedAt: _date(json['updatedAt']),
      deletedAt: _date(json['deletedAt']),
    );
  }
}

class HubUserModel extends HubUser {
  const HubUserModel({
    required super.id,
    required super.firstName,
    required super.lastName,
  });

  /// `uploadedBy` / `assignedTo` arrive populated ({_id, firstName,
  /// lastName}); a bare id string or null gives no name to show.
  static HubUserModel? tryParse(dynamic v) {
    if (v is Map) {
      return HubUserModel(
        id: _s(v['_id'] ?? v['id']),
        firstName: _s(v['firstName']),
        lastName: _s(v['lastName']),
      );
    }
    if (v is String && v.isNotEmpty) {
      return HubUserModel(id: v, firstName: '', lastName: '');
    }
    return null;
  }
}

class DocumentActivityModel extends DocumentActivity {
  const DocumentActivityModel({
    required super.id,
    required super.action,
    required super.performedBy,
    required super.role,
    super.note,
    super.createdAt,
  });

  factory DocumentActivityModel.fromJson(Map<String, dynamic> json) {
    final performedBy = json['performedBy'];

    return DocumentActivityModel(
      id: _s(json['_id'] ?? json['id']),
      action: _s(json['action']),
      performedBy: performedBy is Map
          ? _s(performedBy['_id'] ?? performedBy['id'])
          : _s(performedBy),
      role: _s(json['role']),
      note: _s(json['note']),
      createdAt: _date(json['createdAt']),
    );
  }
}

class HubDocumentPageModel extends HubDocumentPage {
  const HubDocumentPageModel({
    required super.documents,
    required super.page,
    required super.limit,
    required super.total,
    required super.totalPages,
  });

  /// Parses { data: [...], pagination: { page, limit, total, totalPages } }.
  /// Missing pagination falls back to the requested [page] / [limit].
  factory HubDocumentPageModel.fromJson(
    Map<String, dynamic> json, {
    required int page,
    required int limit,
  }) {
    final rawData = json['data'];
    final documents = [
      if (rawData is List)
        for (final d in rawData)
          if (d is Map<String, dynamic>) HubDocumentModel.fromJson(d),
    ];

    final pagination = json['pagination'];
    final p = pagination is Map ? pagination : const {};

    return HubDocumentPageModel(
      documents: documents,
      page: _i(p['page'], page),
      limit: _i(p['limit'], limit),
      total: _i(p['total'], documents.length),
      totalPages: _i(p['totalPages'], 1),
    );
  }

  /// Parses GET /leads/getAllLead?hasAttachments=true —
  /// { leads: [...], currentPage, totalPages, totalLeads } — into one
  /// document per non-deleted attachment / image. Paging (and [total])
  /// counts leads, not files. When the paging keys are missing, a full
  /// page is taken to mean there may be another.
  factory HubDocumentPageModel.fromLeadsJson(
    Map<String, dynamic> json, {
    required int page,
    required int limit,
  }) {
    return HubDocumentPageModel._fromRecords(
      json,
      records: json['leads'] ?? json['data'],
      total: json['totalLeads'],
      toDocument: (f, lead) => HubDocumentModel.fromLeadFile(f, lead: lead),
      page: page,
      limit: limit,
    );
  }

  /// Parses GET /deals/getAll?hasAttachments=true — a bare list wrapped
  /// as { deals: [...] } by the repository — the same way as
  /// [HubDocumentPageModel.fromLeadsJson]. The list has no paging keys,
  /// so [total] is 0 (unknown) unless the backend starts sending one.
  factory HubDocumentPageModel.fromDealsJson(
    Map<String, dynamic> json, {
    required int page,
    required int limit,
  }) {
    return HubDocumentPageModel._fromRecords(
      json,
      records: json['deals'] ?? json['data'],
      total: json['totalDeals'] ?? json['total'],
      toDocument: (f, deal) => HubDocumentModel.fromDealFile(f, deal: deal),
      page: page,
      limit: limit,
      unknownTotal: 0,
    );
  }

  /// Shared by leads and deals: one document per non-deleted attachment /
  /// image of each record. Paging counts records. When the paging keys
  /// are missing, a full page is taken to mean there may be another.
  /// [unknownTotal] is used when no total arrives (null → records on
  /// this page).
  factory HubDocumentPageModel._fromRecords(
    Map<String, dynamic> json, {
    required dynamic records,
    required dynamic total,
    required HubDocumentModel Function(
      Map<String, dynamic> file,
      Map<String, dynamic> record,
    ) toDocument,
    required int page,
    required int limit,
    int? unknownTotal,
  }) {
    final list = [
      if (records is List)
        for (final r in records)
          if (r is Map<String, dynamic>) r,
    ];

    final documents = [
      for (final record in list)
        for (final key in const ['attachments', 'images'])
          if (record[key] is List)
            for (final f in record[key] as List)
              if (f is Map<String, dynamic> &&
                  f['isDeleted'] != true &&
                  _s(f['path']).isNotEmpty)
                toDocument(f, record),
    ];

    final pagination = json['pagination'];
    final p = pagination is Map ? pagination : const {};
    final current = _i(json['currentPage'] ?? p['page'], page);
    final guessedPages = list.length < limit ? current : current + 1;

    return HubDocumentPageModel(
      documents: documents,
      page: current,
      limit: limit,
      total: _i(total ?? p['total'], unknownTotal ?? list.length),
      totalPages: _i(json['totalPages'] ?? p['totalPages'], guessedPages),
    );
  }
}
