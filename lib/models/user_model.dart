class UserModel {
  final String id;
  final String email;
  final String? displayName;
  final String preferredBibleVersion;
  final Map<String, dynamic>? lastReadPosition;
  final DateTime createdAt;
  
  UserModel({
    required this.id,
    required this.email,
    this.displayName,
    required this.preferredBibleVersion,
    this.lastReadPosition,
    required this.createdAt,
  });
  
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      displayName: json['display_name'],
      preferredBibleVersion: json['preferred_bible_version'] ?? 'ABB',
      lastReadPosition: json['last_read_position'],
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'display_name': displayName,
      'preferred_bible_version': preferredBibleVersion,
      'last_read_position': lastReadPosition,
      'created_at': createdAt.toIso8601String(),
    };
  }
  
  UserModel copyWith({
    String? id,
    String? email,
    String? displayName,
    String? preferredBibleVersion,
    Map<String, dynamic>? lastReadPosition,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      preferredBibleVersion: preferredBibleVersion ?? this.preferredBibleVersion,
      lastReadPosition: lastReadPosition ?? this.lastReadPosition,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}