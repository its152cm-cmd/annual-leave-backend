class Recommendation {
  final String id;
  final String destination;
  final String flightTime;
  final String cost;
  final String imageUrl;
  final String matchPercentage;
  final List<String> tags;

  Recommendation({
    required this.id,
    required this.destination,
    required this.flightTime,
    required this.cost,
    required this.imageUrl,
    required this.matchPercentage,
    required this.tags,
  });

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      id: json['id'] ?? '',
      destination: json['destination'] ?? '',
      flightTime: json['flight_time'] ?? '',
      cost: json['cost'] ?? '',
      imageUrl: json['image_url'] ?? '',
      matchPercentage: json['match_percentage'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination,
      'flight_time': flightTime,
      'cost': cost,
      'image_url': imageUrl,
      'match_percentage': matchPercentage,
      'tags': tags,
    };
  }
}