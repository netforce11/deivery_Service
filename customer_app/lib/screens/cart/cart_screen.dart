import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../order/order_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('장바구니', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          if (cart.itemCount > 0)
            TextButton(
              onPressed: () => showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('장바구니 비우기'),
                  content: const Text('모든 메뉴를 삭제하시겠어요?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () { cart.clear(); Navigator.pop(context); },
                      child: const Text('비우기'),
                    ),
                  ],
                ),
              ),
              child: const Text('비우기', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: cart.itemCount == 0
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('장바구니가 비어있어요', style: TextStyle(color: Colors.grey, fontSize: 16)),
                ],
              ),
            )
          : Column(
              children: [
                // 가게 정보
                if (cart.store != null)
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.storefront, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(cart.store!.name,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                const Divider(height: 1),
                // 아이템 목록
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: cart.items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final item = cart.items[i];
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.menu.name,
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text('${_fmt(item.menu.price)}원',
                                      style: const TextStyle(color: Colors.orange)),
                                ],
                              ),
                            ),
                            // 수량 조절
                            Row(
                              children: [
                                _circleBtn(Icons.remove, Colors.grey.shade300,
                                    () => cart.removeItem(item.menu.id)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('${item.quantity}',
                                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                ),
                                _circleBtn(Icons.add, Colors.orange,
                                    () => cart.addItem(item.menu, cart.store!)),
                              ],
                            ),
                            const SizedBox(width: 12),
                            // 소계
                            SizedBox(
                              width: 72,
                              child: Text(
                                '${_fmt(item.menu.price * item.quantity)}원',
                                textAlign: TextAlign.right,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                              onPressed: () => cart.deleteItem(item.menu.id),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // 금액 요약
                _PriceSummary(cart: cart),
              ],
            ),
      bottomNavigationBar: cart.itemCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OrderScreen()),
                  ),
                  child: Text(
                    '주문하기  ${_fmt(cart.total)}원',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _circleBtn(IconData icon, Color bg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30, height: 30,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: bg == Colors.orange ? Colors.white : Colors.grey.shade700),
      ),
    );
  }
}

class _PriceSummary extends StatelessWidget {
  final CartProvider cart;
  const _PriceSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _row('음식 금액', '${_fmt(cart.subtotal)}원'),
          const SizedBox(height: 8),
          _row('배달비', '${_fmt(cart.deliveryFee)}원'),
          const Divider(height: 24),
          _row('합계', '${_fmt(cart.total)}원', bold: true, color: Colors.orange),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      fontSize: bold ? 17 : 14,
      color: color,
    );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
