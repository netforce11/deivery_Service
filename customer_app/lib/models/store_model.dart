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
  // 날씨 할증 필드
  final bool weatherSurchargeActive;
  final int weatherSurchargeAmount;
  // 리뷰 필드
  final double avgRating;
  final int reviewCount;
  // 활성 이벤트 요약 (null이면 이벤트 없음)
  final Map<String, dynamic>? activeEvent;

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
    this.weatherSurchargeActive = false,
    this.weatherSurchargeAmount = 1000,
    this.avgRating = 0.0,
    this.reviewCount = 0,
    this.activeEvent,
  });

  /// 이벤트 종류 문자열 ('flashSale' | 'luckyOrder' | 'challenge' | 'welcomeCoupon' | null)
  String? get activeEventType => activeEvent?['type'] as String?;


  String? get activeEventBadge {
    switch (activeEventType) {
      case 'flashSale':
        final pct = activeEvent?['discountPercent'];
        return pct != null ? '⚡ ${pct}% 할인중' : '⚡ 타임어택';
      case 'luckyOrder':
        return '🍀 럭키 오더';
      case 'challenge':
        return '🏆 챌린지';
      case 'welcomeCoupon':
        final pct = activeEvent?['welcomeDiscountPercent'];
        return pct != null ? '🎁 첫주문 ${pct}%' : '🎁 웰컴쿠폰';
      default:
        return null;
    }
  }

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
      weatherSurchargeActive: map['weatherSurchargeActive'] ?? false,
      weatherSurchargeAmount: (map['weatherSurchargeAmount'] ?? 1000).toInt(),
      avgRating: (map['avgRating'] ?? 0.0).toDouble(),
      reviewCount: (map['reviewCount'] ?? 0).toInt(),
      activeEvent: map['activeEvent'] as Map<String, dynamic>?,
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
