class UserEntity {
  final String id;
  final String email;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final DateTime createdAt;

  const UserEntity({
    required this.id,
    required this.email,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.role = 'customer',
    required this.createdAt,
  });

  bool get isAdmin => role == 'admin';

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      role: json['role'] as String? ?? 'customer',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'phone': phone,
        'avatar_url': avatarUrl,
        'role': role,
      };

  UserEntity copyWith({
    String? fullName,
    String? phone,
    String? avatarUrl,
  }) {
    return UserEntity(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      role: role,
      createdAt: createdAt,
    );
  }
}
