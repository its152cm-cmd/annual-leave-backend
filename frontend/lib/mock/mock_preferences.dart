final Map<String, dynamic> mockTravelPreference = {
  "transcript": "Looking for a relaxed cultural experience with lots of local coffee shops and accessible walking paths.",
  "pace": "Balanced",
  "accessibility": "Standard",
  "restroom_priority": "Medium",
  "start_time": "08:00 AM",
  "end_time": "09:00 PM",
};

final List<Map<String, dynamic>> mockDefaultPreferenceCategories = [
  {
    'name': 'Dietary',
    'single_select': false,
    'options': [
      {'label': 'Vegetarian', 'selected': false},
      {'label': 'Vegan', 'selected': false},
      {'label': 'Halal', 'selected': true},
      {'label': 'Gluten-Free', 'selected': false},
      {'label': 'No Seafood', 'selected': false},
    ],
  },
  {
    'name': 'Pace',
    'single_select': true,
    'options': [
      {'label': 'Relaxed', 'selected': false},
      {'label': 'Moderate', 'selected': true},
      {'label': 'Fast-paced', 'selected': false},
    ],
  },
  {
    'name': 'Interests',
    'single_select': false,
    'options': [
      {'label': 'Culture & History', 'selected': true},
      {'label': 'Nature', 'selected': false},
      {'label': 'Shopping', 'selected': false},
      {'label': 'Foodie', 'selected': true},
      {'label': 'Nightlife', 'selected': false},
    ],
  },
];

final List<Map<String, dynamic>> mockSwipeCards = [
  {
    "id": "1",
    "title": "PETRONAS Twin Towers & KLCC",
    "tag": "Famous Attraction • Citywalk",
    "category": "Famous attractions",
    "image_url": "https://images.unsplash.com/photo-1596422846543-75c6fc197f07?auto=format&fit=crop&w=800&q=80"
  },
  {
    "id": "2",
    "title": "Jalan Alor Night Market",
    "tag": "Food • Street Eats",
    "category": "Food",
    "image_url": "https://images.unsplash.com/photo-1504674900247-0877df9cc836?auto=format&fit=crop&w=800&q=80"
  },
  {
    "id": "3",
    "title": "Batu Caves Rainbow Steps",
    "tag": "Culture • Heritage",
    "category": "Culture",
    "image_url": "https://images.unsplash.com/photo-1548013146-72479768bada?auto=format&fit=crop&w=800&q=80"
  },
  {
    "id": "4",
    "title": "Chinatown Speakeasy Bars",
    "tag": "Nightlife • Hidden gems",
    "category": "Nightlife",
    "image_url": "https://images.unsplash.com/photo-1514933651103-005eec06c04b?auto=format&fit=crop&w=800&q=80"
  },
  {
    "id": "5",
    "title": "Bukit Bintang Artisan Cafés",
    "tag": "Cafés • Coffee Culture",
    "category": "Cafés",
    "image_url": "https://images.unsplash.com/photo-1501339847302-ac426a4a7cbb?auto=format&fit=crop&w=800&q=80"
  },
  {
    "id": "6",
    "title": "Taman Negara Rainforest Trek",
    "tag": "Nature • Adventure",
    "category": "Nature",
    "image_url": "https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=800&q=80"
  },
  {
    "id": "7",
    "title": "Sultan Abdul Samad Building",
    "tag": "History • Photography",
    "category": "History",
    "image_url": "https://images.unsplash.com/photo-1565008447742-97f6f38c985c?auto=format&fit=crop&w=800&q=80"
  },
  {
    "id": "8",
    "title": "Kampung Baru Local Homestay",
    "tag": "Local experiences • Culture",
    "category": "Local experiences",
    "image_url": "https://images.unsplash.com/photo-1528127269322-539801943592?auto=format&fit=crop&w=800&q=80"
  },
  {
    "id": "9",
    "title": "Central Market Craft Souvenirs",
    "tag": "Shopping • Heritage",
    "category": "Shopping",
    "image_url": "https://images.unsplash.com/photo-1472851294608-062f824d29cc?auto=format&fit=crop&w=800&q=80"
  },
  {
    "id": "10",
    "title": "Klang Gates Quartz Ridge",
    "tag": "Hidden gems • Photography",
    "category": "Hidden gems",
    "image_url": "https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?auto=format&fit=crop&w=800&q=80"
  }
];
