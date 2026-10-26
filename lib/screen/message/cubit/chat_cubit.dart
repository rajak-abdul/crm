import 'dart:async';

import 'package:crm_app/screen/message/cubit/chat_state.dart';
import 'package:crm_app/screen/message/modal/message_modal.dart';
import 'package:crm_app/services/auth_interceptor.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Unread messages across direct chats and groups, for badges outside the
/// Messages screen (e.g. the dashboard drawer). Kept up to date by every
/// [ChatCubit] whenever it has contacts or groups loaded.
final ValueNotifier<int> chatUnreadTotal = ValueNotifier<int>(0);

/// Fetches contacts and groups once, just to refresh [chatUnreadTotal].
Future<void> refreshChatUnreadTotal() async {
  final cubit = ChatCubit();
  try {
    await cubit.loadChatData();
  } finally {
    await cubit.close();
  }
}

class ChatCubit extends Cubit<ChatState> {
  late final Dio dio;

  String _tenantSlug = '';

  io.Socket? _socket;
  String _currentUserId = '';
  String _currentUserName = '';
  String? _activeContactId;
  String? _activeGroupId;
  String _dbName = '';

  ChatCubit()
      : dio = Dio(
          BaseOptions(
            baseUrl:
                'https://crm-backend-api.techzarinfo.cloud/',
            connectTimeout:
                const Duration(seconds: 30),
            receiveTimeout:
                const Duration(seconds: 30),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
          ),
        ),
        super(const ChatState());

  @override
  void onChange(Change<ChatState> change) {
    super.onChange(change);

    final s = change.nextState;
    if (s.contactsResponse == null && s.groupsResponse == null) return;

    final direct = (s.contactsResponse?.contacts ?? const <ContactModel>[])
        .fold<int>(0, (sum, c) => sum + c.unreadCount);
    final groups = (s.groupsResponse?.groups ?? const <GroupModel>[])
        .fold<int>(0, (sum, g) => sum + g.unreadCount);

    chatUnreadTotal.value = direct + groups;
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _tenantSlug = (
      prefs.getString('tenant_slug') ??
      prefs.getString('tenantSlug') ??
      ''
    ).trim();

    if (_tenantSlug.isEmpty) {
      throw Exception('Tenant slug not found');
    }

    final token = prefs.getString('token') ?? '';

    if (token.isNotEmpty) {
      dio.options.headers['Authorization'] =
          'Bearer $token';
    }

    // Needed to tell which reactions/messages are mine, even if the
    // socket never connected.
    if (_currentUserId.isEmpty) {
      _currentUserId = prefs.getString('user_id') ?? '';
    }

    dio.options.headers['Accept'] =
        'application/json';

    dio.options.connectTimeout =
        const Duration(seconds: 30);

    dio.options.receiveTimeout =
        const Duration(seconds: 30);

    if (!dio.interceptors.any(
      (interceptor) =>
          interceptor is AuthInterceptor,
    )) {
      dio.interceptors.add(
        AuthInterceptor(),
      );
    }
  }

  // ============================================================
  // GET CONTACTS
  // ============================================================

  Future<void> getContacts() async {
    if (isClosed) return;

    try {
      emit(
        state.copyWith(
          isLoading: true,
          errorMessage: null,
        ),
      );

      await initialize();

      if (isClosed) return;

      final response = await dio.get(
        '$_tenantSlug/api/chat/contacts',
      );

      if (isClosed) return;

      if (response.data is Map<String, dynamic>) {
        final result = ContactsResponse.fromJson(
          Map<String, dynamic>.from(
            response.data,
          ),
        );

        emit(
          state.copyWith(
            isLoading: false,
            contactsResponse: result,
            errorMessage: null,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage:
                'Invalid contacts response',
          ),
        );
      }
    } on DioException catch (e) {
      if (isClosed) return;

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              e.response?.data is Map
                  ? e.response?.data['message']
                          ?.toString() ??
                      'Failed to load contacts'
                  : 'Failed to load contacts',
        ),
      );
    } catch (e) {
      if (isClosed) return;

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // REACT TO MESSAGE (direct)
  // ============================================================

  String get currentUserId => _currentUserId;

  /// One reaction per user: picking the same emoji again removes it,
  /// picking a different one replaces it. The UI updates immediately and
  /// rolls back if the request fails.
  ///
  /// Returns null on success, or the error message to show.
  Future<String?> reactToMessage({
    required String messageId,
    required String emoji,
  }) async {
    if (isClosed) return null;

    final original = _findMessage(messageId);
    if (original == null) return 'Message not found';

    final others = original.reactions
        .where((r) => r.userId != _currentUserId)
        .toList();
    final hadSame = original.reactions.any(
      (r) => r.userId == _currentUserId && r.emoji == emoji,
    );

    _replaceMessage(
      original.copyWith(
        reactions: [
          ...others,
          if (!hadSame)
            ChatReactionModel(userId: _currentUserId, emoji: emoji, id: ''),
        ],
      ),
    );

    final Response<dynamic> response;
    try {
      await initialize();

      if (isClosed) return null;

      response = await dio.post(
        '$_tenantSlug/api/chat/messages/$messageId/reaction',
        data: {
          // Empty emoji tells the server to remove this user's reaction.
          'emoji': hadSame ? '' : emoji,
        },
      );
    } on DioException catch (e) {
      debugPrint(
        'Reaction failed [${e.response?.statusCode}] '
        '${e.requestOptions.method} ${e.requestOptions.uri}\n'
        '${e.response?.data ?? e.message}',
      );

      if (isClosed) return null;

      _replaceMessage(original);

      final data = e.response?.data;
      return (data is Map ? data['message']?.toString() : null) ??
          'Failed to add reaction (${e.response?.statusCode ?? e.type.name})';
    } catch (e) {
      debugPrint('Reaction failed: $e');

      if (isClosed) return null;

      _replaceMessage(original);
      return e.toString();
    }

    if (isClosed) return null;

    debugPrint(
      'Reaction ${hadSame ? 'REMOVE' : 'ADD'} $emoji by $_currentUserId '
      '-> ${response.statusCode} ${response.data}',
    );

    // The server accepted the reaction — from here on never roll back.
    // Prefer its reaction list when one comes back.
    try {
      final serverReactions = _reactionsFrom(response.data);
      final current = _findMessage(messageId);
      if (serverReactions != null && current != null) {
        _replaceMessage(current.copyWith(reactions: serverReactions));
      }
    } catch (e) {
      debugPrint('Reaction response not parsed: $e\n${response.data}');
    }

    return null;
  }

  /// Pulls `reactions` out of `{reactions}`, `{message: {reactions}}`
  /// or `{data: {reactions}}`; null when the response has none.
  List<ChatReactionModel>? _reactionsFrom(dynamic data) {
    if (data is! Map) return null;
    dynamic list = data['reactions'];
    for (final key in const ['message', 'data']) {
      final nested = data[key];
      if (list == null && nested is Map) list = nested['reactions'];
    }
    if (list is! List) return null;
    return list
        .whereType<Map>()
        .map((e) => ChatReactionModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  ChatMessageModel? _findMessage(String messageId) {
    final messages = state.messagesResponse?.messages ?? const [];
    for (final m in messages) {
      if (m.id == messageId) return m;
    }
    return null;
  }

  void _replaceMessage(ChatMessageModel message) {
    if (isClosed) return;

    final current = state.messagesResponse;
    if (current == null) return;

    final list = List<ChatMessageModel>.of(current.messages);
    final idx = list.indexWhere((m) => m.id == message.id);
    if (idx < 0) return;

    list[idx] = message;

    emit(
      state.copyWith(
        messagesResponse: ChatMessagesResponse(
          messages: list,
          page: current.page,
          limit: current.limit,
        ),
      ),
    );
  }

  // ============================================================
  // GET GROUPS
  // ============================================================

  Future<void> getGroups() async {
    if (isClosed) return;

    try {
      emit(
        state.copyWith(
          isLoading: true,
          errorMessage: null,
        ),
      );

      await initialize();

      if (isClosed) return;

      final response = await dio.get(
        '$_tenantSlug/api/groups',
      );

      if (isClosed) return;

      if (response.data is Map<String, dynamic>) {
        final result = GroupsResponse.fromJson(
          Map<String, dynamic>.from(
            response.data,
          ),
        );

        emit(
          state.copyWith(
            isLoading: false,
            groupsResponse: result,
            errorMessage: null,
          ),
        );
      } else {
        emit(
          state.copyWith(
            isLoading: false,
            errorMessage:
                'Invalid groups response',
          ),
        );
      }
    } on DioException catch (e) {
      if (isClosed) return;

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              e.response?.data is Map
                  ? e.response?.data['message']
                          ?.toString() ??
                      'Failed to load groups'
                  : 'Failed to load groups',
        ),
      );
    } catch (e) {
      if (isClosed) return;

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // GET GROUP MESSAGES
  // ============================================================

  Future<void> getGroupMessages(
    String groupId, {
    int page = 1,
    int limit = 50,
  }) async {
    if (isClosed) return;

    // Direct-chat socket events must not leak into an open group thread.
    _activeContactId = null;
    _activeGroupId = groupId;
    _joinGroupRoom(groupId);

    try {
      emit(
        state.copyWith(
          messagesLoading: true,
          messagesError: null,
          clearMessages: true,
        ),
      );

      await initialize();

      if (isClosed) return;

      final response = await dio.get(
        '$_tenantSlug/api/groups/$groupId/messages',
        queryParameters: {
          'page': page,
          'limit': limit,
        },
      );

      // User switched to another conversation while this was loading.
      if (isClosed || _activeGroupId != groupId) return;

      final data = response.data;
      final Map<String, dynamic>? json = data is Map
          ? Map<String, dynamic>.from(data)
          : data is List
              ? {'messages': data}
              : null;

      if (json == null) {
        emit(
          state.copyWith(
            messagesLoading: false,
            messagesError: 'Invalid group messages response',
          ),
        );
        return;
      }

      final prefs = await SharedPreferences.getInstance();

      final currentUserId =
          prefs.getString('user_id') ?? '';

      final parsed = ChatMessagesResponse.fromJson(
        json,
        currentUserId: currentUserId,
      );

      // Group pins live on this device only.
      final pins = (prefs.getStringList(_groupPinsKey(groupId)) ?? const [])
          .toSet();
      final result = ChatMessagesResponse(
        messages: [
          for (final m in parsed.messages)
            m.copyWith(isPinned: pins.contains(m.id)),
        ],
        page: parsed.page,
        limit: parsed.limit,
      );

      if (isClosed || _activeGroupId != groupId) return;

      emit(
        state.copyWith(
          messagesLoading: false,
          messagesResponse: result,
          messagesError: null,
        ),
      );

      markGroupRead(groupId);
      _startPolling();
    } on DioException catch (e) {
      if (isClosed || _activeGroupId != groupId) return;

      emit(
        state.copyWith(
          messagesLoading: false,
          messagesError:
              e.response?.data is Map
                  ? e.response?.data['message']
                          ?.toString() ??
                      'Failed to load group messages'
                  : 'Failed to load group messages',
        ),
      );
    } catch (e) {
      if (isClosed || _activeGroupId != groupId) return;

      emit(
        state.copyWith(
          messagesLoading: false,
          messagesError: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // GET UNREAD COUNT
  // ============================================================

  Future<void> getUnreadCount() async {
    if (isClosed) return;

    try {
      await initialize();

      if (isClosed) return;

      final response = await dio.get(
        '$_tenantSlug/api/chat/unread-count',
      );

      if (isClosed) return;

      if (response.data is Map<String, dynamic>) {
        final data = Map<String, dynamic>.from(
          response.data,
        );

        final count = data['unreadCount'];

        emit(
          state.copyWith(
            unreadCount: count is int
                ? count
                : int.tryParse(
                      count?.toString() ?? '0',
                    ) ??
                    0,
          ),
        );
      }
    } on DioException catch (e) {
      if (isClosed) return;

      emit(
        state.copyWith(
          errorMessage:
              e.response?.data is Map
                  ? e.response?.data['message']
                          ?.toString() ??
                      'Failed to load unread count'
                  : 'Failed to load unread count',
        ),
      );
    } catch (e) {
      if (isClosed) return;

      emit(
        state.copyWith(
          errorMessage: e.toString(),
        ),
      );
    }
  }

  // ============================================================
  // LOAD ALL CHAT DATA
  // ============================================================

  Future<void> loadChatData() async {
    if (isClosed) return;

    try {
      emit(
        state.copyWith(
          isLoading: true,
          errorMessage: null,
        ),
      );

      await initialize();

      if (isClosed) return;

      final results = await Future.wait([
        dio.get(
          '$_tenantSlug/api/chat/contacts',
        ),
        dio.get(
          '$_tenantSlug/api/groups',
        ),
        dio.get(
          '$_tenantSlug/api/chat/unread-count',
        ),
      ]);

      if (isClosed) return;

      final contactsResponse =
          ContactsResponse.fromJson(
        Map<String, dynamic>.from(
          results[0].data,
        ),
      );

      final groupsResponse =
          GroupsResponse.fromJson(
        Map<String, dynamic>.from(
          results[1].data,
        ),
      );

      final unreadData =
          Map<String, dynamic>.from(
        results[2].data,
      );

      final count = unreadData['unreadCount'];

      emit(
        state.copyWith(
          isLoading: false,
          contactsResponse: contactsResponse,
          groupsResponse: groupsResponse,
          unreadCount: count is int
              ? count
              : int.tryParse(
                    count?.toString() ?? '0',
                  ) ??
                  0,
          errorMessage: null,
        ),
      );
    } on DioException catch (e) {
      if (isClosed) return;

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage:
              e.response?.data is Map
                  ? e.response?.data['message']
                          ?.toString() ??
                      'Failed to load chat data'
                  : 'Failed to load chat data',
        ),
      );
    } catch (e) {
      if (isClosed) return;

      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

// ============================================================
// GET CHAT MESSAGES
// ============================================================

Future<void> getMessages(
  String contactId, {
  int page = 1,
  int limit = 50,
}) async {
  if (isClosed) return;

  final switched = _activeContactId != contactId;

  _activeContactId = contactId;
  _activeGroupId = null;

  try {
    emit(
      state.copyWith(
        messagesLoading: true,
        messagesError: null,
        clearMessages: switched,
      ),
    );

    await initialize();

    if (isClosed) return;

    final response = await dio.get(
      '$_tenantSlug/api/chat/messages/$contactId',
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );

    if (isClosed || _activeContactId != contactId) return;

    if (response.data is Map<String, dynamic>) {
      final prefs = await SharedPreferences.getInstance();

      final currentUserId =
          prefs.getString('user_id') ?? '';

      final result = ChatMessagesResponse.fromJson(
        Map<String, dynamic>.from(
          response.data,
        ),
        currentUserId: currentUserId,
      );

      if (isClosed) return;

      emit(
        state.copyWith(
          messagesLoading: false,
          messagesResponse: result,
          messagesError: null,
        ),
      );

      markChatRead(contactId);
      _startPolling();
    } else {
      emit(
        state.copyWith(
          messagesLoading: false,
          messagesError:
              'Invalid messages response',
        ),
      );
    }
  } on DioException catch (e) {
    if (isClosed) return;

    emit(
      state.copyWith(
        messagesLoading: false,
        messagesError:
            e.response?.data is Map
                ? e.response?.data['message']
                        ?.toString() ??
                    'Failed to load messages'
                : 'Failed to load messages',
      ),
    );
  } catch (e) {
    if (isClosed) return;

    emit(
      state.copyWith(
        messagesLoading: false,
        messagesError: e.toString(),
      ),
    );
  }
}

// ============================================================
// UPLOAD CHAT FILE
// ============================================================

Future<Map<String, dynamic>?> uploadChatFile(
  PlatformFile file,
) async {
  if (isClosed) return null;

  try {
    await initialize();

    if (isClosed) return null;

    if (file.path == null) {
      throw Exception('File path not found');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        file.path!,
        filename: file.name,
      ),
    });

    final response = await dio.post(
      '$_tenantSlug/api/chat/upload',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    if (isClosed) return null;

    if (response.statusCode == 200 ||
        response.statusCode == 201) {
      if (response.data is Map) {
        return Map<String, dynamic>.from(
          response.data,
        );
      }
    }

    throw Exception('Failed to upload file');
  } on DioException catch (e) {
    if (isClosed) return null;

    emit(
      state.copyWith(
        errorMessage:
            e.response?.data is Map
                ? e.response?.data['message']
                        ?.toString() ??
                    'Failed to upload file'
                : 'Failed to upload file',
      ),
    );

    return null;
  } catch (e) {
    if (isClosed) return null;

    emit(
      state.copyWith(
        errorMessage: e.toString(),
      ),
    );

    return null;
  }
}

  // ============================================================
  // PIN / UNPIN MESSAGE
  // ============================================================

  void _setMessagePinned(String messageId, bool isPinned) {
    if (isClosed) return;

    final current = state.messagesResponse;
    if (current == null) return;

    final list = List<ChatMessageModel>.of(current.messages);
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    list[idx] = list[idx].copyWith(isPinned: isPinned);

    emit(
      state.copyWith(
        messagesResponse: ChatMessagesResponse(
          messages: list,
          page: current.page,
          limit: current.limit,
        ),
      ),
    );
  }

  Future<bool> togglePinMessage(String messageId, bool isPinned) async {
    if (isClosed) return false;

    final newValue = !isPinned;

    try {
      await initialize();

      if (isClosed) return false;

      await dio.patch(
        '$_tenantSlug/api/chat/pin/$messageId',
        data: {
          'isPinned': newValue,
        },
      );

      if (isClosed) return false;

      _setMessagePinned(messageId, newValue);
      return true;
    } on DioException catch (e) {
      if (isClosed) return false;

      emit(
        state.copyWith(
          messagesError:
              e.response?.data is Map
                  ? e.response?.data['message']
                          ?.toString() ??
                      'Failed to update pin'
                  : 'Failed to update pin',
        ),
      );

      return false;
    } catch (e) {
      if (isClosed) return false;

      emit(
        state.copyWith(
          messagesError: e.toString(),
        ),
      );

      return false;
    }
  }
  // ============================================================
  // PIN / UNPIN GROUP MESSAGE (stored on this device)
  // ============================================================

  static String _groupPinsKey(String groupId) =>
      'pinned_group_messages_$groupId';

  /// Pins are kept in pin order, so the last id is the newest pin.
  Future<bool> togglePinGroupMessage({
    required String groupId,
    required String messageId,
    required bool isPinned,
  }) async {
    if (isClosed) return false;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _groupPinsKey(groupId);

      final ids = List<String>.of(prefs.getStringList(key) ?? const [])
        ..remove(messageId);
      if (!isPinned) ids.add(messageId);

      await prefs.setStringList(key, ids);

      if (isClosed) return false;

      if (_activeGroupId == groupId) {
        _setMessagePinned(messageId, !isPinned);
      }
      return true;
    } catch (e) {
      debugPrint('Group pin failed: $e');
      return false;
    }
  }

  // ============================================================
  // MARK AS READ (DIRECT / GROUP)
  // ============================================================

  /// The backend hasn't confirmed which HTTP method its `/read` routes use,
  /// so try the likely ones and remember the first that the server accepts
  /// (shared by every ChatCubit for the rest of the app session).
  static String? _readMethod;
  static const _kReadMethods = ['PATCH', 'PUT', 'POST'];

  /// Zeroes the badge right away, then tells the server and refreshes the
  /// total unread count. If the server call fails, the next contacts/groups
  /// fetch will show the server's real count again.
  Future<void> _markRead({
    required String path,
    required void Function() clearLocalBadge,
  }) async {
    if (isClosed) return;

    clearLocalBadge();

    try {
      await initialize();

      if (isClosed) return;

      final known = _readMethod;
      final methods = known != null ? [known] : _kReadMethods;

      for (var i = 0; i < methods.length; i++) {
        try {
          final response = await dio.request(
            '$_tenantSlug$path',
            options: Options(method: methods[i]),
          );
          if (_readMethod == null) {
            debugPrint(
              'Mark read works with ${methods[i]} '
              '-> ${response.statusCode} ${response.data}',
            );
          }
          _readMethod = methods[i];
          break;
        } on DioException catch (e) {
          // 404/405 = no such route for this method; try the next one.
          final code = e.response?.statusCode;
          final wrongMethod = code == 404 || code == 405;
          if (!wrongMethod || i == methods.length - 1) rethrow;
        }
      }

      if (isClosed) return;

      await getUnreadCount();
    } on DioException catch (e) {
      debugPrint(
        'Mark read failed [${e.response?.statusCode}] $path\n'
        '${e.response?.data ?? e.message}',
      );
    } catch (e) {
      debugPrint('Mark read failed: $e');
    }
  }

  Future<void> markChatRead(String contactId) => _markRead(
        path: '/api/chat/messages/$contactId/read',
        clearLocalBadge: () {
          final current = state.contactsResponse;
          if (current == null ||
              !current.contacts
                  .any((c) => c.id == contactId && c.unreadCount > 0)) {
            return;
          }

          emit(
            state.copyWith(
              contactsResponse: ContactsResponse(
                contacts: [
                  for (final c in current.contacts)
                    c.id == contactId ? c.copyWith(unreadCount: 0) : c,
                ],
              ),
            ),
          );
        },
      );

  Future<void> markGroupRead(String groupId) => _markRead(
        path: '/api/groups/$groupId/read',
        clearLocalBadge: () {
          final current = state.groupsResponse;
          if (current == null ||
              !current.groups
                  .any((g) => g.id == groupId && g.unreadCount > 0)) {
            return;
          }

          emit(
            state.copyWith(
              groupsResponse: GroupsResponse(
                groups: [
                  for (final g in current.groups)
                    g.id == groupId ? g.copyWith(unreadCount: 0) : g,
                ],
              ),
            ),
          );
        },
      );
  //
  // 
  //
  // ============================================================
  // CLEAR CHAT (DIRECT / GROUP)
  // ============================================================

  void _clearOpenMessages() {
    if (isClosed) return;

    final current = state.messagesResponse;

    emit(
      state.copyWith(
        messagesResponse: ChatMessagesResponse(
          messages: const [],
          page: current?.page ?? 1,
          limit: current?.limit ?? 50,
        ),
      ),
    );
  }

  /// [isOpen] is whether the chat being cleared is the one on screen; the
  /// list's ⋮ menu can clear a chat that isn't open, and that must not
  /// wipe the open conversation. [clearPreview] drops the list row's
  /// last-message preview.
  Future<bool> _clear(
    String path,
    String fallbackError, {
    required bool isOpen,
    required void Function() clearPreview,
  }) async {
    if (isClosed) return false;

    try {
      await initialize();

      if (isClosed) return false;

      await dio.delete('$_tenantSlug$path');

      if (isClosed) return false;

      if (isOpen) _clearOpenMessages();
      clearPreview();
      return true;
    } on DioException catch (e) {
      if (isClosed || !isOpen) return false;

      emit(
        state.copyWith(
          messagesError:
              e.response?.data is Map
                  ? e.response?.data['message']
                          ?.toString() ??
                      fallbackError
                  : fallbackError,
        ),
      );

      return false;
    } catch (e) {
      if (isClosed || !isOpen) return false;

      emit(
        state.copyWith(
          messagesError: e.toString(),
        ),
      );

      return false;
    }
  }

  Future<bool> clearGroupChat(String groupId) async {
    final success = await _clear(
      '/api/groups/$groupId/clear',
      'Failed to clear group chat',
      isOpen: _activeGroupId == groupId,
      clearPreview: () {
        final current = state.groupsResponse;
        if (current == null) return;
        emit(
          state.copyWith(
            groupsResponse: GroupsResponse(
              groups: [
                for (final g in current.groups)
                  g.id == groupId
                      ? g.copyWith(unreadCount: 0, clearLastMessage: true)
                      : g,
              ],
            ),
          ),
        );
      },
    );

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_groupPinsKey(groupId));
    }

    return success;
  }

  /// Also used by the list's "Delete chat": the backend's delete for a
  /// direct chat is this same endpoint.
  Future<bool> clearChat(String userId) => _clear(
        '/api/chat/clear/$userId',
        'Failed to clear chat',
        isOpen: _activeContactId == userId,
        clearPreview: () {
          final current = state.contactsResponse;
          if (current == null) return;
          emit(
            state.copyWith(
              contactsResponse: ContactsResponse(
                contacts: [
                  for (final c in current.contacts)
                    c.id == userId
                        ? c.copyWith(unreadCount: 0, clearLastMessage: true)
                        : c,
                ],
              ),
            ),
          );
        },
      );

  // ============================================================
  // PIN / UNPIN GROUP CHAT IN THE LIST (stored on this device —
  // there is no backend API for this yet)
  // ============================================================

  String get _pinnedGroupsKey => 'pinned_group_chats_$_currentUserId';

  Future<void> loadPinnedGroups() async {
    if (isClosed) return;
    try {
      await initialize();
      final prefs = await SharedPreferences.getInstance();
      if (isClosed) return;
      emit(state.copyWith(
        pinnedGroupIds: prefs.getStringList(_pinnedGroupsKey) ?? const [],
      ));
    } catch (e) {
      debugPrint('Load pinned groups failed: $e');
    }
  }

  /// Newest pin goes first.
  Future<void> toggleGroupChatPin(String groupId) async {
    if (isClosed) return;

    final ids = List<String>.of(state.pinnedGroupIds);
    if (!ids.remove(groupId)) ids.insert(0, groupId);
    emit(state.copyWith(pinnedGroupIds: ids));

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_pinnedGroupsKey, ids);
    } catch (e) {
      debugPrint('Save pinned groups failed: $e');
    }
  }

  // ============================================================
  // SOCKET CONNECTION
  // ============================================================

  Future<void> connectSocket() async {
    if (isClosed || _socket != null) return;

    await initialize();

    if (isClosed) return;

    final prefs = await SharedPreferences.getInstance();

    final token = prefs.getString('token') ?? '';
    final userId = prefs.getString('user_id') ?? '';
    final userName = prefs.getString('user_name') ?? '';

    if (token.isEmpty || userId.isEmpty) return;

    _currentUserId = userId;
    _currentUserName = userName;

    String dbName = '';
    try {
      final decoded = JwtDecoder.decode(token);
      dbName = decoded['dbName']?.toString() ?? '';
    } catch (_) {}

    if (dbName.isEmpty) {
      dbName = 'crm_$_tenantSlug';
    }

    _dbName = dbName;

    if (isClosed) return;

    _socket = io.io(
      'https://crm-backend-api.techzarinfo.cloud',
      io.OptionBuilder()
          .setTransports(['websocket'])
          // io.io() caches sockets per server; without this, reopening the
          // Messages screen gets back the socket disposed last time and
          // silently receives nothing.
          .enableForceNew()
          .disableAutoConnect()
          .setAuth({
            'userId': userId,
            'dbName': dbName,
            'name': userName,
          })
          .build(),
    );

    _socket!.onConnectError((e) => debugPrint('Chat socket connect error: $e'));
    _socket!.onError((e) => debugPrint('Chat socket error: $e'));
    _socket!.onDisconnect((reason) =>
        debugPrint('Chat socket disconnected: $reason'));

    _socket!.on('chat:message_sent', _handleMessageSent);
    _socket!.on('chat:message', _handleIncomingMessage);
    _socket!.on(_kGroupSentEvent, _handleMessageSent);
    _socket!.on(_kGroupMessageEvent, _handleIncomingGroupMessage);
    _socket!.on(_kGroupDeletedEvent, _handleGroupMessageDeleted);

    // Re-join the open group's room after a reconnect.
    _socket!.onConnect((_) {
      debugPrint('Chat socket connected (${_socket?.id})');
      final groupId = _activeGroupId;
      if (groupId != null) _joinGroupRoom(groupId);
    });

    _socket!.connect();
  }

  // Group socket events — mirror the direct-chat `chat:*` naming.
  // Adjust here if the backend uses different names.
  static const _kGroupJoinEvent = 'group:join';
  static const _kGroupSendEvent = 'group:send';
  static const _kGroupSentEvent = 'group:message_sent';
  static const _kGroupMessageEvent = 'group:message';
  static const _kGroupDeleteEvent = 'group:delete';
  static const _kGroupDeletedEvent = 'group:deleted';

  void _joinGroupRoom(String groupId) {
    _socket?.emit(_kGroupJoinEvent, {
      'groupId': groupId,
      'dbName': _dbName,
    });
  }

  // ============================================================
  // DELETE GROUP MESSAGE (socket only — no REST endpoint)
  // ============================================================

  /// Asks the backend to delete a group message. The UI updates when the
  /// backend broadcasts `group:deleted` back to the room (including us).
  bool deleteGroupMessage({
    required String messageId,
    required String groupId,
  }) {
    if (isClosed) return false;

    final socket = _socket;
    if (socket == null || !socket.connected) {
      emit(
        state.copyWith(
          messagesError: 'Not connected. Please try again.',
        ),
      );
      return false;
    }

    socket.emit(_kGroupDeleteEvent, {
      'messageId': messageId,
      'groupId': groupId,
      'dbName': _dbName,
    });
    return true;
  }

  void _handleGroupMessageDeleted(dynamic data) {
    if (isClosed) return;
    if (data is! Map) return;

    final groupId = data['groupId']?.toString();
    final messageId = data['messageId']?.toString();
    if (messageId == null || groupId != _activeGroupId) return;

    _markMessageDeleted(messageId);
  }

  void _handleIncomingGroupMessage(dynamic data) {
    if (isClosed) return;
    try {
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);

      final groupId = map['groupId']?.toString();
      if (_activeGroupId == null || groupId != _activeGroupId) return;

      final message = ChatMessageModel.fromJson(
        map,
        currentUserId: _currentUserId,
      );

      // The room broadcast also reaches the sender; swap it in for the
      // optimistic copy instead of showing the message twice.
      var tempId = map['tempId']?.toString();
      if (tempId == null && message.isMe) {
        final pending = state.messagesResponse?.messages.where(
          (m) =>
              m.id.startsWith('temp-') &&
              m.message == message.message &&
              m.fileName == message.fileName,
        );
        if (pending != null && pending.isNotEmpty) {
          tempId = pending.first.id;
        }
      }

      _upsertMessage(message, tempId: tempId);

      // The user is looking at this group, so it's already read.
      if (!message.isMe) markGroupRead(groupId!);
    } catch (e) {
      debugPrint('Chat socket payload not handled: $e');
    }
  }

  void disconnectSocket() {
    _socket?.dispose();
    _socket = null;
  }

  void _handleMessageSent(dynamic data) {
    if (isClosed) return;
    try {
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final tempId = map['tempId']?.toString();

      // This ack is only ever for a message *I* sent — isMe is always true
      // here regardless of what the ack payload's senderId field says.
      final parsed = ChatMessageModel.fromJson(
        map,
        currentUserId: _currentUserId,
      );
      final message = parsed.copyWith(isMe: true);

      _upsertMessage(message, tempId: tempId);
    } catch (e) {
      debugPrint('Chat socket payload not handled: $e');
    }
  }

  void _handleIncomingMessage(dynamic data) {
    if (isClosed) return;
    debugPrint('Chat socket <- chat:message $data');
    try {
      if (data is! Map) return;
      final map = Map<String, dynamic>.from(data);
      final message = ChatMessageModel.fromJson(
        map,
        currentUserId: _currentUserId,
      );

      final activeId = _activeContactId;
      final isOpen = activeId != null &&
          (message.senderId == activeId || message.receiverId == activeId);

      if (!isOpen) {
        if (!message.isMe) _bumpContactUnread(message);
        return;
      }

      _upsertMessage(message);

      // The user is looking at this chat, so it's already read.
      if (!message.isMe) markChatRead(activeId);
    } catch (e) {
      debugPrint('Chat socket payload not handled: $e');
    }
  }

  /// A direct message arrived for a chat that isn't open: move it to the
  /// top of the list with a +1 badge and refresh the total.
  void _bumpContactUnread(ChatMessageModel message) {
    final current = state.contactsResponse;
    if (current == null) return;

    final idx = current.contacts.indexWhere((c) => c.id == message.senderId);
    if (idx < 0) {
      // Someone new — only the server knows their details.
      getContacts();
      return;
    }

    final contact = current.contacts[idx];
    final updated = contact.copyWith(
      unreadCount: contact.unreadCount + 1,
      lastMessage: LastMessageModel(
        message: message.message,
        fileType: message.fileType,
        fileName: message.fileName,
        createdAt: message.createdAt,
        isRead: false,
      ),
    );

    emit(
      state.copyWith(
        contactsResponse: ContactsResponse(
          contacts: [
            updated,
            for (final c in current.contacts)
              if (c.id != contact.id) c,
          ],
        ),
      ),
    );

    getUnreadCount();
  }

  /// Call when the user leaves a chat, so later messages count as unread.
  void closeConversation() {
    _activeContactId = null;
    _activeGroupId = null;
    _stopPolling();
  }

  // ============================================================
  // POLLING FALLBACK
  // ============================================================
  // The socket should deliver messages instantly, but if it's down or the
  // server doesn't emit to this user, the open chat would only update on a
  // manual refresh. So while a chat is open, quietly re-fetch it every few
  // seconds and merge anything new.

  static const _kPollInterval = Duration(seconds: 3);

  Timer? _pollTimer;
  bool _pollInFlight = false;

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_kPollInterval, (_) => _pollActiveChat());
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollActiveChat() async {
    final contactId = _activeContactId;
    final groupId = _activeGroupId;
    if (isClosed || _pollInFlight || (contactId == null && groupId == null)) {
      return;
    }
    // Don't fight the initial load.
    if (state.messagesLoading) return;

    _pollInFlight = true;
    try {
      await initialize();

      final response = await dio.get(
        contactId != null
            ? '$_tenantSlug/api/chat/messages/$contactId'
            : '$_tenantSlug/api/groups/$groupId/messages',
        queryParameters: {'page': 1, 'limit': 50},
      );

      // User switched chats while this was in flight.
      if (isClosed ||
          contactId != _activeContactId ||
          groupId != _activeGroupId) {
        return;
      }

      final data = response.data;
      final Map<String, dynamic>? json = data is Map
          ? Map<String, dynamic>.from(data)
          : data is List
              ? {'messages': data}
              : null;
      if (json == null) return;

      final fetched = ChatMessagesResponse.fromJson(
        json,
        currentUserId: _currentUserId,
      ).messages;

      final current = state.messagesResponse;
      final existing = current?.messages ?? const <ChatMessageModel>[];
      final byId = {for (final m in existing) m.id: m};

      var changed = false;
      var receivedNew = false;

      for (final m in fetched) {
        final old = byId[m.id];
        if (old == null) {
          changed = true;
          if (!m.isMe) receivedNew = true;
          // Group pins are local-only; everything else comes from the server.
          byId[m.id] = m;
        } else if (_differs(old, m)) {
          changed = true;
          byId[m.id] = groupId != null ? m.copyWith(isPinned: old.isPinned) : m;
        }
      }

      // A "sending…" copy whose real message has now arrived.
      final sentTexts = fetched
          .where((m) => m.isMe)
          .map((m) => '${m.message}|${m.fileName}')
          .toSet();
      byId.removeWhere((id, m) {
        final done = id.startsWith('temp-') &&
            sentTexts.contains('${m.message}|${m.fileName}');
        if (done) changed = true;
        return done;
      });

      if (!changed) return;

      final merged = byId.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      emit(
        state.copyWith(
          messagesResponse: ChatMessagesResponse(
            messages: merged,
            page: current?.page ?? 1,
            limit: current?.limit ?? 50,
          ),
        ),
      );

      // The user is looking at this chat, so new messages are already read.
      if (receivedNew) {
        if (contactId != null) {
          markChatRead(contactId);
        } else {
          markGroupRead(groupId!);
        }
      }
    } catch (e) {
      debugPrint('Chat poll failed: $e');
    } finally {
      _pollInFlight = false;
    }
  }

  static bool _differs(ChatMessageModel a, ChatMessageModel b) =>
      a.message != b.message ||
      a.isDeleted != b.isDeleted ||
      a.isRead != b.isRead ||
      a.reactions.length != b.reactions.length ||
      !a.reactions.every(
        (r) => b.reactions.any((x) => x.userId == r.userId && x.emoji == r.emoji),
      );

  void _upsertMessage(ChatMessageModel message, {String? tempId}) {
    if (isClosed) return;

    final current = state.messagesResponse;
    final list = List<ChatMessageModel>.of(current?.messages ?? const []);
    final matchId = tempId ?? message.id;
    final idx = list.indexWhere((m) => m.id == matchId);

    if (idx >= 0) {
      // Socket payloads don't know about local group pins; keep them.
      list[idx] = list[idx].isPinned && !message.isPinned
          ? message.copyWith(isPinned: true)
          : message;
    } else {
      list.add(message);
    }

    emit(
      state.copyWith(
        messagesResponse: ChatMessagesResponse(
          messages: list,
          page: current?.page ?? 1,
          limit: current?.limit ?? 50,
        ),
      ),
    );
  }


  // Marks isDeleted true (same flag the backend uses) so the message renders
  // as a "This message was deleted" placeholder instead of disappearing.
  void _markMessageDeleted(String messageId) {
    if (isClosed) return;

    final current = state.messagesResponse;
    if (current == null) return;

    final list = List<ChatMessageModel>.of(current.messages);
    final idx = list.indexWhere((m) => m.id == messageId);
    if (idx < 0) return;

    list[idx] = list[idx].copyWith(isDeleted: true);

    emit(
      state.copyWith(
        messagesResponse: ChatMessagesResponse(
          messages: list,
          page: current.page,
          limit: current.limit,
        ),
      ),
    );
  }

  // ============================================================
  // DELETE MESSAGE (for everyone)
  // ============================================================

  Future<bool> deleteMessageForEveryone(String messageId) async {
    if (isClosed) return false;

    try {
      await initialize();

      if (isClosed) return false;

      await dio.delete(
        '$_tenantSlug/api/chat/messages/$messageId',
      );

      if (isClosed) return false;

      _markMessageDeleted(messageId);
      return true;
    } on DioException catch (e) {
      if (isClosed) return false;

      emit(
        state.copyWith(
          messagesError:
              e.response?.data is Map
                  ? e.response?.data['message']
                          ?.toString() ??
                      'Failed to delete message'
                  : 'Failed to delete message',
        ),
      );

      return false;
    } catch (e) {
      if (isClosed) return false;

      emit(
        state.copyWith(
          messagesError: e.toString(),
        ),
      );

      return false;
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  void sendMessage({
    required String receiverId,
    required String message,
    String? fileUrl,
    String? fileName,
    String? fileType,
    String? replyToId,
    String? replyToMessage,
    String? replyToSenderName,
  }) {
    if (isClosed) return;

    final payload = _addOptimisticMessage(
      targetId: receiverId,
      message: message,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      replyToId: replyToId,
      replyToMessage: replyToMessage,
      replyToSenderName: replyToSenderName,
    );

    _socket?.emit('chat:send', {
      'receiverId': receiverId,
      ...payload,
    });
  }

  // ============================================================
  // LEAVE GROUP
  // ============================================================

  /// Returns null on success, or the error message to show.
  Future<String?> leaveGroup(String groupId) async {
    if (isClosed) return null;

    try {
      await initialize();

      if (isClosed) return null;

      await dio.delete(
        '$_tenantSlug/api/groups/$groupId/leave',
      );

      if (isClosed) return null;

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_groupPinsKey(groupId));

      if (isClosed) return null;

      final leavingOpenGroup = _activeGroupId == groupId;
      if (leavingOpenGroup) _activeGroupId = null;

      final groups = state.groupsResponse;

      emit(
        state.copyWith(
          groupsResponse: groups == null
              ? null
              : GroupsResponse(
                  groups: groups.groups.where((g) => g.id != groupId).toList(),
                ),
          clearMessages: leavingOpenGroup,
        ),
      );

      return null;
    } on DioException catch (e) {
      debugPrint(
        'Leave group failed [${e.response?.statusCode}] '
        '${e.response?.data ?? e.message}',
      );

      final data = e.response?.data;
      return (data is Map ? data['message']?.toString() : null) ??
          'Failed to leave group';
    } catch (e) {
      debugPrint('Leave group failed: $e');
      return e.toString();
    }
  }
  // ============================================================
  // SEND GROUP MESSAGE
  // ============================================================

  void sendGroupMessage({
    required String groupId,
    required String message,
    String? fileUrl,
    String? fileName,
    String? fileType,
    String? replyToId,
    String? replyToMessage,
    String? replyToSenderName,
  }) {
    if (isClosed) return;

    final payload = _addOptimisticMessage(
      targetId: groupId,
      message: message,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      replyToId: replyToId,
      replyToMessage: replyToMessage,
      replyToSenderName: replyToSenderName,
    );

    _socket?.emit(_kGroupSendEvent, {
      'groupId': groupId,
      'dbName': _dbName,
      ...payload,
    });
  }

  /// Shows the message immediately under a temp id and returns the shared
  /// socket payload (without the receiver/group id).
  Map<String, dynamic> _addOptimisticMessage({
    required String targetId,
    required String message,
    String? fileUrl,
    String? fileName,
    String? fileType,
    String? replyToId,
    String? replyToMessage,
    String? replyToSenderName,
  }) {
    final tempId = 'temp-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();

    final replyTo = replyToId != null
        ? ChatReplyModel(
            messageId: replyToId,
            message: replyToMessage ?? '',
            senderName: replyToSenderName ?? '',
          )
        : null;

    final optimistic = ChatMessageModel(
      id: tempId,
      senderId: _currentUserId,
      receiverId: targetId,
      senderName: _currentUserName,
      senderRole: '',
      message: message,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      isMe: true,
      isRead: false,
      isPinned: false,
      isDeleted: false,
      replyTo: replyTo,
      reactions: const [],
      createdAt: now,
      updatedAt: now,
    );

    _upsertMessage(optimistic);

    return {
      'message': message,
      'tempId': tempId,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (fileName != null) 'fileName': fileName,
      if (fileType != null) 'fileType': fileType,
      if (replyTo != null) 'replyTo': replyTo.toJson(),
    };
  }

  @override
  Future<void> close() {
    _stopPolling();
    disconnectSocket();
    return super.close();
  }
}