import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/store_event_model.dart';

class StoreEventService {
  final _db = FirebaseFirestore.instance;

  String? get _storeId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _col => _db.collection('storeEvents');

  /// 현재 가게 활성 이벤트 스트림
  Stream<List<StoreEventModel>> watchActiveEvents() {
    if (_storeId == null) return const Stream.empty();
    return _col
        .where('storeId', isEqualTo: _storeId)
        .where('isActive', isEqualTo: true)
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                StoreEventModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// 이벤트 전체 이력 (최근 30일)
  Stream<List<StoreEventModel>> watchAllEvents() {
    if (_storeId == null) return const Stream.empty();
    final since = DateTime.now().subtract(const Duration(days: 30));
    return _col
        .where('storeId', isEqualTo: _storeId)
        .where('startAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('startAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) =>
                StoreEventModel.fromMap(d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// ⚡ 타임어택 이벤트 시작
  Future<void> startFlashSale({
    required int discountPercent,
    required int durationMinutes,
    int? maxParticipants,
  }) async {
    if (_storeId == null) return;
    final now = DateTime.now();
    final end = now.add(Duration(minutes: durationMinutes));

    await _col.add(StoreEventModel(
      id: '',
      storeId: _storeId!,
      type: EventType.flashSale,
      isActive: true,
      discountPercent: discountPercent,
      durationMinutes: durationMinutes,
      maxParticipants: maxParticipants,
      startAt: now,
      endAt: end,
    ).toMap());

    // 가게 문서에 활성 이벤트 요약 반영
    await _db.collection('stores').doc(_storeId).update({
      'activeEvent': {
        'type': 'flashSale',
        'discountPercent': discountPercent,
        'endAt': Timestamp.fromDate(end),
      }
    });
  }

  /// 🍀 럭키 오더 이벤트 시작
  Future<void> startLuckyOrder({
    required int luckyOrderNumber,
    required String reward,
  }) async {
    if (_storeId == null) return;
    final now = DateTime.now();

    await _col.add(StoreEventModel(
      id: '',
      storeId: _storeId!,
      type: EventType.luckyOrder,
      isActive: true,
      luckyOrderNumber: luckyOrderNumber,
      luckyReward: reward,
      startAt: now,
    ).toMap());

    await _db.collection('stores').doc(_storeId).update({
      'activeEvent': {
        'type': 'luckyOrder',
        'luckyOrderNumber': luckyOrderNumber,
        'luckyReward': reward,
      }
    });
  }

  /// 🏆 챌린지 시작
  Future<void> startChallenge({
    required int targetOrders,
    required String reward,
  }) async {
    if (_storeId == null) return;
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day, 23, 59, 59);

    await _col.add(StoreEventModel(
      id: '',
      storeId: _storeId!,
      type: EventType.challenge,
      isActive: true,
      targetOrders: targetOrders,
      challengeReward: reward,
      startAt: now,
      endAt: end,
    ).toMap());

    await _db.collection('stores').doc(_storeId).update({
      'activeEvent': {
        'type': 'challenge',
        'targetOrders': targetOrders,
        'challengeReward': reward,
      }
    });
  }

  /// 🎁 웰컴 쿠폰 토글
  Future<void> toggleWelcomeCoupon({
    required bool enable,
    int discountPercent = 10,
  }) async {
    if (_storeId == null) return;

    if (enable) {
      await _col.add(StoreEventModel(
        id: '',
        storeId: _storeId!,
        type: EventType.welcomeCoupon,
        isActive: true,
        welcomeDiscountPercent: discountPercent,
        startAt: DateTime.now(),
      ).toMap());

      await _db.collection('stores').doc(_storeId).update({
        'activeEvent': {
          'type': 'welcomeCoupon',
          'welcomeDiscountPercent': discountPercent,
        }
      });
    } else {
      // 기존 웰컴쿠폰 이벤트 비활성화
      final snap = await _col
          .where('storeId', isEqualTo: _storeId)
          .where('type', isEqualTo: 'welcomeCoupon')
          .where('isActive', isEqualTo: true)
          .get();
      final batch = _db.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      await batch.commit();

      await _db.collection('stores').doc(_storeId).update({
        'activeEvent': FieldValue.delete(),
      });
    }
  }

  /// 이벤트 수동 종료
  Future<void> endEvent(String eventId) async {
    await _col.doc(eventId).update({
      'isActive': false,
      'endAt': Timestamp.fromDate(DateTime.now()),
    });

    // 더 이상 활성 이벤트 없으면 가게 activeEvent 초기화
    final remaining = await _col
        .where('storeId', isEqualTo: _storeId)
        .where('isActive', isEqualTo: true)
        .get();
    if (remaining.docs.isEmpty && _storeId != null) {
      await _db.collection('stores').doc(_storeId).update({
        'activeEvent': FieldValue.delete(),
      });
    }
  }

  /// 주문 발생 시 이벤트 카운터 업데이트 (order_service에서 호출)
  Future<String?> onOrderPlaced(String storeId) async {
    // 활성 이벤트 조회
    final snap = await _col
        .where('storeId', isEqualTo: storeId)
        .where('isActive', isEqualTo: true)
        .get();

    String? reward; // 고객에게 전달할 혜택 메시지

    for (final doc in snap.docs) {
      final event = StoreEventModel.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);

      if (event.isExpired || event.isFull) {
        await doc.reference.update({'isActive': false});
        continue;
      }

      if (event.type == EventType.luckyOrder) {
        final newCount = event.participantCount + 1;
        await doc.reference.update({'participantCount': newCount});
        if (newCount == event.luckyOrderNumber) {
          reward = '🍀 럭키 오더 당첨! ${event.luckyReward}';
        }
      } else if (event.type == EventType.challenge) {
        final newCount = event.currentOrders + 1;
        await doc.reference.update({'currentOrders': newCount});
        if (newCount >= (event.targetOrders ?? 999)) {
          reward = '🏆 챌린지 달성!';
          await doc.reference.update({'isActive': false});
        }
      } else if (event.type == EventType.flashSale) {
        final newCount = event.participantCount + 1;
        await doc.reference.update({'participantCount': newCount});
        if (event.maxParticipants != null &&
            newCount >= event.maxParticipants!) {
          await doc.reference.update({'isActive': false});
        }
      }
    }
    return reward;
  }
}
