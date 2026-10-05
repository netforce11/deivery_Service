class UserModel {
  final String id;
  final String name;
  final String phone;
  final String address;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'] ?? '',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'address': address,
      'createdAt': createdAt,
    };
  }
}
