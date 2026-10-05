class MenuModel {
  final String id;
  final String storeId;
  final String name;
  final int price;
  final String description;
  final String imageUrl;
  final bool isAvailable;

  MenuModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.price,
    required this.description,
    required this.imageUrl,
    required this.isAvailable,
  });

  factory MenuModel.fromMap(Map<String, dynamic> map, String id) {
    return MenuModel(
      id: id,
      storeId: map['storeId'] ?? '',
      name: map['name'] ?? '',
      price: map['price'] ?? 0,
      description: map['description'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      isAvailable: map['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'name': name,
      'price': price,
      'description': description,
      'imageUrl': imageUrl,
      'isAvailable': isAvailable,
    };
  }
}
