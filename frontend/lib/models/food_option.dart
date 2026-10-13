class FoodOption {
  final String id;
  final String name;
  final String imageUrl;
  final String cuisineType; // e.g., "Ramen", "Kaiseki", "Street Food"
  final String priceTier; // e.g., "¥", "¥¥", "¥¥¥"
  final String description;
  final double rating;
  final int reviewCount;
  final List<String> menuItems;
  final String price;
  final String openingHours;
  final int? visitDurationMinutes;
  final String location;
  bool isFavourite;

  FoodOption({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.cuisineType,
    required this.priceTier,
    required this.description,
    required this.rating,
    required this.reviewCount,
    this.menuItems = const [],
    this.price = '',
    this.openingHours = '',
    this.visitDurationMinutes,
    this.location = '',
    this.isFavourite = false,
  });

  factory FoodOption.fromJson(Map<String, dynamic> json) {
    return FoodOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      cuisineType: json['cuisine_type'] as String? ?? '',
      priceTier: json['price_tier'] as String? ?? '',
      description: json['description'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['review_count'] as int? ?? 0,
      menuItems: (json['menu_items'] as List<dynamic>? ?? const [])
          .map((item) => item.toString()).toList(),
      price: json['price'] as String? ?? json['price_tier'] as String? ?? '',
      openingHours: json['opening_hours'] as String? ?? '',
      visitDurationMinutes: (json['visit_duration_minutes'] as num?)?.toInt(),
      location: json['location'] as String? ?? '',
      isFavourite: json['is_favourite'] as bool? ??
          json['isFavourite'] as bool? ??
          false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'cuisine_type': cuisineType,
      'price_tier': priceTier,
      'description': description,
      'rating': rating,
      'review_count': reviewCount,
      'menu_items': menuItems,
      'price': price,
      'opening_hours': openingHours,
      'visit_duration_minutes': visitDurationMinutes,
      'location': location,
      'is_favourite': isFavourite,
    };
  }
}
