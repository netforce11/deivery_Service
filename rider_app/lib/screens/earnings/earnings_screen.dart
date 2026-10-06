import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/order_model.dart';

class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _db = FirebaseFirestore.instance;
  final _riderId = FirebaseAuth.instance.currentUser?.uid ?? '';

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

  Stream<List<OrderModel>> _monthlyDeliveries() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    return _db
        .collection('orders')
        .where('riderId', isEqualTo: _riderId)
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

  Stream<List<OrderModel>> _allDeliveries() {
    return _db
        .collection('orders')
        .where('riderId', isEqualTo: _riderId)
        .where('status', isEqualTo: 'delivered')
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
      backgroundColor: const Color(0xFFF0FFF4),
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        title: const Text('수익 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.green.shade200,
          tabs: const [
            Tab(text: '이번 달 수익'),
            Tab(text: '전체 내역'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 이번 달 탭
          StreamBuilder<List<OrderModel>>(
            stream: _monthlyDeliveries(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.green));
              }
              return _MonthlySummary(orders: snap.data ?? []);
            },
          ),
          // 전체 내역 탭
          StreamBuilder<List<OrderModel>>(
            stream: _allDeliveries(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.green));
              }
              return _AllHistoryTab(orders: snap.data ?? []);
            },
          ),
        ],
      ),
    );
  }
}

// ── 이번 달 수익 요약 ─────────────────────────────────────────────────────────
class _MonthlySummary extends StatelessWidget {
  final List<OrderModel> orders;
  const _MonthlySummary({required this.orders});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalEarnings = orders.fold(0, (s, o) => s + o.riderPay);
    final count = orders.length;

    // 일별 수익 집계
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final dailyEarnings = List<int>.filled(daysInMonth, 0);
    final dailyCount = List<int>.filled(daysInMonth, 0);
    for (final o in orders) {
      final day = o.createdAt.day - 1;
      if (day >= 0 && day < daysInMonth) {
        dailyEarnings[day] += o.riderPay;
        dailyCount[day]++;
      }
    }
    final maxEarning = dailyEarnings.isEmpty
        ? 1
        : dailyEarnings.reduce((a, b) => a > b ? a : b);

    // 오늘 수익
    final todayEarning = now.day <= daysInMonth ? dailyEarnings[now.day - 1] : 0;
    final todayCount = now.day <= daysInMonth ? dailyCount[now.day - 1] : 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${now.year}년 ${now.month}월 수익',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green.shade700),
          ),
          const SizedBox(height: 16),

          // 메인 수익 카드
          _EarningsCard(
            totalEarnings: totalEarnings,
            count: count,
            todayEarning: todayEarning,
            todayCount: todayCount,
          ),
          const SizedBox(height: 24),

          // 일별 수익 차트
          Text('일별 수익',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 12),
          _RiderBarChart(
            dailyEarnings: dailyEarnings,
            dailyCount: dailyCount,
            maxEarning: maxEarning == 0 ? 1 : maxEarning,
            today: now.day,
          ),
          const SizedBox(height: 24),

          // 일별 상세 리스트 (배달이 있는 날만)
          Text('날짜별 내역',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          ...List.generate(daysInMonth, (i) {
            if (dailyEarnings[i] == 0) return const SizedBox.shrink();
            final date = DateTime(now.year, now.month, i + 1);
            return _DayRow(
              date: date,
              earning: dailyEarnings[i],
              count: dailyCount[i],
              isToday: i + 1 == now.day,
            );
          }).reversed,
        ],
      ),
    );
  }
}

// ── 수익 메인 카드 ───────────────────────────────────────────────────────────
class _EarningsCard extends StatelessWidget {
  final int totalEarnings;
  final int count;
  final int todayEarning;
  final int todayCount;

  const _EarningsCard({
    required this.totalEarnings,
    required this.count,
    required this.todayEarning,
    required this.todayCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade700, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.green.withOpacity(0.3),
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
              const Text('이번 달 총 수익',
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
          Text('${_fmt(totalEarnings)}원',
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
                  Icons.today,
                  '오늘 수익',
                  '${_fmt(todayEarning)}원',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _statItem(
                  Icons.delivery_dining,
                  '오늘 배달',
                  '$todayCount건',
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _statItem(
                  Icons.monetization_on,
                  '건당 평균',
                  count > 0
                      ? '${_fmt(totalEarnings ~/ count)}원'
                      : '-',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 4),
        Text(label,
            style: const TextStyle(color: Colors.white60, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

// ── 라이더 일별 막대 차트 ────────────────────────────────────────────────────
class _RiderBarChart extends StatelessWidget {
  final List<int> dailyEarnings;
  final List<int> dailyCount;
  final int maxEarning;
  final int today;

  const _RiderBarChart({
    required this.dailyEarnings,
    required this.dailyCount,
    required this.maxEarning,
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
              children: List.generate(dailyEarnings.length, (i) {
                final ratio = maxEarning > 0
                    ? dailyEarnings[i] / maxEarning
                    : 0.0;
                final isToday = i + 1 == today;
                final hasData = dailyEarnings[i] > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: hasData
                          ? '${i + 1}일: ${_fmt(dailyEarnings[i])}원 (${dailyCount[i]}건)'
                          : '',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (hasData)
                            Container(
                              height: 110 * ratio + 4,
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Colors.green.shade600
                                    : Colors.green.shade200,
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
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: List.generate(dailyEarnings.length, (i) {
              final showLabel = (i + 1) % 5 == 0 || i == 0;
              return Expanded(
                child: Text(
                  showLabel ? '${i + 1}' : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9,
                      color: i + 1 == today
                          ? Colors.green.shade600
                          : Colors.grey.shade400),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── 날짜별 행 ────────────────────────────────────────────────────────────────
class _DayRow extends StatelessWidget {
  final DateTime date;
  final int earning;
  final int count;
  final bool isToday;

  const _DayRow({
    required this.date,
    required this.earning,
    required this.count,
    required this.isToday,
  });

  @override
  Widget build(BuildContext context) {
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    final weekday = weekdays[date.weekday - 1];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isToday ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: isToday
            ? Border.all(color: Colors.green.shade200)
            : null,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 1)),
        ],
      ),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Text(
                  '${date.day}일',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isToday
                          ? Colors.green.shade700
                          : Colors.grey.shade700),
                ),
                Text(weekday,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Icon(Icons.delivery_dining,
                    size: 14, color: Colors.green.shade400),
                const SizedBox(width: 4),
                Text('$count건 배달',
                    style: TextStyle(
                        fontSize: 13, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Text(
            '+${_fmt(earning)}원',
            style: TextStyle(
                color: Colors.green.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 15),
          ),
        ],
      ),
    );
  }
}

// ── 전체 내역 탭 ──────────────────────────────────────────────────────────────
class _AllHistoryTab extends StatelessWidget {
  final List<OrderModel> orders;
  const _AllHistoryTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('완료된 배달이 없어요',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          ],
        ),
      );
    }

    // 월별로 그룹핑
    final Map<String, List<OrderModel>> grouped = {};
    for (final o in orders) {
      final key = '${o.createdAt.year}년 ${o.createdAt.month}월';
      grouped.putIfAbsent(key, () => []).add(o);
    }

    return ListView(
      padding: const EdgeInsets.all(12),
      children: grouped.entries.map((entry) {
        final monthOrders = entry.value;
        final monthTotal =
            monthOrders.fold(0, (s, o) => s + o.riderPay);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 월별 헤더
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(entry.key,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600)),
                  Text('${_fmt(monthTotal)}원 · ${monthOrders.length}건',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.green.shade600,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            ...monthOrders.map((o) => _DeliveryRow(order: o)),
            const SizedBox(height: 8),
          ],
        );
      }).toList(),
    );
  }
}

class _DeliveryRow extends StatelessWidget {
  final OrderModel order;
  const _DeliveryRow({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // 시간
            Text(
              '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontFamily: 'monospace'),
            ),
            const SizedBox(width: 12),
            // 주소
            Expanded(
              child: Text(
                order.deliveryAddress,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // 수익
            Text(
              '+${_fmt(order.riderPay)}원',
              style: TextStyle(
                  color: Colors.green.shade600,
                  fontWeight: FontWeight.bold,
                  fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
