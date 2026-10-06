import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StoreRiderManagementScreen extends StatefulWidget {
  const StoreRiderManagementScreen({super.key});

  @override
  State<StoreRiderManagementScreen> createState() =>
      _StoreRiderManagementScreenState();
}

class _StoreRiderManagementScreenState
    extends State<StoreRiderManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _db = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('가게 / 라이더 관리',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // 탭 바
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF161B22),
              borderRadius: BorderRadius.circular(10),
            ),
            child: TabBar(
              controller: _tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              indicator: BoxDecoration(
                color: const Color(0xFF1A237E),
                borderRadius: BorderRadius.circular(10),
              ),
              tabs: const [
                Tab(text: '🏪  가게'),
                Tab(text: '🛵  라이더'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _StoreList(db: _db),
                _RiderList(db: _db),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 가게 목록 ─────────────────────────────────────────────────────────────────
class _StoreList extends StatelessWidget {
  final FirebaseFirestore db;
  const _StoreList({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('stores').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5C6BC0)));
        }
        final docs = snap.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            final isOpen = data['isOpen'] == true;
            final approved = data['approved'] != false; // null이면 기존 승인된 것으로 처리

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade900),
              ),
              child: Row(
                children: [
                  // 아이콘
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.store, color: Colors.orange, size: 22),
                  ),
                  const SizedBox(width: 14),
                  // 정보
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(data['name'] ?? '-',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            _badge(data['category'] ?? '', Colors.orange),
                            if (!approved) ...[
                              const SizedBox(width: 6),
                              _badge('승인대기', Colors.amber),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(data['address'] ?? '-',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  // 액션
                  Row(
                    children: [
                      // 영업중/준비중 토글
                      _toggleBtn(
                        isOpen ? '영업중' : '준비중',
                        isOpen ? Colors.green : Colors.grey,
                        () => db.collection('stores').doc(d.id)
                            .update({'isOpen': !isOpen}),
                      ),
                      const SizedBox(width: 8),
                      // 정지 버튼
                      _toggleBtn('정지', Colors.red, () async {
                        final confirm = await _confirmDialog(
                            context, '가게 정지', '${data['name']} 가게를 정지하겠습니까?');
                        if (confirm == true) {
                          await db.collection('stores').doc(d.id)
                              .update({'isOpen': false, 'suspended': true});
                        }
                      }),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── 라이더 목록 ───────────────────────────────────────────────────────────────
class _RiderList extends StatelessWidget {
  final FirebaseFirestore db;
  const _RiderList({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db.collection('riders').orderBy('createdAt', descending: true).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5C6BC0)));
        }
        final docs = snap.data!.docs;
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            final isOnline = data['isOnline'] == true;
            final suspended = data['suspended'] == true;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF161B22),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: suspended
                        ? Colors.red.withOpacity(0.3)
                        : Colors.grey.shade900),
              ),
              child: Row(
                children: [
                  // 온라인 상태 표시
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isOnline ? Colors.green : Colors.grey)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.directions_bike,
                        color: isOnline ? Colors.green : Colors.grey, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(data['name'] ?? d.id.substring(0, 8),
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            _badge(
                              isOnline ? '온라인' : '오프라인',
                              isOnline ? Colors.green : Colors.grey,
                            ),
                            if (suspended) ...[
                              const SizedBox(width: 6),
                              _badge('정지됨', Colors.red),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(data['email'] ?? '-',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  // 정지/해제
                  _toggleBtn(
                    suspended ? '정지해제' : '계정정지',
                    suspended ? Colors.green : Colors.red,
                    () async {
                      final label = suspended ? '정지 해제' : '계정 정지';
                      final confirm = await _confirmDialog(
                          context, label, '라이더 계정을 $label 하겠습니까?');
                      if (confirm == true) {
                        await db.collection('riders').doc(d.id)
                            .update({'suspended': !suspended});
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────────────────────────
Widget _badge(String label, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: color.withOpacity(0.3)),
    ),
    child: Text(label,
        style: TextStyle(
            color: color, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}

Widget _toggleBtn(String label, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    ),
  );
}

Future<bool?> _confirmDialog(
    BuildContext context, String title, String content) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(content, style: const TextStyle(color: Colors.grey)),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소')),
        TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('확인',
                style: TextStyle(color: Colors.redAccent))),
      ],
    ),
  );
}
