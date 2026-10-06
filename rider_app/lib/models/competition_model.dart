import 'package:cloud_firestore/cloud_firestore.dart';

// ── 경쟁 종류 ─────────────────────────────────────────────────────────────────

enum CompetitionType {
  longDistance, // 최고 장거리 운행
  efficiency,   // 최고 효율 라이더
}

extension CompetitionTypeExt on CompetitionType {
  String get label {
    switch (this) {
      case CompetitionType.longDistance: return '최고 장거리 운행';
      case CompetitionType.efficiency:   return '최고 효율 라이더';
    }
  }

  String get emoji {
    switch (this) {
      case CompetitionType.longDistance: return '🏆';
      case CompetitionType.efficiency:   return '⚡';
    }
  }
}

// ── 이동 수단 ─────────────────────────────────────────────────────────────────

enum VehicleType { bicycle, motorcycle, car, all }

extension VehicleTypeExt on VehicleType {
  String get label {
    switch (this) {
      case VehicleType.bicycle:    return '자전거';
      case VehicleType.motorcycle: return '오토바이';
      case VehicleType.car:        return '자동차';
      case VehicleType.all:        return '전체';
    }
  }

  String get emoji {
    switch (this) {
      case VehicleType.bicycle:    return '🚲';
      case VehicleType.motorcycle: return '🛵';
      case VehicleType.car:        return '🚗';
      case VehicleType.all:        return '🏁';
    }
  }
}

// ── 경쟁 이벤트 모델 ──────────────────────────────────────────────────────────
// Firestore 컬렉션: riderCompetitions

class CompetitionModel {
  final String id;
  final String name;               // 예: "달려라 하니 상 - 10월"
  final CompetitionType type;
  final VehicleType vehicleType;   // longDistance 전용 (efficiency는 all)
  final String region;             // "" = 전국, "서울" / "부산" 등
  final DateTime startDate;
  final DateTime endDate;
  final bool isActive;             // 관제서버에서 수동 활성화/비활성화
  final String prizeDescription;  // 상품 설명
  final int maxRank;               // 표시할 최대 순위 (기본 10)
  final DateTime createdAt;

  CompetitionModel({
    required this.id,
    required this.name,
    required this.type,
    this.vehicleType = VehicleType.all,
    this.region = '',
    required this.startDate,
    required this.endDate,
    this.isActive = false,
    this.prizeDescription = '',
    this.maxRank = 10,
    required this.createdAt,
  });

  /// 현재 시각 기준 진행 중인지 (isActive + 날짜 범위 모두 만족)
  bool get isRunning {
    if (!isActive) return false;
    final now = DateTime.now();
    return now.isAfter(startDate) && now.isBefore(endDate);
  }

  /// 종료까지 남은 시간
  Duration get remaining {
    final now = DateTime.now();
    if (now.isAfter(endDate)) return Duration.zero;
    return endDate.difference(now);
  }

  /// 지역 표시명
  String get regionLabel => region.isEmpty ? '전국' : region;

  factory CompetitionModel.fromMap(Map<String, dynamic> map, String id) {
    return CompetitionModel(
      id: id,
      name: map['name'] as String? ?? '',
      type: _parseType(map['type']),
      vehicleType: _parseVehicle(map['vehicleType']),
      region: map['region'] as String? ?? '',
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      isActive: map['isActive'] == true,
      prizeDescription: map['prizeDescription'] as String? ?? '',
      maxRank: (map['maxRank'] ?? 10).toInt(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'type': type.name,
    'vehicleType': vehicleType.name,
    'region': region,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
    'isActive': isActive,
    'prizeDescription': prizeDescription,
    'maxRank': maxRank,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  static CompetitionType _parseType(dynamic v) {
    try { return CompetitionType.values.firstWhere((e) => e.name == v); }
    catch (_) { return CompetitionType.efficiency; }
  }

  static VehicleType _parseVehicle(dynamic v) {
    try { return VehicleType.values.firstWhere((e) => e.name == v); }
    catch (_) { return VehicleType.all; }
  }
}

// ── 참가자 기록 모델 ──────────────────────────────────────────────────────────
// Firestore 컬렉션: riderCompetitionEntries

class CompetitionEntryModel {
  final String id;             // {competitionId}_{riderId}
  final String competitionId;
  final String riderId;
  final String riderName;
  final VehicleType vehicleType;
  final String region;

  // longDistance 지표
  final double totalDistanceKm;

  // efficiency 지표
  final int totalDeliveries;
  final int totalWorkMinutes;

  final DateTime lastUpdated;

  CompetitionEntryModel({
    required this.id,
    required this.competitionId,
    required this.riderId,
    required this.riderName,
    this.vehicleType = VehicleType.motorcycle,
    this.region = '',
    this.totalDistanceKm = 0,
    this.totalDeliveries = 0,
    this.totalWorkMinutes = 0,
    required this.lastUpdated,
  });

  /// 시간당 배달 건수 (효율 지표)
  double get deliveriesPerHour {
    if (totalWorkMinutes <= 0) return 0;
    return totalDeliveries / (totalWorkMinutes / 60);
  }

  /// 정렬 점수 (타입별)
  double score(CompetitionType type) {
    switch (type) {
      case CompetitionType.longDistance: return totalDistanceKm;
      case CompetitionType.efficiency:   return deliveriesPerHour;
    }
  }

  factory CompetitionEntryModel.fromMap(
      Map<String, dynamic> map, String id) {
    return CompetitionEntryModel(
      id: id,
      competitionId: map['competitionId'] as String? ?? '',
      riderId: map['riderId'] as String? ?? '',
      riderName: map['riderName'] as String? ?? '라이더',
      vehicleType: _parseVehicle(map['vehicleType']),
      region: map['region'] as String? ?? '',
      totalDistanceKm: (map['totalDistanceKm'] ?? 0).toDouble(),
      totalDeliveries: (map['totalDeliveries'] ?? 0).toInt(),
      totalWorkMinutes: (map['totalWorkMinutes'] ?? 0).toInt(),
      lastUpdated:
          (map['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'competitionId': competitionId,
    'riderId': riderId,
    'riderName': riderName,
    'vehicleType': vehicleType.name,
    'region': region,
    'totalDistanceKm': totalDistanceKm,
    'totalDeliveries': totalDeliveries,
    'totalWorkMinutes': totalWorkMinutes,
    'lastUpdated': Timestamp.fromDate(lastUpdated),
  };

  static VehicleType _parseVehicle(dynamic v) {
    try { return VehicleType.values.firstWhere((e) => e.name == v); }
    catch (_) { return VehicleType.motorcycle; }
  }
}
