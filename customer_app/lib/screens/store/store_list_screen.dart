import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/store_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/store_service.dart';
import '../../services/auth_service.dart';
import '../../services/customer_location_service.dart';
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
  final _locSvc = CustomerLocationService.instance;

  String _selectedCategory = '전체';
  double? _userLat;
  double? _userLng;
  bool _locLoading = true;

  static const double _eventRadiusKm = 5.0; // 이벤트 노출 반경

  static const List<String> _categories = ['전체', '한식', '중식', '일식', '양식', '치킨', '피자', '분식'];

  @override
  void initState() {
    super.initState();
    _storeService.seedSampleData();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    final pos = await _locSvc.getCurrentPosition();
    if (mounted) {
      setState(() {
        _userLat = pos?.latitude;
        _userLng = pos?.longitude;
        _locLoading = false;
      });
    }
  }

  /// 가게 목록을 세 그룹으로 분류 후 합침:
  /// 1) 5km 이내 이벤트 중 (거리순)
  /// 2) 5km 초과 이벤트 중 (숨김 — 상단 배너 미노출)
  /// 3) 일반 가게 (위치 있으면 거리순, 없으면 서버 순)
  ({
    List<StoreModel> nearbyEvents,
    List<StoreModel> normalStores,
  }) _classify(List<StoreModel> stores) {
    List<StoreModel> nearbyEvents = [];
    List<StoreModel> normalStores = [];

    for (final s in stores) {
      if (!s.isOpen) {
        normalStores.add(s);
        continue;
      }
      if (s.activeEventBadge != null) {
        final dist = CustomerLocationService.distanceKm(
            _userLat ?? 0, _userLng ?? 0, s.lat, s.lng);
        // 위치 모를 때는 이벤트 가게 모두 상단 노출 (dist 0 → 무조건 포함)
        final withinRadius = _userLat == null || dist <= _eventRadiusKm;
        if (withinRadius) {
          nearbyEvents.add(s);
        } else {
          normalStores.add(s); // 5km 초과 이벤트 → 일반 목록에 포함
        }
      } else {
        normalStores.add(s);
      }
    }

    // 이벤트 가게: 거리 가까운 순
    if (_userLat != null) {
      nearbyEvents.sort((a, b) {
        final da = CustomerLocationService.distanceKm(_userLat!, _userLng!, a.lat, a.lng);
        final db = CustomerLocationService.distanceKm(_userLat!, _userLng!, b.lat, b.lng);
        return da.compareTo(db);
      });
      // 일반 가게: 영업중 우선, 같으면 거리순
      normalStores.sort((a, b) {
        if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
        final da = CustomerLocationService.distanceKm(_userLat!, _userLng!, a.lat, a.lng);
        final db = CustomerLocationService.distanceKm(_userLat!, _userLng!, b.lat, b.lng);
        return da.compareTo(db);
      });
    }

    return (nearbyEvents: nearbyEvents, normalStores: normalStores);
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
          // 위치 감지 상태 바
          if (_locLoading)
            LinearProgressIndicator(
              color: Colors.orange,
              backgroundColor: Colors.orange.shade100,
              minHeight: 2,
            )
          else if (_userLat == null)
            _LocationPermissionBanner(onRetry: _fetchLocation),

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

                final classified = _classify(stores);

                return ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    // ── 5km 이내 이벤트 중인 가게 (상단 가로 스크롤) ────
                    if (classified.nearbyEvents.isNotEmpty) ...[
                      _EventBanner(
                        stores: classified.nearbyEvents,
                        userLat: _userLat,
                        userLng: _userLng,
                      ),
                      const SizedBox(height: 4),
                    ],
                    // ── 일반 가게 (거리순) ───────────────────────────────
                    ...classified.normalStores.map((s) => _StoreCard(
                          store: s,
                          userLat: _userLat,
                          userLng: _userLng,
                        )),
                  ],
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

// ── 위치 권한 안내 배너 ────────────────────────────────────────────────────────
class _LocationPermissionBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _LocationPermissionBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.orange.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '위치 권한이 없어 거리 정보가 제한됩니다.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              foregroundColor: Colors.orange,
            ),
            child: const Text('재시도', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

// ── 일반 가게 카드 ────────────────────────────────────────────────────────────
class _StoreCard extends StatelessWidget {
  final StoreModel store;
  final double? userLat;
  final double? userLng;
  const _StoreCard({required this.store, this.userLat, this.userLng});

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
                    if (userLat != null && userLng != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.near_me, size: 11, color: Colors.blue.shade300),
                          const SizedBox(width: 2),
                          Text(
                            CustomerLocationService.distanceLabel(
                              CustomerLocationService.distanceKm(
                                  userLat!, userLng!, store.lat, store.lng),
                            ),
                            style: TextStyle(fontSize: 11, color: Colors.blue.shade400),
                          ),
                        ],
                      ),
                    ],
                    if (store.reviewCount > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 2),
                          Text(
                            '${store.avgRating.toStringAsFixed(1)}  (${store.reviewCount})',
                            style: const TextStyle(
                                fontSize: 12, color: Colors.amber,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                    // 이벤트 뱃지
                    if (store.activeEventBadge != null) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _eventBadgeColor(store.activeEventType)
                              .withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _eventBadgeColor(store.activeEventType)
                                  .withOpacity(0.5)),
                        ),
                        child: Text(
                          store.activeEventBadge!,
                          style: TextStyle(
                              fontSize: 11,
                              color: _eventBadgeColor(store.activeEventType),
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
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

  Color _eventBadgeColor(String? type) {
    switch (type) {
      case 'flashSale':     return Colors.red;
      case 'luckyOrder':    return Colors.green;
      case 'challenge':     return Colors.amber.shade700;
      case 'welcomeCoupon': return Colors.purple;
      default:              return Colors.grey;
    }
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

// ── 이벤트 중인 가게 가로 스크롤 배너 ─────────────────────────────────────────

class _EventBanner extends StatelessWidget {
  final List<StoreModel> stores;
  final double? userLat;
  final double? userLng;
  const _EventBanner({required this.stores, this.userLat, this.userLng});

  Color _badgeColor(String? type) {
    switch (type) {
      case 'flashSale':     return Colors.red;
      case 'luckyOrder':    return Colors.green.shade600;
      case 'challenge':     return Colors.amber.shade700;
      case 'welcomeCoupon': return Colors.purple;
      default:              return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            children: [
              const Text('🔥 ',style: TextStyle(fontSize: 16)),
              const Text('지금 이벤트 중',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${stores.length}곳',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.red.shade600,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: stores.length,
            itemBuilder: (_, i) {
              final store = stores[i];
              final color = _badgeColor(store.activeEventType);
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => StoreDetailScreen(store: store)),
                ),
                child: Container(
                  width: 140,
                  margin: EdgeInsets.only(
                      left: i == 0 ? 4 : 6, right: i == stores.length - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: color.withOpacity(0.4), width: 1.5),
                    boxShadow: [
                      BoxShadow(
                          color: color.withOpacity(0.12),
                          blurRadius: 8,
                          spreadRadius: 1)
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 이벤트 뱃지
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          store.activeEventBadge!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        store.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        store.category,
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11),
                      ),
                      if (userLat != null && userLng != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.near_me, size: 10, color: Colors.blue.shade300),
                            const SizedBox(width: 2),
                            Text(
                              CustomerLocationService.distanceLabel(
                                CustomerLocationService.distanceKm(
                                    userLat!, userLng!, store.lat, store.lng),
                              ),
                              style: TextStyle(fontSize: 10, color: Colors.blue.shade400),
                            ),
                          ],
                        ),
                      ],
                      if (store.reviewCount > 0) ...[
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star,
                                color: Colors.amber, size: 12),
                            const SizedBox(width: 2),
                            Text(
                              store.avgRating.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 20),
      ],
    );
  }
}
