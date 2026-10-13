class ReplanAlternative {
  const ReplanAlternative({
    required this.id,
    required this.title,
    required this.description,
    required this.distance,
    required this.travelTime,
    required this.openingHours,
    required this.visitDuration,
    required this.price,
    required this.category,
    required this.imageUrl,
  });

  final String id;
  final String title;
  final String description;
  final String distance;
  final String travelTime;
  final String openingHours;
  final String visitDuration;
  final String price;
  final String category;
  final String imageUrl;

  factory ReplanAlternative.fromJson(Map<String, dynamic> json) {
    return ReplanAlternative(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      distance: json['distance'] as String,
      travelTime: json['travel_time'] as String,
      openingHours: json['opening_hours'] as String,
      visitDuration: json['visit_duration'] as String,
      price: json['price'] as String,
      category: json['category'] as String,
      imageUrl: json['image_url'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'distance': distance,
    'travel_time': travelTime,
    'opening_hours': openingHours,
    'visit_duration': visitDuration,
    'price': price,
    'category': category,
    'image_url': imageUrl,
  };
}
