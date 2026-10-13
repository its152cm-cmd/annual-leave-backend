import 'dart:typed_data';

class AccountProfile {
  const AccountProfile({
    required this.name,
    required this.userId,
    required this.avatarUrl,
    required this.countriesVisited,
    required this.citiesExplored,
    required this.tripsCompleted,
    required this.distanceTravelledKm,
    this.avatarBytes,
  });

  final String name;
  final String userId;
  final String avatarUrl;
  final int countriesVisited;
  final int citiesExplored;
  final int tripsCompleted;
  final int distanceTravelledKm;
  final Uint8List? avatarBytes;

  factory AccountProfile.fromJson(Map<String, dynamic> json) {
    return AccountProfile(
      name: json['name'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String? ?? '',
      countriesVisited: json['countries_visited'] as int? ?? 0,
      citiesExplored: json['cities_explored'] as int? ?? 0,
      tripsCompleted: json['trips_completed'] as int? ?? 0,
      distanceTravelledKm: json['distance_travelled_km'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'user_id': userId,
    'avatar_url': avatarUrl,
    'countries_visited': countriesVisited,
    'cities_explored': citiesExplored,
    'trips_completed': tripsCompleted,
    'distance_travelled_km': distanceTravelledKm,
  };

  AccountProfile copyWith({
    String? name,
    String? avatarUrl,
    Uint8List? avatarBytes,
    bool clearAvatarBytes = false,
  }) {
    return AccountProfile(
      name: name ?? this.name,
      userId: userId,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      countriesVisited: countriesVisited,
      citiesExplored: citiesExplored,
      tripsCompleted: tripsCompleted,
      distanceTravelledKm: distanceTravelledKm,
      avatarBytes: clearAvatarBytes ? null : avatarBytes ?? this.avatarBytes,
    );
  }
}
