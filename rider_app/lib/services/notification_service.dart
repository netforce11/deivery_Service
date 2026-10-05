import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('백그라운드 메시지 수신: ${message.notification?.title}');
}

class NotificationService {
  static final _messaging = FirebaseMessaging.instance;
  static final _db = FirebaseFirestore.instance;

  static Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('알림 권한: ${settings.authorizationStatus}');

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    await _saveToken();
    _messaging.onTokenRefresh.listen(_updateToken);

    FirebaseMessaging.onMessage.listen((message) {
      debugPrint('라이더 알림: ${message.notification?.title}');
    });
  }

  static Future<void> _saveToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    String? token;
    if (kIsWeb) {
      try {
        token = await _messaging.getToken(
          vapidKey: 'YOUR_VAPID_KEY',
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
    }
  }

  static Future<void> _updateToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('riders').doc(uid).set(
      {'fcmToken': token},
      SetOptions(merge: true),
    );
  }

  static Future<void> clearToken() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _db.collection('riders').doc(uid).update({'fcmToken': null});
  }
}
