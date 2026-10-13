// lib/mock/mock_group_chat_data_source.dart
//
// Simulates the backend for group chat messages and polls. Returns raw JSON.
// Replace with an API-client call when the backend exists.

import 'mock_group_chat.dart';

class GroupChatMockDataSource {
  static final Map<String, String> _lastReadMessageIdByReaderAndGroup = {};

  String? getLastReadMessageId(String groupId, String readerId) =>
      _lastReadMessageIdByReaderAndGroup['$readerId::$groupId'];

  void markMessagesRead({
    required String groupId,
    required String readerId,
    required String throughMessageId,
  }) {
    _lastReadMessageIdByReaderAndGroup['$readerId::$groupId'] =
        throughMessageId;
  }

  Map<String, dynamic> _getGroupData(String groupId) {
    return mockGroupChatData[groupId] ?? {'messages': [], 'polls': []};
  }

  void ensureGroup(String groupId) {
    mockGroupChatData.putIfAbsent(
      groupId,
      () => {
        'messages': <Map<String, dynamic>>[],
        'polls': <Map<String, dynamic>>[],
      },
    );
  }

  Future<List<Map<String, dynamic>>> fetchMessages(String groupId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    final list = _getGroupData(groupId)['messages'] as List<dynamic>? ?? [];
    return list.map((json) => Map<String, dynamic>.from(json as Map)).toList();
  }

  Future<Map<String, dynamic>> createMessage({
    required String groupId,
    required String senderId,
    required String senderName,
    String? senderAvatar,
    required String text,
    String type = 'text',
    String? attachmentUrl,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final message = {
      'id': 'msg_${DateTime.now().millisecondsSinceEpoch}',
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'timestamp': DateTime.now().toIso8601String(),
      'type': type,
      'attachmentUrl': attachmentUrl,
      'isAiResponse': false,
    };
    final group = mockGroupChatData.putIfAbsent(
      groupId,
      () => {
        'messages': <Map<String, dynamic>>[],
        'polls': <Map<String, dynamic>>[],
      },
    );
    (group['messages'] as List<dynamic>).add(message);
    return message;
  }

  Future<Map<String, dynamic>> createAiResponse(
    String groupId,
    String prompt,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));

    String responseText =
        "Here is what I found for '$prompt': Kyoto has amazing seasonal views and historic temples!";
    Map<String, dynamic>? cardPayload;

    final lowerPrompt = prompt.toLowerCase();
    if (lowerPrompt.contains('food') || lowerPrompt.contains('eat')) {
      responseText = "Based on your group's preferences, I recommend Nishiki Market for street food!";
      cardPayload = {
        'id': 'sug_3',
        'title': 'Nishiki Market',
        'location': 'Nakagyo, Kyoto',
        'category': 'FOOD • NIGHTLIFE',
        'matchPercentage': 82,
        'imageUrl': 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=600&q=80',
      };
    } else if (lowerPrompt.contains('museum') ||
        lowerPrompt.contains('visit')) {
      responseText =
          "Ghibli Museum and Kiyomizu-dera are top matches for your group!";
      cardPayload = {
        'id': 'sug_1',
        'title': 'Kiyomizu-dera',
        'location': 'Higashiyama, Kyoto',
        'category': 'GROUP MATCH',
        'matchPercentage': 94,
        'imageUrl': 'https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=600&q=80',
      };
    }

    final message = {
      'id': 'ai_msg_${DateTime.now().millisecondsSinceEpoch}',
      'senderId': 'ai_planner',
      'senderName': 'AI PLANNER • LIVE',
      'text': responseText,
      'timestamp': DateTime.now().toIso8601String(),
      'type': cardPayload != null ? 'aiRecommendationCard' : 'text',
      'isAiResponse': true,
      'cardPayload': cardPayload,
    };
    final group = mockGroupChatData.putIfAbsent(
      groupId,
      () => {
        'messages': <Map<String, dynamic>>[],
        'polls': <Map<String, dynamic>>[],
      },
    );
    (group['messages'] as List<dynamic>).add(message);
    return message;
  }

  Future<List<Map<String, dynamic>>> fetchPolls(String groupId) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    final list = _getGroupData(groupId)['polls'] as List<dynamic>? ?? [];
    return list.map((json) => Map<String, dynamic>.from(json as Map)).toList();
  }

  Future<Map<String, dynamic>> savePoll(
    String groupId,
    Map<String, dynamic> pollJson,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 150));

    if (!mockGroupChatData.containsKey(groupId)) {
      mockGroupChatData[groupId] = {'messages': [], 'polls': []};
    }

    final polls = mockGroupChatData[groupId]!['polls'] as List<dynamic>;
    polls.removeWhere(
      (entry) => (entry as Map<String, dynamic>)['id'] == pollJson['id'],
    );
    polls.add(pollJson);
    return pollJson;
  }

  Future<Map<String, dynamic>> toggleVote({
    required String groupId,
    required String pollId,
    required String optionId,
    required String userId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));

    final groupData = _getGroupData(groupId);
    if (groupData['polls'] == null || (groupData['polls'] as List).isEmpty) {
      throw Exception('Poll not found');
    }

    final polls = (groupData['polls'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final pollData = polls.firstWhere((poll) => poll['id'] == pollId);
    final options = (pollData['options'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final allowMultipleAnswers =
        pollData['allowMultipleAnswers'] as bool? ?? true;
    final selectedOption = options.firstWhere(
      (option) => option['id'] == optionId,
    );

    final selectedVoterIds =
        (selectedOption['votedUserIds'] as List<dynamic>? ?? []).cast<String>();
    final isCancellingVote = selectedVoterIds.contains(userId);

    for (final option in options) {
      final voterIds = (option['votedUserIds'] as List<dynamic>? ?? [])
          .cast<String>()
          .toList();
      if (option['id'] == optionId && isCancellingVote) {
        voterIds.remove(userId);
      } else if (option['id'] == optionId && !voterIds.contains(userId)) {
        voterIds.add(userId);
      } else if (!isCancellingVote &&
          !allowMultipleAnswers &&
          option['id'] != optionId) {
        voterIds.remove(userId);
      }
      option['votedUserIds'] = voterIds;
      option['voteCount'] = voterIds.length;
    }

    return Map<String, dynamic>.from(pollData);
  }

  Future<void> removeMemberVotes(String groupId, String memberId) async {
    final groupData = _getGroupData(groupId);
    if (groupData['polls'] == null) return;

    final polls = (groupData['polls'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final poll in polls) {
      final options = (poll['options'] as List<dynamic>)
          .cast<Map<String, dynamic>>();
      for (final option in options) {
        final voterIds = (option['votedUserIds'] as List<dynamic>? ?? [])
            .cast<String>()
            .where((id) => id != memberId)
            .toList();
        option['votedUserIds'] = voterIds;
        option['voteCount'] = voterIds.length;
      }
    }
  }
}
