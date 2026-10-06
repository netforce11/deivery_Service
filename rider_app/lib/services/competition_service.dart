import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/competition_model.dart';

/// 달려라 하니 상 — 경쟁 서비스
/// - 진행 중인 대회 목록 조회
/// - 내 기록 업데이트 (배달 완료 시 호출)
/// - 리더보드 조회
class CompetitionService {
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _competitions =>
      _db.collection('riderCompetitions');
  CollectionReference get _entries =>
      _db.collection('riderCompetitionEntries');

  // ── 대회 목록 ─────────────────────────────────────────────────────────────

  /// 현재 활성화된 대회 목록 (실시간)
  /// isActive=true인 것만 조회, 날짜 필터는 클라이언트에서 처리
  Stream<List<CompetitionModel>> watchActiveCompetitions() {
    return _competitions
        .where('isActive', isEqualTo: true)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CompetitionModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .where((c) => c.isRunning) // 날짜 범위도 체크
            .toList());
  }

  /// 전체 대회 목록 (관리자용 — 비활성 포함)
  Stream<List<CompetitionModel>> watchAllCompetitions() {
    return _competitions
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => CompetitionModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ── 기록 업데이트 ─────────────────────────────────────────────────────────

  /// 배달 완료 시 호출 — 진행 중인 모든 대회에 기록 업데이트
  /// [distanceKm]: 해당 배달의 거리
  /// [workMinutes]: 배달에 걸린 시간(분)
  /// [vehicleType]: 라이더의 이동 수단
  /// [region]: 라이더의 현재 지역
  Future<void> recordDelivery({
    required String riderName,
    required double distanceKm,
    required int workMinutes,
    required VehicleType vehicleType,
    required String region,
  }) async {
    if (_uid == null) return;

    // 진행 중인 대회 목록 조회
    final snap = await _competitions
        .where('isActive', isEqualTo: true)
        .get();

    final now = DateTime.now();
    final batch = _db.batch();
    bool hasBatch = false;

    for (final doc in snap.docs) {
      final competition = CompetitionModel.fromMap(
          doc.data() as Map<String, dynamic>, doc.id);

      // 날짜 범위 확인
      if (!competition.isRunning) continue;

      // 지역 필터 (빈 문자열 = 전국, 참가 가능)
      final compRegion = competition.region;
      if (compRegion.isNotEmpty && compRegion != region) continue;

      // 이동 수단 필터 (longDistance만 해당)
      if (competition.type == CompetitionType.longDistance &&
          competition.vehicleType != VehicleType.all &&
          competition.vehicleType != vehicleType) continue;

      final entryId = '${doc.id}_$_uid';
      final entryRef = _entries.doc(entryId);

      // 기록 누적 (merge)
      batch.set(
        entryRef,
        {
          'competitionId': doc.id,
          'riderId': _uid,
          'riderName': riderName,
          'vehicleType': vehicleType.name,
          'region': region,
          'totalDistanceKm': FieldValue.increment(distanceKm),
          'totalDeliveries': FieldValue.increment(1),
          'totalWorkMinutes': FieldValue.increment(workMinutes),
          'lastUpdated': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
      hasBatch = true;
    }

    if (hasBatch) await batch.commit();
  }

  // ── 리더보드 ─────────────────────────────────────────────────────────────

  /// 특정 대회의 리더보드 (실시간)
  Stream<List<CompetitionEntryModel>> watchLeaderboard(
    CompetitionModel competition, {
    String? region,       // null = 전국 합산
    VehicleType? vehicle, // null = 전체 차종
  }) {
    Query q = _entries
        .where('competitionId', isEqualTo: competition.id);

    if (region != null && region.isNotEmpty) {
      q = q.where('region', isEqualTo: region);
    }
    if (vehicle != null && vehicle != VehicleType.all) {
      q = q.where('vehicleType', isEqualTo: vehicle.name);
    }

    // 정렬 필드 선택
    final orderField = competition.type == CompetitionType.longDistance
        ? 'totalDistanceKm'
        : 'totalDeliveries'; // efficiency는 클라이언트에서 재계산

    return q
        .orderBy(orderField, descending: true)
        .limit(competition.maxRank)
        .snapshots()
        .map((snap) {
      final entries = snap.docs
          .map((d) => CompetitionEntryModel.fromMap(
              d.data() as Map<String, dynamic>, d.id))
          .toList();

      // efficiency는 deliveriesPerHour 기준으로 재정렬
      if (competition.type == CompetitionType.efficiency) {
        entries.sort((a, b) =>
            b.deliveriesPerHour.compareTo(a.deliveriesPerHour));
      }
      return entries;
    });
  }

  /// 내 순위 조회
  Future<int?> getMyRank(CompetitionModel competition) async {
    if (_uid == null) return null;

    final orderField = competition.type == CompetitionType.longDistance
        ? 'totalDistanceKm'
        : 'totalDeliveries';

    // 내 기록 조회
    final mySnap =
        await _entries.doc('${competition.id}_$_uid').get();
    if (!mySnap.exists) return null;

    final myEntry = CompetitionEntryModel.fromMap(
        mySnap.data() as Map<String, dynamic>, mySnap.id);
    final myScore = myEntry.score(competition.type);

    // 나보다 높은 점수 라이더 수 = 내 순위 - 1
    final betterSnap = await _entries
        .where('competitionId', isEqualTo: competition.id)
        .where(orderField, isGreaterThan: myScore)
        .count()
        .get();

    return (betterSnap.count ?? 0) + 1;
  }
}
