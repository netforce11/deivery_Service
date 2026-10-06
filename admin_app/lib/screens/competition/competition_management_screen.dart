import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ── 모델 인라인 (admin_app 전용 경량 버전) ────────────────────────────────────

enum _CompType { longDistance, efficiency }
enum _Vehicle  { bicycle, motorcycle, car, all }

const _typeLabel   = {_CompType.longDistance: '최고 장거리 운행', _CompType.efficiency: '최고 효율 라이더'};
const _typeEmoji   = {_CompType.longDistance: '🏆', _CompType.efficiency: '⚡'};
const _vehicleLabel = {_Vehicle.bicycle: '자전거', _Vehicle.motorcycle: '오토바이', _Vehicle.car: '자동차', _Vehicle.all: '전체'};
const _vehicleEmoji = {_Vehicle.bicycle: '🚲', _Vehicle.motorcycle: '🛵', _Vehicle.car: '🚗', _Vehicle.all: '🏁'};

_CompType _parseType(dynamic v) {
  try { return _CompType.values.firstWhere((e) => e.name == v); } catch (_) { return _CompType.efficiency; }
}
_Vehicle _parseVehicle(dynamic v) {
  try { return _Vehicle.values.firstWhere((e) => e.name == v); } catch (_) { return _Vehicle.all; }
}

// ── 메인 화면 ──────────────────────────────────────────────────────────────────

class CompetitionManagementScreen extends StatefulWidget {
  const CompetitionManagementScreen({super.key});

  @override
  State<CompetitionManagementScreen> createState() =>
      _CompetitionManagementScreenState();
}

class _CompetitionManagementScreenState
    extends State<CompetitionManagementScreen>
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
          // ── 헤더 ────────────────────────────────────────────────────────
          Row(
            children: [
              const Text('🏃 달려라 하니 상',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              _primaryBtn('+ 새 대회 만들기', () => _showCreateDialog(context)),
            ],
          ),
          const SizedBox(height: 16),

          // ── 탭 ─────────────────────────────────────────────────────────
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
                Tab(text: '📋  대회 목록'),
                Tab(text: '🏅  리더보드'),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _CompetitionList(db: _db),
                _LeaderboardTab(db: _db),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 새 대회 생성 다이얼로그 ────────────────────────────────────────────────
  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _CreateCompetitionDialog(db: _db),
    );
  }
}

// ── 대회 목록 탭 ──────────────────────────────────────────────────────────────

class _CompetitionList extends StatelessWidget {
  final FirebaseFirestore db;
  const _CompetitionList({required this.db});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('riderCompetitions')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF5C6BC0)));
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('🏃', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 12),
                Text('생성된 대회가 없습니다.',
                    style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }
        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (_, i) => _CompetitionCard(doc: docs[i], db: db),
        );
      },
    );
  }
}

class _CompetitionCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final FirebaseFirestore db;
  const _CompetitionCard({required this.doc, required this.db});

  @override
  Widget build(BuildContext context) {
    final data = doc.data() as Map<String, dynamic>;
    final type = _parseType(data['type']);
    final vehicle = _parseVehicle(data['vehicleType']);
    final isActive = data['isActive'] == true;
    final region = data['region'] as String? ?? '';
    final start = (data['startDate'] as Timestamp?)?.toDate();
    final end = (data['endDate'] as Timestamp?)?.toDate();
    final now = DateTime.now();
    final isRunning = isActive &&
        start != null && end != null &&
        now.isAfter(start) && now.isBefore(end);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF5C6BC0).withOpacity(0.5)
              : Colors.grey.shade900,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_typeEmoji[type]!, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(data['name'] ?? '-',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15)),
              ),
              // 상태 배지
              _statusBadge(isRunning, isActive),
              const SizedBox(width: 8),
              // 활성/비활성 토글
              _toggleSwitch(isActive, doc.id),
            ],
          ),
          const SizedBox(height: 10),
          // 메타 정보
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _chip(_typeLabel[type]!, Colors.indigo),
              if (type == _CompType.longDistance)
                _chip('${_vehicleEmoji[vehicle]} ${_vehicleLabel[vehicle]}',
                    Colors.orange),
              _chip('📍 ${region.isEmpty ? '전국' : region}', Colors.teal),
              _chip(
                '🗓 ${_fmt(start)} → ${_fmt(end)}',
                Colors.grey,
              ),
            ],
          ),
          if ((data['prizeDescription'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('🎁 ${data['prizeDescription']}',
                style: TextStyle(color: Colors.amber.shade300, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _statusBadge(bool isRunning, bool isActive) {
    final label = isRunning ? '진행중' : isActive ? '대기중' : '비활성';
    final color = isRunning ? Colors.green : isActive ? Colors.amber : Colors.grey;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  Widget _toggleSwitch(bool isActive, String docId) {
    return Switch(
      value: isActive,
      activeColor: const Color(0xFF5C6BC0),
      onChanged: (v) =>
          db.collection('riderCompetitions').doc(docId).update({'isActive': v}),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(label,
          style: TextStyle(color: color.withOpacity(0.9), fontSize: 11)),
    );
  }

  String _fmt(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.month}/${dt.day}';
  }
}

// ── 리더보드 탭 ───────────────────────────────────────────────────────────────

class _LeaderboardTab extends StatefulWidget {
  final FirebaseFirestore db;
  const _LeaderboardTab({required this.db});

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  String? _selectedCompId;
  String? _selectedCompName;
  _CompType? _selectedType;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 대회 선택 패널
        SizedBox(
          width: 220,
          child: _CompetitionPicker(
            db: widget.db,
            selectedId: _selectedCompId,
            onSelect: (id, name, type) => setState(() {
              _selectedCompId = id;
              _selectedCompName = name;
              _selectedType = type;
            }),
          ),
        ),
        const SizedBox(width: 12),
        // 리더보드 패널
        Expanded(
          child: _selectedCompId == null
              ? Center(
                  child: Text('← 대회를 선택하세요',
                      style: TextStyle(color: Colors.grey.shade600)))
              : _LeaderboardPanel(
                  db: widget.db,
                  competitionId: _selectedCompId!,
                  competitionName: _selectedCompName ?? '',
                  type: _selectedType ?? _CompType.efficiency,
                ),
        ),
      ],
    );
  }
}

class _CompetitionPicker extends StatelessWidget {
  final FirebaseFirestore db;
  final String? selectedId;
  final void Function(String id, String name, _CompType type) onSelect;
  const _CompetitionPicker(
      {required this.db, this.selectedId, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: db
          .collection('riderCompetitions')
          .where('isActive', isEqualTo: true)
          .orderBy('startDate', descending: true)
          .snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF161B22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade900),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('활성 대회',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
              const Divider(color: Color(0xFF21262D), height: 1),
              ...docs.map((d) {
                final data = d.data() as Map<String, dynamic>;
                final selected = selectedId == d.id;
                return InkWell(
                  onTap: () => onSelect(d.id, data['name'] ?? '',
                      _parseType(data['type'])),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    color: selected
                        ? const Color(0xFF1A237E).withOpacity(0.3)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        Text(_typeEmoji[_parseType(data['type'])]!,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(data['name'] ?? '-',
                              style: TextStyle(
                                  color: selected
                                      ? Colors.white
                                      : Colors.grey.shade400,
                                  fontSize: 12),
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              if (docs.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('활성 대회 없음',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LeaderboardPanel extends StatelessWidget {
  final FirebaseFirestore db;
  final String competitionId;
  final String competitionName;
  final _CompType type;
  const _LeaderboardPanel({
    required this.db,
    required this.competitionId,
    required this.competitionName,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final orderField = type == _CompType.longDistance
        ? 'totalDistanceKm'
        : 'totalDeliveries';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade900),
      ),
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text('${_typeEmoji[type]} $competitionName',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
              ],
            ),
          ),
          // 컬럼 헤더
          _headerRow(type),
          // 데이터
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: db
                  .collection('riderCompetitionEntries')
                  .where('competitionId', isEqualTo: competitionId)
                  .orderBy(orderField, descending: true)
                  .limit(20)
                  .snapshots(),
              builder: (_, snap) {
                if (!snap.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: Color(0xFF5C6BC0)));
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('기록 없음',
                          style: TextStyle(color: Colors.grey)));
                }

                // efficiency는 클라이언트 재정렬
                final entries = docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return _EntryRow.fromMap(data);
                }).toList();

                if (type == _CompType.efficiency) {
                  entries.sort((a, b) =>
                      b.deliveriesPerHour.compareTo(a.deliveriesPerHour));
                }

                return ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, i) =>
                      _dataRow(entries[i], i + 1, type),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerRow(_CompType type) {
    final cols = type == _CompType.longDistance
        ? ['순위', '라이더', '지역', '수단', '총 거리', '']
        : ['순위', '라이더', '지역', '배달수', '시간당', ''];
    return Container(
      color: const Color(0xFF0D1117),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: cols
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(c,
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 11,
                            fontWeight: FontWeight.w600)),
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _dataRow(_EntryRow e, int rank, _CompType type) {
    final medal = rank == 1
        ? '🥇'
        : rank == 2
            ? '🥈'
            : rank == 3
                ? '🥉'
                : '$rank';
    final scoreStr = type == _CompType.longDistance
        ? '${e.distanceKm.toStringAsFixed(1)} km'
        : '${e.deliveries}건';
    final extraStr = type == _CompType.longDistance
        ? _vehicleLabel[_parseVehicle(e.vehicle)] ?? '-'
        : '${e.deliveriesPerHour.toStringAsFixed(1)}/h';

    final cols = type == _CompType.longDistance
        ? [medal, e.name, e.region.isEmpty ? '전국' : e.region, extraStr, scoreStr, '']
        : [medal, e.name, e.region.isEmpty ? '전국' : e.region, scoreStr, extraStr, ''];

    return Container(
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: Colors.grey.shade900, width: 0.5)),
        color: rank <= 3
            ? const Color(0xFF1A237E).withOpacity(0.08)
            : Colors.transparent,
      ),
      child: Row(
        children: cols
            .map((c) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Text(c,
                        style: TextStyle(
                            color: rank <= 3
                                ? Colors.white
                                : Colors.grey.shade300,
                            fontSize: 13)),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _EntryRow {
  final String name;
  final String region;
  final String vehicle;
  final double distanceKm;
  final int deliveries;
  final int workMinutes;

  _EntryRow({
    required this.name,
    required this.region,
    required this.vehicle,
    required this.distanceKm,
    required this.deliveries,
    required this.workMinutes,
  });

  double get deliveriesPerHour =>
      workMinutes > 0 ? deliveries / (workMinutes / 60) : 0;

  factory _EntryRow.fromMap(Map<String, dynamic> m) => _EntryRow(
        name: m['riderName'] as String? ?? '-',
        region: m['region'] as String? ?? '',
        vehicle: m['vehicleType'] as String? ?? 'motorcycle',
        distanceKm: (m['totalDistanceKm'] ?? 0).toDouble(),
        deliveries: (m['totalDeliveries'] ?? 0).toInt(),
        workMinutes: (m['totalWorkMinutes'] ?? 0).toInt(),
      );
}

// ── 새 대회 생성 다이얼로그 ────────────────────────────────────────────────────

class _CreateCompetitionDialog extends StatefulWidget {
  final FirebaseFirestore db;
  const _CreateCompetitionDialog({required this.db});

  @override
  State<_CreateCompetitionDialog> createState() =>
      _CreateCompetitionDialogState();
}

class _CreateCompetitionDialogState
    extends State<_CreateCompetitionDialog> {
  final _nameCtrl = TextEditingController();
  final _prizeCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();

  _CompType _type = _CompType.efficiency;
  _Vehicle _vehicle = _Vehicle.all;
  DateTime _start = DateTime.now();
  DateTime _end = DateTime.now().add(const Duration(days: 30));
  bool _active = false;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _prizeCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF161B22),
      title: const Text('새 대회 만들기',
          style: TextStyle(color: Colors.white, fontSize: 16)),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _field('대회 이름', _nameCtrl, hint: '예: 달려라 하니 상 - 10월'),
              const SizedBox(height: 14),
              // 종류
              _label('종류'),
              Row(
                children: _CompType.values.map((t) {
                  final sel = _type == t;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: _chipToggle(
                          '${_typeEmoji[t]} ${_typeLabel[t]}', sel),
                    ),
                  );
                }).toList(),
              ),
              if (_type == _CompType.longDistance) ...[
                const SizedBox(height: 14),
                _label('이동 수단'),
                Row(
                  children: _Vehicle.values.map((v) {
                    final sel = _vehicle == v;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: GestureDetector(
                        onTap: () => setState(() => _vehicle = v),
                        child: _chipToggle(
                            '${_vehicleEmoji[v]} ${_vehicleLabel[v]}', sel),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
              _field('지역 (비워두면 전국)', _regionCtrl, hint: '예: 서울'),
              const SizedBox(height: 14),
              // 날짜
              _label('기간'),
              Row(
                children: [
                  Expanded(
                      child: _datePick('시작', _start,
                          (d) => setState(() => _start = d))),
                  const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('→',
                          style: TextStyle(color: Colors.grey))),
                  Expanded(
                      child: _datePick('종료', _end,
                          (d) => setState(() => _end = d))),
                ],
              ),
              const SizedBox(height: 14),
              _field('상품 설명', _prizeCtrl, hint: '예: 상위 10명 스타벅스 기프티콘'),
              const SizedBox(height: 14),
              Row(
                children: [
                  Switch(
                    value: _active,
                    activeColor: const Color(0xFF5C6BC0),
                    onChanged: (v) => setState(() => _active = v),
                  ),
                  const SizedBox(width: 8),
                  Text(_active ? '즉시 활성화' : '비활성 (나중에 활성화)',
                      style: TextStyle(
                          color: _active ? Colors.white : Colors.grey,
                          fontSize: 13)),
                ],
              ),
            ],
          ),
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
              : const Text('만들기',
                  style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await widget.db.collection('riderCompetitions').add({
        'name': _nameCtrl.text.trim(),
        'type': _type.name,
        'vehicleType': _vehicle.name,
        'region': _regionCtrl.text.trim(),
        'startDate': Timestamp.fromDate(_start),
        'endDate': Timestamp.fromDate(_end),
        'isActive': _active,
        'prizeDescription': _prizeCtrl.text.trim(),
        'maxRank': 10,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl, {String hint = ''}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        const SizedBox(height: 6),
        TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade700, fontSize: 12),
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
                borderSide:
                    const BorderSide(color: Color(0xFF5C6BC0))),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }

  Widget _datePick(
      String label, DateTime value, ValueChanged<DateTime> onPick) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value,
          firstDate: DateTime(2024),
          lastDate: DateTime(2030),
          builder: (ctx, child) => Theme(
            data: ThemeData.dark(),
            child: child!,
          ),
        );
        if (picked != null) onPick(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1117),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Text(
          '$label: ${value.month}/${value.day}',
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: TextStyle(color: Colors.grey.shade400, fontSize: 12));

  Widget _chipToggle(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: selected
            ? const Color(0xFF1A237E)
            : const Color(0xFF0D1117),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: selected
                ? const Color(0xFF5C6BC0)
                : Colors.grey.shade800),
      ),
      child: Text(label,
          style: TextStyle(
              color: selected ? Colors.white : Colors.grey.shade500,
              fontSize: 12)),
    );
  }
}

// ── 공통 ──────────────────────────────────────────────────────────────────────

Widget _primaryBtn(String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1A237E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF5C6BC0).withOpacity(0.5)),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
    ),
  );
}
