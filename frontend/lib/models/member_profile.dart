class MemberProfile {
  final String id;
  final String name;
  final String role;
  final String? avatarUrl;
  final String leaveBalanceSummary;
  final List<String> preferences;

  const MemberProfile({
    required this.id,
    required this.name,
    required this.role,
    this.avatarUrl,
    required this.leaveBalanceSummary,
    required this.preferences,
  });

  factory MemberProfile.fromJson(Map<String, dynamic> json) {
    return MemberProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      leaveBalanceSummary: json['leaveBalanceSummary'] as String? ?? '',
      preferences: List<String>.from(json['preferences'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'avatarUrl': avatarUrl,
      'leaveBalanceSummary': leaveBalanceSummary,
      'preferences': preferences,
    };
  }
}