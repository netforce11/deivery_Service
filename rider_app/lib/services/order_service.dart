import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';

class OrderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 수락된 주문 중 라이더 미배정 주문 (배달 가능 목록)
  Stream<List<OrderModel>> watchAvailableOrders() {
    return _db
        .collection('orders')
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => OrderModel.fromMap(d.data(), d.id))
          .where((o) => o.riderId == null)
          .toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      return list;
    });
  }

  // 내가 맡은 배달 (진행중)
  Stream<List<OrderModel>> watchMyOrders(String riderId) {
    return _db
        .collection('orders')
        .where('riderId', isEqualTo: riderId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => OrderModel.fromMap(d.data(), d.id))
          .where((o) => o.status == 'assigned' || o.status == 'picked_up')
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  // 배달 수락 (라이더가 주문 픽업 담당)
  Future<void> acceptDelivery(String orderId, String riderId) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'assigned',
      'riderId': riderId,
    });
  }

  // 픽업 완료
  Future<void> pickupOrder(String orderId) async {
    await _db.collection('orders').doc(orderId).update({'status': 'picked_up'});
  }

  // 배달 완료
  Future<void> completeDelivery(String orderId) async {
    await _db.collection('orders').doc(orderId).update({'status': 'delivered'});
  }
}
