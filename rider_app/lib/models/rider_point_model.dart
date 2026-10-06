import 'package:cloud_firestore/cloud_firestore.dart';

/// 포인트 적립 사유
enum PointReason {
  longDistanceCollaboration, // 장거리 협업 +3
  fiveHourWork,              // 5시간 근무 +1
  kindnessDaily,             // 고객 친절 일일 +1
  noCancelDaily,             // 취소/거절 없음 +2
  monthly100,                // 월 100건 달성 +2
  badWeatherDelivery,        // 우천/악천후 +1
  peakTime5,                 // 피크타임 연속 5건 +1
  sevenDayStreak,            // 7일 연속 출근 +3
  newAreaDelivery,           // 신규 배달지역 +1
}

extension PointReasonExt on PointReason {
  String get label {
    switch (this) {
      case PointReason.longDistanceCollaboration: return '장거리 협업 참여';
      case PointReason.fiveHourWork:             return '5시간 근무 달성';
      case PointReason.kindnessDaily:            return '고객 친절 달성';
      case PointReason.noCancelDaily:            return '취소/거절 없음';
      case PointReason.monthly100:               return '월 100건 달성';
      case PointReason.badWeatherDelivery:       return '악천후 배달 완료';
      case PointReason.peakTime5:                return '피크타임 연속 5건';
      case PointReason.sevenDayStreak:           return '7일 연속 출근';
      case PointReason.newAreaDelivery:          return '신규 지역 배달';
    }
  }

  int get points {
    switch (this) {
      case PointReason.longDistanceCollaboration: return 3;
      case PointReason.fiveHourWork:             return 1;
      case PointReason.kindnessDaily:            return 1;
      case PointReason.noCancelDaily:            return 2;
      case PointReason.monthly100:               return 2;
      case PointReason.badWeatherDelivery:       return 1;
      case PointReason.peakTime5:                return 1;
      case PointReason.sevenDayStreak:           return 3;
      case PointReason.newAreaDelivery:          return 1;
    }
  }
}

/// 포인트 이력 단건
class PointHistoryEntry {
  final PointReason reason;
  final int points;
  final DateTime earnedAt;

  PointHistoryEntry({
    required this.reason,
    required this.points,
    required this.earnedAt,
  });

  factory PointHistoryEntry.fromMap(Map<String, dynamic> map) {
    return PointHistoryEntry(
      reason: _parseReason(map['reason']),
      points: (map['points'] ?? 0).toInt(),
      earnedAt: (map['earnedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'reason': reason.name,
    'points': points,
    'earnedAt': Timestamp.fromDate(earnedAt),
  };

  static PointReason _parseReason(dynamic v) {
    try {
      return PointReason.values.firstWhere((e) => e.name == v);
    } catch (_) {
      return PointReason.fiveHourWork;
    }
  }
}

/// 라이더 포인트 상태
class RiderPointModel {
  final String riderId;
  final int totalPoints;        // 누적 포인트 (부스터 충전용)
  final int dailyPoints;        // 오늘 획득 포인트 (콜 우선순위용)
  final int boosterCharges;     // 충전된 부스터 횟수 (100점당 1회)
  final DateTime? boosterActiveUntil; // 부스터 만료 시각 (null=비활성)
  final int consecutiveDays;    // 연속 출근일
  final DateTime? lastWorkDate; // 마지막 근무일
  final List<PointHistoryEntry> todayHistory; // 오늘 적립 내역

  RiderPointModel({
    required this.riderId,
    this.totalPoints = 0,
    this.dailyPoints = 0,
    this.boosterCharges = 0,
    this.boosterActiveUntil,
    this.consecutiveDays = 0,
    this.lastWorkDate,
    this.todayHistory = const [],
  });

  bool get isBoosterActive =>
      boosterActiveUntil != null &&
      boosterActiveUntil!.isAfter(DateTime.now());

  Duration get boosterRemaining =>
      isBoosterActive
          ? boosterActiveUntil!.difference(DateTime.now())
          : Duration.zero;

  /// 등급 계산
  String get grade {
    if (totalPoints >= 300) return 'GOLD';
    if (totalPoints >= 150) return 'SILVER';
    return 'BRONZE';
  }

  /// 다음 등급까지 필요 포인트
  int get pointsToNextGrade {
    if (totalPoints >= 300) return 0;
    if (totalPoints >= 150) return 300 - totalPoints;
    return 150 - totalPoints;
  }

  /// 다음 부스터 충전까지 필요 포인트
  int get pointsToNextBooster => 100 - (totalPoints % 100);

  factory RiderPointModel.fromMap(Map<String, dynamic> map, String riderId) {
    final historyRaw = map['todayHistory'] as List? ?? [];
    return RiderPointModel(
      riderId: riderId,
      totalPoints: (map['totalPoints'] ?? 0).toInt(),
      dailyPoints: (map['dailyPoints'] ?? 0).toInt(),
      boosterCharges: (map['boosterCharges'] ?? 0).toInt(),
      boosterActiveUntil:
          (map['boosterActiveUntil'] as Timestamp?)?.toDate(),
      consecutiveDays: (map['consecutiveDays'] ?? 0).toInt(),
      lastWorkDate: (map['lastWorkDate'] as Timestamp?)?.toDate(),
      todayHistory: historyRaw
          .map((e) => PointHistoryEntry.fromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toMap() => {
    'totalPoints': totalPoints,
    'dailyPoints': dailyPoints,
    'boosterCharges': boosterCharges,
    'boosterActiveUntil': boosterActiveUntil != null
        ? Timestamp.fromDate(boosterActiveUntil!)
        : null,
    'consecutiveDays': consecutiveDays,
    'lastWorkDate':
        lastWorkDate != null ? Timestamp.fromDate(lastWorkDate!) : null,
    'todayHistory': todayHistory.map((e) => e.toMap()).toList(),
  };
}
