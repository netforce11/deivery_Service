import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/order_model.dart';
import '../../services/store_service.dart';

class OrderHistoryScreen extends StatelessWidget {
  const OrderHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final storeService = StoreService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('주문 내역', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: storeService.watchMyOrders(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.orange));
          }
          if (snap.hasError) {
            return Center(child: Text('오류: ${snap.error}'));
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('주문 내역이 없어요', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: orders.length,
            itemBuilder: (_, i) => _OrderCard(order: orders[i]),
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final OrderModel order;
  const _OrderCard({required this.order});

  bool get _isActive =>
      order.status == 'assigned' || order.status == 'picked_up';

  bool get _hasRiderPos =>
      order.riderLat != null && order.riderLng != null;

  @override
  Widget build(BuildContext context) {
    final statusInfo = _statusInfo(order.status);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 라이더 실시간 지도 (배달 중일 때만)
          if (_isActive && _hasRiderPos)
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  SizedBox(
                    height: 200,
                    child: FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(order.riderLat!, order.riderLng!),
                        initialZoom: 15,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.delivery.customer',
                        ),
                        MarkerLayer(markers: [
                          // 라이더
                          Marker(
                            point: LatLng(order.riderLat!, order.riderLng!),
                            child: const Icon(Icons.delivery_dining,
                                color: Colors.green, size: 36),
                          ),
                          // 배달지
                          if (order.deliveryLat != 0 && order.deliveryLng != 0)
                            Marker(
                              point: LatLng(order.deliveryLat, order.deliveryLng),
                              child: const Icon(Icons.home_outlined,
                                  color: Colors.red, size: 32),
                            ),
                        ]),
                      ],
                    ),
                  ),
                  // 지도 위 라벨
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 4)
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.delivery_dining,
                              size: 14, color: Colors.green),
                          const SizedBox(width: 4),
                          Text(
                            order.status == 'picked_up'
                                ? '라이더가 배달 중이에요 🚴'
                                : '라이더가 픽업하러 가고 있어요',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 상태 + 날짜
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
                    Text(
                      _dateStr(order.createdAt),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // 주문 상태 진행 표시
                _StatusBar(status: order.status),
                const SizedBox(height: 12),
                const Divider(),
                // 아이템 목록
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Expanded(child: Text(item.name)),
                          Text('${item.quantity}개',
                              style: TextStyle(color: Colors.grey.shade600)),
                          const SizedBox(width: 12),
                          Text('${_fmt(item.price * item.quantity)}원',
                              style: const TextStyle(fontWeight: FontWeight.w500)),
                        ],
                      ),
                    )),
                const Divider(),
                // 금액
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                        '음식 ${_fmt(order.totalPrice)}원 + 배달비 ${_fmt(order.deliveryFee)}원',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13)),
                    Text(
                      '${_fmt(order.totalPrice + order.deliveryFee)}원',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                          fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // 주소
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(order.deliveryAddress,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _StatusMeta _statusInfo(String status) {
    switch (status) {
      case 'pending':
        return _StatusMeta('접수 대기', Colors.orange, Colors.orange.shade50);
      case 'accepted':
        return _StatusMeta('주문 수락', Colors.blue, Colors.blue.shade50);
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

  String _dateStr(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _StatusMeta {
  final String label;
  final Color color;
  final Color bg;
  _StatusMeta(this.label, this.color, this.bg);
}

// 주문 상태 진행 바
class _StatusBar extends StatelessWidget {
  final String status;
  const _StatusBar({required this.status});

  static const _steps = ['pending', 'accepted', 'assigned', 'picked_up', 'delivered'];
  static const _labels = ['접수대기', '수락', '기사배정', '픽업', '완료'];

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return const Text('❌ 주문이 취소되었습니다',
          style: TextStyle(color: Colors.red, fontSize: 13));
    }
    final currentIdx = _steps.indexOf(status);
    return Row(
      children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final stepIdx = i ~/ 2;
          final filled = stepIdx < currentIdx;
          return Expanded(
            child: Container(
              height: 2,
              color: filled ? Colors.orange : Colors.grey.shade200,
            ),
          );
        }
        final stepIdx = i ~/ 2;
        final done = stepIdx <= currentIdx;
        return Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: done ? Colors.orange : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: done
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(height: 4),
            Text(_labels[stepIdx],
                style: TextStyle(
                  fontSize: 10,
                  color: done ? Colors.orange : Colors.grey,
                  fontWeight: done ? FontWeight.bold : FontWeight.normal,
                )),
          ],
        );
      }),
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
