import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/store_model.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 내 가게 정보 조회
  Future<StoreModel?> getMyStore(String ownerId) async {
    final snap = await _db
        .collection('stores')
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return StoreModel.fromMap(snap.docs.first.data(), snap.docs.first.id);
  }

  // 내 가게 주문 실시간 스트림
  Stream<List<OrderModel>> watchStoreOrders(String storeId) {
    return _db
        .collection('orders')
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => OrderModel.fromMap(d.data(), d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // 주문 수락
  Future<void> acceptOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).update({'status': 'accepted'});
  }

  // 주문 거절 (취소)
  Future<void> rejectOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).update({'status': 'cancelled'});
  }

  // 가게 영업 상태 토글
  Future<void> toggleStoreOpen(String storeId, bool isOpen) async {
    await _db.collection('stores').doc(storeId).update({'isOpen': isOpen});
  }
}
