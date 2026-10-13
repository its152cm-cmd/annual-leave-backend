// Simulates the chat list and invitation backend. Returns raw JSON data.

import 'mock_chat_list.dart';

class ChatListMockDataSource {
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final list =
        mockChatListData['conversations'] as List<dynamic>? ?? const [];
    return list.map((json) => Map<String, dynamic>.from(json as Map)).toList();
  }

  Future<List<Map<String, dynamic>>> fetchInvitations() async {
    final list = mockChatListData['invitations'] as List<dynamic>? ?? const [];
    return list.map((json) => Map<String, dynamic>.from(json as Map)).toList();
  }

  Future<bool> createConversation(Map<String, dynamic> conversation) async {
    final conversations = List<dynamic>.from(
      mockChatListData['conversations'] as List<dynamic>? ?? const [],
    );
    final groupId = conversation['groupId'] as String;
    if (conversations.any(
      (entry) => (entry as Map<String, dynamic>)['groupId'] == groupId,
    )) {
      return false;
    }

    conversations.insert(0, conversation);
    mockChatListData['conversations'] = conversations;
    return true;
  }

  Future<bool> acceptInvitation(String invitationId) async {
    final invitations = List<dynamic>.from(
      mockChatListData['invitations'] as List<dynamic>? ?? const [],
    );
    final invitation = invitations.cast<Map<String, dynamic>>().firstWhere(
      (entry) => entry['id'] == invitationId,
      orElse: () => <String, dynamic>{},
    );
    if (invitation.isEmpty) return false;

    final groupId = invitation['groupId'] as String? ?? '';
    final conversations = List<dynamic>.from(
      mockChatListData['conversations'] as List<dynamic>? ?? const [],
    );
    if (groupId.isNotEmpty &&
        !conversations.any(
          (entry) => (entry as Map<String, dynamic>)['groupId'] == groupId,
        )) {
      conversations.insert(0, {
        'groupId': groupId,
        'title': invitation['tripTitle'] as String? ?? 'Trip Chat',
        'destination': invitation['destination'] as String? ?? '',
        'lastMessage': 'Welcome to the group chat.',
        'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
        'unreadCount': 0,
        'avatarUrl': invitation['hostAvatar'] as String? ?? '',
        'isLiveSync': true,
      });
      mockChatListData['conversations'] = conversations;
    }

    mockChatListData['invitations'] = invitations
        .where((entry) => (entry as Map<String, dynamic>)['id'] != invitationId)
        .toList();
    return true;
  }

  Future<bool> declineInvitation(String invitationId) async {
    final invitations = List<dynamic>.from(
      mockChatListData['invitations'] as List<dynamic>? ?? const [],
    );
    final filtered = invitations
        .where((entry) => (entry as Map<String, dynamic>)['id'] != invitationId)
        .toList();
    final changed = filtered.length != invitations.length;
    mockChatListData['invitations'] = filtered;
    return changed;
  }
}
