import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/store_model.dart';
import '../../models/menu_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/store_service.dart';

class StoreDetailScreen extends StatefulWidget {
  final StoreModel store;
  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final StoreService _storeService = StoreService();
  List<MenuModel> _menus = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  Future<void> _loadMenus() async {
    final menus = await _storeService.getMenus(widget.store.id);
    if (mounted) setState(() { _menus = menus; _loading = false; });
  }

  Future<void> _addToCart(MenuModel menu) async {
    final cart = context.read<CartProvider>();
    if (cart.isDifferentStore(widget.store)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('장바구니 초기화'),
          content: Text('다른 가게(${cart.store!.name})의 메뉴가 있습니다.\n새로 담으시겠어요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('초기화 후 담기'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      cart.clear();
    }
    cart.addItem(menu, widget.store);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${menu.name} 담았어요!'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // 헤더
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.orange, Color(0xFFFF7043)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.storefront, size: 80, color: Colors.white38),
                ),
              ),
            ),
          ),
          // 가게 정보
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.store.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Text('영업중',
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(widget.store.category,
                      style: TextStyle(color: Colors.grey.shade600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(widget.store.address,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoChip(Icons.delivery_dining, '배달비 3,500원'),
                        _infoChip(Icons.timer, '30~45분'),
                        _infoChip(Icons.phone, widget.store.phone),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 메뉴 헤더
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('메뉴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          // 메뉴 목록
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.orange)),
            )
          else if (_menus.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('등록된 메뉴가 없습니다', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _MenuCard(menu: _menus[i], onAdd: () => _addToCart(_menus[i])),
                childCount: _menus.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      // 장바구니 버튼
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
                  onPressed: () => Navigator.pushNamed(context, '/cart'),
                  child: Text(
                    '장바구니 보기 (${cart.itemCount}개)  |  ${_fmt(cart.total)}원',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.orange),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.orange)),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuModel menu;
  final VoidCallback onAdd;
  const _MenuCard({required this.menu, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.items
        .where((e) => e.menu.id == menu.id)
        .fold(0, (s, e) => s + e.quantity);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(menu.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (menu.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(menu.description,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  Text('${_fmt(menu.price)}원',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ),
            // 수량 조절 또는 담기 버튼
            if (qty == 0)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onAdd,
                child: const Text('담기'),
              )
            else
              Row(
                children: [
                  _circleBtn(Icons.remove, () => context.read<CartProvider>().removeItem(menu.id)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  _circleBtn(Icons.add, onAdd),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
