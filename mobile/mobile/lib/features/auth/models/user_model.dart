class UserModel {
  final String id;
  final String email;
  final String? name;

  const UserModel({
    required this.id,
    required this.email,
    this.name,
  });
}
