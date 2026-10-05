import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../../models/order_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/store_service.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _addressCtrl = TextEditingController();
  final _storeService = StoreService();
  bool _submitting = false;

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _placeOrder() async {
    if (_addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('배달 주소를 입력해주세요'), backgroundColor: Colors.red),
      );
      return;
    }

    final cart = context.read<CartProvider>();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || cart.store == null) return;

    setState(() => _submitting = true);

    try {
      final subtotal = cart.subtotal;
      final platformFee = (subtotal * 0.12).round();
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
        deliveryFee: 3500,
        riderPay: 3500,
        deliveryAddress: _addressCtrl.text.trim(),
        deliveryLat: 35.8175, // TODO: 실제 지오코딩
        deliveryLng: 127.1084,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      await _storeService.createOrder(order);
      cart.clear();

      if (mounted) {
        // 주문 완료 → 주문 내역으로 이동
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
        title: const Text('주문하기', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 배달 주소 입력
            _sectionTitle('📍 배달 주소'),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                hintText: '배달받을 주소를 입력해주세요',
                prefixIcon: const Icon(Icons.location_on, color: Colors.orange),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.orange),
                ),
              ),
              maxLines: 2,
            ),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(item.menu.name,
                                  style: const TextStyle(fontSize: 15)),
                            ),
                            Text('${item.quantity}개',
                                style: TextStyle(color: Colors.grey.shade600)),
                            const SizedBox(width: 12),
                            Text(
                              '${_fmt(item.menu.price * item.quantity)}원',
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                  _priceRow('배달비', cart.deliveryFee),
                  const Divider(height: 24),
                  _priceRow('최종 결제금액', cart.total, bold: true, color: Colors.orange),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '* 플랫폼 수수료 ${_fmt((cart.subtotal * 0.12).round())}원은 업체 부담입니다',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // 결제 방법 (현재는 가상 현금결제)
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('선택됨',
                        style: TextStyle(color: Colors.orange, fontSize: 12)),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _submitting ? null : _placeOrder,
            child: _submitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    '${_fmt(cart.total)}원 주문하기',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) =>
      Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));

  Widget _priceRow(String label, int amount, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 17 : 14,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text('${_fmt(amount)}원', style: style)],
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
