import 'dart:math';
import 'package:geolocator/geolocator.dart';

class CustomerLocationService {
  static CustomerLocationService? _instance;
  static CustomerLocationService get instance =>
      _instance ??= CustomerLocationService._();
  CustomerLocationService._();

  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  /// 현재 위치 가져오기 (권한 포함)
  /// 실패하면 null 반환 — UI가 null 처리해서 위치 없이도 동작해야 함
  Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // 배터리 절약
          timeLimit: Duration(seconds: 5),
        ),
      );
      return _lastPosition;
    } catch (_) {
      return _lastPosition; // 실패 시 마지막 위치라도 반환
    }
  }

  /// 두 좌표 간 거리 (km) — Haversine 공식
  static double distanceKm(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    const r = 6371.0; // 지구 반경 km
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  static double _rad(double deg) => deg * pi / 180;

  /// 거리 표시 문자열 (500m 이하면 m 단위)
  static String distanceLabel(double km) {
    if (km < 0.5) return '${(km * 1000).round()}m';
    return '${km.toStringAsFixed(1)}km';
  }
}
