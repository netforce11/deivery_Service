import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/store_model.dart';
import '../models/menu_model.dart';
import '../models/order_model.dart';

class StoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── 가게 목록 (실시간 스트림) ──────────────────────────────────────
  Stream<List<StoreModel>> watchStores({String? category}) {
    Query<Map<String, dynamic>> q = _db.collection('stores');
    if (category != null && category != '전체') {
      q = q.where('category', isEqualTo: category);
    }
    return q.snapshots().map((snap) =>
        snap.docs.map((d) => StoreModel.fromMap(d.data(), d.id)).toList());
  }

  // ── 가게 단건 조회 ─────────────────────────────────────────────────
  Future<StoreModel?> getStore(String storeId) async {
    final doc = await _db.collection('stores').doc(storeId).get();
    if (!doc.exists) return null;
    return StoreModel.fromMap(doc.data()!, doc.id);
  }

  // ── 메뉴 목록 (해당 가게) ─────────────────────────────────────────
  Future<List<MenuModel>> getMenus(String storeId) async {
    final snap = await _db
        .collection('menus')
        .where('storeId', isEqualTo: storeId)
        .get();
    // isAvailable 필터는 Dart에서 처리 (복합 인덱스 불필요)
    return snap.docs
        .map((d) => MenuModel.fromMap(d.data(), d.id))
        .where((m) => m.isAvailable)
        .toList();
  }

  // ── 주문 생성 ─────────────────────────────────────────────────────
  Future<String> createOrder(OrderModel order) async {
    final ref = await _db.collection('orders').add(order.toMap());
    return ref.id;
  }

  // ── 내 주문 내역 (실시간 스트림) ─────────────────────────────────
  Stream<List<OrderModel>> watchMyOrders(String customerId) {
    return _db
        .collection('orders')
        .where('customerId', isEqualTo: customerId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => OrderModel.fromMap(d.data(), d.id)).toList());
  }

  // ── 샘플 가게 데이터 Firestore에 추가 (개발용) ────────────────────
  Future<void> seedSampleData() async {
    final storesSnap = await _db.collection('stores').limit(1).get();

    // 가게는 있는데 메뉴가 없으면 메뉴만 다시 추가
    if (storesSnap.docs.isNotEmpty) {
      final menusSnap = await _db.collection('menus').limit(1).get();
      if (menusSnap.docs.isEmpty) {
        final storeId = storesSnap.docs.first.id;
        final menus = [
          {'storeId': storeId, 'name': '전주비빔밥', 'price': 12000, 'description': '전통 방식 비빔밥', 'imageUrl': '', 'isAvailable': true},
          {'storeId': storeId, 'name': '돌솥비빔밥', 'price': 13000, 'description': '뜨끈한 돌솥', 'imageUrl': '', 'isAvailable': true},
          {'storeId': storeId, 'name': '콩나물국밥', 'price': 9000, 'description': '해장에 최고', 'imageUrl': '', 'isAvailable': true},
        ];
        for (final menu in menus) {
          await _db.collection('menus').add(menu);
        }
      }
      return;
    }

    final stores = [
      {
        'name': '전주 비빔밥 명가',
        'category': '한식',
        'address': '전주시 완산구 태조로 44',
        'lat': 35.8175,
        'lng': 127.1084,
        'phone': '063-000-0001',
        'ownerId': 'sample_owner_1',
        'isOpen': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': '전주 순대국밥',
        'category': '한식',
        'address': '전주시 덕진구 백제대로 567',
        'lat': 35.8462,
        'lng': 127.1258,
        'phone': '063-000-0002',
        'ownerId': 'sample_owner_2',
        'isOpen': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': '피자헛 전주점',
        'category': '양식',
        'address': '전주시 완산구 효자동1가 100',
        'lat': 35.8150,
        'lng': 127.1020,
        'phone': '063-000-0003',
        'ownerId': 'sample_owner_3',
        'isOpen': true,
        'createdAt': FieldValue.serverTimestamp(),
      },
      {
        'name': '맛있는 치킨집',
        'category': '치킨',
        'address': '전주시 완산구 삼천동1가 200',
        'lat': 35.8080,
        'lng': 127.0900,
        'phone': '063-000-0004',
        'ownerId': 'sample_owner_4',
        'isOpen': false,
        'createdAt': FieldValue.serverTimestamp(),
      },
    ];

    final menus = <Map<String, dynamic>>[
      {'storeId': '', 'name': '전주비빔밥', 'price': 12000, 'description': '전통 방식 비빔밥', 'imageUrl': '', 'isAvailable': true},
      {'storeId': '', 'name': '돌솥비빔밥', 'price': 13000, 'description': '뜨끈한 돌솥', 'imageUrl': '', 'isAvailable': true},
      {'storeId': '', 'name': '콩나물국밥', 'price': 9000, 'description': '해장에 최고', 'imageUrl': '', 'isAvailable': true},
    ];

    for (int i = 0; i < stores.length; i++) {
      final storeRef = await _db.collection('stores').add(stores[i]);
      if (i == 0) {
        for (final menu in menus) {
          final m = Map<String, dynamic>.from(menu);
          m['storeId'] = storeRef.id;
          await _db.collection('menus').add(m);
        }
      }
    }
  }
}
