import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/rider_aid_campaign_model.dart';
import '../models/rider_point_model.dart';
import 'rider_point_service.dart';

/// 라이언 일병 구하기 서비스
///
/// 흐름:
/// 1. 관리자가 캠페인 생성 (admin_app에서 직접 Firestore write)
/// 2. 라이더가 일반 콜 수락 시 "라이언 콜로 참여" 옵션 표시
/// 3. 배달 완료 시 [completeRyanCall] 호출
///    - 라이더 수익의 50%를 캠페인 적립금에 누적
///    - 회사 매칭 (동일 금액) 기록
///    - 라이더에게 +5 보상 포인트 적립
///    - 캠페인 목표 달성 시 자동 완료
class RiderAidService {
  final _db = FirebaseFirestore.instance;
  final _pointSvc = RiderPointService();

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _campaigns => _db.collection('riderAidCampaigns');
  CollectionReference get _contributions =>
      _db.collection('riderAidContributions');

  // ── 캠페인 조회 ───────────────────────────────────────────────────────────

  /// 현재 활성 캠페인 (실시간) — 라이더 앱 표시용
  Stream<List<RiderAidCampaignModel>> watchActiveCampaigns() {
    return _campaigns
        .where('status', isEqualTo: AidCampaignStatus.active.name)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RiderAidCampaignModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// 전체 캠페인 (관리자용)
  Stream<List<RiderAidCampaignModel>> watchAllCampaigns() {
    return _campaigns
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RiderAidCampaignModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// 캠페인 참여 기록 (실시간)
  Stream<List<RiderAidContributionModel>> watchContributions(
      String campaignId) {
    return _contributions
        .where('campaignId', isEqualTo: campaignId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => RiderAidContributionModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  // ── 라이언 콜 완료 처리 ────────────────────────────────────────────────────

  /// 배달 완료 후 호출 — 라이언 콜로 참여한 경우
  ///
  /// [campaignId]: 참여 캠페인 ID
  /// [orderId]: 완료된 주문 ID
  /// [riderName]: 라이더 표시 이름
  /// [riderEarnings]: 라이더 수익 (원) — 플랫폼 수수료 제외 후 금액
  ///
  /// Returns: 적립된 총 금액 (라이더 기부 + 회사 매칭)
  Future<RyanCallResult> completeRyanCall({
    required String campaignId,
    required String orderId,
    required String riderName,
    required int riderEarnings,
  }) async {
    if (_uid == null) return RyanCallResult.notLoggedIn;
    if (riderEarnings <= 0) return RyanCallResult.invalidAmount;

    // 캠페인 유효성 확인
    final campSnap = await _campaigns.doc(campaignId).get();
    if (!campSnap.exists) return RyanCallResult.campaignNotFound;

    final campaign = RiderAidCampaignModel.fromMap(
        campSnap.data() as Map<String, dynamic>, campaignId);
    if (!campaign.isActive) return RyanCallResult.campaignNotActive;
    if (campaign.isGoalReached) return RyanCallResult.goalAlreadyReached;

    // 계산
    final riderContribution = (riderEarnings * 0.5).floor(); // 50% 차감
    final companyMatch = riderContribution;                   // 1:1 매칭
    final total = riderContribution + companyMatch;

    final now = DateTime.now();
    final newTotal = campaign.currentAmount + total;
    final goalReached = newTotal >= campaign.goalAmount;

    await _db.runTransaction((tx) async {
      // 1. 참여 기록 저장
      final contribRef = _contributions.doc();
      tx.set(contribRef, {
        'campaignId': campaignId,
        'riderId': _uid,
        'riderName': riderName,
        'orderId': orderId,
        'riderContribution': riderContribution,
        'companyMatch': companyMatch,
        'totalContribution': total,
        'createdAt': Timestamp.fromDate(now),
      });

      // 2. 캠페인 누계 업데이트
      tx.update(_campaigns.doc(campaignId), {
        'currentAmount': FieldValue.increment(total),
        'companyMatchAmount': FieldValue.increment(companyMatch),
        'participantCount': FieldValue.increment(1),
        // 목표 달성 시 자동 완료
        if (goalReached) 'status': AidCampaignStatus.completed.name,
      });

      // 3. 주문에 라이언 콜 참여 표시
      tx.update(_db.collection('orders').doc(orderId), {
        'isRyanCall': true,
        'ryanCallCampaignId': campaignId,
        'ryanCallContribution': total,
      });
    });

    // 4. 보상 포인트 +5 적립 (트랜잭션 밖 — 실패해도 기부는 완료)
    await _pointSvc.earnPoints(PointReason.ryanCall);

    return goalReached
        ? RyanCallResult.successGoalReached
        : RyanCallResult.success;
  }

  // ── 관리자용 캠페인 관리 ──────────────────────────────────────────────────

  /// 캠페인 수동 완료/취소 (관리자)
  Future<void> updateCampaignStatus(
      String campaignId, AidCampaignStatus status) async {
    await _campaigns.doc(campaignId).update({'status': status.name});
  }
}

// ── 결과 코드 ────────────────────────────────────────────────────────────────

enum RyanCallResult {
  success,
  successGoalReached,   // 기부 완료 + 캠페인 목표 달성
  notLoggedIn,
  invalidAmount,
  campaignNotFound,
  campaignNotActive,
  goalAlreadyReached,
}

extension RyanCallResultExt on RyanCallResult {
  bool get isSuccess =>
      this == RyanCallResult.success ||
      this == RyanCallResult.successGoalReached;

  String get message {
    switch (this) {
      case RyanCallResult.success:
        return '🪖 참여 완료! +7 포인트가 적립됐습니다.';
      case RyanCallResult.successGoalReached:
        return '🎉 목표 달성! 전우를 도왔습니다. +7 포인트 적립!';
      case RyanCallResult.notLoggedIn:
        return '로그인이 필요합니다.';
      case RyanCallResult.invalidAmount:
        return '수익 정보가 올바르지 않습니다.';
      case RyanCallResult.campaignNotFound:
        return '캠페인을 찾을 수 없습니다.';
      case RyanCallResult.campaignNotActive:
        return '종료된 캠페인입니다.';
      case RyanCallResult.goalAlreadyReached:
        return '이미 목표 금액이 달성된 캠페인입니다.';
    }
  }
}
