// ================= UNREAD COUNT HELPER =================

/// Parses `unreadCount` whether the API sends it as int, double or string.
/// Never negative, so the UI can rely on `> 0` meaning "has unread".
int parseUnreadCount(dynamic raw) {
  final value = raw is num ? raw.toInt() : int.tryParse('${raw ?? ''}') ?? 0;
  return value < 0 ? 0 : value;
}

// ================= AVATAR URL HELPER =================

/// Resolves a raw avatar/profileImage value from the API into a full URL.
///
/// [bareFilenameFolder], when given, is prefixed onto values that are just a
/// filename with no path segments (e.g. "abc123.jpg" -> "/uploads/users/abc123.jpg"),
/// matching the convention the backend already uses for user profile photos
/// (see `_resolveProfileImageUrl` in main.dart).
String? resolveChatAvatarUrl(String? raw, {String? bareFilenameFolder}) {
  final trimmed = raw?.trim() ?? '';
  if (trimmed.isEmpty) return null;
  if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
    return trimmed;
  }
  var path = trimmed.replaceAll('\\', '/');
  if (bareFilenameFolder != null && !path.contains('/')) {
    path = '$bareFilenameFolder/$path';
  }
  if (!path.startsWith('/')) path = '/$path';
  return 'https://crm-backend-api.techzarinfo.cloud$path';
}

String? resolveContactAvatarUrl(String? raw) =>
    resolveChatAvatarUrl(raw, bareFilenameFolder: 'uploads/users');

// ================= CONTACT RESPONSE =================

class ContactsResponse {
  final List<ContactModel> contacts;

  ContactsResponse({
    required this.contacts,
  });

  factory ContactsResponse.fromJson(Map<String, dynamic> json) {
    return ContactsResponse(
      contacts: (json['contacts'] as List<dynamic>? ?? [])
          .map((e) => ContactModel.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'contacts': contacts.map((e) => e.toJson()).toList(),
    };
  }
}


// ================= CONTACT MODEL =================

class ContactModel {
  final String id;
  final String name;
  final String email;
  final String? profileImage;
  final String role;
  final LastMessageModel? lastMessage;
  final int unreadCount;

  ContactModel({
    required this.id,
    required this.name,
    required this.email,
    this.profileImage,
    required this.role,
    this.lastMessage,
    required this.unreadCount,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      role: json['role'] ?? '',
      lastMessage: json['lastMessage'] != null
          ? LastMessageModel.fromJson(json['lastMessage'])
          : null,
      unreadCount: parseUnreadCount(json['unreadCount']),
    );
  }

  ContactModel copyWith({int? unreadCount, LastMessageModel? lastMessage}) {
    return ContactModel(
      id: id,
      name: name,
      email: email,
      profileImage: profileImage,
      role: role,
      lastMessage: lastMessage ?? this.lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'email': email,
      'profileImage': profileImage,
      'role': role,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
    };
  }
}

//


// ================= LAST MESSAGE =================

class LastMessageModel {
  final String message;
  final String? fileType;
  final String? fileName;
  final DateTime createdAt;
  final bool isRead;
  final String? senderName;

  LastMessageModel({
    required this.message,
    this.fileType,
    this.fileName,
    required this.createdAt,
    required this.isRead,
    this.senderName,
  });

  factory LastMessageModel.fromJson(Map<String, dynamic> json) {
    return LastMessageModel(
      message: json['message'] ?? '',
      fileType: json['fileType'],
      fileName: json['fileName'],
      createdAt: (DateTime.tryParse(
            json['createdAt'] ?? '',
          ) ??
          DateTime.now())
          .toLocal(),
      isRead: json['isRead'] ?? false,
      senderName: json['senderName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'fileType': fileType,
      'fileName': fileName,
      'createdAt': createdAt.toIso8601String(),
      'isRead': isRead,
      if (senderName != null) 'senderName': senderName,
    };
  }
}


// ================= GROUP RESPONSE =================

class GroupsResponse {
  final List<GroupModel> groups;

  GroupsResponse({
    required this.groups,
  });

  factory GroupsResponse.fromJson(Map<String, dynamic> json) {
    return GroupsResponse(
      groups: (json['groups'] as List<dynamic>? ?? [])
          .map((e) => GroupModel.fromJson(e))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'groups': groups.map((e) => e.toJson()).toList(),
    };
  }
}


// ================= GROUP MODEL =================

class GroupModel {
  final String id;
  final String name;
  final String description;
  final String? avatar;
  final String createdBy;
  final List<GroupMemberModel> members;
  final List<String> admins;
  final int memberCount;
  final bool onlyAdminsCanMessage;
  final GroupLastMessageModel? lastMessage;
  final int unreadCount;

  GroupModel({
    required this.id,
    required this.name,
    required this.description,
    this.avatar,
    required this.createdBy,
    required this.members,
    required this.admins,
    required this.memberCount,
    required this.onlyAdminsCanMessage,
    this.lastMessage,
    required this.unreadCount,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    return GroupModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      avatar: json['avatar'],
      createdBy: json['createdBy'] ?? '',
      members: (json['members'] as List<dynamic>? ?? [])
          .map((e) => GroupMemberModel.fromJson(e))
          .toList(),
      admins: List<String>.from(json['admins'] ?? []),
      memberCount: json['memberCount'] ?? 0,
      onlyAdminsCanMessage:
          json['onlyAdminsCanMessage'] ?? false,
      lastMessage: json['lastMessage'] != null
          ? GroupLastMessageModel.fromJson(json['lastMessage'])
          : null,
      unreadCount: parseUnreadCount(json['unreadCount']),
    );
  }

  GroupModel copyWith({int? unreadCount}) {
    return GroupModel(
      id: id,
      name: name,
      description: description,
      avatar: avatar,
      createdBy: createdBy,
      members: members,
      admins: admins,
      memberCount: memberCount,
      onlyAdminsCanMessage: onlyAdminsCanMessage,
      lastMessage: lastMessage,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'description': description,
      'avatar': avatar,
      'createdBy': createdBy,
      'members': members.map((e) => e.toJson()).toList(),
      'admins': admins,
      'memberCount': memberCount,
      'onlyAdminsCanMessage': onlyAdminsCanMessage,
      'lastMessage': lastMessage?.toJson(),
      'unreadCount': unreadCount,
    };
  }
}


// ================= GROUP MEMBER =================

class GroupMemberModel {
  final String id;
  final String name;
  final String? profileImage;

  GroupMemberModel({
    required this.id,
    required this.name,
    this.profileImage,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      profileImage: json['profileImage'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'profileImage': profileImage,
    };
  }
}


// ================= GROUP LAST MESSAGE =================

class GroupLastMessageModel {
  final String message;
  final String? fileType;
  final String? senderName;
  final DateTime createdAt;

  GroupLastMessageModel({
    required this.message,
    this.fileType,
    this.senderName,
    required this.createdAt,
  });

  factory GroupLastMessageModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return GroupLastMessageModel(
      message: json['message'] ?? '',
      fileType: json['fileType'],
      senderName: json['senderName'],
      createdAt: (DateTime.tryParse(
            json['createdAt'] ?? '',
          ) ??
          DateTime.now())
          .toLocal(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'fileType': fileType,
      'senderName': senderName,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}



// ================= CHAT MESSAGE =================

class ChatMessageModel {
  final String id;
  final String senderId;
  final String receiverId;
  final String senderName;
  final String senderRole;

  /// 'message' for normal messages, 'system' for group events
  /// like "X created the group".
  final String type;

  final String message;

  final String? fileUrl;
  final String? fileName;
  final String? fileType;

  final bool isMe;
  final bool isRead;
  final DateTime? readAt;

  final bool isPinned;
  final bool isDeleted;

  final ChatReplyModel? replyTo;
  final List<ChatReactionModel> reactions;

  final DateTime createdAt;
  final DateTime updatedAt;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.senderName,
    required this.senderRole,
    this.type = 'message',
    required this.message,
    this.fileUrl,
    this.fileName,
    this.fileType,
    required this.isMe,
    required this.isRead,
    this.readAt,
    required this.isPinned,
    required this.isDeleted,
    this.replyTo,
    required this.reactions,
    required this.createdAt,
    required this.updatedAt,
  });

  ChatMessageModel copyWith({
    bool? isMe,
    bool? isPinned,
    bool? isDeleted,
    List<ChatReactionModel>? reactions,
  }) {
    return ChatMessageModel(
      id: id,
      senderId: senderId,
      receiverId: receiverId,
      senderName: senderName,
      senderRole: senderRole,
      type: type,
      message: message,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      isMe: isMe ?? this.isMe,
      isRead: isRead,
      readAt: readAt,
      isPinned: isPinned ?? this.isPinned,
      isDeleted: isDeleted ?? this.isDeleted,
      replyTo: replyTo,
      reactions: reactions ?? this.reactions,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  factory ChatMessageModel.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    // Group messages may come with senderId populated as a user object.
    final sender = json['senderId'];
    final senderId = sender is Map
        ? (sender['_id'] ?? '').toString()
        : (sender ?? '').toString();

    // Group messages have no isRead flag; they're "read" once anyone
    // other than the sender appears in readBy.
    final readBy = json['readBy'] is List ? json['readBy'] as List : const [];
    final readByOthers = readBy.any(
      (r) => r is Map && r['userId']?.toString() != senderId,
    );

    return ChatMessageModel(
      id: json['_id'] ?? '',
      senderId: senderId,
      receiverId: (json['receiverId'] ?? json['groupId'] ?? '').toString(),
      senderName: json['senderName'] ??
          (sender is Map ? sender['name']?.toString() : null) ??
          '',
      senderRole: json['senderRole'] ??
          (sender is Map ? sender['role']?.toString() : null) ??
          '',
      type: json['type']?.toString() ?? 'message',
      message: json['message'] ?? '',

      fileUrl: json['fileUrl'],
      fileName: json['fileName'],
      fileType: json['fileType'],

      isMe: senderId.isNotEmpty && senderId == currentUserId,

      isRead: json['isRead'] ?? readByOthers,

      readAt: json['readAt'] != null
          ? DateTime.tryParse(
              json['readAt'].toString(),
            )?.toLocal()
          : null,

      isPinned: json['isPinned'] ?? false,
      isDeleted: json['isDeleted'] ?? false,

      replyTo: json['replyTo'] != null
          ? ChatReplyModel.fromJson(
              Map<String, dynamic>.from(
                json['replyTo'],
              ),
            )
          : null,

      reactions:
          (json['reactions'] as List<dynamic>? ?? [])
              .map(
                (e) => ChatReactionModel.fromJson(
                  Map<String, dynamic>.from(e),
                ),
              )
              .toList(),

      createdAt: (DateTime.tryParse(
            json['createdAt']?.toString() ?? '',
          ) ??
          DateTime.now())
          .toLocal(),

      updatedAt: (DateTime.tryParse(
            json['updatedAt']?.toString() ?? '',
          ) ??
          DateTime.now())
          .toLocal(),
    );
  }
}

// ================= CHAT REPLY =================

class ChatReplyModel {
  final String? messageId;
  final String message;
  final String senderName;

  ChatReplyModel({
    this.messageId,
    required this.message,
    required this.senderName,
  });

  factory ChatReplyModel.fromJson(
    Map<String, dynamic> json,
  ) {
    return ChatReplyModel(
      messageId: json['messageId'],
      message: json['message'] ?? '',
      senderName: json['senderName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'messageId': messageId,
      'message': message,
      'senderName': senderName,
    };
  }
}


// ================= CHAT REACTION =================

class ChatReactionModel {
  final String userId;
  final String emoji;
  final String id;

  ChatReactionModel({
    required this.userId,
    required this.emoji,
    required this.id,
  });

  factory ChatReactionModel.fromJson(
    Map<String, dynamic> json,
  ) {
    // userId may be a plain id or a populated user object.
    final user = json['userId'];
    return ChatReactionModel(
      userId: user is Map
          ? (user['_id'] ?? '').toString()
          : (user ?? '').toString(),
      emoji: (json['emoji'] ?? '').toString(),
      id: (json['_id'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'emoji': emoji,
      '_id': id,
    };
  }
}

// ================= CHAT MESSAGES RESPONSE =================

class ChatMessagesResponse {
  final List<ChatMessageModel> messages;
  final int page;
  final int limit;

  ChatMessagesResponse({
    required this.messages,
    required this.page,
    required this.limit,
  });

  factory ChatMessagesResponse.fromJson(
    Map<String, dynamic> json, {
    required String currentUserId,
  }) {
    return ChatMessagesResponse(
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map(
            (e) => ChatMessageModel.fromJson(
              Map<String, dynamic>.from(e),
              currentUserId: currentUserId,
            ),
          )
          .toList(),
      page: json['page'] ?? 1,
      limit: json['limit'] ?? 50,
    );
  }
}