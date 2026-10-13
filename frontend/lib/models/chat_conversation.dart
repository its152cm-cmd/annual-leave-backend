// lib/models/chat_conversation.dart

class ChatConversation {
  final String groupId;
  final String? tripId;
  final String title;
  final String destination;
  final String lastMessage;
  final DateTime lastMessageTime;
  final int unreadCount;
  final String avatarUrl;
  final bool isLiveSync;

  ChatConversation({
    required this.groupId,
    this.tripId,
    required this.title,
    required this.destination,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.avatarUrl,
    this.isLiveSync = true,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      groupId: json['groupId'] as String,
      tripId: json['tripId'] as String?,
      title: json['title'] as String,
      destination: json['destination'] as String,
      lastMessage: json['lastMessage'] as String,
      lastMessageTime: DateTime.parse(json['lastMessageTime'] as String),
      unreadCount: json['unreadCount'] as int? ?? 0,
      avatarUrl: json['avatarUrl'] as String? ?? '',
      isLiveSync: json['isLiveSync'] as bool? ?? true,
    );
  }
}
