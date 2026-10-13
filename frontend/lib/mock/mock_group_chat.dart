// lib/mock/mock_group_chat.dart

final DateTime _mockChatStartTime = DateTime.now().subtract(
  const Duration(minutes: 5),
);

// Restructured to a Map where the key is the groupId
final Map<String, Map<String, dynamic>> mockGroupChatData = {
  "group_kyoto_1": {
    "messages": [
      {
        "id": "msg_1",
        "senderId": "collab_2",
        "senderName": "Alex Wong",
        "text": "I'm thinking of Tokyo for our next trip. What do you think?",
        "timestamp": _mockChatStartTime.toIso8601String(),
        "type": "text",
        "isAiResponse": false,
      },
      {
        "id": "msg_2",
        "senderId": "collab_3",
        "senderName": "Miriam Al-Jamil",
        "text": "Sounds great! I've been wanting to visit the new Ghibli Museum.",
        "timestamp": _mockChatStartTime
            .add(const Duration(minutes: 2))
            .toIso8601String(),
        "type": "text",
        "isAiResponse": false,
      },
      {
        "id": "msg_3",
        "senderId": "collab_1",
        "senderName": "Sarah Chen",
        "text": "Kyoto's a place we can consider too for planning this trip.",
        "timestamp": _mockChatStartTime
            .add(const Duration(minutes: 3))
            .toIso8601String(),
        "type": "text",
        "isAiResponse": false,
      },
      {
        "id": "msg_4",
        "senderId": "collab_4",
        "senderName": "David Tan",
        "text": "RM 1,000 to RM 5,000. Let's avoid super crowded areas.",
        "timestamp": _mockChatStartTime
            .add(const Duration(minutes: 4))
            .toIso8601String(),
        "type": "text",
        "isAiResponse": false,
      },
      {
        "id": "msg_5",
        "senderId": "ai_planner",
        "senderName": "AI PLANNER • LIVE",
        "senderAvatar": null,
        "text": "Kyoto is a historic Japanese city famous for its classical Buddhist temples, peaceful gardens, and traditional wooden houses. As the former imperial capital of Japan, it preserves the nation's rich cultural heritage through timeless shrines and food culture.",
        "timestamp": _mockChatStartTime
            .add(const Duration(minutes: 5))
            .toIso8601String(),
        "type": "text",
        "isAiResponse": true,
      },
    ],
    "polls": <Map<String, dynamic>>[
      {
        "id": "poll_1",
        "question": "Where Should We Visit",
        "isClosed": false,
        "options": [
          {
            "id": "opt_1",
            "text": "Shibuya Crossing",
            "votedUserIds": ["user_me", "collab_2"],
          },
          {
            "id": "opt_2",
            "text": "Ghibli Museum",
            "votedUserIds": ["collab_3"],
          },
          {
            "id": "opt_3",
            "text": "Asakusa Kannon Temple",
            "votedUserIds": ["collab_4"],
          },
        ],
      },
      {
        "id": "poll_2",
        "question": "Preferred Accommodation Type",
        "isClosed": false,
        "options": [
          {
            "id": "opt_2_1",
            "text": "Traditional Ryokan",
            "votedUserIds": ["user_me", "collab_3"],
          },
          {
            "id": "opt_2_2",
            "text": "City Center Hotel",
            "votedUserIds": ["collab_2"],
          },
          {"id": "opt_2_3", "text": "Airbnb Apartment", "votedUserIds": []},
        ],
      },
    ],
  },

  "group_bali_2": {
    "messages": [
      {
        "id": "msg_bali_1",
        "senderId": "collab_2",
        "senderName": "Alex",
        "text": "Should we book the villa near Canggu?",
        "timestamp": _mockChatStartTime.toIso8601String(),
        "type": "text",
        "isAiResponse": false,
      }
    ],
    "polls": <Map<String, dynamic>>[],
  },

  "group_seoul_3": {
    "messages": [
      {
        "id": "msg_seoul_1",
        "senderId": "collab_7",
        "senderName": "Mei",
        "text": "Added Myeongdong street food to preferences",
        "timestamp": _mockChatStartTime.toIso8601String(),
        "type": "text",
        "isAiResponse": false,
      }
    ],
    "polls": <Map<String, dynamic>>[],
  },
};