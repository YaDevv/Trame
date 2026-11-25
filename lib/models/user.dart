enum UserRole { member, admin }

class User {
  const User({required this.id, required this.displayName, required this.role});

  final String id;
  final String displayName;
  final UserRole role;

  bool get isAdmin => role == UserRole.admin;
}
