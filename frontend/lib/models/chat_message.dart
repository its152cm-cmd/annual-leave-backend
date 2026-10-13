import 'dart:typed_data';

enum MessageType { text, image, file, aiRecommendationCard }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String text;
  final DateTime timestamp;
  final MessageType type;
  final String? attachmentUrl;
  // A photo or file picked on this device (not sent to the server yet).
  final Uint8List? attachmentBytes;
  final int? attachmentSize;
  final bool isAiResponse;
  final Map<String, dynamic>? cardPayload; // Stores destination/restaurant recommendation data

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.text,
    required this.timestamp,
    this.type = MessageType.text,
    this.attachmentUrl,
    this.attachmentBytes,
    this.attachmentSize,
    this.isAiResponse = false,
    this.cardPayload,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      senderId: json['senderId'] as String,
      senderName: json['senderName'] as String,
      senderAvatar: json['senderAvatar'] as String?,
      text: json['text'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.text,
      ),
      attachmentUrl: json['attachmentUrl'] as String?,
      attachmentSize: (json['attachmentSize'] as num?)?.toInt(),
      isAiResponse: json['isAiResponse'] as bool? ?? false,
      cardPayload: json['cardPayload'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'senderName': senderName,
      'senderAvatar': senderAvatar,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
      'type': type.name,
      'attachmentUrl': attachmentUrl,
      'isAiResponse': isAiResponse,
      'cardPayload': cardPayload,
    };
  }
}