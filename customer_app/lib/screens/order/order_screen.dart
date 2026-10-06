import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../models/store_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/store_service.dart';
import '../../services/geocoding_service.dart';
import '../../utils/delivery_fee_calculator.dart';
import '../address/address_search_screen.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _storeService = StoreService();
  AddressResult? _selectedAddress;
  bool _submitting = false;
  double? _distanceKm;

  Future<void> _openAddressSearch() async {
    final cart = context.read<CartProvider>();
    final result = await Navigator.push<AddressResult>(
      context,
      MaterialPageRoute(builder: (_) => const AddressSearchScreen()),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedAddress = result;
        _distanceKm = null;
      });

      // 가게 좌표가 있으면 거리 계산
      final store = cart.store;
      if (store != null && store.lat != 0 && store.lng != 0) {
        final km = DeliveryFeeCalculator.distanceKm(
          store.lat, store.lng, result.lat, result.lng,
        );
        if (mounted) {
          setState(() => _distanceKm = km);
          cart.setDeliveryDistance(km);
        }
      } else {
        cart.clearDistance();
      }
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('배달 주소를 선택해주세요'), backgroundColor: Colors.red),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || cart.store == null) return;

    setState(() => _submitting = true);

    try {
      final subtotal = cart.subtotal;
      final fee = cart.deliveryFee;
      final platformFee = (subtotal * 0.12).round();
      final km = _distanceKm;
      final isLong = km != null && DeliveryFeeCalculator.isLongDistance(km);

      final order = OrderModel(
        id: '',
        customerId: uid,
        storeId: cart.store!.id,
        riderId: null,
        bundleId: null,
        items: cart.items
            .map((e) => OrderItem(
                  menuId: e.menu.id,
                  name: e.menu.name,
                  price: e.menu.price,
                  quantity: e.quantity,
                ))
            .toList(),
        totalPrice: subtotal,
        platformFee: platformFee,
        deliveryFee: fee,
        riderPay: fee,      // 라이더 수령액 = 배달비 전액
        deliveryAddress: _selectedAddress!.shortName,
        deliveryLat: _selectedAddress!.lat,
        deliveryLng: _selectedAddress!.lng,
        distanceKm: km,
        isLongDistance: isLong,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _storeService.createOrder(order);
      cart.clear();

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/orders', (r) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('주문이 완료되었어요! 🎉'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('주문 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title:
            const Text('주문하기', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 배달 주소
            _sectionTitle('📍 배달 주소'),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _openAddressSearch,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedAddress != null
                        ? Colors.orange
                        : Colors.transparent,
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(Icons.location_on,
                        color: _selectedAddress != null
                            ? Colors.orange
                            : Colors.grey.shade400),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _selectedAddress == null
                          ? Text('배달받을 주소를 검색해주세요',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 14))
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedAddress!.shortName,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedAddress!.displayName,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade500),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey.shade400),
                  ],
                ),
              ),
            ),

            // 거리 및 배달 유형 배지
            if (_distanceKm != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  _DistanceBadge(distanceKm: _distanceKm!),
                  const SizedBox(width: 8),
                  if (DeliveryFeeCalculator.isLongDistance(_distanceKm!))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.purple.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.directions_bike,
                              size: 13, color: Colors.purple.shade600),
                          const SizedBox(width: 4),
                          Text('장거리 배달',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.purple.shade700,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 24),

            // 주문 목록
            _sectionTitle('🛒 주문 목록'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ...cart.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(item.menu.name,
                                  style: const TextStyle(fontSize: 15)),
                            ),
                            Text('${item.quantity}개',
                                style:
                                    TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(width: 12),
                            Text(
                              '${_fmt(item.menu.price * item.quantity)}원',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 결제 금액
            _sectionTitle('💳 결제 금액'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _priceRow('음식 금액', cart.subtotal),
                  const SizedBox(height: 8),
                  // 배달비 행 — 거리 정보 포함
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Text('배달비',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700)),
                          if (_distanceKm != null) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${_distanceKm!.toStringAsFixed(1)}km)',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400),
                            ),
                          ],
                        ],
                      ),
                      Text('${_fmt(cart.deliveryFee)}원',
                          style: TextStyle(
                              fontSize: 14,
                              color: cart.isLongDistance
                                  ? Colors.purple
                                  : Colors.grey.shade700)),
                    ],
                  ),
                  const Divider(height: 24),
                  _priceRow('최종 결제금액', cart.total,
                      bold: true, color: Colors.orange),
                ],
              ),
            ),

            // 배달비 안내 (장거리일 때)
            if (cart.isLongDistance) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.purple.shade400),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '장거리 배달은 숙련된 장거리 전문 라이더가 배정됩니다.',
                        style: TextStyle(
                            fontSize: 12, color: Colors.purple.shade700),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),

            // 배달비 구간 안내
            _sectionTitle('🚴 배달비 안내'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _feeRow('3km 이하', 3500, _distanceKm, 0, 3),
                  _feeRow('3~7km', 5000, _distanceKm, 3, 7),
                  _feeRow('7~15km', 8000, _distanceKm, 7, 15),
                  _feeRow('15~30km', 12000, _distanceKm, 15, 30),
                  _feeRow('30km 초과', 20000, _distanceKm, 30, 999),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 결제 방법
            _sectionTitle('💵 결제 방법'),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.payments_outlined, color: Colors.orange),
                  const SizedBox(width: 12),
                  const Text('현금결제 (추후 카드/간편결제 추가 예정)'),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('선택됨',
                        style:
                            TextStyle(color: Colors.orange, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _submitting ? null : _placeOrder,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    '${_fmt(cart.total)}원 주문하기',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _feeRow(String label, int fee, double? dist, double min, double max) {
    final isActive = dist != null && dist > min && dist <= max;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (isActive)
            const Icon(Icons.arrow_right, size: 18, color: Colors.orange)
          else
            const SizedBox(width: 18),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    fontSize: 13,
                    color: isActive ? Colors.orange : Colors.grey.shade600,
                    fontWeight:
                        isActive ? FontWeight.bold : FontWeight.normal)),
          ),
          Text('${_fmt(fee)}원',
              style: TextStyle(
                  fontSize: 13,
                  color: isActive ? Colors.orange : Colors.grey.shade600,
                  fontWeight:
                      isActive ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

  Widget _priceRow(String label, int amount,
      {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 17 : 14,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text('${_fmt(amount)}원', style: style)
      ],
    );
  }
}

class _DistanceBadge extends StatelessWidget {
  final double distanceKm;
  const _DistanceBadge({required this.distanceKm});

  @override
  Widget build(BuildContext context) {
    final isLong = DeliveryFeeCalculator.isLongDistance(distanceKm);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isLong ? Colors.purple.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isLong ? Colors.purple.shade200 : Colors.blue.shade200),
      ),
      child: Text(
        '${distanceKm.toStringAsFixed(1)}km',
        style: TextStyle(
            fontSize: 12,
            color: isLong ? Colors.purple.shade700 : Colors.blue.shade700,
            fontWeight: FontWeight.w600),
      ),
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
