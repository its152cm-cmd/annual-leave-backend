class Collaborator {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;
  final bool isAdded;

  Collaborator({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.isAdded = false,
  });

  factory Collaborator.fromJson(Map<String, dynamic> json) {
    return Collaborator(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      isAdded: json['isAdded'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'isAdded': isAdded,
    };
  }

  Collaborator copyWith({bool? isAdded}) {
    return Collaborator(
      id: id,
      name: name,
      email: email,
      avatarUrl: avatarUrl,
      isAdded: isAdded ?? this.isAdded,
    );
  }
}