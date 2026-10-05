import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

// 백그라운드 메시지 핸들러 (top-level 함수여야 함)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('백그라운드 메시지 수신: ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  /// 앱 시작 시 초기화 — main.dart에서 호출
  static Future<void> initialize() async {
    // 백그라운드 핸들러 등록
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // 알림 권한 요청
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('알림 권한: ${settings.authorizationStatus}');

    // 포그라운드 알림 표시 설정 (iOS)
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // FCM 토큰 저장
    await _saveToken();

    // 토큰 갱신 시 자동 업데이트
    _messaging.onTokenRefresh.listen(_updateToken);

    // 포그라운드 메시지 수신
    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('포그라운드 메시지: ${message.notification?.title}');
      // Flutter local notifications로 직접 표시하거나 스낵바 등으로 처리 가능
    });
  }

  static Future<void> _saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String? token;
    if (kIsWeb) {
      // 웹은 VAPID 키 필요 (Firebase Console → 프로젝트 설정 → 클라우드 메시징 → 웹 푸시 인증서)
      try {
        token = await _messaging.getToken(
          vapidKey: 'YOUR_VAPID_KEY', // Firebase Console에서 발급
        );
      } catch (e) {
        debugPrint('웹 FCM 토큰 오류: $e');
        return;
      }
    } else {
      token = await _messaging.getToken();
    }

    if (token != null) {
      await _updateToken(token);
      debugPrint('FCM 토큰 저장 완료');
    }
  }

  static Future<void> _updateToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('customers').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  /// 로그아웃 시 토큰 삭제
  static Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('customers').doc(uid).update({'fcmToken': null});
  }
}
