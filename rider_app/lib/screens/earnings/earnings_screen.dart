import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/order_model.dart';
import 'delivery_detail_screen.dart';

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

  // 수익 목표
  int _monthlyGoal = 0;
  int _dailyGoal = 0;
  final _prefs = SharedPreferences.getInstance();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final prefs = await _prefs;
    setState(() {
      _monthlyGoal = prefs.getInt('monthly_goal') ?? 0;
      _dailyGoal = prefs.getInt('daily_goal') ?? 0;
    });
  }

  Future<void> _saveGoals(int monthly, int daily) async {
    final prefs = await _prefs;
    await prefs.setInt('monthly_goal', monthly);
    await prefs.setInt('daily_goal', daily);
    setState(() {
      _monthlyGoal = monthly;
      _dailyGoal = daily;
    });
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

  void _showGoalDialog(int currentMonthly, int currentDaily) {
    final monthCtrl =
        TextEditingController(text: currentMonthly > 0 ? '$currentMonthly' : '');
    final dayCtrl =
        TextEditingController(text: currentDaily > 0 ? '$currentDaily' : '');

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('수익 목표 설정',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: monthCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '월 목표 (원)',
                hintText: '예: 3000000',
                prefixIcon:
                    Icon(Icons.calendar_month, color: Colors.green.shade600),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dayCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '일 목표 (원)',
                hintText: '예: 100000',
                prefixIcon:
                    Icon(Icons.today, color: Colors.green.shade600),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white),
            onPressed: () {
              final m = int.tryParse(monthCtrl.text) ?? 0;
              final d = int.tryParse(dayCtrl.text) ?? 0;
              _saveGoals(m, d);
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      appBar: AppBar(
        backgroundColor: Colors.green.shade600,
        foregroundColor: Colors.white,
        title:
            const Text('수익 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          // 목표 설정 버튼
          IconButton(
            icon: const Icon(Icons.flag_outlined),
            tooltip: '목표 설정',
            onPressed: () => _showGoalDialog(_monthlyGoal, _dailyGoal),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.green.shade200,
          tabs: const [
            Tab(text: '이번 달'),
            Tab(text: '통계'),
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
              return _MonthlySummary(
                orders: snap.data ?? [],
                monthlyGoal: _monthlyGoal,
                dailyGoal: _dailyGoal,
                onGoalTap: () =>
                    _showGoalDialog(_monthlyGoal, _dailyGoal),
              );
            },
          ),
          // 통계 탭
          StreamBuilder<List<OrderModel>>(
            stream: _monthlyDeliveries(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator(color: Colors.green));
              }
              return _StatsTab(orders: snap.data ?? []);
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
  final int monthlyGoal;
  final int dailyGoal;
  final VoidCallback onGoalTap;

  const _MonthlySummary({
    required this.orders,
    required this.monthlyGoal,
    required this.dailyGoal,
    required this.onGoalTap,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalEarnings = orders.fold(0, (s, o) => s + o.riderPay);
    final count = orders.length;

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

          _EarningsCard(
            totalEarnings: totalEarnings,
            count: count,
            todayEarning: todayEarning,
            todayCount: todayCount,
          ),
          const SizedBox(height: 16),

          // 목표 달성률
          _GoalProgressCard(
            totalEarnings: totalEarnings,
            todayEarning: todayEarning,
            monthlyGoal: monthlyGoal,
            dailyGoal: dailyGoal,
            onTap: onGoalTap,
          ),
          const SizedBox(height: 24),

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

// ── 목표 달성률 카드 ──────────────────────────────────────────────────────────
class _GoalProgressCard extends StatelessWidget {
  final int totalEarnings;
  final int todayEarning;
  final int monthlyGoal;
  final int dailyGoal;
  final VoidCallback onTap;

  const _GoalProgressCard({
    required this.totalEarnings,
    required this.todayEarning,
    required this.monthlyGoal,
    required this.dailyGoal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasGoal = monthlyGoal > 0 || dailyGoal > 0;

    if (!hasGoal) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade100),
          ),
          child: Row(
            children: [
              Icon(Icons.flag_outlined, color: Colors.green.shade400, size: 20),
              const SizedBox(width: 10),
              Text('수익 목표를 설정해보세요',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
              const Spacer(),
              Icon(Icons.chevron_right, color: Colors.grey.shade400),
            ],
          ),
        ),
      );
    }

    final monthRatio =
        monthlyGoal > 0 ? (totalEarnings / monthlyGoal).clamp(0.0, 1.0) : null;
    final dayRatio =
        dailyGoal > 0 ? (todayEarning / dailyGoal).clamp(0.0, 1.0) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade100),
          boxShadow: [
            BoxShadow(
                color: Colors.green.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.flag, color: Colors.green.shade600, size: 18),
                const SizedBox(width: 6),
                const Text('목표 달성률',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Spacer(),
                Icon(Icons.edit_outlined,
                    size: 16, color: Colors.grey.shade400),
              ],
            ),
            if (monthRatio != null) ...[
              const SizedBox(height: 12),
              _progressBar(
                label: '이번 달',
                current: totalEarnings,
                goal: monthlyGoal,
                ratio: monthRatio,
                color: Colors.green.shade600,
              ),
            ],
            if (dayRatio != null) ...[
              const SizedBox(height: 10),
              _progressBar(
                label: '오늘',
                current: todayEarning,
                goal: dailyGoal,
                ratio: dayRatio,
                color: Colors.teal.shade500,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _progressBar({
    required String label,
    required int current,
    required int goal,
    required double ratio,
    required Color color,
  }) {
    final pct = (ratio * 100).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text('$pct% (${_fmt(current)} / ${_fmt(goal)}원)',
                style: TextStyle(
                    fontSize: 12,
                    color: ratio >= 1 ? color : Colors.grey.shade600,
                    fontWeight:
                        ratio >= 1 ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(
                ratio >= 1 ? Colors.amber.shade600 : color),
          ),
        ),
        if (ratio >= 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('🎉 목표 달성!',
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.shade700,
                    fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}

// ── 통계 탭 (시간대별 분석) ───────────────────────────────────────────────────
class _StatsTab extends StatelessWidget {
  final List<OrderModel> orders;
  const _StatsTab({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart, size: 72, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('이번 달 배달 데이터가 없어요',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          ],
        ),
      );
    }

    // 시간대별 집계 (0~23)
    final hourlyEarnings = List<int>.filled(24, 0);
    final hourlyCount = List<int>.filled(24, 0);
    for (final o in orders) {
      hourlyEarnings[o.createdAt.hour] += o.riderPay;
      hourlyCount[o.createdAt.hour]++;
    }
    final maxHourly =
        hourlyEarnings.reduce((a, b) => a > b ? a : b);

    // 요일별 집계 (월=0 ~ 일=6)
    final weeklyEarnings = List<int>.filled(7, 0);
    final weeklyCount = List<int>.filled(7, 0);
    for (final o in orders) {
      final wd = o.createdAt.weekday - 1; // 1=월 → 0
      weeklyEarnings[wd] += o.riderPay;
      weeklyCount[wd]++;
    }
    final maxWeekly =
        weeklyEarnings.reduce((a, b) => a > b ? a : b);

    // 피크 시간대
    int peakHour = 0;
    for (int i = 1; i < 24; i++) {
      if (hourlyEarnings[i] > hourlyEarnings[peakHour]) peakHour = i;
    }

    final totalCount = orders.length;
    final totalEarnings = orders.fold(0, (s, o) => s + o.riderPay);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 요약 카드
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.access_time,
                  label: '피크 시간대',
                  value: '$peakHour시~${peakHour + 1}시',
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  icon: Icons.monetization_on,
                  label: '건당 평균',
                  value: totalCount > 0
                      ? '${_fmt(totalEarnings ~/ totalCount)}원'
                      : '-',
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // 시간대별 차트
          Text('시간대별 수익',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text('이번 달 시간대별 누적 수익',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          const SizedBox(height: 12),
          _HourlyChart(
              hourlyEarnings: hourlyEarnings,
              hourlyCount: hourlyCount,
              maxEarning: maxHourly == 0 ? 1 : maxHourly,
              peakHour: peakHour),
          const SizedBox(height: 24),

          // 요일별 차트
          Text('요일별 수익',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 4),
          Text('이번 달 요일별 누적 수익',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
          const SizedBox(height: 12),
          _WeeklyChart(
              weeklyEarnings: weeklyEarnings,
              weeklyCount: weeklyCount,
              maxEarning: maxWeekly == 0 ? 1 : maxWeekly),
          const SizedBox(height: 24),

          // 시간대별 상세 테이블
          Text('시간대별 상세',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          ...List.generate(24, (h) {
            if (hourlyCount[h] == 0) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: h == peakHour
                    ? Colors.orange.shade50
                    : Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: h == peakHour
                    ? Border.all(color: Colors.orange.shade200)
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text('$h시~${h + 1}시',
                        style: TextStyle(
                            fontSize: 12,
                            color: h == peakHour
                                ? Colors.orange.shade700
                                : Colors.grey.shade600,
                            fontWeight: h == peakHour
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('${hourlyCount[h]}건',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade600)),
                  ),
                  Text('+${_fmt(hourlyEarnings[h])}원',
                      style: TextStyle(
                          fontSize: 14,
                          color: Colors.green.shade700,
                          fontWeight: FontWeight.bold)),
                  if (h == peakHour) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text('피크',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color)),
        ],
      ),
    );
  }
}

// ── 시간대별 막대 차트 ────────────────────────────────────────────────────────
class _HourlyChart extends StatelessWidget {
  final List<int> hourlyEarnings;
  final List<int> hourlyCount;
  final int maxEarning;
  final int peakHour;

  const _HourlyChart({
    required this.hourlyEarnings,
    required this.hourlyCount,
    required this.maxEarning,
    required this.peakHour,
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
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (h) {
                final ratio = maxEarning > 0
                    ? hourlyEarnings[h] / maxEarning
                    : 0.0;
                final isPeak = h == peakHour && hourlyEarnings[h] > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: hourlyCount[h] > 0
                          ? '$h시: ${_fmt(hourlyEarnings[h])}원 (${hourlyCount[h]}건)'
                          : '',
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            height: hourlyEarnings[h] > 0
                                ? 90 * ratio + 4
                                : 4,
                            decoration: BoxDecoration(
                              color: isPeak
                                  ? Colors.orange.shade500
                                  : hourlyEarnings[h] > 0
                                      ? Colors.green.shade300
                                      : Colors.grey.shade100,
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(2)),
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
            children: List.generate(24, (h) {
              final show = h % 6 == 0;
              return Expanded(
                child: Text(
                  show ? '$h' : '',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 9, color: Colors.grey.shade400),
                ),
              );
            }),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Container(
                  width: 10, height: 10,
                  color: Colors.orange.shade500),
              const SizedBox(width: 4),
              Text('피크 시간대',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── 요일별 막대 차트 ──────────────────────────────────────────────────────────
class _WeeklyChart extends StatelessWidget {
  final List<int> weeklyEarnings;
  final List<int> weeklyCount;
  final int maxEarning;

  const _WeeklyChart({
    required this.weeklyEarnings,
    required this.weeklyCount,
    required this.maxEarning,
  });

  @override
  Widget build(BuildContext context) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (d) {
          final ratio =
              maxEarning > 0 ? weeklyEarnings[d] / maxEarning : 0.0;
          final isWeekend = d >= 5;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  if (weeklyEarnings[d] > 0)
                    Text(
                      '${_fmt(weeklyEarnings[d] ~/ 1000)}k',
                      style: TextStyle(
                          fontSize: 9,
                          color: isWeekend
                              ? Colors.red.shade400
                              : Colors.green.shade600),
                    ),
                  const SizedBox(height: 4),
                  Container(
                    height: weeklyEarnings[d] > 0 ? 80 * ratio + 4 : 4,
                    decoration: BoxDecoration(
                      color: isWeekend
                          ? (weeklyEarnings[d] > 0
                              ? Colors.red.shade200
                              : Colors.grey.shade100)
                          : (weeklyEarnings[d] > 0
                              ? Colors.green.shade300
                              : Colors.grey.shade100),
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(3)),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(days[d],
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isWeekend
                              ? Colors.red.shade400
                              : Colors.grey.shade600)),
                  Text('${weeklyCount[d]}건',
                      style: TextStyle(
                          fontSize: 10, color: Colors.grey.shade400)),
                ],
              ),
            ),
          );
        }),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                  child: _statItem(Icons.today, '오늘 수익',
                      '${_fmt(todayEarning)}원')),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                  child: _statItem(
                      Icons.delivery_dining, '오늘 배달', '$todayCount건')),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                  child: _statItem(
                      Icons.monetization_on,
                      '건당 평균',
                      count > 0
                          ? '${_fmt(totalEarnings ~/ count)}원'
                          : '-')),
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
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isToday ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border:
            isToday ? Border.all(color: Colors.green.shade200) : null,
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
                style:
                    TextStyle(color: Colors.grey.shade400, fontSize: 15)),
          ],
        ),
      );
    }

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
                  Text(
                      '${_fmt(monthTotal)}원 · ${monthOrders.length}건',
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
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DeliveryDetailScreen(order: order)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Text(
                '${order.createdAt.hour.toString().padLeft(2, '0')}:${order.createdAt.minute.toString().padLeft(2, '0')}',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.storeName,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      order.deliveryAddress,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '+${_fmt(order.riderPay)}원',
                    style: TextStyle(
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  if (order.isLongDistance)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('장거리',
                          style: TextStyle(fontSize: 9, color: Colors.purple.shade600, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade300),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
