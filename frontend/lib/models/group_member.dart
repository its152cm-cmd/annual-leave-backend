class GroupMember {
  final String id;
  final String name;
  final String role; // 'Host' or 'Member'
  final String? avatarUrl;
  final List<String> preferences;
  final String leaveBalanceSummary;
  final double minBudget;
  final double maxBudget;
  final String dateRange;
  final bool isMe;

  GroupMember({
    required this.id,
    required this.name,
    this.role = 'Member',
    this.avatarUrl,
    this.preferences = const [],
    required this.leaveBalanceSummary,
    this.minBudget = 1000.0,
    this.maxBudget = 5000.0,
    this.dateRange = 'Jun 12 - Jun 18, 2026',
    this.isMe = false,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      name: json['name'] as String,
      role: json['role'] as String? ?? 'Member',
      avatarUrl: json['avatarUrl'] as String?,
      preferences: (json['preferences'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      leaveBalanceSummary:
          json['leaveBalanceSummary'] as String? ?? '12 Days Available',
      minBudget: (json['minBudget'] as num?)?.toDouble() ?? 1000.0,
      maxBudget: (json['maxBudget'] as num?)?.toDouble() ?? 5000.0,
      dateRange: json['dateRange'] as String? ?? 'Jun 12 - Jun 18, 2026',
      isMe: json['isMe'] as bool? ?? (json['id'] == 'user_me'),
    );
  }

  GroupMember copyWith({
    String? id,
    String? name,
    String? role,
    String? avatarUrl,
    List<String>? preferences,
    String? leaveBalanceSummary,
    double? minBudget,
    double? maxBudget,
    String? dateRange,
    bool? isMe,
  }) {
    return GroupMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      preferences: preferences ?? List.from(this.preferences),
      leaveBalanceSummary: leaveBalanceSummary ?? this.leaveBalanceSummary,
      minBudget: minBudget ?? this.minBudget,
      maxBudget: maxBudget ?? this.maxBudget,
      dateRange: dateRange ?? this.dateRange,
      isMe: isMe ?? this.isMe,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'avatarUrl': avatarUrl,
      'preferences': preferences,
      'leaveBalanceSummary': leaveBalanceSummary,
      'minBudget': minBudget,
      'maxBudget': maxBudget,
      'dateRange': dateRange,
      'isMe': isMe,
    };
  }
}