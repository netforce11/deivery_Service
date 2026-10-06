import 'package:cloud_firestore/cloud_firestore.dart';

/// 캠페인 상태
enum AidCampaignStatus { active, completed, cancelled }

/// 라이언 일병 구하기 캠페인
/// Firestore 컬렉션: riderAidCampaigns
class RiderAidCampaignModel {
  final String id;
  final String injuredRiderName;   // 부상 라이더 이름 (익명 처리 가능)
  final bool isAnonymous;          // 익명 공개 여부
  final String description;        // 부상 경위 / 도움 요청 내용
  final int goalAmount;            // 목표 적립금 (원)
  final int currentAmount;         // 현재 적립금 (원)
  final int companyMatchAmount;    // 회사 매칭 누계 (원)
  final int participantCount;      // 참여 라이더 수
  final AidCampaignStatus status;
  final DateTime startDate;
  final DateTime? endDate;         // null = 목표 달성 시 자동 종료
  final DateTime createdAt;

  RiderAidCampaignModel({
    required this.id,
    required this.injuredRiderName,
    this.isAnonymous = false,
    this.description = '',
    required this.goalAmount,
    this.currentAmount = 0,
    this.companyMatchAmount = 0,
    this.participantCount = 0,
    this.status = AidCampaignStatus.active,
    required this.startDate,
    this.endDate,
    required this.createdAt,
  });

  bool get isActive => status == AidCampaignStatus.active;

  /// 목표 달성률 (0.0 ~ 1.0 이상)
  double get progress =>
      goalAmount > 0 ? currentAmount / goalAmount : 0;

  /// 목표 달성 여부
  bool get isGoalReached => currentAmount >= goalAmount;

  /// 표시 이름 (익명이면 마스킹)
  String get displayName =>
      isAnonymous ? '익명의 라이더' : injuredRiderName;

  /// 남은 금액
  int get remainingAmount =>
      (goalAmount - currentAmount).clamp(0, goalAmount);

  factory RiderAidCampaignModel.fromMap(
      Map<String, dynamic> map, String id) {
    return RiderAidCampaignModel(
      id: id,
      injuredRiderName: map['injuredRiderName'] as String? ?? '라이더',
      isAnonymous: map['isAnonymous'] == true,
      description: map['description'] as String? ?? '',
      goalAmount: (map['goalAmount'] ?? 0).toInt(),
      currentAmount: (map['currentAmount'] ?? 0).toInt(),
      companyMatchAmount: (map['companyMatchAmount'] ?? 0).toInt(),
      participantCount: (map['participantCount'] ?? 0).toInt(),
      status: _parseStatus(map['status']),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'injuredRiderName': injuredRiderName,
    'isAnonymous': isAnonymous,
    'description': description,
    'goalAmount': goalAmount,
    'currentAmount': currentAmount,
    'companyMatchAmount': companyMatchAmount,
    'participantCount': participantCount,
    'status': status.name,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static AidCampaignStatus _parseStatus(dynamic v) {
    try {
      return AidCampaignStatus.values.firstWhere((e) => e.name == v);
    } catch (_) {
      return AidCampaignStatus.active;
    }
  }
}

/// 라이언 콜 참여 기록 1건
/// Firestore 컬렉션: riderAidContributions
class RiderAidContributionModel {
  final String id;
  final String campaignId;
  final String riderId;
  final String riderName;
  final String orderId;
  final int riderContribution;    // 라이더 차감액 (수익의 50%)
  final int companyMatch;         // 회사 매칭 (= riderContribution)
  final int totalContribution;    // 합계
  final DateTime createdAt;

  RiderAidContributionModel({
    required this.id,
    required this.campaignId,
    required this.riderId,
    required this.riderName,
    required this.orderId,
    required this.riderContribution,
    required this.companyMatch,
    required this.totalContribution,
    required this.createdAt,
  });

  factory RiderAidContributionModel.fromMap(
      Map<String, dynamic> map, String id) {
    return RiderAidContributionModel(
      id: id,
      campaignId: map['campaignId'] as String,
      riderId: map['riderId'] as String,
      riderName: map['riderName'] as String? ?? '라이더',
      orderId: map['orderId'] as String,
      riderContribution: (map['riderContribution'] ?? 0).toInt(),
      companyMatch: (map['companyMatch'] ?? 0).toInt(),
      totalContribution: (map['totalContribution'] ?? 0).toInt(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'campaignId': campaignId,
    'riderId': riderId,
    'riderName': riderName,
    'orderId': orderId,
    'riderContribution': riderContribution,
    'companyMatch': companyMatch,
    'totalContribution': totalContribution,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}
