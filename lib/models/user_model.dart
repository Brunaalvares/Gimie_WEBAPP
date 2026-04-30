class UserModel {
  final String id;
  final String email;
  final String name;
  final String username;
  final String? photoUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final List<String> followingIds;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.username,
    this.photoUrl,
    this.bio,
    required this.createdAt,
    this.lastLogin,
    this.followingIds = const [],
  });

  // From JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? json['uid'] ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      username: json['username'] ?? '',
      photoUrl: json['photoUrl'] ?? json['photo_url'],
      bio: json['bio']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      lastLogin: json['lastLogin'] != null
          ? DateTime.parse(json['lastLogin'])
          : null,
      followingIds: (json['followingIds'] as List<dynamic>?)
              ?.map((id) => id.toString())
              .toList() ??
          (json['following'] as List<dynamic>?)
                  ?.map((id) => id.toString())
                  .toList() ??
          const [],
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'username': username,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
      'followingIds': followingIds,
    };
  }

  // From Firestore
  factory UserModel.fromFirestore(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      username: data['username'] ?? '',
      photoUrl: data['photoUrl'],
      bio: data['bio']?.toString(),
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : DateTime.now(),
      lastLogin: data['lastLogin'] != null
          ? (data['lastLogin'] as dynamic).toDate()
          : null,
      followingIds: (data['followingIds'] as List<dynamic>?)
              ?.map((id) => id.toString())
              .toList() ??
          (data['following'] as List<dynamic>?)
                  ?.map((id) => id.toString())
                  .toList() ??
          const [],
    );
  }

  // To Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'email': email,
      'name': name,
      'username': username,
      'photoUrl': photoUrl,
      'bio': bio,
      'createdAt': createdAt,
      'lastLogin': lastLogin,
      'followingIds': followingIds,
    };
  }

  // Copy with
  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? username,
    String? photoUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? lastLogin,
    List<String>? followingIds,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      username: username ?? this.username,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
      followingIds: followingIds ?? this.followingIds,
    );
  }
}
