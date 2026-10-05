class BundleModel {
  final String id;
  final String riderId;
  final String storeId;
  final List<String> orderIds; // 최대 3건
  final double maxDistance;    // 2000m (2km)
  final String status;         // delivering, completed
  final DateTime createdAt;

  BundleModel({
    required this.id,
    required this.riderId,
    required this.storeId,
    required this.orderIds,
    required this.maxDistance,
    required this.status,
    required this.createdAt,
  });

  factory BundleModel.fromMap(Map<String, dynamic> map, String id) {
    return BundleModel(
      id: id,
      riderId: map['riderId'] ?? '',
      storeId: map['storeId'] ?? '',
      orderIds: List<String>.from(map['orderIds'] ?? []),
      maxDistance: map['maxDistance'] ?? 2000.0,
      status: map['status'] ?? 'delivering',
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'storeId': storeId,
      'orderIds': orderIds,
      'maxDistance': maxDistance,
      'status': status,
      'createdAt': createdAt,
    };
  }
}
