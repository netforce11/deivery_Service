import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// 날씨 할증 Firestore 처리 서비스
class WeatherSurchargeService {
  final _db = FirebaseFirestore.instance;

  String? get _storeId => FirebaseAuth.instance.currentUser?.uid;

  /// 날씨 할증 기능 ON/OFF 토글 저장
  Future<void> setWeatherSurchargeEnabled(bool enabled) async {
    if (_storeId == null) return;
    await _db.collection('stores').doc(_storeId).update({
      'weatherSurchargeEnabled': enabled,
      // 비활성화 시 진행 중인 할증도 종료
      if (!enabled) 'weatherSurchargeActive': false,
      if (!enabled) 'weatherSurchargeExpiry': null,
    });
  }

  /// 30분 할증 수락 처리
  Future<void> activateSurcharge({int amount = 1000}) async {
    if (_storeId == null) return;
    final expiry = DateTime.now().add(const Duration(minutes: 30));
    await _db.collection('stores').doc(_storeId).update({
      'weatherSurchargeActive': true,
      'weatherSurchargeAmount': amount,
      'weatherSurchargeExpiry': Timestamp.fromDate(expiry),
    });
  }

  /// 할증 만료 처리 (자동 해제)
  Future<void> deactivateSurcharge() async {
    if (_storeId == null) return;
    await _db.collection('stores').doc(_storeId).update({
      'weatherSurchargeActive': false,
      'weatherSurchargeExpiry': null,
    });
  }

  /// 할증 금액 변경
  Future<void> setSurchargeAmount(int amount) async {
    if (_storeId == null) return;
    await _db.collection('stores').doc(_storeId).update({
      'weatherSurchargeAmount': amount,
    });
  }
}
