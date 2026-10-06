import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/store_achievement_model.dart';

class StoreAchievementService {
  final _db = FirebaseFirestore.instance;

  String? get _storeId => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _col => _db.collection('storeAchievements');

  /// 오늘 달성 항목 스트림
  Stream<List<StoreAchievementModel>> watchTodayAchievements() {
    if (_storeId == null) return const Stream.empty();
    final todayStart = _todayStart();
    return _col
        .where('storeId', isEqualTo: _storeId)
        .where('earnedAt', isGreaterThan: Timestamp.fromDate(todayStart))
        .orderBy('earnedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => StoreAchievementModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// 전체 달성 이력 (최근 30일)
  Stream<List<StoreAchievementModel>> watchHistory() {
    if (_storeId == null) return const Stream.empty();
    final since = DateTime.now().subtract(const Duration(days: 30));
    return _col
        .where('storeId', isEqualTo: _storeId)
        .where('earnedAt', isGreaterThan: Timestamp.fromDate(since))
        .orderBy('earnedAt', descending: true)
        .snapshots()
        .map((s) => s.docs
            .map((d) => StoreAchievementModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// 주문 발생 시 주문왕 / 럭키 번호 체크 (order_service에서 호출)
  /// [orderCount] 오늘 이 가게에 들어온 누적 주문 수
  /// [category] 가게 카테고리
  /// [luckyTargetNumber] 가게가 설정한 럭키 주문번호 (없으면 null)
  /// [dailyRevenue] 현재 당일 매출
  Future<StoreAchievementModel?> onOrderArrived({
    required String storeId,
    required int orderCount,
    required String category,
    int? luckyTargetNumber,
    int dailyRevenue = 0,
  }) async {
    // ── 럭키 주문번호 체크 ───────────────────────────────────────────────────
    if (luckyTargetNumber != null && orderCount == luckyTargetNumber) {
      final bonus = StoreAchievementModel.calcLuckyBonus(dailyRevenue);
      if (bonus != null) {
        final model = StoreAchievementModel(
          id: '',
          storeId: storeId,
          type: AchievementType.luckyNumber,
          earnedAt: DateTime.now(),
          luckyOrderNumber: luckyTargetNumber,
          dailyRevenue: dailyRevenue,
          bonusAmount: bonus,
        );
        final ref = await _col.add(model.toMap());
        // 보너스 적립 대기 상태로 기록 (실제 지급은 정산 배치에서)
        await _db.collection('storeBonusQueue').add({
          'storeId': storeId,
          'achievementId': ref.id,
          'bonusAmount': bonus,
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
        return StoreAchievementModel.fromMap(model.toMap(), ref.id);
      }
    }
    return null;
  }

  /// 자정에 주문왕 집계 (앱 시작 시 또는 Cloud Functions에서 호출)
  /// 카테고리 내 당일 주문 수를 비교해 1위 가게에 주문왕 뱃지 부여
  Future<void> computeDailyOrderKing(String category) async {
    final todayStart = _todayStart();
    final yesterday = todayStart.subtract(const Duration(days: 1));

    // 어제 날짜의 모든 주문을 카테고리로 집계
    final ordersSnap = await _db
        .collection('orders')
        .where('storeCategory', isEqualTo: category)
        .where('status', isEqualTo: 'delivered')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
        .where('createdAt', isLessThan: Timestamp.fromDate(todayStart))
        .get();

    // 가게별 주문 수 집계
    final Map<String, int> counts = {};
    for (final doc in ordersSnap.docs) {
      final sid = doc['storeId'] as String? ?? '';
      counts[sid] = (counts[sid] ?? 0) + 1;
    }
    if (counts.isEmpty) return;

    // 카테고리 평균 주문 수
    final total = counts.values.fold(0, (a, b) => a + b);
    final avg = total / counts.length;

    // 1위 찾기
    final topEntry = counts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final ratio = topEntry.value / avg;

    // 평균 대비 1.5배 이상일 때만 주문왕 부여 (너무 쉽게 주면 의미 없음)
    if (ratio < 1.5) return;

    // 이미 어제 주문왕 뱃지 있는지 확인
    final existing = await _col
        .where('storeId', isEqualTo: topEntry.key)
        .where('type', isEqualTo: 'orderKing')
        .where('earnedAt', isGreaterThan: Timestamp.fromDate(yesterday))
        .where('earnedAt', isLessThan: Timestamp.fromDate(todayStart))
        .get();
    if (existing.docs.isNotEmpty) return;

    await _col.add(StoreAchievementModel(
      id: '',
      storeId: topEntry.key,
      type: AchievementType.orderKing,
      earnedAt: yesterday.add(const Duration(hours: 23, minutes: 59)),
      category: category,
      orderRatio: ratio,
      orderCount: topEntry.value,
    ).toMap());
  }

  DateTime _todayStart() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
