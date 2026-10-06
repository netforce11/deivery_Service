import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// OSRM (OpenStreetMap Routing Machine) 무료 경로 API
class RoutingService {
  static const _base = 'https://router.project-osrm.org/route/v1/driving';

  /// 두 좌표 간 경로 폴리라인 반환
  static Future<List<LatLng>> getRoute(LatLng from, LatLng to) async {
    final url =
        '$_base/${from.longitude},${from.latitude};${to.longitude},${to.latitude}'
        '?overview=full&geometries=geojson';
    try {
      final resp = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return _fallback(from, to);
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return _fallback(from, to);
      final coords =
          routes[0]['geometry']['coordinates'] as List<dynamic>;
      return coords
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      return _fallback(from, to);
    }
  }

  /// API 실패 시 직선 대체
  static List<LatLng> _fallback(LatLng from, LatLng to) => [from, to];

  /// 두 좌표 간 직선 거리 (km)
  static double distanceKm(LatLng from, LatLng to) {
    const dist = Distance();
    return dist.as(LengthUnit.Kilometer, from, to);
  }

  /// 거리 → 예상 시간 (분, 평균 20km/h 기준)
  static int estimatedMinutes(double km) => (km / 20 * 60).ceil();
}
