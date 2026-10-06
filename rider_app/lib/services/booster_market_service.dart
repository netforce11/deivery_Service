import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/booster_market_model.dart';
import '../models/rider_point_model.dart';

/// 부스터 마켓 서비스
/// - 라이더끼리 부스터 사용권을 사고팔 수 있는 P2P 마켓
/// - 플랫폼 수수료 10%, 판매자 90% 수취 (포인트로 결제/지급)
/// - 월 최대 2회 구매 제한
class BoosterMarketService {
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  CollectionReference get _market => _db.collection('boosterMarket');
  CollectionReference get _points => _db.collection('riderPoints');

  // ── 판매 등록 ──────────────────────────────────────────────────────────────

  /// 부스터 가격 범위 상수
  static const int minPrice = 10;
  static const int maxPrice = 90;

  /// 내 부스터를 마켓에 등록
  /// [price]: 포인트 판매가 (최소 10점, 최대 90점)
  Future<BoosterMarketResult> listForSale({required int price}) async {
    if (_uid == null) return BoosterMarketResult.notLoggedIn;
    if (price < minPrice || price > maxPrice) return BoosterMarketResult.invalidPrice;

    final snap = await _points.doc(_uid).get();
    if (!snap.exists) return BoosterMarketResult.noBooster;

    final model = RiderPointModel.fromMap(
        snap.data() as Map<String, dynamic>, _uid!);

    if (!model.isBoosterSellable) {
      if (model.boosterCharges <= 0) return BoosterMarketResult.noBooster;
      if (model.isBoosterActive) return BoosterMarketResult.boosterActive;
      return BoosterMarketResult.sellWindowExpired;
    }

    // 이미 판매 중인 게시글 있는지 확인
    final existing = await _market
        .where('sellerId', isEqualTo: _uid)
        .where('status', isEqualTo: 'available')
        .limit(1)
        .get();
    if (existing.docs.isNotEmpty) return BoosterMarketResult.alreadyListed;

    final now = DateTime.now();
    final listing = BoosterMarketModel(
      id: '',
      sellerId: _uid!,
      sellerName: model.riderId, // 이름 필드 없으면 uid 사용 (UI에서 별도 조회 가능)
      price: price,
      boosterGrantedAt: model.boosterGrantedAt!,
      boosterExpiry: model.boosterSellableUntil!,
      status: BoosterListingStatus.available,
      createdAt: now,
    );

    final batch = _db.batch();

    // 마켓에 게시글 추가
    final docRef = _market.doc();
    batch.set(docRef, listing.toMap());

    // 판매자 포인트에서 부스터 차감 (판매 등록 시 즉시 차감)
    batch.update(_points.doc(_uid), {
      'boosterCharges': FieldValue.increment(-1),
    });

    await batch.commit();
    return BoosterMarketResult.success;
  }

  // ── 구매 ──────────────────────────────────────────────────────────────────

  /// 마켓 게시글 구매
  /// 월 2회 제한 / 포인트로 결제 / 판매자 90% 지급 / 플랫폼 10% 수수료
  Future<BoosterMarketResult> purchase(String listingId) async {
    if (_uid == null) return BoosterMarketResult.notLoggedIn;

    return _db.runTransaction<BoosterMarketResult>((tx) async {
      // 1. 게시글 확인
      final listingSnap = await tx.get(_market.doc(listingId));
      if (!listingSnap.exists) return BoosterMarketResult.listingNotFound;

      final listing = BoosterMarketModel.fromMap(
          listingSnap.data() as Map<String, dynamic>, listingId);

      if (!listing.isAvailable) return BoosterMarketResult.listingNotFound;
      if (listing.sellerId == _uid) return BoosterMarketResult.cannotBuyOwn;

      // 2. 구매자 포인트 확인
      final buyerSnap = await tx.get(_points.doc(_uid));
      if (!buyerSnap.exists) return BoosterMarketResult.insufficientPoints;

      final buyer = RiderPointModel.fromMap(
          buyerSnap.data() as Map<String, dynamic>, _uid!);

      // 월 구매 제한 체크
      if (!buyer.canPurchaseBooster) {
        return BoosterMarketResult.monthlyLimitReached;
      }

      // 포인트 잔액 확인
      if (buyer.totalPoints < listing.price) {
        return BoosterMarketResult.insufficientPoints;
      }

      // 3. 판매자 포인트 확인
      final sellerSnap = await tx.get(_points.doc(listing.sellerId));
      if (!sellerSnap.exists) return BoosterMarketResult.listingNotFound;

      final now = DateTime.now();

      // 4. 게시글 sold 처리
      tx.update(_market.doc(listingId), {
        'status': BoosterListingStatus.sold.name,
        'buyerId': _uid,
        'soldAt': Timestamp.fromDate(now),
      });

      // 5. 구매자: 포인트 차감 + 부스터 +1 + 월 구매 횟수 +1
      tx.update(_points.doc(_uid), {
        'totalPoints': FieldValue.increment(-listing.price),
        'boosterCharges': FieldValue.increment(1),
        'boosterGrantedAt': Timestamp.fromDate(now),
        'monthlyPurchaseCount': FieldValue.increment(1),
        'purchaseCountResetAt': Timestamp.fromDate(now),
      });

      // 6. 판매자: 수수료 제외 포인트 지급 (판매자 90%)
      tx.update(_points.doc(listing.sellerId), {
        'totalPoints': FieldValue.increment(listing.sellerReceives),
      });

      // 7. 플랫폼 수수료 기록 (선택적 — 별도 컬렉션에 기록)
      final feeRef = _db.collection('platformFees').doc();
      tx.set(feeRef, {
        'type': 'boosterMarket',
        'listingId': listingId,
        'buyerId': _uid,
        'sellerId': listing.sellerId,
        'salePrice': listing.price,
        'fee': listing.platformFee,
        'createdAt': Timestamp.fromDate(now),
      });

      return BoosterMarketResult.success;
    });
  }

  // ── 판매 취소 ──────────────────────────────────────────────────────────────

  /// 내 판매 게시글 취소 (부스터 반환)
  Future<BoosterMarketResult> cancelListing(String listingId) async {
    if (_uid == null) return BoosterMarketResult.notLoggedIn;

    return _db.runTransaction<BoosterMarketResult>((tx) async {
      final snap = await tx.get(_market.doc(listingId));
      if (!snap.exists) return BoosterMarketResult.listingNotFound;

      final listing = BoosterMarketModel.fromMap(
          snap.data() as Map<String, dynamic>, listingId);

      if (listing.sellerId != _uid) return BoosterMarketResult.notOwner;
      if (listing.status != BoosterListingStatus.available) {
        return BoosterMarketResult.listingNotFound;
      }

      // 취소 처리
      tx.update(_market.doc(listingId), {
        'status': BoosterListingStatus.cancelled.name,
      });

      // 부스터 반환 (판매 기한이 남아있으면 복원)
      final now = DateTime.now();
      if (now.isBefore(listing.boosterExpiry)) {
        tx.update(_points.doc(_uid), {
          'boosterCharges': FieldValue.increment(1),
        });
      }

      return BoosterMarketResult.success;
    });
  }

  // ── 목록 조회 ──────────────────────────────────────────────────────────────

  /// 마켓에 올라온 판매 가능 목록 (실시간)
  Stream<List<BoosterMarketModel>> watchListings() {
    return _market
        .where('status', isEqualTo: BoosterListingStatus.available.name)
        .where('boosterExpiry',
            isGreaterThan: Timestamp.fromDate(DateTime.now()))
        .orderBy('boosterExpiry')
        .orderBy('price')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BoosterMarketModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// 내 판매 내역 (실시간)
  Stream<List<BoosterMarketModel>> watchMyListings() {
    if (_uid == null) return const Stream.empty();
    return _market
        .where('sellerId', isEqualTo: _uid)
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BoosterMarketModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }
}

// ── 결과 코드 ────────────────────────────────────────────────────────────────

enum BoosterMarketResult {
  success,
  notLoggedIn,
  noBooster,           // 보유 부스터 없음
  boosterActive,       // 이미 부스터 활성화 중 (판매 불가)
  sellWindowExpired,   // 7일 판매 기한 초과
  alreadyListed,       // 이미 판매 등록됨
  listingNotFound,     // 게시글 없음 또는 이미 sold/cancelled
  cannotBuyOwn,        // 자신의 게시글 구매 불가
  insufficientPoints,  // 포인트 부족
  monthlyLimitReached, // 월 2회 구매 한도 초과
  notOwner,            // 취소 권한 없음
  invalidPrice,        // 유효하지 않은 가격
}

extension BoosterMarketResultExt on BoosterMarketResult {
  String get message {
    switch (this) {
      case BoosterMarketResult.success:             return '완료되었습니다.';
      case BoosterMarketResult.notLoggedIn:         return '로그인이 필요합니다.';
      case BoosterMarketResult.noBooster:           return '판매할 부스터가 없습니다.';
      case BoosterMarketResult.boosterActive:       return '부스터가 사용 중입니다. 비활성 상태의 부스터만 판매할 수 있습니다.';
      case BoosterMarketResult.sellWindowExpired:   return '판매 가능 기한(7일)이 지났습니다.';
      case BoosterMarketResult.alreadyListed:       return '이미 판매 등록된 부스터가 있습니다.';
      case BoosterMarketResult.listingNotFound:     return '게시글을 찾을 수 없거나 이미 판매되었습니다.';
      case BoosterMarketResult.cannotBuyOwn:        return '자신의 게시글은 구매할 수 없습니다.';
      case BoosterMarketResult.insufficientPoints:  return '포인트가 부족합니다.';
      case BoosterMarketResult.monthlyLimitReached: return '이번 달 구매 한도(2회)에 도달했습니다.';
      case BoosterMarketResult.notOwner:            return '취소 권한이 없습니다.';
      case BoosterMarketResult.invalidPrice:        return '판매가는 10포인트 이상 90포인트 이하로 설정해주세요.';
    }
  }

  bool get isSuccess => this == BoosterMarketResult.success;
}
