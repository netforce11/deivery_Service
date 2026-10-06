import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

/// 기상청 단기예보 API 연동 서비스
/// PTY (강수형태): 0=없음, 1=비, 2=비/눈, 3=눈, 4=소나기
class WeatherService {
  static const String _apiKey =
      'YOUR_KMA_API_KEY'; // 공공데이터포털 발급 키로 교체

  /// 위경도 → 기상청 격자좌표(nx, ny) 변환 (기상청 공식 알고리즘)
  static Map<String, int> latLngToGrid(double lat, double lon) {
    const RE = 6371.00877;
    const GRID = 5.0;
    const SLAT1 = 30.0 * math.pi / 180.0;
    const SLAT2 = 60.0 * math.pi / 180.0;
    const OLON = 126.0 * math.pi / 180.0;
    const OLAT = 38.0 * math.pi / 180.0;
    const XO = 43.0;
    const YO = 136.0;

    final sn = math.log(math.cos(SLAT1) / math.cos(SLAT2)) /
        math.log(math.tan(math.pi * 0.25 + SLAT2 * 0.5) /
            math.tan(math.pi * 0.25 + SLAT1 * 0.5));
    final sf = math.pow(math.tan(math.pi * 0.25 + SLAT1 * 0.5), sn) *
        math.cos(SLAT1) /
        sn;
    final ro = RE / GRID * sf /
        math.pow(math.tan(math.pi * 0.25 + OLAT * 0.5), sn);

    final ra = RE / GRID * sf /
        math.pow(math.tan(math.pi * 0.25 + lat * math.pi / 180.0 * 0.5), sn);
    var theta = lon * math.pi / 180.0 - OLON;
    if (theta > math.pi) theta -= 2.0 * math.pi;
    if (theta < -math.pi) theta += 2.0 * math.pi;
    theta *= sn;

    final x = (ra * math.sin(theta) + XO + 0.5).floor();
    final y = (ro - ra * math.cos(theta) + YO + 0.5).floor();
    return {'nx': x, 'ny': y};
  }

  /// 현재 강수 여부 조회 (초단기실황)
  /// 반환값: 0=없음, 1=비, 2=비/눈, 3=눈, 4=소나기
  static Future<int> getCurrentPrecipitation(double lat, double lng) async {
    final grid = latLngToGrid(lat, lng);
    final now = DateTime.now();
    // 기상청 기준시간: 매시 40분 이후에 해당 시각 데이터 제공
    final baseTime = now.minute >= 40
        ? now
        : now.subtract(const Duration(hours: 1));
    final baseDate =
        '${baseTime.year}${baseTime.month.toString().padLeft(2, '0')}${baseTime.day.toString().padLeft(2, '0')}';
    final baseHour = '${baseTime.hour.toString().padLeft(2, '0')}00';

    final url = Uri.parse(
      'http://apis.data.go.kr/1360000/VilageFcstInfoService_2.0/getUltraSrtNcst'
      '?serviceKey=$_apiKey'
      '&numOfRows=10'
      '&pageNo=1'
      '&dataType=JSON'
      '&base_date=$baseDate'
      '&base_time=$baseHour'
      '&nx=${grid['nx']}'
      '&ny=${grid['ny']}',
    );

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return 0;

      final json = jsonDecode(res.body);
      final items = json['response']?['body']?['items']?['item'] as List? ?? [];
      for (final item in items) {
        if (item['category'] == 'PTY') {
          return int.tryParse(item['obsrValue'].toString()) ?? 0;
        }
      }
    } catch (_) {}
    return 0;
  }

  /// 비가 오는지 여부
  static bool isRaining(int pty) => pty == 1 || pty == 2 || pty == 4;

  /// 눈이 오는지 여부
  static bool isSnowing(int pty) => pty == 3;

  /// 날씨 조건 텍스트
  static String weatherLabel(int pty) {
    switch (pty) {
      case 1: return '비';
      case 2: return '비/눈';
      case 3: return '눈';
      case 4: return '소나기';
      default: return '맑음';
    }
  }
}
