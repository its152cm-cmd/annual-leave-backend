import 'dart:convert';
import 'dart:typed_data';
// lib/services/group_chat_service.dart

import '../core/api/api_client.dart';
import '../mock/mock_group_chat_data_source.dart';
import '../models/chat_message.dart';
import '../models/group_member.dart';
import '../models/group_poll.dart';
import 'group_planning_service.dart';
import 'group_summary_service.dart';

class GroupChatService {
  GroupChatService({GroupChatMockDataSource? dataSource})
    : _dataSource = dataSource ?? GroupChatMockDataSource();

  final GroupChatMockDataSource _dataSource;
  final GroupSummaryService _summaryService = GroupSummaryService();

  void ensureGroup(String groupId) => _dataSource.ensureGroup(groupId);

  /// Saved messages of a real group chat (oldest first), or null if this is
  /// not a saved group or the server cannot be reached.
  Future<List<Map<String, dynamic>>?> _savedMessages(String groupId) async {
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId == null || ApiClient.sessionToken == null) return null;
    try {
      final r = await ApiClient().get('/api/chats/$tripId/messages');
      return (r as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }

  Future<List<ChatMessage>> getChatMessages(String groupId) async {
    final saved = await _savedMessages(groupId);
    final rawMessages = saved == null
        ? await _dataSource.fetchMessages(groupId)
        : [
            for (final m in saved)
              {
                ...m,
                // the screen knows the signed-in person as 'user_me'
                if (m['isMine'] == true) 'senderId': 'user_me',
              },
          ];
    final members = await _summaryService.getGroupMembers(groupId);
    final membersById = {for (final member in members) member.id: member};

    return rawMessages.map((json) {
      final member = membersById[json['senderId']];
      return ChatMessage.fromJson({
        ...json,
        if (member != null) 'senderName': member.name,
        if (member != null) 'senderAvatar': member.avatarUrl,
      });
    }).toList();
  }

  Future<int> getUnreadMessageCount({
    required String groupId,
    required String readerId,
    required String senderId,
  }) async {
    final messages = await _dataSource.fetchMessages(groupId);
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId != null && ApiClient.sessionToken != null) {
      try {
        final r = await ApiClient().get('/api/chats/$tripId/unread');
        return (r as Map)['unread'] as int? ?? 0;
      } catch (_) {}
    }
    final lastReadId = _dataSource.getLastReadMessageId(groupId, readerId);
    final lastReadIndex = lastReadId == null
        ? -1
        : messages.indexWhere((message) => message['id'] == lastReadId);
    return messages
        .skip(lastReadIndex + 1)
        .where((message) => message['senderId'] != senderId)
        .length;
  }

  Future<void> markMessagesRead({
    required String groupId,
    required String readerId,
    required String throughMessageId,
  }) async {
    _dataSource.markMessagesRead(
      groupId: groupId,
      readerId: readerId,
      throughMessageId: throughMessageId,
    );
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId != null && ApiClient.sessionToken != null) {
      try {
        await ApiClient().post('/api/chats/$tripId/read');
      } catch (_) {}
    }
  }

  static const _pollPrefix = 'section:';
  static const _aiPollPrefix = 'ai:';
  static const _sectionTitles = {
    'Accommodation': 'Vote: Accommodation',
    'Flights': 'Vote: Flights',
    'Food': 'Vote: Food',
    'Activities': 'Vote: Activities',
  };

  /// One poll per section (Accommodation, Flights, Food, Activities) built
  /// from what members shared. It appears as soon as something is shared.
  Future<List<GroupPoll>> _sharedPolls(String groupId) async {
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId == null) return [];
    try {
      final shares = await GroupPlanningService().getShares(tripId);
      final polls = <GroupPoll>[];
      for (final entry in _sectionTitles.entries) {
        final items = shares.where((s) => s['section'] == entry.key).toList();
        if (items.isEmpty) continue;
        polls.add(
          GroupPoll(
            id: '$_pollPrefix${entry.key}',
            question: entry.value,
            options: [
              for (final s in items)
                PollOption(
                  id: s['id'] as String,
                  text: s['title'] as String,
                  voteCount: (s['voterIds'] as List).length,
                  votedUserIds: List<String>.from(s['voterIds'] as List),
                ),
            ],
          ),
        );
      }
      return polls;
    } catch (_) {
      return [];
    }
  }

  GroupPoll _aiPollFromJson(Map<String, dynamic> j) => GroupPoll(
    id: '$_aiPollPrefix${j['id']}',
    question: j['question'] as String,
    options: [
      for (final o in (j['options'] as List).cast<Map>())
        PollOption(
          id: o['id'] as String,
          text: o['text'] as String,
          voteCount: (o['voterIds'] as List).length,
          votedUserIds: List<String>.from(o['voterIds'] as List),
        ),
    ],
  );

  /// Polls the AI started by itself from the chat (it reads the chat when
  /// the conversation pauses). The server starts the reading when this is
  /// asked for, so the regular refresh is all that is needed.
  Future<List<GroupPoll>> _aiPolls(String groupId) async {
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId == null || ApiClient.sessionToken == null) return [];
    try {
      final r = await ApiClient().get('/api/chats/$tripId/polls');
      final polls = (r as List)
          .map((e) => _aiPollFromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      return polls.reversed.toList(); // newest first
    } catch (_) {
      return [];
    }
  }

  /// Host only: finish a poll so it leaves the top of the chat.
  Future<void> closePoll(String groupId, String pollId) async {
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId == null || !pollId.startsWith(_aiPollPrefix)) return;
    await ApiClient().post(
      '/api/chats/$tripId/polls/${pollId.substring(_aiPollPrefix.length)}/close',
    );
  }

  Future<List<GroupPoll>> getActivePolls(String groupId) async {
    final rawPolls = await _dataSource.fetchPolls(groupId);
    final manual = rawPolls
        .map((json) => GroupPoll.fromJson(json))
        .where((poll) => !poll.isClosed)
        .toList();
    return [
      ...await _aiPolls(groupId),
      ...await _sharedPolls(groupId),
      ...manual,
    ];
  }

  Future<GroupPoll> addPoll(String groupId, GroupPoll poll) async {
    await _dataSource.savePoll(groupId, poll.toJson());
    return poll;
  }

  Future<bool> addGroupMember(
    dynamic groupIdOrMember, [
    GroupMember? maybeMember,
  ]) {
    if (groupIdOrMember is GroupMember) {
      return _summaryService.addGroupMember('group_kyoto_1', groupIdOrMember);
    }

    final groupId = groupIdOrMember as String;
    final member =
        maybeMember ??
        (throw ArgumentError.value(
          groupIdOrMember,
          'member',
          'A member must be provided when adding a group member.',
        ));
    return _summaryService.addGroupMember(groupId, member);
  }

  Future<bool> removeGroupMember({
    required String groupId,
    required String requesterId,
    required String memberId,
  }) async {
    final removed = await _summaryService.removeGroupMember(
      groupId: groupId,
      requesterId: requesterId,
      memberId: memberId,
    );
    if (removed) await _dataSource.removeMemberVotes(groupId, memberId);
    return removed;
  }

  Future<List<GroupMember>> getGroupMembers(String groupId) {
    return _summaryService.getGroupMembers(groupId);
  }

  /// Shares a photo or file. For a saved group it is uploaded so every member sees it;
  /// otherwise it stays on this device only.
  Future<ChatMessage> sendAttachment({
    required String groupId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required MessageType type,
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId != null && ApiClient.sessionToken != null) {
      final r = await ApiClient().post('/api/chats/$tripId/attachments', {
        'name': name,
        'mimeType': mimeType,
        'dataBase64': base64Encode(bytes),
      });
      return ChatMessage.fromJson({
        ...Map<String, dynamic>.from(r as Map),
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
      });
    }
    return ChatMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      text: name,
      timestamp: DateTime.now(),
      type: type,
      attachmentBytes: bytes,
      attachmentSize: bytes.length,
    );
  }

  Future<ChatMessage> sendMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String text,
    MessageType type = MessageType.text,
    String? attachmentUrl,
  }) async {
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId != null && type == MessageType.text && ApiClient.sessionToken != null) {
      // saved on the server, so it is still there after signing out and in
      final r = await ApiClient().post('/api/chats/$tripId/messages', {'text': text});
      return ChatMessage.fromJson({
        ...Map<String, dynamic>.from(r as Map),
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
      });
    }
    final json = await _dataSource.createMessage(
      groupId: groupId,
      senderId: senderId,
      senderName: senderName,
      senderAvatar: senderAvatar,
      text: text,
      type: type.name,
      attachmentUrl: attachmentUrl,
    );
    return ChatMessage.fromJson(json);
  }

  /// The AI answers the swiped message. Real groups: Gemini answers using
  /// the group's decisions and preferences, and the reply is saved in the
  /// chat for everyone. Sample groups keep the built-in example answer.
  Future<ChatMessage> triggerAiResponse(
    String groupId,
    String promptText,
  ) async {
    final tripId = GroupPlanningService.tripIdFor(groupId);
    if (tripId != null && ApiClient.sessionToken != null) {
      final r = await ApiClient().post('/api/chats/$tripId/ai-reply', {
        'text': promptText,
      });
      return ChatMessage.fromJson(Map<String, dynamic>.from(r as Map));
    }
    final json = await _dataSource.createAiResponse(groupId, promptText);
    return ChatMessage.fromJson(json);
  }

  Future<GroupPoll> votePoll({
    required String groupId,
    required String pollId,
    required String optionId,
    required String userId,
  }) async {
    if (pollId.startsWith(_aiPollPrefix)) {
      final tripId = GroupPlanningService.tripIdFor(groupId)!;
      final raw = pollId.substring(_aiPollPrefix.length);
      final r = await ApiClient().post('/api/chats/$tripId/polls/$raw/vote', {
        'option_id': optionId,
      });
      return _aiPollFromJson(Map<String, dynamic>.from(r as Map));
    }
    if (pollId.startsWith(_pollPrefix)) {
      final tripId = GroupPlanningService.tripIdFor(groupId)!;
      await GroupPlanningService().vote(tripId, optionId);
      final polls = await _sharedPolls(groupId);
      // The last vote for the last item removes the whole section poll.
      return polls.where((p) => p.id == pollId).firstOrNull ??
          GroupPoll(id: pollId, question: '', options: []);
    }
    final json = await _dataSource.toggleVote(
      groupId: groupId,
      pollId: pollId,
      optionId: optionId,
      userId: userId,
    );
    return GroupPoll.fromJson(json);
  }
}
