import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/store_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/store_service.dart';
import '../../services/auth_service.dart';
import 'store_detail_screen.dart';
import '../order/order_history_screen.dart';

class StoreListScreen extends StatefulWidget {
  const StoreListScreen({super.key});

  @override
  State<StoreListScreen> createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  final StoreService _storeService = StoreService();
  final AuthService _authService = AuthService();
  String _selectedCategory = '전체';

  static const List<String> _categories = ['전체', '한식', '중식', '일식', '양식', '치킨', '피자', '분식'];

  @override
  void initState() {
    super.initState();
    _storeService.seedSampleData(); // 샘플 데이터 최초 1회만 추가
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('🚀 배달 서비스', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: '주문 내역',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: '로그아웃',
            onPressed: () async {
              await _authService.signOut();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 카테고리 필터
          _buildCategoryBar(),
          // 가게 목록
          Expanded(
            child: StreamBuilder<List<StoreModel>>(
              stream: _storeService.watchStores(category: _selectedCategory),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Colors.orange));
                }
                if (snap.hasError) {
                  return Center(child: Text('오류: ${snap.error}'));
                }
                final stores = snap.data ?? [];
                if (stores.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_mall_directory_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('가게가 없습니다', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: stores.length,
                  itemBuilder: (_, i) => _StoreCard(store: stores[i]),
                );
              },
            ),
          ),
        ],
      ),
      // 장바구니 FAB
      floatingActionButton: cart.itemCount > 0
          ? FloatingActionButton.extended(
              backgroundColor: Colors.orange,
              onPressed: () => Navigator.pushNamed(context, '/cart'),
              icon: const Icon(Icons.shopping_cart),
              label: Text('장바구니 ${cart.itemCount}개  |  ${_fmt(cart.total)}원'),
            )
          : null,
    );
  }

  Widget _buildCategoryBar() {
    return Container(
      height: 48,
      color: Colors.orange,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: _categories.length,
        itemBuilder: (_, i) {
          final cat = _categories[i];
          final selected = cat == _selectedCategory;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: selected ? Colors.white : Colors.orange.shade700,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                cat,
                style: TextStyle(
                  color: selected ? Colors.orange : Colors.white,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final StoreModel store;
  const _StoreCard({required this.store});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: store.isOpen
            ? () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StoreDetailScreen(store: store)),
                )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // 아이콘 영역
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.storefront, size: 32, color: Colors.orange),
              ),
              const SizedBox(width: 16),
              // 정보 영역
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(store.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        _statusBadge(store.isOpen),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(store.category,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text(store.address,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(bool isOpen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: isOpen ? Colors.green : Colors.grey.shade300),
      ),
      child: Text(
        isOpen ? '영업중' : '준비중',
        style: TextStyle(
          color: isOpen ? Colors.green : Colors.grey,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
