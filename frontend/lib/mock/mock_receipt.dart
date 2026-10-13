final Map<String, dynamic> mockScannedReceiptData = {
  "id": "rcpt_001",
  "merchantName": "Nori House",
  "timestamp": "Today · 19:42 · 3 people",
  "peopleCount": 3,
  "paidByMemberName": "Alex Ramses",
  "paidByMemberAvatar": "AR",
  "memberSplits": [
    {
      "id": "AR",
      "name": "Alex Ramses",
      "colorHex": 0xFF66BB6A,
      "splitPercentage": 36,
    },
    {
      "id": "MK",
      "name": "Mei Chen",
      "colorHex": 0xFF7E57C2,
      "splitPercentage": 32,
    },
    {
      "id": "JL",
      "name": "John Lee",
      "colorHex": 0xFFFFB74D,
      "splitPercentage": 32,
    },
  ],
  "items": [
    {
      "id": "item_1",
      "title": "Miso ramen",
      "price": 24.0,
      "quantity": 2,
      "assignedMemberIds": ["AR", "MK"],
    },
    {
      "id": "item_2",
      "title": "Salmon maki",
      "price": 28.0,
      "quantity": 1,
      "assignedMemberIds": ["AR", "JL"],
    },
    {
      "id": "item_3",
      "title": "Matcha soda",
      "price": 8.0,
      "quantity": 3,
      "assignedMemberIds": ["AR", "MK", "JL"],
    },
  ],
};

final List<Map<String, dynamic>> mockRecentReceipts = [
  {
    'id': 'trip_rcpt_001',
    'merchantName': 'Ichiran Ramen, Kyoto',
    'timestamp': '15 October 2026 · 4 people · Pending split',
    'peopleCount': 4,
    'paidByMemberName': 'You',
    'paidByMemberAvatar': 'Y',
    'memberSplits': <Map<String, dynamic>>[],
    'items': [
      {
        'id': 'trip_rcpt_001_item',
        'title': 'Ramen dinner',
        'price': 240.0,
        'quantity': 1,
        'assignedMemberIds': <String>[],
      },
    ],
  },
  {
    'id': 'trip_rcpt_002',
    'merchantName': 'Shinkansen Tickets',
    'timestamp': '12 October 2026 · 4 people · Settled',
    'peopleCount': 4,
    'paidByMemberName': 'You',
    'paidByMemberAvatar': 'Y',
    'memberSplits': <Map<String, dynamic>>[],
    'items': [
      {
        'id': 'trip_rcpt_002_item',
        'title': 'Train tickets',
        'price': 680.0,
        'quantity': 1,
        'assignedMemberIds': <String>[],
      },
    ],
  },
];
