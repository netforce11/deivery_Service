import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';
import '../../models/store_model.dart';

class SettlementScreen extends StatefulWidget {
  final StoreModel store;
  const SettlementScreen({super.key, required this.store});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Stream<List<OrderModel>> _deliveredOrders() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _db
        .collection('orders')
        .where('storeId', isEqualTo: widget.store.id)
        .where('status', isEqualTo: 'delivered')
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => OrderModel.fromMap(d.data(), d.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: const Text('정산 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.indigo.shade200,
          tabs: const [
            Tab(text: '이번 달 정산'),
            Tab(text: '주문 내역'),
          ],
        ),
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _deliveredOrders(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.indigo));
          }
          final orders = snap.data ?? [];
          return TabBarView(
            controller: _tabController,
            children: [
              _SummaryTab(orders: orders),
              _HistoryTab(orders: orders),
            ],
          );
        },
      ),
    );
  }
}

// ── 이번 달 정산 요약 탭 ─────────────────────────────────────────────────────
class _SummaryTab extends StatelessWidget {
  final List<OrderModel> orders;
  const _SummaryTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    final totalSales = orders.fold(0, (s, o) => s + o.totalPrice);
    final totalFee = orders.fold(0, (s, o) => s + o.platformFee);
    final netAmount = totalSales - totalFee;
    final count = orders.length;

    // 일별 매출 집계 (이번 달)
    final now = DateTime.now();
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final dailySales = List<int>.filled(daysInMonth, 0);
    for (final o in orders) {
      final day = o.createdAt.day - 1;
      if (day >= 0 && day < daysInMonth) {
        dailySales[day] += o.totalPrice;
      }
    }
    final maxSale = dailySales.isEmpty
        ? 1
        : dailySales.reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 이번 달 헤더
          Text(
            '${now.year}년 ${now.month}월 정산',
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo),
          ),
          const SizedBox(height: 16),

          // 요약 카드
          _SummaryCard(
            totalSales: totalSales,
            totalFee: totalFee,
            netAmount: netAmount,
            count: count,
          ),
          const SizedBox(height: 24),

          // 일별 매출 차트
          const Text('일별 매출',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _DailyBarChart(
            dailySales: dailySales,
            maxSale: maxSale == 0 ? 1 : maxSale,
            today: now.day,
          ),
          const SizedBox(height: 24),

          // 수수료 안내
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigo.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16, color: Colors.indigo.shade400),
                    const SizedBox(width: 6),
                    Text('수수료 안내',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade700)),
                  ],
                ),
                const SizedBox(height: 8),
                _feeRow('플랫폼 수수료', '음식값의 12%'),
                _feeRow('배달비', '고객 부담 (3,500원)'),
                _feeRow('정산 주기', '매월 말일 기준'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _feeRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.indigo.shade600, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: Colors.indigo.shade800,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── 요약 카드 ────────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final int totalSales;
  final int totalFee;
  final int netAmount;
  final int count;

  const _SummaryCard({
    required this.totalSales,
    required this.totalFee,
    required this.netAmount,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.indigo.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('실수령액',
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('$count건',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${_fmt(netAmount)}원',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -1)),
          const SizedBox(height: 20),
          const Divider(color: Colors.white24),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _statItem(
                    '총 매출', '${_fmt(totalSales)}원', Colors.white),
              ),
              Container(width: 1, height: 36, color: Colors.white24),
              Expanded(
                child: _statItem(
                    '플랫폼 수수료', '-${_fmt(totalFee)}원', Colors.red.shade200),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── 일별 막대 차트 ───────────────────────────────────────────────────────────
class _DailyBarChart extends StatelessWidget {
  final List<int> dailySales;
  final int maxSale;
  final int today;

  const _DailyBarChart({
    required this.dailySales,
    required this.maxSale,
    required this.today,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(dailySales.length, (i) {
                final ratio =
                    maxSale > 0 ? dailySales[i] / maxSale : 0.0;
                final isToday = i + 1 == today;
                final hasData = dailySales[i] > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (hasData)
                          Container(
                            height: 110 * ratio + 4,
                            decoration: BoxDecoration(
                              color: isToday
                                  ? Colors.indigo
                                  : Colors.indigo.shade200,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(3)),
                            ),
                          )
                        else
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          // X축 레이블 (5일 간격)
          Row(
            children: List.generate(dailySales.length, (i) {
              final showLabel = (i + 1) % 5 == 0 || i == 0;
              return Expanded(
                child: Text(
                  showLabel ? '${i + 1}' : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      color: i + 1 == today
                          ? Colors.indigo
                          : Colors.grey.shade400),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // 최고 매출 안내
          if (maxSale > 0)
            Text('최고 ${_fmt(maxSale)}원',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

// ── 주문 내역 탭 ──────────────────────────────────────────────────────────────
class _HistoryTab extends StatelessWidget {
  final List<OrderModel> orders;
  const _HistoryTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('이번 달 완료된 주문이 없어요',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: orders.length,
      itemBuilder: (_, i) => _OrderRow(order: orders[i]),
    );
  }
}

class _OrderRow extends StatelessWidget {
  final OrderModel order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context) {
    final netAmount = order.totalPrice - order.platformFee;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 날짜
            SizedBox(
              width: 36,
              child: Column(
                children: [
                  Text(
                    '${order.createdAt.day}',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _monthLabel(order.createdAt.month),
                    style: TextStyle(
                        fontSize: 10, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const VerticalDivider(width: 1),
            const SizedBox(width: 12),
            // 주문 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.items.map((e) => e.name).join(', '),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '매출 ${_fmt(order.totalPrice)}원  수수료 -${_fmt(order.platformFee)}원',
                    style:
                        TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            // 실수령
            Text(
              '+${_fmt(netAmount)}원',
              style: const TextStyle(
                  color: Colors.indigo,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  String _monthLabel(int month) {
    const months = ['Jan','Feb','Mar','Apr','May','Jun',
                    'Jul','Aug','Sep','Oct','Nov','Dec'];
    return months[month - 1];
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
