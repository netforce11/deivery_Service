class StoreModel {
  final String id;
  final String name;
  final String category;
  final String address;
  final double lat;
  final double lng;
  final String phone;
  final String ownerId;
  final bool isOpen;
  final DateTime createdAt;

  StoreModel({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.lat,
    required this.lng,
    required this.phone,
    required this.ownerId,
    required this.isOpen,
    required this.createdAt,
  });

  factory StoreModel.fromMap(Map<String, dynamic> map, String id) {
    return StoreModel(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      address: map['address'] ?? '',
      lat: map['lat'] ?? 0.0,
      lng: map['lng'] ?? 0.0,
      phone: map['phone'] ?? '',
      ownerId: map['ownerId'] ?? '',
      isOpen: map['isOpen'] ?? false,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'category': category,
      'address': address,
      'lat': lat,
      'lng': lng,
      'phone': phone,
      'ownerId': ownerId,
      'isOpen': isOpen,
      'createdAt': createdAt,
    };
  }
}
