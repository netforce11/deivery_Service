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
  // 즉시 구현 기능 필드
  final String notice;           // 공지사항
  final int estimatedMinutes;    // 예상 조리시간 (분)
  final Map<String, Map<String, String>> businessHours; // 요일별 영업시간

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
    this.notice = '',
    this.estimatedMinutes = 30,
    this.businessHours = const {},
  });

  factory StoreModel.fromMap(Map<String, dynamic> map, String id) {
    // 요일별 영업시간 파싱
    Map<String, Map<String, String>> bh = {};
    final rawBh = map['businessHours'];
    if (rawBh is Map) {
      rawBh.forEach((day, times) {
        if (times is Map) {
          bh[day] = {'open': times['open'] ?? '09:00', 'close': times['close'] ?? '22:00'};
        }
      });
    }

    return StoreModel(
      id: id,
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      address: map['address'] ?? '',
      lat: (map['lat'] ?? 0.0).toDouble(),
      lng: (map['lng'] ?? 0.0).toDouble(),
      phone: map['phone'] ?? '',
      ownerId: map['ownerId'] ?? '',
      isOpen: map['isOpen'] ?? false,
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      notice: map['notice'] ?? '',
      estimatedMinutes: (map['estimatedMinutes'] ?? 30).toInt(),
      businessHours: bh,
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
      'notice': notice,
      'estimatedMinutes': estimatedMinutes,
      'businessHours': businessHours,
    };
  }

  StoreModel copyWith({
    bool? isOpen,
    String? notice,
    int? estimatedMinutes,
    Map<String, Map<String, String>>? businessHours,
  }) {
    return StoreModel(
      id: id,
      name: name,
      category: category,
      address: address,
      lat: lat,
      lng: lng,
      phone: phone,
      ownerId: ownerId,
      isOpen: isOpen ?? this.isOpen,
      createdAt: createdAt,
      notice: notice ?? this.notice,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      businessHours: businessHours ?? this.businessHours,
    );
  }
}
