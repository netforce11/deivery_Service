import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/order_model.dart';
import '../../models/store_model.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../menu/menu_management_screen.dart';
import '../settlement/settlement_screen.dart';

class OrderDashboardScreen extends StatefulWidget {
  const OrderDashboardScreen({super.key});

  @override
  State<OrderDashboardScreen> createState() => _OrderDashboardScreenState();
}

class _OrderDashboardScreenState extends State<OrderDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _orderService = OrderService();
  final _authService = AuthService();
  StoreModel? _store;
  bool _loadingStore = true;
  late TabController _tabController;

  // 새 주문 알림용 — 이전 pending 개수 추적
  int _prevPendingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadStore();
  }

  Future<void> _loadStore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final store = await _orderService.getMyStore(uid);
    if (mounted) setState(() { _store = store; _loadingStore = false; });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _checkNewOrders(List<OrderModel> orders) {
    final pending = orders.where((o) => o.status == 'pending').length;
    if (pending > _prevPendingCount && _prevPendingCount >= 0) {
      // 새 주문 알림
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.notifications_active, color: Colors.white),
                  SizedBox(width: 8),
                  Text('🔔 새 주문이 들어왔어요!',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              backgroundColor: Colors.indigo,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
          _tabController.animateTo(0); // 대기중 탭으로 이동
        }
      });
    }
    _prevPendingCount = pending;
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingStore) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.indigo)),
      );
    }

    if (_store == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('업체 관리'),
          backgroundColor: Colors.indigo,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store_outlined, size: 64, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('등록된 가게가 없습니다',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: _loadStore,
                child: const Text('새로고침'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<OrderModel>>(
      stream: _orderService.watchStoreOrders(_store!.id),
      builder: (context, snap) {
        final orders = snap.data ?? [];

        if (snap.hasData) _checkNewOrders(orders);

        final pending = orders.where((o) => o.status == 'pending').toList();
        final active = orders
            .where((o) =>
                o.status == 'accepted' ||
                o.status == 'assigned' ||
                o.status == 'picked_up')
            .toList();
        final done = orders
            .where((o) =>
                o.status == 'delivered' || o.status == 'cancelled')
            .toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF0F4FF),
          appBar: AppBar(
            backgroundColor: Colors.indigo,
            foregroundColor: Colors.white,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_store!.name,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                Text('주문 관리',
                    style: TextStyle(
                        fontSize: 12, color: Colors.indigo.shade100)),
              ],
            ),
            actions: [
              // 영업 상태 토글
              Row(
                children: [
                  Text(
                    _store!.isOpen ? '영업중' : '준비중',
                    style: TextStyle(
                      fontSize: 13,
                      color: _store!.isOpen
                          ? Colors.greenAccent
                          : Colors.white60,
                    ),
                  ),
                  Switch(
                    value: _store!.isOpen,
                    onChanged: (val) async {
                      await _orderService.toggleStoreOpen(_store!.id, val);
                      setState(() =>
                          _store = StoreModel(
                            id: _store!.id,
                            name: _store!.name,
                            category: _store!.category,
                            address: _store!.address,
                            lat: _store!.lat,
                            lng: _store!.lng,
                            phone: _store!.phone,
                            ownerId: _store!.ownerId,
                            isOpen: val,
                            createdAt: _store!.createdAt,
                          ));
                    },
                    activeColor: Colors.greenAccent,
                    inactiveThumbColor: Colors.white54,
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.restaurant_menu),
                tooltip: '메뉴 관리',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MenuManagementScreen(store: _store!),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.account_balance_wallet_outlined),
                tooltip: '정산 관리',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettlementScreen(store: _store!),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: () async {
                  await _authService.signOut();
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.indigo.shade200,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('대기중'),
                      if (pending.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _badge(pending.length),
                      ],
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('진행중'),
                      if (active.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        _badge(active.length, color: Colors.orange),
                      ],
                    ],
                  ),
                ),
                const Tab(text: '완료/취소'),
              ],
            ),
          ),
          body: snap.connectionState == ConnectionState.waiting
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.indigo))
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _OrderList(
                      orders: pending,
                      emptyMsg: '대기 중인 주문이 없어요',
                      emptyIcon: Icons.hourglass_empty,
                      onAccept: (id) => _orderService.acceptOrder(id),
                      onReject: (id) => _confirmReject(id),
                    ),
                    _OrderList(
                      orders: active,
                      emptyMsg: '진행 중인 주문이 없어요',
                      emptyIcon: Icons.delivery_dining_outlined,
                    ),
                    _OrderList(
                      orders: done,
                      emptyMsg: '완료된 주문이 없어요',
                      emptyIcon: Icons.check_circle_outline,
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _confirmReject(String orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('주문 거절'),
        content: const Text('이 주문을 거절하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('거절'),
          ),
        ],
      ),
    );
    if (ok == true) await _orderService.rejectOrder(orderId);
  }

  Widget _badge(int count, {Color color = Colors.red}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
      child: Text('$count',
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// ── 주문 목록 위젯 ─────────────────────────────────────────────────────────
class _OrderList extends StatelessWidget {
  final List<OrderModel> orders;
  final String emptyMsg;
  final IconData emptyIcon;
  final Future<void> Function(String)? onAccept;
  final Future<void> Function(String)? onReject;

  const _OrderList({
    required this.orders,
    required this.emptyMsg,
    required this.emptyIcon,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(emptyMsg,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, i) => _OrderCard(
        order: orders[i],
        onAccept: onAccept,
        onReject: onReject,
      ),
    );
  }
}

// ── 주문 카드 ──────────────────────────────────────────────────────────────
class _OrderCard extends StatelessWidget {
  final OrderModel order;
  final Future<void> Function(String)? onAccept;
  final Future<void> Function(String)? onReject;

  const _OrderCard({required this.order, this.onAccept, this.onReject});

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(order.status);
    final timeStr = _timeStr(order.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: order.status == 'pending' ? 4 : 1,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: order.status == 'pending'
              ? Border.all(color: Colors.indigo.shade300, width: 2)
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusInfo.bg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(statusInfo.label,
                        style: TextStyle(
                            color: statusInfo.color,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  Text(timeStr,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 12),

              // 주문 아이템
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.circle, size: 6, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Text(item.name)),
                        Text('${item.quantity}개',
                            style:
                                TextStyle(color: Colors.grey.shade600)),
                        const SizedBox(width: 12),
                        Text('${_fmt(item.price * item.quantity)}원',
                            style: const TextStyle(
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )),

              const Divider(height: 20),

              // 금액 + 주소
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('음식 ${_fmt(order.totalPrice)}원',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 13)),
                  Text('${_fmt(order.totalPrice)}원',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                          fontSize: 16)),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.location_on,
                      size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order.deliveryAddress,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              // 수락/거절 버튼 (pending일 때만)
              if (order.status == 'pending') ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => onReject?.call(order.id),
                        child: const Text('거절'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: () => onAccept?.call(order.id),
                        child: const Text('수락',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  _StatusMeta _statusInfo(String status) {
    switch (status) {
      case 'pending':
        return _StatusMeta('새 주문', Colors.indigo, Colors.indigo.shade50);
      case 'accepted':
        return _StatusMeta('수락됨', Colors.blue, Colors.blue.shade50);
      case 'assigned':
        return _StatusMeta('기사 배정', Colors.purple, Colors.purple.shade50);
      case 'picked_up':
        return _StatusMeta('픽업 완료', Colors.teal, Colors.teal.shade50);
      case 'delivered':
        return _StatusMeta('배달 완료', Colors.green, Colors.green.shade50);
      case 'cancelled':
        return _StatusMeta('취소됨', Colors.red, Colors.red.shade50);
      default:
        return _StatusMeta(status, Colors.grey, Colors.grey.shade100);
    }
  }

  String _timeStr(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusMeta {
  final String label;
  final Color color;
  final Color bg;
  _StatusMeta(this.label, this.color, this.bg);
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
