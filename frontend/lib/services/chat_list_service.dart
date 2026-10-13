// lib/services/chat_list_service.dart

import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../mock/mock_chat_list.dart';
import '../mock/mock_chat_list_data_source.dart';
import '../models/chat_conversation.dart';
import '../models/group_member.dart';
import '../models/trip.dart';
import '../models/trip_invitation.dart';
import 'account_service.dart';
import 'group_chat_service.dart';
import 'expense_service.dart';
import 'group_summary_service.dart';
import 'trip_service.dart';

class ChatListService {
  static final ValueNotifier<int> conversationsRevision = ValueNotifier(0);

  ChatListService({ChatListMockDataSource? dataSource})
    : _dataSource = dataSource ?? ChatListMockDataSource();

  final ChatListMockDataSource _dataSource;
  final GroupChatService _groupChatService = GroupChatService();
  final GroupSummaryService _groupSummaryService = GroupSummaryService();
  final AccountService _accountService = AccountService();

  Future<String> createTripGroupChat(Trip trip) async {
    final groupId = 'trip_${trip.id}';
    final created = await _dataSource.createConversation({
      'groupId': groupId,
      'tripId': trip.id,
      'title': trip.destination.isEmpty
          ? 'New Group Trip'
          : '${trip.destination} Group Chat',
      'destination': trip.destination,
      'lastMessage': 'Group chat for ${trip.dateRange}',
      'lastMessageTime': DateTime.now().toUtc().toIso8601String(),
      'unreadCount': 0,
      'avatarUrl': trip.imageUrl,
      'isLiveSync': true,
    });
    _groupChatService.ensureGroup(groupId);
    await _groupSummaryService.createTripGroup(groupId: groupId, trip: trip);
    if ((await _groupSummaryService.getGroupMembers(groupId)).isEmpty) {
      final currentUser = await _accountService.getCurrentUser();
      if (currentUser != null) {
        await _groupSummaryService.addGroupMember(
          groupId,
          GroupMember(
            id: 'user_me',
            name: currentUser.name,
            role: 'Host',
            avatarUrl: currentUser.avatarUrl,
            isMe: true,
            leaveBalanceSummary: '',
          ),
        );
      }
      // Invited people join the list only after they accept (see syncMembers).
    }
    if (created) conversationsRevision.value++;
    return groupId;
  }

  /// Brings the group chats saved on the server back after an app restart.
  Future<void> _restoreSavedChats() async {
    if (ApiClient.sessionToken == null) return; // signed out: nothing to load
    try {
      final response = await ApiClient().get('/api/chats');
      for (final raw in (response as List)) {
        final chat = Map<String, dynamic>.from(raw as Map);
        final groupId = chat['groupId'] as String;
        final tripId = chat['tripId'] as String;
        final created = await _dataSource.createConversation(chat);
        if (!created) {
          // keep the list's preview and time up to date with saved messages
          for (final entry in (mockChatListData['conversations'] as List)) {
            final existing = entry as Map<String, dynamic>;
            if (existing['groupId'] == groupId) {
              existing['lastMessage'] = chat['lastMessage'];
              existing['lastMessageTime'] = chat['lastMessageTime'];
              existing['title'] = chat['title'];
            }
          }
        }
        _groupChatService.ensureGroup(groupId);
        if (created) {
          Trip trip;
          try {
            trip = await TripService().getTrip(tripId);
          } catch (_) {
            trip = Trip(
              id: tripId,
              destination: chat['destination'] as String? ?? '',
              dateRange: '',
              duration: '',
              budget: '',
              imageUrl: chat['avatarUrl'] as String? ?? '',
              status: 'draft',
            );
          }
          await _groupSummaryService.createTripGroup(
            groupId: groupId,
            trip: trip,
          );
        }
        // Always refresh the people and the name: someone may have accepted
        // or renamed the chat since last time.
        await _groupSummaryService.syncMembers(groupId);
      }
    } catch (e) {
      debugPrint('[chats] $e');
    }
  }

  Future<List<ChatConversation>> getConversations() async {
    await _restoreSavedChats();
    // Only chats that belong to the signed-in account (no sample chats).
    final list = (await _dataSource.fetchConversations())
        .where((c) => ExpenseService.isSavedGroup(c['groupId'] as String? ?? ''))
        .toList();
    final account = await _accountService.getCurrentUser();
    final readerId = account?.userId.trim().isNotEmpty == true
        ? account!.userId.trim()
        : 'signed_out';
    return Future.wait(
      list.map((json) async {
        final groupId = json['groupId'] as String;
        final members = await _groupChatService.getGroupMembers(groupId);
        final senderId =
            members.where((member) => member.isMe).firstOrNull?.id ?? 'user_me';
        final unreadCount = await _groupChatService.getUnreadMessageCount(
          groupId: groupId,
          readerId: readerId,
          senderId: senderId,
        );
        return ChatConversation.fromJson({...json, 'unreadCount': unreadCount});
      }),
    );
  }

  Future<bool> hasGroupChatForTrip(Trip trip) async {
    if (trip.generatedFromGroupChat) return true;
    final conversations = await _dataSource.fetchConversations();
    final tripGroupId = 'trip_${trip.id}';
    return conversations.any(
      (conversation) => conversation['groupId'] == tripGroupId,
    );
  }

  Future<List<TripInvitation>> getPendingInvitations() async {
    if (ApiClient.sessionToken == null) return [];
    try {
      final response = await ApiClient().get('/api/invitations');
      return (response as List)
          .map(
            (json) =>
                TripInvitation.fromJson(Map<String, dynamic>.from(json as Map)),
          )
          .toList();
    } catch (e) {
      debugPrint('[invitations] $e');
      return [];
    }
  }

  Future<bool> acceptInvitation(String invitationId) async {
    try {
      await ApiClient().post('/api/invitations/$invitationId/accept');
      await _restoreSavedChats(); // so the chat is ready to open
      TripService.tripListRevision.value++; // and the trip shows in Trips
      conversationsRevision.value++;
      return true;
    } catch (e) {
      debugPrint('[invitations] $e');
      return false;
    }
  }

  Future<bool> declineInvitation(String invitationId) async {
    try {
      await ApiClient().post('/api/invitations/$invitationId/decline');
      return true;
    } catch (e) {
      debugPrint('[invitations] $e');
      return false;
    }
  }
}
