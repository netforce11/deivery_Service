import 'dart:convert';
import 'package:http/http.dart' as http;

class AddressResult {
  final String displayName;   // 전체 주소 (한국어)
  final String shortName;     // 짧은 주소 (도로명/지번 위주)
  final double lat;
  final double lng;

  AddressResult({
    required this.displayName,
    required this.shortName,
    required this.lat,
    required this.lng,
  });
}

class GeocodingService {
  // Nominatim (OpenStreetMap) — 무료, API 키 불필요
  // 주의: 초당 1회 호출 제한 (상업용은 유료 플랜 사용)
  static const _baseUrl = 'https://nominatim.openstreetmap.org';

  /// 주소 텍스트로 검색 → 결과 목록 반환
  static Future<List<AddressResult>> search(String query) async {
    if (query.trim().isEmpty) return [];

    final uri = Uri.parse('$_baseUrl/search').replace(queryParameters: {
      'q': query,
      'format': 'json',
      'addressdetails': '1',
      'limit': '7',
      'countrycodes': 'kr',          // 한국만 검색
      'accept-language': 'ko',       // 한국어 결과
    });

    try {
      final resp = await http.get(uri, headers: {
        'User-Agent': 'DeliveryApp/1.0 (contact@example.com)',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return [];

      final data = jsonDecode(resp.body) as List<dynamic>;
      return data.map((item) {
        final address = item['address'] as Map<String, dynamic>? ?? {};
        final shortName = _buildShortName(address, item['display_name'] ?? '');
        return AddressResult(
          displayName: item['display_name'] ?? '',
          shortName: shortName,
          lat: double.tryParse(item['lat'] ?? '0') ?? 0,
          lng: double.tryParse(item['lon'] ?? '0') ?? 0,
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 위도/경도 → 주소 (역지오코딩)
  static Future<AddressResult?> reverseGeocode(double lat, double lng) async {
    final uri = Uri.parse('$_baseUrl/reverse').replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'format': 'json',
      'addressdetails': '1',
      'accept-language': 'ko',
    });

    try {
      final resp = await http.get(uri, headers: {
        'User-Agent': 'DeliveryApp/1.0 (contact@example.com)',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode != 200) return null;
      final item = jsonDecode(resp.body) as Map<String, dynamic>;
      final address = item['address'] as Map<String, dynamic>? ?? {};
      final shortName = _buildShortName(address, item['display_name'] ?? '');
      return AddressResult(
        displayName: item['display_name'] ?? '',
        shortName: shortName,
        lat: lat,
        lng: lng,
      );
    } catch (e) {
      return null;
    }
  }

  /// 표시할 짧은 주소 조합
  static String _buildShortName(Map<String, dynamic> addr, String fallback) {
    // 우선순위: 도로명 > 동 > 구 > 시
    final road = addr['road'] as String?;
    final houseNumber = addr['house_number'] as String?;
    final suburb = addr['suburb'] as String?;
    final quarter = addr['quarter'] as String?;
    final city = addr['city'] as String? ??
        addr['county'] as String? ??
        addr['state'] as String? ?? '';

    final parts = <String>[];
    if (city.isNotEmpty) parts.add(city);
    if (suburb != null) parts.add(suburb);
    else if (quarter != null) parts.add(quarter);
    if (road != null) {
      parts.add(houseNumber != null ? '$road $houseNumber' : road);
    }

    return parts.isEmpty ? fallback : parts.join(' ');
  }
}
