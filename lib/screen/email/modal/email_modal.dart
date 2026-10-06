class EmailContact {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String company;
  final String type;
  final String status;
  final String source;
  final DateTime? createdAt;
  final String displayId;

  EmailContact({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.company,
    required this.type,
    required this.status,
    required this.source,
    required this.createdAt,
    required this.displayId,
  });

  factory EmailContact.fromJson(Map<String, dynamic> json) {
    return EmailContact(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      company: json['company']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      source: json['source']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      displayId: json['displayId']?.toString() ?? '',
    );
  }
}

class EmailContactsResponse {
  final List<EmailContact> contacts;
  final int total;
  final int page;
  final int limit;

  // Overall lead/deal totals, when the API sends them. The contacts
  // list only holds the current page, so counting it would undercount.
  final int? totalLeads;
  final int? totalDeals;

  EmailContactsResponse({
    required this.contacts,
    required this.total,
    this.page = 1,
    this.limit = 10,
    this.totalLeads,
    this.totalDeals,
  });

  factory EmailContactsResponse.fromJson(
    Map<String, dynamic> json, {
    int page = 1,
    int limit = 10,
  }) {
    final data = json['data'] as List? ?? [];

    final contacts = data
        .map(
          (item) => EmailContact.fromJson(
            item as Map<String, dynamic>,
          ),
        )
        .toList();

    return EmailContactsResponse(
      contacts: contacts,
      total: _readInt(json, ['total', 'totalCount', 'count']) ??
          contacts.length,
      page: _readInt(json, ['page', 'currentPage']) ?? page,
      limit: limit,
      totalLeads: _readInt(json, ['leadCount', 'totalLeads', 'leads']),
      totalDeals: _readInt(json, ['dealCount', 'totalDeals', 'deals']),
    );
  }

  // Looks for the first key that holds a number, at the top level or
  // inside a `pagination` / `meta` block.
  static int? _readInt(Map<String, dynamic> json, List<String> keys) {
    for (final source in [json, json['pagination'], json['meta']]) {
      if (source is! Map) continue;

      for (final key in keys) {
        final value = int.tryParse(source[key]?.toString() ?? '');
        if (value != null) return value;
      }
    }

    return null;
  }

  int get leadCount {
    return totalLeads ??
        contacts
            .where((contact) => contact.type.toLowerCase() == 'lead')
            .length;
  }

  int get dealCount {
    return totalDeals ??
        contacts
            .where((contact) => contact.type.toLowerCase() == 'deal')
            .length;
  }
}