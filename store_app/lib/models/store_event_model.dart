import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType {
  flashSale,   // ⚡ 타임어택 할인
  luckyOrder,  // 🍀 럭키 오더
  challenge,   // 🏆 챌린지 (건수 달성)
  welcomeCoupon, // 🎁 첫 주문 쿠폰
}

extension EventTypeExt on EventType {
  String get label {
    switch (this) {
      case EventType.flashSale:     return '타임어택';
      case EventType.luckyOrder:    return '럭키 오더';
      case EventType.challenge:     return '챌린지';
      case EventType.welcomeCoupon: return '웰컴 쿠폰';
    }
  }

  String get emoji {
    switch (this) {
      case EventType.flashSale:     return '⚡';
      case EventType.luckyOrder:    return '🍀';
      case EventType.challenge:     return '🏆';
      case EventType.welcomeCoupon: return '🎁';
    }
  }

  String get description {
    switch (this) {
      case EventType.flashSale:     return '제한 시간 동안 할인 적용';
      case EventType.luckyOrder:    return 'N번째 주문자에게 혜택 제공';
      case EventType.challenge:     return '목표 달성 시 수수료 혜택';
      case EventType.welcomeCoupon: return '첫 주문 고객 자동 할인';
    }
  }

  String get value => name;

  static EventType fromValue(String v) =>
      EventType.values.firstWhere((e) => e.name == v,
          orElse: () => EventType.flashSale);
}

class StoreEventModel {
  final String id;
  final String storeId;
  final EventType type;
  final bool isActive;

  // 타임어택 전용
  final int? discountPercent;    // 10 ~ 50
  final int? durationMinutes;    // 이벤트 지속 시간
  final int? maxParticipants;    // 선착순 제한 (null = 무제한)
  final int participantCount;    // 현재 참여 수

  // 럭키오더 전용
  final int? luckyOrderNumber;   // N번째 주문자 (예: 10)
  final String? luckyReward;     // '배달비 무료' | '10% 할인' | '음료 서비스'

  // 챌린지 전용
  final int? targetOrders;       // 목표 건수
  final int currentOrders;       // 현재 완료 건수
  final String? challengeReward; // '수수료 1% 감면' | '배너 노출 +1일'

  // 웰컴쿠폰 전용
  final int? welcomeDiscountPercent;

  final DateTime startAt;
  final DateTime? endAt;         // null이면 수동 종료

  StoreEventModel({
    required this.id,
    required this.storeId,
    required this.type,
    required this.isActive,
    this.discountPercent,
    this.durationMinutes,
    this.maxParticipants,
    this.participantCount = 0,
    this.luckyOrderNumber,
    this.luckyReward,
    this.targetOrders,
    this.currentOrders = 0,
    this.challengeReward,
    this.welcomeDiscountPercent,
    required this.startAt,
    this.endAt,
  });

  bool get isExpired => endAt != null && DateTime.now().isAfter(endAt!);
  bool get isFull =>
      maxParticipants != null && participantCount >= maxParticipants!;

  /// 타임어택 남은 시간 (null이면 시간 제한 없음)
  Duration? get remaining {
    if (endAt == null) return null;
    final r = endAt!.difference(DateTime.now());
    return r.isNegative ? Duration.zero : r;
  }

  /// 챌린지 달성률
  double get challengeProgress =>
      targetOrders == null ? 0 : (currentOrders / targetOrders!).clamp(0.0, 1.0);

  factory StoreEventModel.fromMap(Map<String, dynamic> map, String id) {
    return StoreEventModel(
      id: id,
      storeId: map['storeId'] ?? '',
      type: EventTypeExt.fromValue(map['type'] ?? 'flashSale'),
      isActive: map['isActive'] ?? false,
      discountPercent: map['discountPercent'],
      durationMinutes: map['durationMinutes'],
      maxParticipants: map['maxParticipants'],
      participantCount: map['participantCount'] ?? 0,
      luckyOrderNumber: map['luckyOrderNumber'],
      luckyReward: map['luckyReward'],
      targetOrders: map['targetOrders'],
      currentOrders: map['currentOrders'] ?? 0,
      challengeReward: map['challengeReward'],
      welcomeDiscountPercent: map['welcomeDiscountPercent'],
      startAt: (map['startAt'] as Timestamp).toDate(),
      endAt: map['endAt'] != null
          ? (map['endAt'] as Timestamp).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'type': type.value,
        'isActive': isActive,
        if (discountPercent != null) 'discountPercent': discountPercent,
        if (durationMinutes != null) 'durationMinutes': durationMinutes,
        if (maxParticipants != null) 'maxParticipants': maxParticipants,
        'participantCount': participantCount,
        if (luckyOrderNumber != null) 'luckyOrderNumber': luckyOrderNumber,
        if (luckyReward != null) 'luckyReward': luckyReward,
        if (targetOrders != null) 'targetOrders': targetOrders,
        'currentOrders': currentOrders,
        if (challengeReward != null) 'challengeReward': challengeReward,
        if (welcomeDiscountPercent != null)
          'welcomeDiscountPercent': welcomeDiscountPercent,
        'startAt': Timestamp.fromDate(startAt),
        if (endAt != null) 'endAt': Timestamp.fromDate(endAt!),
      };
}
