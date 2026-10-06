import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rider_point_model.dart';

class RiderPointService {
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _col => _db.collection('riderPoints');

  /// 포인트 상태 실시간 스트림
  Stream<RiderPointModel> watchPoints() {
    if (_uid == null) return const Stream.empty();
    return _col.doc(_uid).snapshots().map((snap) {
      if (!snap.exists) return RiderPointModel(riderId: _uid!);
      return RiderPointModel.fromMap(
          snap.data() as Map<String, dynamic>, _uid!);
    });
  }

  /// 포인트 적립
  Future<void> earnPoints(PointReason reason) async {
    if (_uid == null) return;

    // 오늘 이미 적립한 일일 제한 사유인지 확인
    if (_isDailyLimited(reason)) {
      final snap = await _col.doc(_uid).get();
      if (snap.exists) {
        final model = RiderPointModel.fromMap(
            snap.data() as Map<String, dynamic>, _uid!);
        final alreadyEarned = model.todayHistory
            .any((e) => e.reason == reason && _isToday(e.earnedAt));
        if (alreadyEarned) return; // 오늘 이미 받음
      }
    }

    final pts = reason.points;
    final entry = PointHistoryEntry(
      reason: reason,
      points: pts,
      earnedAt: DateTime.now(),
    );

    await _col.doc(_uid).set({
      'totalPoints': FieldValue.increment(pts),
      'dailyPoints': FieldValue.increment(pts),
      'todayHistory': FieldValue.arrayUnion([entry.toMap()]),
      // 부스터 충전 체크는 클라이언트에서 별도 처리
    }, SetOptions(merge: true));

    // 100점 달성마다 부스터 1회 충전
    await _checkAndGrantBooster();
  }

  /// 부스터 활성화 (3시간)
  Future<bool> activateBooster() async {
    if (_uid == null) return false;
    final snap = await _col.doc(_uid).get();
    if (!snap.exists) return false;

    final model = RiderPointModel.fromMap(
        snap.data() as Map<String, dynamic>, _uid!);
    if (model.boosterCharges <= 0) return false;
    if (model.isBoosterActive) return false; // 이미 활성 중

    final expiry = DateTime.now().add(const Duration(hours: 3));
    await _col.doc(_uid).update({
      'boosterCharges': FieldValue.increment(-1),
      'boosterActiveUntil': Timestamp.fromDate(expiry),
    });
    return true;
  }

  /// 부스터 만료 처리
  Future<void> expireBoosterIfNeeded() async {
    if (_uid == null) return;
    final snap = await _col.doc(_uid).get();
    if (!snap.exists) return;
    final model = RiderPointModel.fromMap(
        snap.data() as Map<String, dynamic>, _uid!);
    if (model.boosterActiveUntil != null && !model.isBoosterActive) {
      await _col.doc(_uid).update({'boosterActiveUntil': null});
    }
  }

  /// 자정에 일간 포인트 초기화 (Cloud Functions 대체 - 앱 시작 시 호출)
  Future<void> resetDailyIfNeeded() async {
    if (_uid == null) return;
    final snap = await _col.doc(_uid).get();
    if (!snap.exists) return;

    final model = RiderPointModel.fromMap(
        snap.data() as Map<String, dynamic>, _uid!);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    // 마지막 근무일이 오늘이 아니면 일간 포인트 초기화
    final lastWork = model.lastWorkDate;
    if (lastWork == null || lastWork.isBefore(todayStart)) {
      // 연속 출근 체크
      final yesterday = todayStart.subtract(const Duration(days: 1));
      final isConsecutive = lastWork != null &&
          lastWork.isAfter(yesterday) &&
          lastWork.isBefore(todayStart);

      final newStreak = isConsecutive ? model.consecutiveDays + 1 : 1;

      await _col.doc(_uid).update({
        'dailyPoints': 0,
        'todayHistory': [],
        'lastWorkDate': Timestamp.fromDate(now),
        'consecutiveDays': newStreak,
      });

      // 7일 연속 출근 보너스
      if (newStreak % 7 == 0) {
        await earnPoints(PointReason.sevenDayStreak);
      }
    }
  }

  /// 콜 배정 우선순위 점수 계산
  /// 부스터 활성 시 거리 보정까지 포함한 최종 점수 반환
  static double callPriorityScore({
    required RiderPointModel points,
    required double distanceKm, // 라이더-픽업지 거리
  }) {
    double score = 0;

    // 1. 등급 기본점
    switch (points.grade) {
      case 'GOLD':   score += 30; break;
      case 'SILVER': score += 15; break;
      default:       score += 0;
    }

    // 2. 오늘 일간 포인트 반영
    score += points.dailyPoints * 2.0;

    // 3. 부스터 활성 시: 거리 패널티 제거 + 대폭 가산
    if (points.isBoosterActive) {
      score += 50; // 부스터 보너스
      // 거리가 멀어도 우선 노출 (거리 패널티 없음)
    } else {
      // 일반: 거리 멀수록 점수 감소 (1km당 -3점)
      score -= distanceKm * 3;
    }

    return score;
  }

  // ── private ──────────────────────────────────────────────────────────────

  bool _isDailyLimited(PointReason reason) {
    // 하루 한 번만 받을 수 있는 사유들
    const dailyLimited = {
      PointReason.fiveHourWork,
      PointReason.kindnessDaily,
      PointReason.noCancelDaily,
      PointReason.badWeatherDelivery,
      PointReason.peakTime5,
      PointReason.newAreaDelivery,
    };
    return dailyLimited.contains(reason);
  }

  bool _isToday(DateTime dt) {
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  }

  Future<void> _checkAndGrantBooster() async {
    if (_uid == null) return;
    final snap = await _col.doc(_uid).get();
    if (!snap.exists) return;
    final data = snap.data() as Map<String, dynamic>;
    final total = (data['totalPoints'] ?? 0) as int;
    // 100점 달성마다 부스터 +1, 획득 시각(boosterGrantedAt) 갱신
    if (total > 0 && total % 100 == 0) {
      await _col.doc(_uid).update({
        'boosterCharges': FieldValue.increment(1),
        'boosterGrantedAt': Timestamp.fromDate(DateTime.now()),
      });
    }
  }

  /// 월 구매 횟수 초기화 (월이 바뀌었으면 리셋)
  Future<void> _resetMonthlyPurchaseIfNeeded(
      Map<String, dynamic> data) async {
    if (_uid == null) return;
    final resetTs = data['purchaseCountResetAt'] as Timestamp?;
    if (resetTs == null) return;
    final reset = resetTs.toDate();
    final now = DateTime.now();
    if (reset.year != now.year || reset.month != now.month) {
      await _col.doc(_uid).update({
        'monthlyPurchaseCount': 0,
        'purchaseCountResetAt': Timestamp.fromDate(now),
      });
    }
  }
}
