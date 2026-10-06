import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/order_model.dart';
import '../models/store_model.dart';
import '../models/menu_model.dart';

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

  // ── 메뉴 관리 ──────────────────────────────────────────────────────────────

  // 메뉴 목록 스트림
  Stream<List<MenuModel>> watchMenus(String storeId) {
    return _db
        .collection('menus')
        .where('storeId', isEqualTo: storeId)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MenuModel.fromMap(d.data(), d.id))
            .toList());
  }

  // 메뉴 추가
  Future<void> addMenu(MenuModel menu) async {
    await _db.collection('menus').add(menu.toMap());
  }

  // 메뉴 수정
  Future<void> updateMenu(String menuId, Map<String, dynamic> data) async {
    await _db.collection('menus').doc(menuId).update(data);
  }

  // 메뉴 삭제
  Future<void> deleteMenu(String menuId) async {
    await _db.collection('menus').doc(menuId).delete();
  }

  // 메뉴 공개여부 토글
  Future<void> toggleMenuAvailable(String menuId, bool isAvailable) async {
    await _db.collection('menus').doc(menuId).update({'isAvailable': isAvailable});
  }

  // 주문 거절 (사유 포함)
  Future<void> rejectOrderWithReason(String orderId, String reason) async {
    await _db.collection('orders').doc(orderId).update({
      'status': 'cancelled',
      'cancelReason': reason,
    });
  }

  // 공지사항 업데이트
  Future<void> updateNotice(String storeId, String notice) async {
    await _db.collection('stores').doc(storeId).update({'notice': notice});
  }

  // 예상 조리시간 업데이트
  Future<void> updateEstimatedMinutes(String storeId, int minutes) async {
    await _db.collection('stores').doc(storeId).update({'estimatedMinutes': minutes});
  }

  // 영업시간 업데이트
  Future<void> updateBusinessHours(
      String storeId, Map<String, Map<String, String>> hours) async {
    await _db.collection('stores').doc(storeId).update({'businessHours': hours});
  }
}
