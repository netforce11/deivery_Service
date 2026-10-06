import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettlementScreen extends StatefulWidget {
  const SettlementScreen({super.key});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('정산 관리',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // 월별 매출 요약
          _MonthlySummary(db: _db),
          const SizedBox(height: 24),

          // 정산 대기 큐 전체
          _BonusQueueSection(db: _db),
          const SizedBox(height: 24),

          // 전우 지원금 정산
          _AidPayoutSection(db: _db),
          const SizedBox(height: 24),

          // 슈퍼라이더 보너스 (MVP: 수동 선정)
          _SuperRiderBonusSection(db: _db),
        ],
      ),
    );
  }
}

// ── 월별 매출 요약 ────────────────────────────────────────────────────────────
class _MonthlySummary extends StatelessWidget {
  final FirebaseFirestore db;
  const _MonthlySummary({required this.db});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(Icons.bar_chart, color: Color(0xFF7986CB), size: 18),
              const SizedBox(width: 8),
              Text(
                '${now.month}월 매출 현황',
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('orders')
                .where('status', isEqualTo: 'delivered')
                .where('deliveredAt',
                    isGreaterThanOrEqualTo:
                        Timestamp.fromDate(monthStart))
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const CircularProgressIndicator(
                    color: Color(0xFF5C6BC0));
              }
              final docs = snap.data!.docs;
              int totalRevenue = 0;
              int totalDeliveryFee = 0;
              int orderCount = docs.length;

              for (final d in docs) {
                final data = d.data() as Map<String, dynamic>;
                totalRevenue += ((data['totalAmount'] ?? 0) as num).toInt();
                totalDeliveryFee +=
                    ((data['deliveryFee'] ?? 0) as num).toInt();
              }

              // 플랫폼 순수익 = 배달비 수취 + 가게 수수료(8%) - 라이더 지급(80%)
              final platformFee =
                  (totalRevenue * 0.08).round(); // 가게 수수료 8%
              final riderPayout =
                  (totalDeliveryFee * 0.8).round(); // 배달비의 80% 라이더 지급
              final netProfit =
                  totalDeliveryFee + platformFee - riderPayout;
              final bonusPool = (netProfit * 0.01).round(); // 순익 1% = 슈퍼라이더 풀

              return Row(
                children: [
                  _summaryTile('총 주문', '$orderCount건', const Color(0xFF5C6BC0)),
                  _divider(),
                  _summaryTile('총 매출', '${_fmt(totalRevenue)}원', Colors.amber),
                  _divider(),
                  _summaryTile('플랫폼 순익', '${_fmt(netProfit)}원', Colors.green),
                  _divider(),
                  _summaryTile(
                      '슈퍼라이더 풀 (1%)', '${_fmt(bonusPool)}원', Colors.purple),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _summaryTile(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
        width: 1, height: 40, color: Colors.grey.shade900);
  }
}

// ── 정산 대기 큐 ─────────────────────────────────────────────────────────────
class _BonusQueueSection extends StatelessWidget {
  final FirebaseFirestore db;
  const _BonusQueueSection({required this.db});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                  color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              const Text('가게 정산 대기',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const Spacer(),
              // 일괄 지급 버튼
              StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection('storeBonusQueue')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (_, snap) {
                  final count = snap.data?.size ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return ElevatedButton.icon(
                    onPressed: () => _payAll(context, snap.data!.docs),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.payments, size: 16),
                    label: Text('전체 지급 ($count건)'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('storeBonusQueue')
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const CircularProgressIndicator(
                    color: Color(0xFF5C6BC0));
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('정산 대기 없음',
                      style: TextStyle(color: Colors.grey)),
                );
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final isPaid = data['status'] == 'paid';
                  final amount = (data['amount'] ?? 0).toInt();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(data['storeName'] ?? d.id,
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 13)),
                              Text(data['reason'] ?? '',
                                  style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 11)),
                            ],
                          ),
                        ),
                        Text('${_fmt(amount)}원',
                            style: TextStyle(
                                color: isPaid
                                    ? Colors.grey
                                    : Colors.amber,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isPaid ? Colors.grey : Colors.green)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(isPaid ? '지급완료' : '대기중',
                              style: TextStyle(
                                  color:
                                      isPaid ? Colors.grey : Colors.green,
                                  fontSize: 11)),
                        ),
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

  Future<void> _payAll(
      BuildContext context, List<QueryDocumentSnapshot> docs) async {
    final pending = docs.where((d) {
      final data = d.data() as Map<String, dynamic>;
      return data['status'] == 'pending';
    }).toList();

    if (pending.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('일괄 지급',
            style: TextStyle(color: Colors.white)),
        content: Text('${pending.length}건의 정산을 일괄 지급 처리하겠습니까?',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('지급',
                  style: TextStyle(color: Colors.green))),
        ],
      ),
    );

    if (confirm != true) return;

    final batch = db.batch();
    for (final d in pending) {
      batch.update(d.reference, {
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}

// ── 전우 지원금 정산 ───────────────────────────────────────────────────────────

class _AidPayoutSection extends StatelessWidget {
  final FirebaseFirestore db;
  const _AidPayoutSection({required this.db});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🪖', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('전우 지원금 정산',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('라이언 일병 구하기',
                    style: TextStyle(color: Colors.teal, fontSize: 11)),
              ),
              const Spacer(),
              // 일괄 지급 버튼
              StreamBuilder<QuerySnapshot>(
                stream: db
                    .collection('riderAidPayouts')
                    .where('status', isEqualTo: 'pending')
                    .snapshots(),
                builder: (_, snap) {
                  final count = snap.data?.size ?? 0;
                  if (count == 0) return const SizedBox.shrink();
                  return ElevatedButton.icon(
                    onPressed: () =>
                        _payAll(context, snap.data!.docs),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    icon: const Icon(Icons.volunteer_activism, size: 16),
                    label: Text('전체 지급 ($count건)'),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          StreamBuilder<QuerySnapshot>(
            stream: db
                .collection('riderAidPayouts')
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (_, snap) {
              if (!snap.hasData) {
                return const CircularProgressIndicator(
                    color: Color(0xFF5C6BC0));
              }
              final docs = snap.data!.docs;
              if (docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('지원금 정산 대기 없음',
                      style: TextStyle(color: Colors.grey.shade600)),
                );
              }
              return Column(
                children: docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  final isPaid = data['status'] == 'paid';
                  final amount = (data['amount'] ?? 0).toInt();
                  final ts =
                      (data['createdAt'] as Timestamp?)?.toDate();
                  final dateStr = ts != null
                      ? '${ts.month}/${ts.day} '
                        '${ts.hour.toString().padLeft(2, '0')}:'
                        '${ts.minute.toString().padLeft(2, '0')}'
                      : '-';

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1117),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Text('🪖 ',
                            style: TextStyle(fontSize: 16)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['riderName'] as String? ?? d.id,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                              ),
                              Text(
                                data['memo'] as String? ?? '',
                                style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        Text(dateStr,
                            style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 11)),
                        const SizedBox(width: 16),
                        Text('${_fmt(amount)}원',
                            style: TextStyle(
                                color:
                                    isPaid ? Colors.grey : Colors.teal,
                                fontWeight: FontWeight.bold,
                                fontSize: 15)),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isPaid ? Colors.grey : Colors.teal)
                                .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(isPaid ? '지급완료' : '대기중',
                              style: TextStyle(
                                  color: isPaid
                                      ? Colors.grey
                                      : Colors.teal,
                                  fontSize: 11)),
                        ),
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

  Future<void> _payAll(
      BuildContext context, List<QueryDocumentSnapshot> docs) async {
    final pending = docs
        .where((d) =>
            (d.data() as Map<String, dynamic>)['status'] == 'pending')
        .toList();
    if (pending.isEmpty) return;

    final totalAmount = pending.fold<int>(
        0,
        (sum, d) =>
            sum +
            ((d.data() as Map<String, dynamic>)['amount'] as num? ?? 0)
                .toInt());

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('전우 지원금 지급',
            style: TextStyle(color: Colors.white)),
        content: Text(
            '${pending.length}명에게 총 ${_fmt(totalAmount)}원을 지급 처리하겠습니까?\n\n'
            '실제 계좌 이체는 별도로 진행해 주세요.',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('지급 처리',
                  style: TextStyle(color: Colors.teal))),
        ],
      ),
    );
    if (confirm != true) return;

    final batch = db.batch();
    final now = FieldValue.serverTimestamp();

    for (final d in pending) {
      // 지원금 지급 상태 업데이트
      batch.update(d.reference, {
        'status': 'paid',
        'paidAt': now,
      });

      // 캠페인 isPaidOut 플래그 업데이트
      final campaignId = (d.data() as Map<String, dynamic>)['campaignId']
          as String?;
      if (campaignId != null) {
        batch.update(
          db.collection('riderAidCampaigns').doc(campaignId),
          {'isPaidOut': true},
        );
      }
    }
    await batch.commit();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '🪖 ${pending.length}명 / ${_fmt(totalAmount)}원 지급 처리 완료'),
          backgroundColor: Colors.teal.shade700,
        ),
      );
    }
  }
}

// ── 슈퍼라이더 보너스 (MVP: 수동) ────────────────────────────────────────────
class _SuperRiderBonusSection extends StatefulWidget {
  final FirebaseFirestore db;
  const _SuperRiderBonusSection({required this.db});

  @override
  State<_SuperRiderBonusSection> createState() =>
      _SuperRiderBonusSectionState();
}

class _SuperRiderBonusSectionState extends State<_SuperRiderBonusSection> {
  bool _loading = false;
  List<Map<String, dynamic>> _topRiders = [];
  int _bonusPool = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆',style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('슈퍼라이더 보너스',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('월 1회 수동 지급',
                    style: TextStyle(color: Colors.purple, fontSize: 11)),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _loading ? null : _calcTopRiders,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade900,
                  foregroundColor: Colors.white,
                ),
                icon: _loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.calculate, size: 16),
                label: const Text('상위 50명 계산'),
              ),
            ],
          ),

          if (_topRiders.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Text('보너스 풀 ',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text('${_fmt(_bonusPool)}원',
                      style: const TextStyle(
                          color: Colors.purple,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Text('  ÷  50명  =  ',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text('${_fmt(_bonusPool ~/ 50)}원 / 1인',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 16)),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () => _payBonus(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('보너스 지급'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // 상위 라이더 목록
            ...List.generate(
                _topRiders.length > 10 ? 10 : _topRiders.length, (i) {
              final r = _topRiders[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Text('${i + 1}위',
                        style: TextStyle(
                            color: i < 3
                                ? Colors.amber
                                : Colors.grey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Text(r['name'] ?? r['riderId'],
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13))),
                    Text('${r['count']}건',
                        style: const TextStyle(
                            color: Color(0xFF7986CB), fontSize: 13)),
                  ],
                ),
              );
            }),
            if (_topRiders.length > 10)
              Text('... 외 ${_topRiders.length - 10}명',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Future<void> _calcTopRiders() async {
    setState(() => _loading = true);
    try {
      final now = DateTime.now();
      final monthStart = Timestamp.fromDate(DateTime(now.year, now.month, 1));

      // 이번 달 완료 주문 집계
      final snap = await widget.db
          .collection('orders')
          .where('status', isEqualTo: 'delivered')
          .where('deliveredAt', isGreaterThanOrEqualTo: monthStart)
          .get();

      // 라이더별 건수 집계
      final Map<String, int> counts = {};
      int totalRevenue = 0;
      for (final d in snap.docs) {
        final data = d.data();
        final riderId = data['riderId'] as String?;
        if (riderId != null) {
          counts[riderId] = (counts[riderId] ?? 0) + 1;
        }
        totalRevenue += ((data['totalAmount'] ?? 0) as num).toInt();
      }

      // 플랫폼 순익 계산 후 1% = 보너스 풀
      final platformNet = (totalRevenue * 0.028).round(); // 대략 2.8% 순익
      final pool = (platformNet * 0.01).round();

      // 상위 50명 정렬
      final sorted = counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top50 = sorted.take(50).toList();

      // 라이더 이름 조회
      final riders = <Map<String, dynamic>>[];
      for (final e in top50) {
        final riderDoc =
            await widget.db.collection('riders').doc(e.key).get();
        riders.add({
          'riderId': e.key,
          'name': riderDoc.data()?['name'] ?? e.key.substring(0, 8),
          'count': e.value,
        });
      }

      setState(() {
        _topRiders = riders;
        _bonusPool = pool;
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _payBonus(BuildContext context) async {
    if (_topRiders.isEmpty) return;
    final perRider = _bonusPool ~/ _topRiders.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('슈퍼라이더 보너스 지급',
            style: TextStyle(color: Colors.white)),
        content: Text(
            '${_topRiders.length}명에게 1인당 ${_fmt(perRider)}원 지급\n총 ${_fmt(_bonusPool)}원',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('지급',
                  style: TextStyle(color: Colors.purple))),
        ],
      ),
    );

    if (confirm != true) return;

    final batch = widget.db.batch();
    final now = DateTime.now();
    final monthKey =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';

    for (final r in _topRiders) {
      final ref = widget.db.collection('superRiderBonus').doc();
      batch.set(ref, {
        'riderId': r['riderId'],
        'riderName': r['name'],
        'month': monthKey,
        'amount': perRider,
        'deliveryCount': r['count'],
        'status': 'paid',
        'paidAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();

    setState(() => _topRiders = []);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${_fmt(_bonusPool)}원 지급 완료 ✅'),
          backgroundColor: Colors.purple,
        ),
      );
    }
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
