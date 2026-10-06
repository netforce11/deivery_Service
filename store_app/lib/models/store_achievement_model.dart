import 'package:cloud_firestore/cloud_firestore.dart';

/// 플랫폼이 가게 사장님에게 주는 당일 달성 보상
enum AchievementType {
  orderKing,       // 🏅 오늘의 주문왕 (카테고리 내 비율 1위)
  luckyNumber,     // 🍀 럭키 주문번호 도착 — 당일 매출 5% 추가 지급
  speedKing,       // ⚡ 스피드왕 (평균 조리시간 카테고리 최단)
  comebackKing,    // 🔥 재방문왕 (당일 재주문 비율 1위)
  reviewStar,      // ⭐ 리뷰 스타 (당일 5점 리뷰 최다)
}

extension AchievementTypeExt on AchievementType {
  String get emoji {
    switch (this) {
      case AchievementType.orderKing:    return '🏅';
      case AchievementType.luckyNumber:  return '🍀';
      case AchievementType.speedKing:    return '⚡';
      case AchievementType.comebackKing: return '🔥';
      case AchievementType.reviewStar:   return '⭐';
    }
  }

  String get title {
    switch (this) {
      case AchievementType.orderKing:    return '오늘의 주문왕';
      case AchievementType.luckyNumber:  return '럭키 주문번호 도착!';
      case AchievementType.speedKing:    return '스피드왕';
      case AchievementType.comebackKing: return '재방문왕';
      case AchievementType.reviewStar:   return '리뷰 스타';
    }
  }

  String get value => name;

  static AchievementType fromValue(String v) =>
      AchievementType.values.firstWhere((e) => e.name == v,
          orElse: () => AchievementType.orderKing);
}

class StoreAchievementModel {
  final String id;
  final String storeId;
  final AchievementType type;
  final DateTime earnedAt;

  // 주문왕 전용
  final String? category;        // 비교 카테고리
  final double? orderRatio;      // 내 주문 수 / 카테고리 평균 (예: 2.3배)
  final int? orderCount;

  // 럭키 주문번호 전용
  final int? luckyOrderNumber;   // 몇 번째 주문이었는지
  final int? dailyRevenue;       // 당일 매출 (원)
  final int? bonusAmount;        // 추가 지급액 (dailyRevenue * 5%, max 50,000원)
  final bool bonusPaid;

  // 스피드왕 전용
  final int? avgMinutes;

  // 재방문왕 전용
  final double? returnRate;      // 0.0 ~ 1.0

  // 리뷰스타 전용
  final int? fiveStarCount;

  StoreAchievementModel({
    required this.id,
    required this.storeId,
    required this.type,
    required this.earnedAt,
    this.category,
    this.orderRatio,
    this.orderCount,
    this.luckyOrderNumber,
    this.dailyRevenue,
    this.bonusAmount,
    this.bonusPaid = false,
    this.avgMinutes,
    this.returnRate,
    this.fiveStarCount,
  });

  /// 럭키 보너스: 매출 5%, 단 당일 매출 100만원 미만 가게만 / 최대 50,000원
  static int? calcLuckyBonus(int dailyRevenue) {
    if (dailyRevenue >= 1000000) return null; // 100만원 이상 지원 안 함
    final bonus = (dailyRevenue * 0.05).round();
    return bonus.clamp(0, 50000);
  }

  factory StoreAchievementModel.fromMap(Map<String, dynamic> map, String id) {
    return StoreAchievementModel(
      id: id,
      storeId: map['storeId'] ?? '',
      type: AchievementTypeExt.fromValue(map['type'] ?? 'orderKing'),
      earnedAt: (map['earnedAt'] as Timestamp).toDate(),
      category: map['category'],
      orderRatio: (map['orderRatio'] as num?)?.toDouble(),
      orderCount: map['orderCount'],
      luckyOrderNumber: map['luckyOrderNumber'],
      dailyRevenue: map['dailyRevenue'],
      bonusAmount: map['bonusAmount'],
      bonusPaid: map['bonusPaid'] ?? false,
      avgMinutes: map['avgMinutes'],
      returnRate: (map['returnRate'] as num?)?.toDouble(),
      fiveStarCount: map['fiveStarCount'],
    );
  }

  Map<String, dynamic> toMap() => {
        'storeId': storeId,
        'type': type.value,
        'earnedAt': Timestamp.fromDate(earnedAt),
        if (category != null) 'category': category,
        if (orderRatio != null) 'orderRatio': orderRatio,
        if (orderCount != null) 'orderCount': orderCount,
        if (luckyOrderNumber != null) 'luckyOrderNumber': luckyOrderNumber,
        if (dailyRevenue != null) 'dailyRevenue': dailyRevenue,
        if (bonusAmount != null) 'bonusAmount': bonusAmount,
        'bonusPaid': bonusPaid,
        if (avgMinutes != null) 'avgMinutes': avgMinutes,
        if (returnRate != null) 'returnRate': returnRate,
        if (fiveStarCount != null) 'fiveStarCount': fiveStarCount,
      };
}
