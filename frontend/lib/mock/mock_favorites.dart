/// Mock backend response for the user's saved (favourite) attractions.
/// Shape matches GET /api/favorites.
final List<Map<String, dynamic>> mockFavorites = [
  {
    "id": "ATTR_002",
    "title": "Fushimi Inari Shrine",
    "location": "Fushimi-ku, Kyoto",
    "price": "Free",
    "tags": ["Nature", "Aesthetic", "Cultural"],
    "rating": 4.8,
    "image_url":
        "https://images.unsplash.com/photo-1478436127897-769e1b3f0f36?auto=format&fit=crop&w=800&q=80",
  },
];