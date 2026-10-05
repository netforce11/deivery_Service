import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/order_model.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _orderService = OrderService();
  final _authService = AuthService();
  late TabController _tabController;
  String? _riderId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _riderId = FirebaseAuth.instance.currentUser?.uid;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('라이더 대시보드',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text('배달 관리', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _authService.signOut(),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.green.shade200,
          tabs: const [
            Tab(text: '배달 가능'),
            Tab(text: '내 배달'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 탭 1: 배달 가능한 주문 (accepted, 라이더 미배정)
          StreamBuilder<List<OrderModel>>(
            stream: _orderService.watchAvailableOrders(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.green));
              }
              final orders = snap.data ?? [];
              if (orders.isEmpty) {
                return _emptyState(
                    '대기 중인 배달이 없어요', Icons.delivery_dining_outlined);
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (_, i) => _AvailableOrderCard(
                  order: orders[i],
                  onAccept: () async {
                    await _orderService.acceptDelivery(orders[i].id, _riderId!);
                    if (mounted) {
                      _tabController.animateTo(1);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('배달을 수락했어요! 가게로 이동해주세요 🚴'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                ),
              );
            },
          ),

          // 탭 2: 내가 진행 중인 배달
          StreamBuilder<List<OrderModel>>(
            stream: _riderId != null
                ? _orderService.watchMyOrders(_riderId!)
                : const Stream.empty(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.green));
              }
              final orders = snap.data ?? [];
              if (orders.isEmpty) {
                return _emptyState('진행 중인 배달이 없어요', Icons.check_circle_outline);
              }
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: orders.length,
                itemBuilder: (_, i) => _MyOrderCard(
                  order: orders[i],
                  onPickup: () => _orderService.pickupOrder(orders[i].id),
                  onComplete: () => _confirmComplete(orders[i].id),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyState(String msg, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 12),
          Text(msg, style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
        ],
      ),
    );
  }

  Future<void> _confirmComplete(String orderId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('배달 완료'),
        content: const Text('배달을 완료하셨나요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('완료', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _orderService.completeDelivery(orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('배달 완료! 수고하셨어요 🎉'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

// ── 배달 가능 주문 카드 ─────────────────────────────────────────────────────
class _AvailableOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onAccept;

  const _AvailableOrderCard({required this.order, required this.onAccept});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.store, size: 16, color: Colors.green.shade600),
                      const SizedBox(width: 6),
                      Text(order.storeName,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  Text(_timeStr(order.createdAt),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 10),
              ...order.items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text('• ${item.name} ${item.quantity}개',
                        style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                  )),
              const Divider(height: 16),
              Row(
                children: [
                  Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(order.deliveryAddress,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${_fmt(order.totalPrice)}원',
                      style: TextStyle(
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                    ),
                    onPressed: onAccept,
                    child: const Text('배달 수락',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 내 배달 카드 ────────────────────────────────────────────────────────────
class _MyOrderCard extends StatelessWidget {
  final OrderModel order;
  final VoidCallback onPickup;
  final VoidCallback onComplete;

  const _MyOrderCard(
      {required this.order, required this.onPickup, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final isAssigned = order.status == 'assigned';
    final isPickedUp = order.status == 'picked_up';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.store, size: 16, color: Colors.green.shade600),
                    const SizedBox(width: 6),
                    Text(order.storeName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPickedUp
                        ? Colors.teal.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPickedUp ? '픽업 완료' : '픽업 대기',
                    style: TextStyle(
                      color: isPickedUp ? Colors.teal : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // 진행 상태 바
            Row(
              children: [
                _step('수락', true),
                _line(isPickedUp),
                _step('픽업', isPickedUp),
                _line(false),
                _step('완료', false, dim: true),
              ],
            ),
            const SizedBox(height: 12),

            ...order.items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• ${item.name} ${item.quantity}개',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 13)),
                )),
            const Divider(height: 16),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(order.deliveryAddress,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                      maxLines: 2),
                ),
              ],
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isPickedUp ? Colors.green.shade600 : Colors.orange,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: isAssigned ? onPickup : (isPickedUp ? onComplete : null),
                child: Text(
                  isAssigned ? '🛵  픽업 완료' : '🎉  배달 완료',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _step(String label, bool active, {bool dim = false}) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active
                ? Colors.green.shade600
                : (dim ? Colors.grey.shade200 : Colors.grey.shade300),
          ),
          child: Icon(Icons.check, size: 14,
              color: active ? Colors.white : Colors.grey.shade400),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color: active ? Colors.green.shade600 : Colors.grey.shade400)),
      ],
    );
  }

  Widget _line(bool active) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(bottom: 14),
        color: active ? Colors.green.shade400 : Colors.grey.shade200,
      ),
    );
  }
}

String _timeStr(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
