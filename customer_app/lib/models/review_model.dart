import 'package:cloud_firestore/cloud_firestore.dart';

/// 리뷰 상태
enum ReviewStatus {
  visible,    // 노출 중
  pending,    // 3.5점 미만 - 24시간 후 댓글 자동 삭제 예정
  commentDeleted, // 댓글만 삭제됨 (별점 유지)
  deleted,    // 가게 요청+500원 수수료로 별점까지 삭제
}

class ReviewModel {
  final String id;
  final String storeId;
  final String orderId;
  final String customerId;
  final String customerName;
  final double rating;        // 0.0 ~ 5.0 (0.1 단위)
  final String comment;       // 최대 200자
  final ReviewStatus status;
  final DateTime createdAt;
  final DateTime? commentExpiresAt; // 3.5점 미만: 댓글 24시간 후 삭제 시각

  ReviewModel({
    required this.id,
    required this.storeId,
    required this.orderId,
    required this.customerId,
    required this.customerName,
    required this.rating,
    required this.comment,
    required this.status,
    required this.createdAt,
    this.commentExpiresAt,
  });

  factory ReviewModel.fromMap(Map<String, dynamic> map, String id) {
    return ReviewModel(
      id: id,
      storeId: map['storeId'] ?? '',
      orderId: map['orderId'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '익명',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'] ?? '',
      status: _parseStatus(map['status']),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      commentExpiresAt:
          (map['commentExpiresAt'] as Timestamp?)?.toDate(),
    );
  }

  static ReviewStatus _parseStatus(dynamic v) {
    switch (v) {
      case 'pending': return ReviewStatus.pending;
      case 'commentDeleted': return ReviewStatus.commentDeleted;
      case 'deleted': return ReviewStatus.deleted;
      default: return ReviewStatus.visible;
    }
  }

  static String _statusStr(ReviewStatus s) {
    switch (s) {
      case ReviewStatus.pending: return 'pending';
      case ReviewStatus.commentDeleted: return 'commentDeleted';
      case ReviewStatus.deleted: return 'deleted';
      default: return 'visible';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'storeId': storeId,
      'orderId': orderId,
      'customerId': customerId,
      'customerName': customerName,
      'rating': rating,
      'comment': comment,
      'status': _statusStr(status),
      'createdAt': Timestamp.fromDate(createdAt),
      'commentExpiresAt': commentExpiresAt != null
          ? Timestamp.fromDate(commentExpiresAt!)
          : null,
    };
  }

  bool get isCommentVisible =>
      status == ReviewStatus.visible || status == ReviewStatus.pending;

  bool get isRatingVisible => status != ReviewStatus.deleted;
}
