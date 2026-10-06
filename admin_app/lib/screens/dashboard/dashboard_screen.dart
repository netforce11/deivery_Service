import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('실시간 현황'),
          const SizedBox(height: 12),
          // 상단 4개 지표
          Row(
            children: [
              _StatCard(
                label: '오늘 주문',
                icon: Icons.receipt_long,
                color: const Color(0xFF5C6BC0),
                stream: _todayOrderCount(),
                unit: '건',
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '진행 중',
                icon: Icons.delivery_dining,
                color: Colors.orange,
                stream: _activeOrderCount(),
                unit: '건',
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '활성 라이더',
                icon: Icons.directions_bike,
                color: Colors.green,
                stream: _activeRiderCount(),
                unit: '명',
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: '오늘 매출',
                icon: Icons.payments_outlined,
                color: Colors.amber,
                stream: _todayRevenue(),
                unit: '원',
                isMoney: true,
              ),
            ],
          ),
          const SizedBox(height: 28),
          _sectionTitle('최근 주문 (실시간)'),
          const SizedBox(height: 12),
          _RecentOrdersTable(),
          const SizedBox(height: 28),
          _sectionTitle('처리 대기'),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _PendingStoreApprovals()),
              const SizedBox(width: 12),
              Expanded(child: _PendingBonusQueue()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title,
        style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold));
  }

  // ── Firestore 스트림 ─────────────────────────────────────────────────────
  Stream<int> _todayOrderCount() {
    final start = DateTime.now();
    final todayStart = DateTime(start.year, start.month, start.day);
    return FirebaseFirestore.instance
        .collection('orders')
        .where('createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .snapshots()
        .map((s) => s.size);
  }

  Stream<int> _activeOrderCount() {
    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', whereIn: ['accepted', 'picked_up'])
        .snapshots()
        .map((s) => s.size);
  }

  Stream<int> _activeRiderCount() {
    return FirebaseFirestore.instance
        .collection('riders')
        .where('isOnline', isEqualTo: true)
        .snapshots()
        .map((s) => s.size);
  }

  Stream<int> _todayRevenue() {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .where('deliveredAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
        .snapshots()
        .map((s) => s.docs.fold<int>(
            0, (sum, d) => sum + ((d['totalAmount'] ?? 0) as num).toInt()));
  }
}

// ── 지표 카드 ────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Stream<int> stream;
  final String unit;
  final bool isMoney;

  const _StatCard({
    required this.label,
    required this.icon,
    required this.color,
    required this.stream,
    required this.unit,
    this.isMoney = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            StreamBuilder<int>(
              stream: stream,
              builder: (_, snap) {
                final val = snap.data ?? 0;
                final display = isMoney ? _fmt(val) : val.toString();
                return Text(
                  '$display $unit',
                  style: TextStyle(
                      color: color,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── 최근 주문 테이블 ────────────────────────────────────────────────────────
class _RecentOrdersTable extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade900),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .orderBy('createdAt', descending: true)
            .limit(8)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator(
                  color: Color(0xFF5C6BC0))),
            );
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                  child: Text('주문 없음',
                      style: TextStyle(color: Colors.grey))),
            );
          }
          return Column(
            children: [
              // 헤더
              _tableRow(
                ['주문번호', '상태', '가게', '금액', '주문시간'],
                isHeader: true,
              ),
              ...docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                final ts = (data['createdAt'] as Timestamp?)?.toDate();
                final time = ts != null
                    ? '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                    : '-';
                return _tableRow([
                  d.id.substring(0, 8).toUpperCase(),
                  _statusLabel(data['status']),
                  data['storeName'] ?? '-',
                  '${_fmt((data['totalAmount'] ?? 0).toInt())}원',
                  time,
                ]);
              }),
            ],
          );
        },
      ),
    );
  }

  Widget _tableRow(List<String> cells, {bool isHeader = false}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.grey.shade900, width: 0.5)),
        color: isHeader ? const Color(0xFF0D1117) : Colors.transparent,
      ),
      child: Row(
        children: cells.asMap().entries.map((e) {
          final flex = e.key == 2 ? 3 : 2; // 가게명 칸 더 넓게
          return Expanded(
            flex: flex,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(
                e.value,
                style: TextStyle(
                  color: isHeader ? Colors.grey.shade500 : Colors.grey.shade300,
                  fontSize: isHeader ? 11 : 13,
                  fontWeight:
                      isHeader ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  String _statusLabel(String? status) {
    switch (status) {
      case 'pending':    return '⏳ 대기';
      case 'accepted':   return '✅ 수락';
      case 'picked_up':  return '🛵 픽업';
      case 'delivered':  return '📦 완료';
      case 'cancelled':  return '❌ 취소';
      default:           return status ?? '-';
    }
  }
}

// ── 가게 승인 대기 ───────────────────────────────────────────────────────────
class _PendingStoreApprovals extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade900),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.store, color: Colors.orange, size: 16),
              const SizedBox(width: 8),
              const Text('가게 승인 대기',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('stores')
                .where('approved', isEqualTo: false)
                .limit(5)
                .snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('대기 중인 가게 없음',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                );
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(data['name'] ?? '-',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    subtitle: Text(data['category'] ?? '',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _actionBtn('승인', Colors.green, () async {
                          await FirebaseFirestore.instance
                              .collection('stores')
                              .doc(d.id)
                              .update({'approved': true, 'isOpen': false});
                        }),
                        const SizedBox(width: 6),
                        _actionBtn('거절', Colors.red, () async {
                          await FirebaseFirestore.instance
                              .collection('stores')
                              .doc(d.id)
                              .delete();
                        }),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── 정산 대기 큐 ─────────────────────────────────────────────────────────────
class _PendingBonusQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade900),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet,
                  color: Color(0xFF5C6BC0), size: 16),
              const SizedBox(width: 8),
              const Text('정산 대기',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('storeBonusQueue')
                .where('status', isEqualTo: 'pending')
                .limit(5)
                .snapshots(),
            builder: (_, snap) {
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('대기 중인 정산 없음',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                );
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final amount = (data['amount'] ?? 0).toInt();
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(data['storeName'] ?? d.id.substring(0, 8),
                        style: const TextStyle(
                            color: Colors.white, fontSize: 13)),
                    subtitle: Text(data['reason'] ?? '',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 11)),
                    trailing: Text('${_fmt(amount)}원',
                        style: const TextStyle(
                            color: Color(0xFF7986CB),
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
