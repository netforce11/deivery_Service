import 'package:flutter/material.dart';
import '../../models/store_model.dart';
import '../../services/order_service.dart';

class StoreSettingsScreen extends StatefulWidget {
  final StoreModel store;
  const StoreSettingsScreen({super.key, required this.store});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _svc = OrderService();
  late StoreModel _store;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
  }

  // ── 공지사항 편집 ────────────────────────────────────────────────────────────
  Future<void> _editNotice() async {
    final ctrl = TextEditingController(text: _store.notice);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('공지사항 편집'),
        content: TextField(
          controller: ctrl,
          maxLines: 4,
          maxLength: 200,
          decoration: const InputDecoration(
            hintText: '예) 오늘 재료 소진으로 양념치킨 품절입니다.',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('저장'),
          ),
        ],
      ),
    );
    if (result != null) {
      await _svc.updateNotice(_store.id, result);
      setState(() => _store = _store.copyWith(notice: result));
    }
  }

  // ── 예상 조리시간 변경 ────────────────────────────────────────────────────────
  Future<void> _editEstimatedTime() async {
    int selected = _store.estimatedMinutes;
    final options = [10, 15, 20, 25, 30, 40, 50, 60, 90];

    final result = await showDialog<int>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('예상 조리시간'),
          content: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((min) {
              final isSelected = selected == min;
              return ChoiceChip(
                label: Text('$min분'),
                selected: isSelected,
                selectedColor: Colors.indigo,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
                onSelected: (_) => setState(() => selected = min),
              );
            }).toList(),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, selected),
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
    if (result != null) {
      await _svc.updateEstimatedMinutes(_store.id, result);
      setState(() => _store = _store.copyWith(estimatedMinutes: result));
    }
  }

  // ── 영업시간 설정 ─────────────────────────────────────────────────────────────
  Future<void> _editBusinessHours() async {
    final days = ['월', '화', '수', '목', '금', '토', '일'];
    final hours = Map<String, Map<String, String>>.from(
      _store.businessHours.map((k, v) => MapEntry(k, Map<String, String>.from(v))),
    );
    // 없는 요일 기본값 채우기
    for (final d in days) {
      hours.putIfAbsent(d, () => {'open': '09:00', 'close': '22:00', 'closed': 'false'});
    }

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('영업시간 설정'),
          contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          content: SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: days.map((day) {
                  final isClosed = hours[day]!['closed'] == 'true';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(day,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: isClosed
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('휴무',
                                      style: TextStyle(color: Colors.grey.shade500)),
                                )
                              : Row(
                                  children: [
                                    _TimeButton(
                                      time: hours[day]!['open']!,
                                      onTap: () async {
                                        final t = await _pickTime(
                                            ctx, hours[day]!['open']!);
                                        if (t != null) {
                                          setState(() => hours[day]!['open'] = t);
                                        }
                                      },
                                    ),
                                    const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 6),
                                      child: Text('~',
                                          style: TextStyle(color: Colors.grey)),
                                    ),
                                    _TimeButton(
                                      time: hours[day]!['close']!,
                                      onTap: () async {
                                        final t = await _pickTime(
                                            ctx, hours[day]!['close']!);
                                        if (t != null) {
                                          setState(() => hours[day]!['close'] = t);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => setState(() {
                            hours[day]!['closed'] =
                                isClosed ? 'false' : 'true';
                          }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isClosed
                                  ? Colors.red.shade50
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isClosed
                                    ? Colors.red.shade200
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Text(
                              '휴무',
                              style: TextStyle(
                                fontSize: 11,
                                color: isClosed
                                    ? Colors.red.shade700
                                    : Colors.grey,
                                fontWeight: isClosed
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                await _svc.updateBusinessHours(_store.id, hours);
                if (mounted) {
                  setState(() => _store = _store.copyWith(businessHours: hours));
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _pickTime(BuildContext ctx, String current) async {
    final parts = current.split(':');
    final init = TimeOfDay(
        hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(context: ctx, initialTime: init);
    if (picked == null) return null;
    return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final days = ['월', '화', '수', '목', '금', '토', '일'];

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('가게 설정', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(_store.name, style: TextStyle(fontSize: 12, color: Colors.indigo.shade100)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── 공지사항 ──────────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.campaign_outlined,
            title: '공지사항',
            subtitle: _store.notice.isEmpty ? '공지사항을 입력해보세요' : _store.notice,
            subtitleColor: _store.notice.isEmpty ? Colors.grey : Colors.black87,
            onTap: _editNotice,
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // ── 예상 조리시간 ──────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.timer_outlined,
            title: '예상 조리시간',
            subtitle: '${_store.estimatedMinutes}분',
            subtitleColor: Colors.indigo,
            onTap: _editEstimatedTime,
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // ── 영업시간 ──────────────────────────────────────────────────────────
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 1,
            child: InkWell(
              onTap: _editBusinessHours,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.access_time,
                              color: Colors.indigo, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('영업시간',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey),
                      ],
                    ),
                    if (_store.businessHours.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      ...days.where((d) => _store.businessHours.containsKey(d)).map((day) {
                        final h = _store.businessHours[day]!;
                        final isClosed = h['closed'] == 'true';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(day,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                        color: (day == '토')
                                            ? Colors.blue
                                            : (day == '일')
                                                ? Colors.red
                                                : Colors.black87)),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                isClosed
                                    ? '휴무'
                                    : '${h['open']} ~ ${h['close']}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isClosed
                                      ? Colors.grey
                                      : Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ] else ...[
                      const SizedBox(height: 8),
                      Text('영업시간을 설정해보세요',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 공통 설정 카드 ────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color subtitleColor;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.subtitleColor,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.indigo, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: TextStyle(
                            color: subtitleColor, fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

// ── 시간 선택 버튼 ───────────────────────────────────────────────────────────
class _TimeButton extends StatelessWidget {
  final String time;
  final VoidCallback onTap;

  const _TimeButton({required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.indigo.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.indigo.shade200),
        ),
        child: Text(time,
            style: const TextStyle(
                color: Colors.indigo,
                fontWeight: FontWeight.bold,
                fontSize: 13)),
      ),
    );
  }
}
