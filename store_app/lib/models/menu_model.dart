class MenuModel {
  final String id;
  final String storeId;
  final String name;
  final String description;
  final int price;
  final String category;
  final bool isAvailable;

  MenuModel({
    required this.id,
    required this.storeId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.isAvailable,
  });

  factory MenuModel.fromMap(Map<String, dynamic> map, String id) {
    return MenuModel(
      id: id,
      storeId: map['storeId'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: (map['price'] ?? 0).toInt(),
      category: map['category'] ?? '기타',
      isAvailable: map['isAvailable'] ?? true,
    );
  }

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'name': name,
        'description': description,
        'price': price,
        'category': category,
        'isAvailable': isAvailable,
      };
}
