import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});

  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  String _statusFilter = '전체';
  final _db = FirebaseFirestore.instance;

  static const _statuses = ['전체', '대기', '수락', '픽업', '완료', '취소'];
  static const _statusMap = {
    '대기': 'pending',
    '수락': 'accepted',
    '픽업': 'picked_up',
    '완료': 'delivered',
    '취소': 'cancelled',
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              const Text('주문 관리',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              // 상태 필터
              ..._statuses.map((s) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _FilterChip(
                      label: s,
                      selected: _statusFilter == s,
                      onTap: () => setState(() => _statusFilter = s),
                    ),
                  )),
            ],
          ),
          const SizedBox(height: 20),

          // 주문 목록
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _buildQuery(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF5C6BC0)));
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('주문 없음',
                          style: TextStyle(color: Colors.grey)));
                }
                return _OrderTable(docs: docs, db: _db);
              },
            ),
          ),
        ],
      ),
    );
  }

  Stream<QuerySnapshot> _buildQuery() {
    Query q = _db.collection('orders').orderBy('createdAt', descending: true);
    final mapped = _statusMap[_statusFilter];
    if (mapped != null) q = q.where('status', isEqualTo: mapped);
    return q.limit(50).snapshots();
  }
}

class _OrderTable extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final FirebaseFirestore db;
  const _OrderTable({required this.docs, required this.db});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade900),
      ),
      child: Column(
        children: [
          // 테이블 헤더
          _row(['주문번호', '가게', '금액', '상태', '주문시간', ''], isHeader: true),
          // 데이터 행
          Expanded(
            child: ListView.builder(
              itemCount: docs.length,
              itemBuilder: (_, i) {
                final d = docs[i];
                final data = d.data() as Map<String, dynamic>;
                final ts = (data['createdAt'] as Timestamp?)?.toDate();
                final time = ts != null
                    ? '${ts.month}/${ts.day} ${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}'
                    : '-';
                final status = data['status'] as String? ?? '';
                final amount = (data['totalAmount'] ?? 0).toInt();

                return _row([
                  d.id.substring(0, 8).toUpperCase(),
                  data['storeName'] ?? '-',
                  '${_fmt(amount)}원',
                  _statusBadge(status),
                  time,
                  '__actions__:${d.id}:$status',
                ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(List<String> cells, {bool isHeader = false}) {
    return Container(
      decoration: BoxDecoration(
        color: isHeader ? const Color(0xFF0D1117) : Colors.transparent,
        border: Border(
            bottom: BorderSide(color: Colors.grey.shade900, width: 0.5)),
      ),
      child: Row(
        children: cells.asMap().entries.map((e) {
          final idx = e.key;
          final val = e.value;
          final flex = idx == 1 ? 3 : (idx == 5 ? 2 : 2);

          if (!isHeader && val.startsWith('__actions__:')) {
            final parts = val.split(':');
            final docId = parts[1];
            final status = parts[2];
            return Expanded(
              flex: flex,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: _ActionButtons(docId: docId, status: status, db: db),
              ),
            );
          }

          return Expanded(
            flex: flex,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              child: Text(
                val,
                style: TextStyle(
                  color: isHeader
                      ? Colors.grey.shade500
                      : Colors.grey.shade300,
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

  String _statusBadge(String status) {
    switch (status) {
      case 'pending':   return '⏳ 대기중';
      case 'accepted':  return '✅ 수락됨';
      case 'picked_up': return '🛵 픽업';
      case 'delivered': return '📦 완료';
      case 'cancelled': return '❌ 취소';
      default:          return status;
    }
  }
}

class _ActionButtons extends StatelessWidget {
  final String docId;
  final String status;
  final FirebaseFirestore db;
  const _ActionButtons(
      {required this.docId, required this.status, required this.db});

  @override
  Widget build(BuildContext context) {
    if (status == 'delivered' || status == 'cancelled') {
      return Text('처리완료',
          style: TextStyle(color: Colors.grey.shade700, fontSize: 11));
    }
    return Row(
      children: [
        _btn('강제취소', Colors.red, () => _forceCancel(context)),
        if (status == 'pending') ...[
          const SizedBox(width: 6),
          _btn('수동수락', Colors.green, () => _manualAccept()),
        ],
      ],
    );
  }

  Widget _btn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Future<void> _forceCancel(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF161B22),
        title: const Text('강제 취소',
            style: TextStyle(color: Colors.white)),
        content: Text('주문 $docId 를 강제 취소하겠습니까?',
            style: const TextStyle(color: Colors.grey)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('아니오')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('취소', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await db.collection('orders').doc(docId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelReason': '관리자 강제 취소',
      });
    }
  }

  Future<void> _manualAccept() async {
    await db.collection('orders').doc(docId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1A237E)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: selected
                  ? const Color(0xFF5C6BC0)
                  : Colors.grey.shade800),
        ),
        child: Text(label,
            style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade400,
                fontSize: 12,
                fontWeight:
                    selected ? FontWeight.bold : FontWeight.normal)),
      ),
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
