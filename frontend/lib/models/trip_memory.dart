import 'dart:typed_data';

class TripMemoryPhoto {
  const TripMemoryPhoto({
    required this.id,
    required this.fileName,
    required this.imageUrl,
    this.localBytes,
  });

  final String id;
  final String fileName;
  final String imageUrl;
  final Uint8List? localBytes;

  factory TripMemoryPhoto.fromJson(Map<String, dynamic> json) {
    return TripMemoryPhoto(
      id: json['id'] as String? ?? '',
      fileName: json['file_name'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'file_name': fileName,
    'image_url': imageUrl,
  };
}

class TripMemory {
  const TripMemory({
    required this.tripId,
    required this.note,
    required this.photos,
  });

  final String tripId;
  final String note;
  final List<TripMemoryPhoto> photos;

  factory TripMemory.fromJson(Map<String, dynamic> json) {
    final photoJson = json['photos'] as List<dynamic>? ?? const [];
    return TripMemory(
      tripId: json['trip_id'] as String? ?? '',
      note: json['note'] as String? ?? '',
      photos: photoJson
          .map(
            (photo) => TripMemoryPhoto.fromJson(
              Map<String, dynamic>.from(photo as Map),
            ),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'trip_id': tripId,
    'note': note,
    'photos': photos.map((photo) => photo.toJson()).toList(),
  };

  TripMemory copyWith({
    String? note,
    List<TripMemoryPhoto>? photos,
  }) {
    return TripMemory(
      tripId: tripId,
      note: note ?? this.note,
      photos: photos ?? this.photos,
    );
  }
}
