class HotelOption {
  final String id;
  final String name;
  final String imageUrl;
  final String location;
  final double rating;
  final String pricePerNightFormatted; // e.g., "RM120/nt" or "RM180/nt"
  final List<String> amenities; // e.g., ["WiFi", "Breakfast", "Spa"]
  final String bookingUrl;
  final List<String> roomTypes;
  final String checkInTime;
  final String checkOutTime;
  bool isFavourite;

  HotelOption({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.location,
    required this.rating,
    required this.pricePerNightFormatted,
    required this.amenities,
    required this.bookingUrl,
    this.roomTypes = const [],
    this.checkInTime = '',
    this.checkOutTime = '',
    this.isFavourite = false,
  });

  factory HotelOption.fromJson(Map<String, dynamic> json) {
    return HotelOption(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      location: json['location'] as String? ?? '',
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      pricePerNightFormatted: json['price_per_night_formatted'] as String? ?? '',
      amenities: (json['amenities'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList() ??
          [],
      bookingUrl: json['booking_url'] as String? ?? '',
      roomTypes: (json['room_types'] as List<dynamic>? ?? const [])
          .map((item) => item.toString()).toList(),
      checkInTime: json['check_in_time'] as String? ?? '',
      checkOutTime: json['check_out_time'] as String? ?? '',
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
      'location': location,
      'rating': rating,
      'price_per_night_formatted': pricePerNightFormatted,
      'amenities': amenities,
      'booking_url': bookingUrl,
      'room_types': roomTypes,
      'check_in_time': checkInTime,
      'check_out_time': checkOutTime,
      'is_favourite': isFavourite,
    };
  }
}
