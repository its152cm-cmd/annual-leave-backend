// lib/models/trip_invitation.dart

class TripInvitation {
  final String id;
  final String groupId;
  final String hostName;
  final String hostAvatar;
  final String tripTitle;
  final String destination;
  final String dates;

  TripInvitation({
    required this.id,
    required this.groupId,
    required this.hostName,
    required this.hostAvatar,
    required this.tripTitle,
    required this.destination,
    required this.dates,
  });

  factory TripInvitation.fromJson(Map<String, dynamic> json) {
    return TripInvitation(
      id: json['id'] as String,
      groupId: json['groupId'] as String? ?? '',
      hostName: json['hostName'] as String,
      hostAvatar: json['hostAvatar'] as String? ?? '',
      tripTitle: json['tripTitle'] as String,
      destination: json['destination'] as String,
      dates: json['dates'] as String,
    );
  }
}