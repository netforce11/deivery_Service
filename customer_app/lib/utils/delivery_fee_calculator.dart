import 'dart:math';

/// 거리(km) 기반 배달비 계산 유틸
class DeliveryFeeCalculator {
  // 배달비 구간 정의
  static const List<_Tier> _tiers = [
    _Tier(maxKm: 3,  fee: 3500,  label: '단거리'),
    _Tier(maxKm: 7,  fee: 5000,  label: '단거리'),
    _Tier(maxKm: 15, fee: 8000,  label: '장거리'),
    _Tier(maxKm: 30, fee: 12000, label: '장거리'),
    _Tier(maxKm: double.infinity, fee: 20000, label: '장거리'),
  ];

  /// 배달비 계산
  static int calculate(double distanceKm) {
    for (final tier in _tiers) {
      if (distanceKm <= tier.maxKm) return tier.fee;
    }
    return 20000;
  }

  /// 거리 구분 라벨 (단거리 / 장거리)
  static String label(double distanceKm) {
    for (final tier in _tiers) {
      if (distanceKm <= tier.maxKm) return tier.label;
    }
    return '장거리';
  }

  /// 장거리 여부 (7km 초과)
  static bool isLongDistance(double distanceKm) => distanceKm > 7.0;

  /// 두 좌표 간 직선 거리(km) — Haversine 공식
  static double distanceKm(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _rad(double deg) => deg * pi / 180;

  /// 배달비 구간 전체 목록 (UI 표시용)
  static List<Map<String, dynamic>> get tiers => _tiers
      .map((t) => {
            'maxKm': t.maxKm == double.infinity ? '30km+' : '${t.maxKm.toInt()}km',
            'fee': t.fee,
            'label': t.label,
          })
      .toList();
}

class _Tier {
  final double maxKm;
  final int fee;
  final String label;
  const _Tier({required this.maxKm, required this.fee, required this.label});
}
