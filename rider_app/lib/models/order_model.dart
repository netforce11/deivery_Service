import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String name;
  final int quantity;
  final int price;

  OrderItem({required this.name, required this.quantity, required this.price});

  factory OrderItem.fromMap(Map<String, dynamic> map) => OrderItem(
        name: map['name'] ?? '',
        quantity: (map['quantity'] ?? 1).toInt(),
        price: (map['price'] ?? 0).toInt(),
      );
}

class OrderModel {
  final String id;
  final String storeId;
  final String storeName;
  final String customerId;
  final String deliveryAddress;
  final double deliveryLat;
  final double deliveryLng;
  final List<OrderItem> items;
  final int totalPrice;
  final int riderPay;
  final String status;
  final String? riderId;
  final double? riderLat;
  final double? riderLng;
  final double? distanceKm;     // 가게→배달지 거리
  final bool isLongDistance;    // 7km 초과 여부
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.storeId,
    required this.storeName,
    required this.customerId,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
    required this.items,
    required this.totalPrice,
    this.riderPay = 3500,
    required this.status,
    this.riderId,
    this.riderLat,
    this.riderLng,
    this.distanceKm,
    this.isLongDistance = false,
    required this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    final rawItems = (map['items'] as List<dynamic>?) ?? [];
    return OrderModel(
      id: id,
      storeId: map['storeId'] ?? '',
      storeName: map['storeName'] ?? '',
      customerId: map['customerId'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      deliveryLat: (map['deliveryLat'] ?? 0.0).toDouble(),
      deliveryLng: (map['deliveryLng'] ?? 0.0).toDouble(),
      items: rawItems.map((e) => OrderItem.fromMap(e as Map<String, dynamic>)).toList(),
      totalPrice: (map['totalPrice'] ?? 0).toInt(),
      riderPay: (map['riderPay'] ?? 3500).toInt(),
      status: map['status'] ?? 'pending',
      riderId: map['riderId'],
      riderLat: map['riderLat'] != null ? (map['riderLat'] as num).toDouble() : null,
      riderLng: map['riderLng'] != null ? (map['riderLng'] as num).toDouble() : null,
      distanceKm: map['distanceKm'] != null ? (map['distanceKm'] as num).toDouble() : null,
      isLongDistance: map['isLongDistance'] ?? false,
      createdAt: map['createdAt'] is Timestamp
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}
