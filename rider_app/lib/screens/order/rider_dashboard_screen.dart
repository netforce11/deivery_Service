import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../models/order_model.dart';
import '../../services/auth_service.dart';
import '../../services/order_service.dart';
import '../../services/location_service.dart';
import '../../services/routing_service.dart';
import '../earnings/earnings_screen.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen>
    with SingleTickerProviderStateMixin {
  final _orderService = OrderService();
  final _authService = AuthService();
  final _locationService = LocationService();
  late TabController _tabController;
  String? _riderId;

  // 필터: 0=전체, 1=단거리, 2=장거리
  int _filterIndex = 0;
  // 장거리 전용 모드
  bool _longDistanceOnly = false;

  static const _filterLabels = ['전체', '단거리', '장거리'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _riderId = FirebaseAuth.instance.currentUser?.uid;
    _locationService.requestPermission();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _locationService.dispose();
    super.dispose();
  }

  List<OrderModel> _applyFilter(List<OrderModel> orders) {
    if (_longDistanceOnly || _filterIndex == 2) {
      return orders.where((o) => o.isLongDistance).toList();
    }
    if (_filterIndex == 1) {
      return orders.where((o) => !o.isLongDistance).toList();
    }
    return orders;
  }

  void _showLongDistanceModeDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.route, color: Colors.purple.shade600),
            const SizedBox(width: 8),
            const Text('장거리 전용 모드'),
          ],
        ),
        content: Text(
          _longDistanceOnly
              ? '장거리 전용 모드를 끄면 모든 배달 요청을 수신합니다.'
              : '장거리 전용 모드를 켜면 7km 초과 배달 요청만 수신합니다.\n\n장거리 배달은 더 높은 배달비(8,000원~)를 제공합니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _longDistanceOnly ? Colors.grey : Colors.purple.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, !_longDistanceOnly),
            child: Text(_longDistanceOnly ? '모드 끄기' : '모드 켜기'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _longDistanceOnly = result;
        if (result) _filterIndex = 0; // 장거리 전용 모드 켜면 필터 초기화
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('라이더 대시보드',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(
              _longDistanceOnly ? '🟣 장거리 전용 모드' : '배달 관리',
              style: TextStyle(
                fontSize: 12,
                color: _longDistanceOnly
                    ? Colors.purple.shade100
                    : Colors.white70,
              ),
            ),
          ],
        ),
        actions: [
          // 장거리 전용 모드 토글 버튼
          IconButton(
            icon: Icon(
              Icons.route,
              color: _longDistanceOnly ? Colors.purple.shade100 : Colors.white,
            ),
            tooltip: '장거리 전용 모드',
            onPressed: _showLongDistanceModeDialog,
          ),
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: '수익 관리',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EarningsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              _locationService.stopTracking();
              _authService.signOut();
            },
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
          // 탭 1: 배달 가능한 주문
          StreamBuilder<List<OrderModel>>(
            stream: _orderService.watchAvailableOrders(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.green));
              }
              final allOrders = snap.data ?? [];
              final orders = _applyFilter(allOrders);

              return Column(
                children: [
                  // 장거리 전용 모드 배너
                  if (_longDistanceOnly)
                    Container(
                      width: double.infinity,
                      color: Colors.purple.shade50,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.route,
                              size: 16, color: Colors.purple.shade600),
                          const SizedBox(width: 8),
                          Text(
                            '장거리 전용 모드 활성화 — 7km 초과 배달만 표시',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),

                  // 필터 칩 (장거리 전용 모드가 아닐 때만 표시)
                  if (!_longDistanceOnly)
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        children: List.generate(
                          _filterLabels.length,
                          (i) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_filterLabels[i]),
                              selected: _filterIndex == i,
                              onSelected: (_) =>
                                  setState(() => _filterIndex = i),
                              selectedColor: i == 2
                                  ? Colors.purple.shade100
                                  : Colors.green.shade100,
                              labelStyle: TextStyle(
                                color: _filterIndex == i
                                    ? (i == 2
                                        ? Colors.purple.shade700
                                        : Colors.green.shade700)
                                    : Colors.grey.shade600,
                                fontWeight: _filterIndex == i
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 주문 목록
                  Expanded(
                    child: orders.isEmpty
                        ? _emptyState(
                            _filterIndex == 2 || _longDistanceOnly
                                ? '장거리 배달 요청이 없어요'
                                : _filterIndex == 1
                                    ? '단거리 배달 요청이 없어요'
                                    : '대기 중인 배달이 없어요',
                            Icons.delivery_dining_outlined,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(12),
                            itemCount: orders.length,
                            itemBuilder: (_, i) => _AvailableOrderCard(
                              order: orders[i],
                              riderLat: _locationService.currentLat,
                              riderLng: _locationService.currentLng,
                              onAccept: () async {
                                await _orderService.acceptDelivery(
                                    orders[i].id, _riderId!);
                                _locationService.startTracking(orders[i].id);
                                if (mounted) {
                                  _tabController.animateTo(1);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('배달을 수락했어요! 위치 추적 시작 🚴'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                  ),
                ],
              );
            },
          ),

          // 탭 2: 내 배달
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
                  onPickup: () async {
                    await _orderService.pickupOrder(orders[i].id);
                    _locationService.startTracking(orders[i].id);
                  },
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
      _locationService.stopTracking();
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

// ── 배달 가능 주문 카드 (탭하면 상세 바텀시트) ──────────────────────────────────
class _AvailableOrderCard extends StatelessWidget {
  final OrderModel order;
  final double? riderLat;
  final double? riderLng;
  final VoidCallback onAccept;

  const _AvailableOrderCard({
    required this.order,
    required this.riderLat,
    required this.riderLng,
    required this.onAccept,
  });

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrderDetailSheet(
        order: order,
        riderLat: riderLat,
        riderLng: riderLng,
        onAccept: () {
          Navigator.pop(context);
          onAccept();
        },
        onReject: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 라이더 위치가 있으면 거리 계산
    double? distKm;
    int? etaMin;
    if (riderLat != null &&
        riderLng != null &&
        order.deliveryLat != 0 &&
        order.deliveryLng != 0) {
      distKm = RoutingService.distanceKm(
        LatLng(riderLat!, riderLng!),
        LatLng(order.deliveryLat, order.deliveryLng),
      );
      etaMin = RoutingService.estimatedMinutes(distKm);
    }

    return GestureDetector(
      onTap: () => _showDetail(context),
      child: Card(
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
                        if (order.isLongDistance) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.purple.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.purple.shade200),
                            ),
                            child: Text('장거리',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.purple.shade700,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ],
                    ),
                    Row(
                      children: [
                        Text(_timeStr(order.createdAt),
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                        const SizedBox(width: 8),
                        // 상세보기 힌트
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('상세보기',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade500)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• ${item.name} ${item.quantity}개',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13)),
                    )),
                const Divider(height: 16),
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 거리/예상 시간
                    if (distKm != null)
                      Row(
                        children: [
                          Icon(Icons.directions_bike,
                              size: 14, color: Colors.blue.shade400),
                          const SizedBox(width: 4),
                          Text(
                            '${distKm.toStringAsFixed(1)}km · 약 ${etaMin}분',
                            style: TextStyle(
                                fontSize: 12, color: Colors.blue.shade600),
                          ),
                        ],
                      )
                    else
                      const SizedBox.shrink(),
                    // 수락 버튼
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
      ),
    );
  }
}

// ── 주문 상세 바텀시트 (거절 포함) ────────────────────────────────────────────
class _OrderDetailSheet extends StatefulWidget {
  final OrderModel order;
  final double? riderLat;
  final double? riderLng;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _OrderDetailSheet({
    required this.order,
    required this.riderLat,
    required this.riderLng,
    required this.onAccept,
    required this.onReject,
  });

  @override
  State<_OrderDetailSheet> createState() => _OrderDetailSheetState();
}

class _OrderDetailSheetState extends State<_OrderDetailSheet> {
  List<LatLng> _route = [];
  bool _loadingRoute = false;

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    if (widget.riderLat == null ||
        widget.riderLng == null ||
        widget.order.deliveryLat == 0) return;
    setState(() => _loadingRoute = true);
    final route = await RoutingService.getRoute(
      LatLng(widget.riderLat!, widget.riderLng!),
      LatLng(widget.order.deliveryLat, widget.order.deliveryLng),
    );
    if (mounted) setState(() { _route = route; _loadingRoute = false; });
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    double? distKm;
    int? etaMin;
    if (widget.riderLat != null && widget.riderLng != null && order.deliveryLat != 0) {
      distKm = RoutingService.distanceKm(
        LatLng(widget.riderLat!, widget.riderLng!),
        LatLng(order.deliveryLat, order.deliveryLng),
      );
      etaMin = RoutingService.estimatedMinutes(distKm);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 드래그 핸들
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // 지도 미리보기 (라이더 위치 → 배달지)
          if (order.deliveryLat != 0)
            SizedBox(
              height: 200,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: Stack(
                  children: [
                    FlutterMap(
                      options: MapOptions(
                        initialCenter: LatLng(order.deliveryLat, order.deliveryLng),
                        initialZoom: 14,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.delivery.rider',
                        ),
                        // 경로 폴리라인
                        if (_route.isNotEmpty)
                          PolylineLayer(polylines: [
                            Polyline(
                              points: _route,
                              color: Colors.blue,
                              strokeWidth: 4,
                            ),
                          ]),
                        MarkerLayer(markers: [
                          // 배달지
                          Marker(
                            point: LatLng(order.deliveryLat, order.deliveryLng),
                            child: const Icon(Icons.location_on,
                                color: Colors.red, size: 32),
                          ),
                          // 라이더 현재 위치
                          if (widget.riderLat != null && widget.riderLng != null)
                            Marker(
                              point: LatLng(widget.riderLat!, widget.riderLng!),
                              child: const Icon(Icons.delivery_dining,
                                  color: Colors.green, size: 28),
                            ),
                        ]),
                      ],
                    ),
                    if (_loadingRoute)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.blue),
                      ),
                  ],
                ),
              ),
            ),

          // 상세 정보
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 가게명 + 시간
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, color: Colors.green.shade600, size: 18),
                        const SizedBox(width: 6),
                        Text(order.storeName,
                            style: const TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Text(_timeStr(order.createdAt),
                        style: TextStyle(
                            color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ),
                const SizedBox(height: 12),

                // 거리 / 예상 시간 / 배달료 정보 행
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _infoCol(Icons.route, '거리',
                          distKm != null ? '${distKm.toStringAsFixed(1)}km' : '-'),
                      _divider(),
                      _infoCol(Icons.schedule, '예상 시간',
                          etaMin != null ? '약 ${etaMin}분' : '-'),
                      _divider(),
                      _infoCol(
                        order.isLongDistance ? Icons.workspace_premium : Icons.payments,
                        '배달료',
                        '${_fmtFee(order.riderPay)}원',
                        valueColor: order.isLongDistance
                            ? Colors.purple.shade700
                            : Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // 주문 메뉴
                Text('주문 내역',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        children: [
                          const Text('• ', style: TextStyle(color: Colors.grey)),
                          Text('${item.name} ',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade700)),
                          Text('${item.quantity}개',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey.shade500)),
                        ],
                      ),
                    )),
                const SizedBox(height: 6),

                // 배달 주소
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(order.deliveryAddress,
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 2),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 수락 / 거절 버튼
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: widget.onReject,
                        child: const Text('거절',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        onPressed: widget.onAccept,
                        child: const Text('배달 수락 🚴',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _infoCol(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: Colors.green.shade600),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: valueColor ?? Colors.grey.shade800)),
      ],
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 36, color: Colors.green.shade100);
}

// ── 내 배달 카드 (경로 지도 포함) ─────────────────────────────────────────────
class _MyOrderCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback onPickup;
  final VoidCallback onComplete;

  const _MyOrderCard(
      {required this.order, required this.onPickup, required this.onComplete});

  @override
  State<_MyOrderCard> createState() => _MyOrderCardState();
}

class _MyOrderCardState extends State<_MyOrderCard> {
  List<LatLng> _route = [];

  @override
  void initState() {
    super.initState();
    _loadRoute();
  }

  Future<void> _loadRoute() async {
    final o = widget.order;
    if (o.riderLat == null || o.riderLng == null || o.deliveryLat == 0) return;
    final route = await RoutingService.getRoute(
      LatLng(o.riderLat!, o.riderLng!),
      LatLng(o.deliveryLat, o.deliveryLng),
    );
    if (mounted) setState(() => _route = route);
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final isAssigned = order.status == 'assigned';
    final isPickedUp = order.status == 'picked_up';
    final hasRiderPos = order.riderLat != null && order.riderLng != null;

    // 남은 거리
    double? distKm;
    int? etaMin;
    if (hasRiderPos && order.deliveryLat != 0) {
      distKm = RoutingService.distanceKm(
        LatLng(order.riderLat!, order.riderLng!),
        LatLng(order.deliveryLat, order.deliveryLng),
      );
      etaMin = RoutingService.estimatedMinutes(distKm);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 지도 (경로 포함)
          if (hasRiderPos)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: SizedBox(
                height: 200,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter:
                        LatLng(order.riderLat!, order.riderLng!),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.delivery.rider',
                    ),
                    // 경로 폴리라인
                    if (_route.isNotEmpty)
                      PolylineLayer(polylines: [
                        Polyline(
                          points: _route,
                          color: Colors.blue.shade600,
                          strokeWidth: 4,
                        ),
                      ]),
                    MarkerLayer(markers: [
                      // 라이더
                      Marker(
                        point: LatLng(order.riderLat!, order.riderLng!),
                        child: const Icon(Icons.delivery_dining,
                            color: Colors.green, size: 32),
                      ),
                      // 배달지
                      if (order.deliveryLat != 0 && order.deliveryLng != 0)
                        Marker(
                          point: LatLng(order.deliveryLat, order.deliveryLng),
                          child: const Icon(Icons.location_on,
                              color: Colors.red, size: 32),
                        ),
                    ]),
                  ],
                ),
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store,
                            size: 16, color: Colors.green.shade600),
                        const SizedBox(width: 6),
                        Text(order.storeName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
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

                // 거리 / 예상 도착 시간
                if (distKm != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.route,
                            size: 14, color: Colors.blue.shade600),
                        const SizedBox(width: 4),
                        Text(
                          '배달지까지 ${distKm.toStringAsFixed(1)}km · 약 ${etaMin}분',
                          style: TextStyle(
                              fontSize: 12, color: Colors.blue.shade700),
                        ),
                      ],
                    ),
                  ),
                ],

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
                const SizedBox(height: 10),

                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text('• ${item.name} ${item.quantity}개',
                          style: TextStyle(
                              color: Colors.grey.shade700, fontSize: 13)),
                    )),
                const Divider(height: 16),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(order.deliveryAddress,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12),
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
                    onPressed: isAssigned
                        ? widget.onPickup
                        : (isPickedUp ? widget.onComplete : null),
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
        ],
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
          child: Icon(Icons.check,
              size: 14,
              color: active ? Colors.white : Colors.grey.shade400),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10,
                color:
                    active ? Colors.green.shade600 : Colors.grey.shade400)),
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

String _fmtFee(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

String _timeStr(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
