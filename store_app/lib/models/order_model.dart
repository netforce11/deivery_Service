class OrderItem {
  final String menuId;
  final String name;
  final int price;
  final int quantity;

  OrderItem({
    required this.menuId,
    required this.name,
    required this.price,
    required this.quantity,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      menuId: map['menuId'] ?? '',
      name: map['name'] ?? '',
      price: map['price'] ?? 0,
      quantity: map['quantity'] ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'menuId': menuId,
      'name': name,
      'price': price,
      'quantity': quantity,
    };
  }
}

class OrderModel {
  final String id;
  final String customerId;
  final String storeId;
  final String? riderId;
  final String? bundleId;
  final List<OrderItem> items;
  final int totalPrice;
  final int platformFee;       // 음식값의 12%
  final int deliveryFee;       // 고객 부담 배달비 3500원
  final int riderPay;          // 기사 수령액 3500원
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  // pending → accepted → assigned → picked_up → delivered → cancelled
  final String status;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.customerId,
    required this.storeId,
    this.riderId,
    this.bundleId,
    required this.items,
    required this.totalPrice,
    required this.platformFee,
    required this.deliveryFee,
    required this.riderPay,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.status,
    required this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      customerId: map['customerId'] ?? '',
      storeId: map['storeId'] ?? '',
      riderId: map['riderId'],
      bundleId: map['bundleId'],
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => OrderItem.fromMap(e))
              .toList() ??
          [],
      totalPrice: map['totalPrice'] ?? 0,
      platformFee: map['platformFee'] ?? 0,
      deliveryFee: map['deliveryFee'] ?? 3500,
      riderPay: map['riderPay'] ?? 3500,
      deliveryAddress: map['deliveryAddress'] ?? '',
      deliveryLat: map['deliveryLat'] ?? 0.0,
      deliveryLng: map['deliveryLng'] ?? 0.0,
      status: map['status'] ?? 'pending',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'storeId': storeId,
      'riderId': riderId,
      'bundleId': bundleId,
      'items': items.map((e) => e.toMap()).toList(),
      'totalPrice': totalPrice,
      'platformFee': platformFee,
      'deliveryFee': deliveryFee,
      'riderPay': riderPay,
      'deliveryAddress': deliveryAddress,
      'deliveryLat': deliveryLat,
      'deliveryLng': deliveryLng,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
