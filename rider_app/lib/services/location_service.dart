import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  Timer? _timer;
  String? _currentOrderId;

  // 마지막으로 알려진 위치
  double? currentLat;
  double? currentLng;

  // 위치 권한 요청
  Future<bool> requestPermission() async {
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  // 현재 위치 한 번 가져오기
  Future<Position?> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      return null;
    }
  }

  // 배달 시작 — 5초마다 위치 업데이트
  void startTracking(String orderId) {
    _currentOrderId = orderId;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final pos = await getCurrentPosition();
      if (pos != null && _currentOrderId != null) {
        currentLat = pos.latitude;
        currentLng = pos.longitude;
        await _db.collection('orders').doc(_currentOrderId).update({
          'riderLat': pos.latitude,
          'riderLng': pos.longitude,
          'riderUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
    // 즉시 한 번 실행
    _updateNow(orderId);
  }

  Future<void> _updateNow(String orderId) async {
    final pos = await getCurrentPosition();
    if (pos != null) {
      currentLat = pos.latitude;
      currentLng = pos.longitude;
      await _db.collection('orders').doc(orderId).update({
        'riderLat': pos.latitude,
        'riderLng': pos.longitude,
        'riderUpdatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // 배달 완료 — 추적 중지
  void stopTracking() {
    _timer?.cancel();
    _timer = null;
    _currentOrderId = null;
  }

  void dispose() {
    stopTracking();
  }
}
