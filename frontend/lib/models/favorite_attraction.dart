import 'attraction.dart';

/// An attraction the user has saved to their favourites.
class FavoriteAttraction {
  final String id;
  final String title;
  final String location;
  final String imageUrl;
  final String price;
  final List<String> tags;
  final double rating;

  const FavoriteAttraction({
    required this.id,
    required this.title,
    required this.location,
    required this.imageUrl,
    this.price = 'Free',
    this.tags = const [],
    this.rating = 4.8,
  });

  /// Build a favourite from a regular [Attraction] (used when the heart is tapped).
  factory FavoriteAttraction.fromAttraction(Attraction attraction) {
    return FavoriteAttraction(
      id: attraction.id,
      title: attraction.title,
      location: attraction.location,
      imageUrl: attraction.imageUrl,
      price: attraction.price,
      tags: attraction.tags,
      rating: attraction.rating,
    );
  }

  factory FavoriteAttraction.fromJson(Map<String, dynamic> json) {
    return FavoriteAttraction(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      location: json['location'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      price: json['price'] as String? ?? 'Free',
      tags: (json['tags'] as List<dynamic>? ?? const [])
          .map((tag) => tag as String)
          .toList(),
      rating: (json['rating'] as num?)?.toDouble() ?? 4.8,
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
    };
  }

  /// Convert back to an [Attraction] so existing cards/widgets can render it.
  Attraction toAttraction() {
    return Attraction(
      id: id,
      title: title,
      location: location,
      imageUrl: imageUrl,
      price: price,
      tags: tags,
      rating: rating,
    );
  }
}