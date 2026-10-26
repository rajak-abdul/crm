import 'package:crm_app/screen/message/modal/message_modal.dart';
import 'package:equatable/equatable.dart';

class ChatState extends Equatable {
  final bool isLoading;
  final String? errorMessage;

  final ContactsResponse? contactsResponse;
  final GroupsResponse? groupsResponse;

  final ChatMessagesResponse? messagesResponse;
  final bool messagesLoading;
  final String? messagesError;

  final int unreadCount;

  /// Groups pinned to the top of the Groups list (stored on this device).
  final List<String> pinnedGroupIds;

  const ChatState({
    this.isLoading = false,
    this.errorMessage,
    this.contactsResponse,
    this.groupsResponse,
    this.messagesResponse,
    this.messagesLoading = false,
    this.messagesError,
    this.unreadCount = 0,
    this.pinnedGroupIds = const [],
  });

  ChatState copyWith({
    bool? isLoading,
    String? errorMessage,
    ContactsResponse? contactsResponse,
    GroupsResponse? groupsResponse,
    ChatMessagesResponse? messagesResponse,
    bool? messagesLoading,
    String? messagesError,
    int? unreadCount,
    List<String>? pinnedGroupIds,
    bool clearMessages = false,
  }) {
    return ChatState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,

      contactsResponse:
          contactsResponse ?? this.contactsResponse,

      groupsResponse:
          groupsResponse ?? this.groupsResponse,

      messagesResponse: clearMessages
          ? null
          : messagesResponse ?? this.messagesResponse,

      messagesLoading:
          messagesLoading ?? this.messagesLoading,

      messagesError: messagesError,

      unreadCount:
          unreadCount ?? this.unreadCount,

      pinnedGroupIds:
          pinnedGroupIds ?? this.pinnedGroupIds,
    );
  }

  @override
  List<Object?> get props => [
        isLoading,
        errorMessage,
        contactsResponse,
        groupsResponse,
        messagesResponse,
        messagesLoading,
        messagesError,
        unreadCount,
        pinnedGroupIds,
      ];
}