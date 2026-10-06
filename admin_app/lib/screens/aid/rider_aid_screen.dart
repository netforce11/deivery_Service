import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── 상수 / 헬퍼 ───────────────────────────────────────────────────────────────

const _activeStatus    = 'active';
const _completedStatus = 'completed';
const _cancelledStatus = 'cancelled';

String _statusLabel(String s) {
  switch (s) {
    case _activeStatus:    return '진행중';
    case _completedStatus: return '완료';
    case _cancelledStatus: return '취소됨';
    default:               return s;
  }
}

Color _statusColor(String s) {
  switch (s) {
    case _activeStatus:    return Colors.green;
    case _completedStatus: return Colors.indigo;
    case _cancelledStatus: return Colors.red;
    default:               return Colors.grey;
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

// ── 메인 화면 ─────────────────────────────────────────────────────────────────

class RiderAidScreen extends StatefulWidget {
  const RiderAidScreen({super.key});

  @override
  State<RiderAidScreen> createState() => _RiderAidScreenState();
}

class _RiderAidScreenState extends State<RiderAidScreen> {
  final _db = FirebaseFirestore.instance;
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──────────────────────────────────────────────────────────
          Row(
            children: [
              const Text('🪖 라이언 일병 구하기',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              _btn('+ 캠페인 만들기', const Color(0xFF1A237E),
                  () => _showCreateDialog(context)),
            ],
          ),
          const SizedBox(height: 8),
          Text('배달 중 부상 라이더를 위한 전우 기부 이벤트',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          const SizedBox(height: 20),

          // ── 본문: 목록 + 상세 ──────────────────────────────────────────────
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 캠페인 목록
                SizedBox(
                  width: 300,
                  child: _CampaignList(
                    db: _db,
                    selectedId: _selectedId,
                    onSelect: (id) => setState(() => _selectedId = id),
                  ),
                ),
                const SizedBox(width: 16),
                // 상세 / 기부 내역
                Expanded(
                  child: _selectedId == null
                      ? _emptyDetail()
                      : _CampaignDetail(
                          db: _db, campaignId: _selectedId!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyDetail() {
    return Center(
      child: Text('← 캠페인을 선택하세요',
          style: TextStyle(color: Colors.grey.shade600)),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateCampaignDialog(db: _db),
    );
  }
}

// ── 캠페인 목록 ───────────────────────────────────────────────────────────────

class _CampaignList extends StatelessWidget {
  final FirebaseFirestore db;
  final String? selectedId;
  final ValueChanged<String> onSelect;
  const _CampaignList(
      {required this.db, this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('riderAidCampaigns')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5C6BC0)));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return _empty();
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data() as Map<String, dynamic>;
            final status = data['status'] as String? ?? _activeStatus;
            final goal = (data['goalAmount'] ?? 0).toInt();
            final current = (data['currentAmount'] ?? 0).toInt();
            final progress = goal > 0 ? current / goal : 0.0;
            final selected = selectedId == d.id;
            final isAnon = data['isAnonymous'] == true;
            final name = isAnon
                ? '익명의 라이더'
                : (data['injuredRiderName'] as String? ?? '라이더');

            return GestureDetector(
              onTap: () => onSelect(d.id),
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF1A237E).withOpacity(0.25)
                      : const Color(0xFF161B22),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF5C6BC0).withOpacity(0.6)
                        : Colors.grey.shade900,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                        ),
                        _statusChip(status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // 진행률 바
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade800,
                        color: progress >= 1.0
                            ? Colors.green
                            : const Color(0xFF5C6BC0),
                        minHeight: 6,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${_fmt(current)}원 / ${_fmt(goal)}원 '
                      '(${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%)',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 11),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(_statusLabel(status),
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🪖', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          Text('캠페인이 없습니다',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
        ],
      ),
    );
  }
}

// ── 캠페인 상세 ───────────────────────────────────────────────────────────────

class _CampaignDetail extends StatelessWidget {
  final FirebaseFirestore db;
  final String campaignId;
  const _CampaignDetail({required this.db, required this.campaignId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream:
          db.collection('riderAidCampaigns').doc(campaignId).snapshots(),
      builder: (_, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5C6BC0)));
        }
        final data = snap.data!.data() as Map<String, dynamic>;
        final status = data['status'] as String? ?? _activeStatus;
        final isActive = status == _activeStatus;
        final goal = (data['goalAmount'] ?? 0).toInt();
        final current = (data['currentAmount'] ?? 0).toInt();
        final companyMatch = (data['companyMatchAmount'] ?? 0).toInt();
        final participants = (data['participantCount'] ?? 0).toInt();
        final progress = goal > 0 ? current / goal : 0.0;
        final isAnon = data['isAnonymous'] == true;
        final name = isAnon
            ? '익명의 라이더'
            : (data['injuredRiderName'] as String? ?? '라이더');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── 요약 카드 ────────────────────────────────────────────────
            Container(
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
                      const Text('🪖 ',
                          style: TextStyle(fontSize: 22)),
                      Expanded(
                        child: Text(name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                      ),
                      _statusChip(status),
                      const SizedBox(width: 8),
                      // 상태 변경 버튼
                      if (isActive) ...[
                        _actionBtn('완료', Colors.green, () async {
                          await db
                              .collection('riderAidCampaigns')
                              .doc(campaignId)
                              .update({'status': _completedStatus});
                        }),
                        const SizedBox(width: 6),
                        _actionBtn('취소', Colors.red, () async {
                          await db
                              .collection('riderAidCampaigns')
                              .doc(campaignId)
                              .update({'status': _cancelledStatus});
                        }),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(data['description'] as String? ?? '',
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13)),
                  const SizedBox(height: 16),
                  // 진행률 바
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      backgroundColor: Colors.grey.shade800,
                      color: progress >= 1.0
                          ? Colors.green
                          : const Color(0xFF5C6BC0),
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 지표 행
                  Row(
                    children: [
                      _stat('총 적립', '${_fmt(current)}원',
                          const Color(0xFF7986CB)),
                      _stat('목표', '${_fmt(goal)}원', Colors.grey),
                      _stat('회사 매칭', '${_fmt(companyMatch)}원',
                          Colors.amber),
                      _stat('참여 라이더', '$participants명', Colors.green),
                      _stat('달성률',
                          '${(progress * 100).clamp(0, 100).toStringAsFixed(1)}%',
                          progress >= 1.0 ? Colors.green : Colors.orange),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // ── 참여 기록 ────────────────────────────────────────────────
            const Text('참여 기록',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14)),
            const SizedBox(height: 10),
            Expanded(child: _ContributionList(db: db, campaignId: campaignId)),
          ],
        );
      },
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 15)),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(_statusLabel(status),
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _actionBtn(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── 기부 내역 리스트 ──────────────────────────────────────────────────────────

class _ContributionList extends StatelessWidget {
  final FirebaseFirestore db;
  final String campaignId;
  const _ContributionList(
      {required this.db, required this.campaignId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade900),
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream: db
            .collection('riderAidContributions')
            .where('campaignId', isEqualTo: campaignId)
            .orderBy('createdAt', descending: true)
            .limit(50)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF5C6BC0)));
          }
          final docs = snap.data!.docs;
          if (docs.isEmpty) {
            return const Center(
                child: Text('참여 기록 없음',
                    style: TextStyle(color: Colors.grey)));
          }
          return Column(
            children: [
              // 헤더
              _row(['라이더', '라이더 기부', '회사 매칭', '합계', '시각'],
                  isHeader: true),
              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data =
                        docs[i].data() as Map<String, dynamic>;
                    final ts =
                        (data['createdAt'] as Timestamp?)?.toDate();
                    final time = ts != null
                        ? '${ts.month}/${ts.day} '
                          '${ts.hour.toString().padLeft(2, '0')}:'
                          '${ts.minute.toString().padLeft(2, '0')}'
                        : '-';
                    return _row([
                      data['riderName'] as String? ?? '-',
                      '${_fmt((data['riderContribution'] ?? 0).toInt())}원',
                      '${_fmt((data['companyMatch'] ?? 0).toInt())}원',
                      '${_fmt((data['totalContribution'] ?? 0).toInt())}원',
                      time,
                    ]);
                  },
                ),
              ),
            ],
          );
        },
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
        children: cells.map((c) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Text(c,
                  style: TextStyle(
                    color: isHeader
                        ? Colors.grey.shade500
                        : Colors.grey.shade300,
                    fontSize: isHeader ? 11 : 13,
                    fontWeight: isHeader
                        ? FontWeight.w600
                        : FontWeight.normal,
                  )),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── 캠페인 생성 다이얼로그 ────────────────────────────────────────────────────

class _CreateCampaignDialog extends StatefulWidget {
  final FirebaseFirestore db;
  const _CreateCampaignDialog({required this.db});

  @override
  State<_CreateCampaignDialog> createState() =>
      _CreateCampaignDialogState();
}

class _CreateCampaignDialogState extends State<_CreateCampaignDialog> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _goalCtrl = TextEditingController(text: '500000');
  bool _isAnonymous = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Row(
        children: [
          Text('🪖 ', style: TextStyle(fontSize: 20)),
          Text('새 캠페인 만들기',
              style: TextStyle(color: Colors.white, fontSize: 16)),
        ],
      ),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 익명 여부
            Row(
              children: [
                Switch(
                  value: _isAnonymous,
                  activeColor: const Color(0xFF5C6BC0),
                  onChanged: (v) => setState(() => _isAnonymous = v),
                ),
                const SizedBox(width: 8),
                Text(_isAnonymous ? '익명으로 공개' : '실명으로 공개',
                    style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 12),
            _field('부상 라이더 이름', _nameCtrl,
                hint: _isAnonymous ? '내부 기록용 (공개 안 됨)' : '라이더 이름'),
            const SizedBox(height: 12),
            _field('부상 경위 / 안내 문구', _descCtrl,
                hint: '예: 교통사고로 3주 입원 중입니다. 전우들의 도움을 부탁드립니다.',
                maxLines: 3),
            const SizedBox(height: 12),
            _field('목표 금액 (원)', _goalCtrl, hint: '500000',
                keyboardType: TextInputType.number),
            const SizedBox(height: 16),
            // 안내 박스
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.withOpacity(0.2)),
              ),
              child: const Text(
                '📌 라이언 콜 완료 시:\n'
                '  · 라이더 수익의 50% → 적립금\n'
                '  · 회사 동일 금액 매칭\n'
                '  · 라이더에게 +5 보상 포인트',
                style: TextStyle(color: Colors.amber, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A237E)),
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('캠페인 시작',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final goal = int.tryParse(_goalCtrl.text.trim()) ?? 0;
    if (goal <= 0) return;

    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      await widget.db.collection('riderAidCampaigns').add({
        'injuredRiderName': _nameCtrl.text.trim(),
        'isAnonymous': _isAnonymous,
        'description': _descCtrl.text.trim(),
        'goalAmount': goal,
        'currentAmount': 0,
        'companyMatchAmount': 0,
        'participantCount': 0,
        'status': 'active',
        'startDate': Timestamp.fromDate(now),
        'endDate': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl,
      {String hint = '', int maxLines = 1, TextInputType? keyboardType}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                TextStyle(color: Colors.grey.shade700, fontSize: 12),
            filled: true,
            fillColor: const Color(0xFF0D1117),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade800)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade800)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF5C6BC0))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}

// ── 공통 위젯 ─────────────────────────────────────────────────────────────────

Widget _btn(String label, Color color, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.5)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold)),
    ),
  );
}
