import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/review_model.dart';

class ReviewService {
  final _db = FirebaseFirestore.instance;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// 해당 주문에 이미 리뷰를 작성했는지 확인
  Future<bool> hasReview(String orderId) async {
    final snap = await _db
        .collection('reviews')
        .where('orderId', isEqualTo: orderId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// 리뷰 작성 (구매자만 가능, 주문 status='delivered' 확인 후 호출)
  Future<void> submitReview({
    required String storeId,
    required String orderId,
    required String customerName,
    required double rating,
    required String comment,
  }) async {
    if (_uid == null) return;

    // 3.5점 미만이면 24시간 후 댓글 자동 삭제
    final isLowRating = rating < 3.5;
    final now = DateTime.now();
    final expiry = isLowRating ? now.add(const Duration(hours: 24)) : null;

    final data = ReviewModel(
      id: '',
      storeId: storeId,
      orderId: orderId,
      customerId: _uid!,
      customerName: customerName,
      rating: rating,
      comment: comment,
      status: isLowRating ? ReviewStatus.pending : ReviewStatus.visible,
      createdAt: now,
      commentExpiresAt: expiry,
    ).toMap();

    await _db.collection('reviews').add(data);

    // 가게 평균 별점 업데이트
    await _updateStoreRating(storeId);
  }

  /// 가게 리뷰 목록 (삭제된 것 제외)
  Stream<List<ReviewModel>> storeReviews(String storeId) {
    return _db
        .collection('reviews')
        .where('storeId', isEqualTo: storeId)
        .where('status', whereNotIn: ['deleted'])
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ReviewModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// 만료된 댓글 자동 삭제 처리 (클라이언트에서 주기적으로 호출하거나 Cloud Functions 사용 권장)
  Future<void> expirePendingComments() async {
    final now = Timestamp.now();
    final snap = await _db
        .collection('reviews')
        .where('status', isEqualTo: 'pending')
        .where('commentExpiresAt', isLessThanOrEqualTo: now)
        .get();

    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {
        'comment': '',
        'status': 'commentDeleted',
      });
    }
    if (snap.docs.isNotEmpty) await batch.commit();
  }

  /// 가게 사장님 댓글 삭제 요청 (500원 수수료 → 별점도 삭제)
  /// 실제 결제 연동은 별도. 여기선 Firestore 상태만 변경.
  Future<void> requestDeleteRating(String reviewId) async {
    await _db.collection('reviews').doc(reviewId).update({
      'status': 'deleted',
      'comment': '',
      'rating': 0.0,
    });

    // 가게 평균 별점 업데이트
    final doc = await _db.collection('reviews').doc(reviewId).get();
    final storeId = doc.data()?['storeId'];
    if (storeId != null) await _updateStoreRating(storeId);
  }

  /// 가게 평균 별점 재계산
  Future<void> _updateStoreRating(String storeId) async {
    final snap = await _db
        .collection('reviews')
        .where('storeId', isEqualTo: storeId)
        .where('status', whereNotIn: ['deleted'])
        .get();

    if (snap.docs.isEmpty) {
      await _db.collection('stores').doc(storeId).update({
        'avgRating': 0.0,
        'reviewCount': 0,
      });
      return;
    }

    final ratings = snap.docs
        .map((d) => (d.data()['rating'] ?? 0.0) as double)
        .where((r) => r > 0)
        .toList();

    final avg = ratings.isEmpty
        ? 0.0
        : ratings.reduce((a, b) => a + b) / ratings.length;

    await _db.collection('stores').doc(storeId).update({
      'avgRating': double.parse(avg.toStringAsFixed(1)),
      'reviewCount': ratings.length,
    });
  }
}
