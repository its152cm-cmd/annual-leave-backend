class Attraction {
  final String id;
  final String title;
  final String location;
  final String imageUrl;
  final String price;
  final List<String> tags;
  final double rating;
  final String openingHours;
  final String description;
  final int? visitDurationMinutes;
  bool isFavourite;

  Attraction({
    required this.id,
    required this.title,
    required this.location,
    required this.imageUrl,
    this.price = 'Free',
    this.tags = const [],
    this.rating = 4.8,
    this.openingHours = '',
    this.description = '',
    this.visitDurationMinutes,
    this.isFavourite = false,
  });

  factory Attraction.fromJson(Map<String, dynamic> json) {
    return Attraction(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      location: json['location'] ?? '',
      imageUrl: json['image_url'] ?? '',
      price: json['price'] as String? ?? 'Free',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag as String)
          .toList(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
      openingHours: json['opening_hours'] as String? ?? '',
      description: json['description'] as String? ?? '',
      visitDurationMinutes: (json['visit_duration_minutes'] as num?)?.toInt(),
      isFavourite: json['is_favourite'] as bool? ??
          json['isFavourite'] as bool? ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'location': location,
      'image_url': imageUrl,
      'price': price,
      'tags': tags,
      'rating': rating,
      'opening_hours': openingHours,
      'description': description,
      'visit_duration_minutes': visitDurationMinutes,
      'is_favourite': isFavourite,
    };
  }
}
