// lib/mock/mock_trip_summary.dart

final Map<String, Map<String, dynamic>> mockTripSummaryDatabase = {
  "group_kyoto_1": {
    "summary": {
      "id": "sum_kyoto",
      "title": "Kyoto Autumn Getaway",
      "destination": "Kyoto, Japan",
      "status": "Planning",
      "dates": "Oct 15 - Oct 22, 2026",
      "budgetRange": {"min": 1500, "max": 2000},
      "selectedAccommodationIds": ["HOTEL_01"],
      "confirmedDetails": {
        "Flights": "Pending",
        "Hotel": "Pending"
      },
      "pendingDecisions": ["Budget", "Accommodation", "Transport"]
    },
    "members": [
      {
        "id": "user_me",
        "name": "You",
        "avatarUrl": "https://i.pravatar.cc/150?img=11",
        "role": "Host",
        "isMe": true,
        "leaveBalanceSummary": "18 Days Available",
        "minBudget": 2000,
        "maxBudget": 5000,
        "preferences": ["Food", "Culture"],
        "dateRange": "Oct 15 - Oct 22, 2026"
      },
      {
        "id": "collab_1",
        "name": "Sarah Chen",
        "avatarUrl": "assets/avatars/ski-traveller.jpg",
        "role": "Member",
        "isMe": false,
        "leaveBalanceSummary": "12 Days Available",
        "minBudget": 1800,
        "maxBudget": 4800,
        "preferences": ["Cafes", "Temple walks"],
        "dateRange": "Oct 15 - Oct 22, 2026"
      },
      {
        "id": "collab_2",
        "name": "Alex Wong",
        "avatarUrl": "assets/avatars/paris-traveller.jpg",
        "role": "Member",
        "isMe": false,
        "leaveBalanceSummary": "12 Days Available",
        "minBudget": 1500,
        "maxBudget": 4500,
        "preferences": ["Nightlife"],
        "dateRange": "Oct 15 - Oct 22, 2026"
      },
      {
        "id": "collab_3",
        "name": "Miriam Al-Jamil",
        "avatarUrl": "assets/avatars/hiking-traveller.jpg",
        "role": "Member",
        "isMe": false,
        "leaveBalanceSummary": "12 Days Available",
        "minBudget": 2000,
        "maxBudget": 5200,
        "preferences": ["Museums", "Food"],
        "dateRange": "Oct 15 - Oct 22, 2026"
      },
      {
        "id": "collab_4",
        "name": "David Tan",
        "avatarUrl": "assets/avatars/green-traveller.jpg",
        "role": "Member",
        "isMe": false,
        "leaveBalanceSummary": "12 Days Available",
        "minBudget": 1200,
        "maxBudget": 4200,
        "preferences": ["Quiet neighborhoods"],
        "dateRange": "Oct 15 - Oct 22, 2026"
      }
    ],
    "suggestions": [
      {
        "id": "sug_1",
        "title": "Kiyomizu-dera",
        "location": "Higashiyama, Kyoto",
        "category": "Culture",
        "matchPercentage": 94,
        "imageUrl": "https://images.unsplash.com/photo-1493976040374-85c8e12f0c0e?auto=format&fit=crop&w=600&q=80"
      }
    ]
  },

  "group_bali_2": {
    "summary": {
      "id": "sum_bali",
      "title": "Bali Retreat 2026",
      "destination": "Bali, Indonesia",
      "status": "Planning",
      "dates": "Nov 1 - Nov 7, 2026",
      "confirmedDetails": {
        "Flights": "Booked",
        "Hotel": "Pending"
      },
      "pendingDecisions": ["Accommodation", "Activities", "Budget"]
    }, // <-- REMOVED THE EXTRA }, THAT WAS HERE
    "members": [
      {
        "id": "user_me",
        "name": "You",
        "avatarUrl": "https://i.pravatar.cc/150?img=11",
        "role": "Member",
        "isMe": true,
        "minBudget": 1000,
        "maxBudget": 3000,
        "preferences": ["Beach", "Relaxation"],
        "dateRange": "Nov 1 - Nov 7"
      },
      {
        "id": "collab_6",
        "name": "Sarah Jenkins",
        "avatarUrl": "https://i.pravatar.cc/150?img=5",
        "role": "Host",
        "isMe": false,
        "minBudget": 1000,
        "maxBudget": 4000,
        "preferences": ["Spa", "Food"],
        "dateRange": "Nov 1 - Nov 7"
      },
      {
        "id": "collab_2",
        "name": "Alex Wong",
        "avatarUrl": "assets/avatars/paris-traveller.jpg",
        "role": "Member",
        "isMe": false,
        "minBudget": 1500,
        "maxBudget": 3500,
        "preferences": ["Nightlife", "Beach"],
        "dateRange": "Nov 1 - Nov 7"
      }
    ],
    "suggestions": []
  },

  "group_seoul_3": {
    "summary": {
      "id": "sum_seoul",
      "title": "Seoul Food & Shopping",
      "destination": "Seoul, South Korea",
      "status": "Planning",
      "dates": "Dec 10 - Dec 18, 2026",
      "confirmedDetails": {
        "Flights": "Pending",
        "Hotel": "Pending"
      },
      "pendingDecisions": ["Flights", "Accommodation", "Budget"]
    },
    "members": [
      {
        "id": "user_me",
        "name": "You",
        "avatarUrl": "https://i.pravatar.cc/150?img=11",
        "role": "Host",
        "isMe": true,
        "minBudget": 3000,
        "maxBudget": 6000,
        "preferences": ["Shopping", "Food"],
        "dateRange": "Dec 10 - Dec 18"
      },
      {
        "id": "collab_7",
        "name": "Mei Chen",
        "avatarUrl": "https://i.pravatar.cc/150?img=9",
        "role": "Member",
        "isMe": false,
        "minBudget": 2500,
        "maxBudget": 5000,
        "preferences": ["Shopping"],
        "dateRange": "Dec 10 - Dec 18"
      }
    ],
    "suggestions": []
  }
};
