import 'package:cloud_firestore/cloud_firestore.dart';

/// 마켓 판매 상태
enum BoosterListingStatus { available, sold, cancelled }

/// 부스터 마켓 판매 게시글 모델
/// Firestore 컬렉션: boosterMarket
class BoosterMarketModel {
  final String id;
  final String sellerId;
  final String sellerName;
  final int price;                    // 판매 가격 (포인트)
  final DateTime boosterGrantedAt;    // 원래 부스터 획득 시각
  final DateTime boosterExpiry;       // 판매 가능 기한 (획득 후 7일)
  final BoosterListingStatus status;
  final String? buyerId;              // 구매자 UID (sold 상태일 때)
  final DateTime createdAt;
  final DateTime? soldAt;

  BoosterMarketModel({
    required this.id,
    required this.sellerId,
    required this.sellerName,
    required this.price,
    required this.boosterGrantedAt,
    required this.boosterExpiry,
    required this.status,
    this.buyerId,
    required this.createdAt,
    this.soldAt,
  });

  /// 판매 가능 여부 (기한 내 + available 상태)
  bool get isAvailable =>
      status == BoosterListingStatus.available &&
      DateTime.now().isBefore(boosterExpiry);

  /// 판매자 수취 금액 (플랫폼 10% 수수료 제외)
  int get sellerReceives => (price * 0.9).floor();

  /// 플랫폼 수수료
  int get platformFee => price - sellerReceives;

  factory BoosterMarketModel.fromMap(Map<String, dynamic> map, String id) {
    return BoosterMarketModel(
      id: id,
      sellerId: map['sellerId'] as String,
      sellerName: map['sellerName'] as String? ?? '라이더',
      price: (map['price'] ?? 0).toInt(),
      boosterGrantedAt:
          (map['boosterGrantedAt'] as Timestamp).toDate(),
      boosterExpiry:
          (map['boosterExpiry'] as Timestamp).toDate(),
      status: _parseStatus(map['status']),
      buyerId: map['buyerId'] as String?,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      soldAt: (map['soldAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'sellerId': sellerId,
    'sellerName': sellerName,
    'price': price,
    'boosterGrantedAt': Timestamp.fromDate(boosterGrantedAt),
    'boosterExpiry': Timestamp.fromDate(boosterExpiry),
    'status': status.name,
    'buyerId': buyerId,
    'createdAt': Timestamp.fromDate(createdAt),
    'soldAt': soldAt != null ? Timestamp.fromDate(soldAt!) : null,
  };

  static BoosterListingStatus _parseStatus(dynamic v) {
    try {
      return BoosterListingStatus.values.firstWhere((e) => e.name == v);
    } catch (_) {
      return BoosterListingStatus.available;
    }
  }
}
