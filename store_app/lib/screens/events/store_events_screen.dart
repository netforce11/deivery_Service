import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/store_event_model.dart';
import '../../services/store_event_service.dart';

class StoreEventsScreen extends StatefulWidget {
  const StoreEventsScreen({super.key});

  @override
  State<StoreEventsScreen> createState() => _StoreEventsScreenState();
}

class _StoreEventsScreenState extends State<StoreEventsScreen> {
  final _service = StoreEventService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text('이벤트 관리',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.add, color: Colors.amber, size: 18),
            label: const Text('이벤트 열기',
                style: TextStyle(color: Colors.amber, fontSize: 13)),
            onPressed: _showEventPicker,
          ),
        ],
      ),
      body: StreamBuilder<List<StoreEventModel>>(
        stream: _service.watchAllEvents(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.amber));
          }

          final events = snap.data ?? [];
          final active = events.where((e) => e.isActive).toList();
          final past = events.where((e) => !e.isActive).toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 활성 이벤트 ───────────────────────────────────────────
              if (active.isNotEmpty) ...[
                _SectionTitle('활성 이벤트', Colors.greenAccent),
                const SizedBox(height: 10),
                ...active.map((e) => _ActiveEventCard(
                      event: e,
                      onEnd: () => _service.endEvent(e.id),
                    )),
                const SizedBox(height: 20),
              ],

              // ── 이벤트 없을 때 ────────────────────────────────────────
              if (active.isEmpty) ...[
                _EmptyState(onTap: _showEventPicker),
                const SizedBox(height: 20),
              ],

              // ── 이벤트 성과 요약 ──────────────────────────────────────
              if (events.isNotEmpty) ...[
                _SectionTitle('이벤트 성과', Colors.white60),
                const SizedBox(height: 10),
                _PerformanceSummary(events: events),
                const SizedBox(height: 20),
              ],

              // ── 지난 이벤트 ───────────────────────────────────────────
              if (past.isNotEmpty) ...[
                _SectionTitle('지난 이벤트', Colors.white38),
                const SizedBox(height: 10),
                ...past.take(5).map((e) => _PastEventTile(event: e)),
              ],
            ],
          );
        },
      ),
    );
  }

  void _showEventPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C2128),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _EventPickerSheet(service: _service),
    );
  }
}

// ── 섹션 타이틀 ──────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionTitle(this.text, this.color);

  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.bold,
          letterSpacing: 1));
}

// ── 이벤트 없을 때 빈 상태 ───────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onTap;
  const _EmptyState({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.amber.withOpacity(0.3),
              style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            const Text('✨', style: TextStyle(fontSize: 36)),
            const SizedBox(height: 12),
            const Text('진행 중인 이벤트가 없어요',
                style: TextStyle(color: Colors.white70, fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('이벤트를 열면 고객 앱에 뱃지가 표시돼요',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.add, size: 16),
              label: const Text('첫 이벤트 열기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.amber,
                side: const BorderSide(color: Colors.amber),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: onTap,
            )
          ],
        ),
      ),
    );
  }
}

// ── 활성 이벤트 카드 ─────────────────────────────────────────────────────────

class _ActiveEventCard extends StatefulWidget {
  final StoreEventModel event;
  final VoidCallback onEnd;

  const _ActiveEventCard({required this.event, required this.onEnd});

  @override
  State<_ActiveEventCard> createState() => _ActiveEventCardState();
}

class _ActiveEventCardState extends State<_ActiveEventCard> {
  Timer? _timer;
  Duration? _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = widget.event.remaining;
    if (_remaining != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _remaining = widget.event.remaining);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Color get _typeColor {
    switch (widget.event.type) {
      case EventType.flashSale:     return Colors.redAccent;
      case EventType.luckyOrder:    return Colors.greenAccent;
      case EventType.challenge:     return Colors.amber;
      case EventType.welcomeCoupon: return Colors.purpleAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.event;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _typeColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _typeColor.withOpacity(0.15),
              blurRadius: 12,
              spreadRadius: 1),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Row(
            children: [
              Text(e.type.emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 8),
              Text(e.type.label,
                  style: TextStyle(
                      color: _typeColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              // 남은 시간
              if (_remaining != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _typeColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _formatDuration(_remaining!),
                    style: TextStyle(
                        color: _typeColor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // 이벤트 상세
          _buildDetail(e),

          const SizedBox(height: 12),
          // 종료 버튼
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: widget.onEnd,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white54,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('이벤트 종료', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetail(StoreEventModel e) {
    switch (e.type) {
      case EventType.flashSale:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${e.discountPercent}% 할인 진행 중',
                style: const TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            if (e.maxParticipants != null)
              _ProgressBar(
                current: e.participantCount,
                max: e.maxParticipants!,
                color: Colors.redAccent,
                label: '${e.participantCount}/${e.maxParticipants}명 참여',
              ),
          ],
        );

      case EventType.luckyOrder:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(children: [
                TextSpan(
                    text: '${e.luckyOrderNumber}번째 ',
                    style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const TextSpan(
                    text: '주문자에게',
                    style: TextStyle(color: Colors.white70, fontSize: 15)),
              ]),
            ),
            const SizedBox(height: 4),
            Text(e.luckyReward ?? '',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text('현재 ${e.participantCount}건 주문 접수',
                style: TextStyle(
                    color: Colors.grey.shade500, fontSize: 12)),
          ],
        );

      case EventType.challenge:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('목표: ${e.targetOrders}건 달성',
                style: const TextStyle(
                    color: Colors.white, fontSize: 15,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            _ProgressBar(
              current: e.currentOrders,
              max: e.targetOrders ?? 1,
              color: Colors.amber,
              label:
                  '${e.currentOrders}/${e.targetOrders}건 · ${e.challengeReward}',
            ),
          ],
        );

      case EventType.welcomeCoupon:
        return Text(
          '첫 주문 고객에게 ${e.welcomeDiscountPercent}% 자동 할인',
          style: const TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        );
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m.toString().padLeft(2, '0')}m';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── 진행바 ────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int current;
  final int max;
  final Color color;
  final String label;

  const _ProgressBar(
      {required this.current,
      required this.max,
      required this.color,
      required this.label});

  @override
  Widget build(BuildContext context) {
    final ratio = (current / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ],
    );
  }
}

// ── 성과 요약 ─────────────────────────────────────────────────────────────────

class _PerformanceSummary extends StatelessWidget {
  final List<StoreEventModel> events;
  const _PerformanceSummary({required this.events});

  @override
  Widget build(BuildContext context) {
    final total = events.length;
    final flashCount = events.where((e) => e.type == EventType.flashSale).length;
    final totalParticipants =
        events.fold(0, (sum, e) => sum + e.participantCount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('진행한 이벤트', '$total회', Colors.amber),
          _Divider(),
          _Stat('타임어택', '$flashCount회', Colors.redAccent),
          _Divider(),
          _Stat('총 참여', '$totalParticipants명', Colors.cyanAccent),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        ],
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      width: 1, height: 32, color: Colors.white12);
}

// ── 지난 이벤트 타일 ──────────────────────────────────────────────────────────

class _PastEventTile extends StatelessWidget {
  final StoreEventModel event;
  const _PastEventTile({required this.event});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(event.type.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(event.type.label,
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.bold,
                        fontSize: 13)),
                Text(
                  _summary(event),
                  style: TextStyle(
                      color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          Text(
            _dateLabel(event.startAt),
            style: TextStyle(color: Colors.grey.shade700, fontSize: 11),
          ),
        ],
      ),
    );
  }

  String _summary(StoreEventModel e) {
    switch (e.type) {
      case EventType.flashSale:
        return '${e.discountPercent}% 할인 · ${e.participantCount}명 참여';
      case EventType.luckyOrder:
        return '${e.luckyOrderNumber}번째 당첨 · ${e.luckyReward}';
      case EventType.challenge:
        return '${e.currentOrders}/${e.targetOrders}건 달성';
      case EventType.welcomeCoupon:
        return '첫 주문 ${e.welcomeDiscountPercent}% 할인';
    }
  }

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${diff}일 전';
  }
}

// ── 이벤트 선택 바텀시트 ──────────────────────────────────────────────────────

class _EventPickerSheet extends StatelessWidget {
  final StoreEventService service;
  const _EventPickerSheet({required this.service});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),
          const Text('어떤 이벤트를 열까요?',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _EventOption(
            emoji: '⚡',
            title: '타임어택 할인',
            desc: '제한 시간 동안 X% 할인 — 고객 앱에 빨간 뱃지 표시',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(context);
              _showFlashSaleDialog(context);
            },
          ),
          _EventOption(
            emoji: '🍀',
            title: '럭키 오더',
            desc: 'N번째 주문자에게 깜짝 혜택 — 기대감 유발',
            color: Colors.greenAccent,
            onTap: () {
              Navigator.pop(context);
              _showLuckyOrderDialog(context);
            },
          ),
          _EventOption(
            emoji: '🏆',
            title: '오늘의 챌린지',
            desc: '목표 주문 수 달성 시 수수료 혜택 — 가게 동기부여',
            color: Colors.amber,
            onTap: () {
              Navigator.pop(context);
              _showChallengeDialog(context);
            },
          ),
          _EventOption(
            emoji: '🎁',
            title: '웰컴 쿠폰',
            desc: '첫 주문 고객 자동 할인 — 신규 고객 유치',
            color: Colors.purpleAccent,
            onTap: () {
              Navigator.pop(context);
              service.toggleWelcomeCoupon(enable: true, discountPercent: 10);
            },
          ),
        ],
      ),
    );
  }

  void _showFlashSaleDialog(BuildContext context) {
    int discount = 10;
    int duration = 30;
    showDialog(
      context: context,
      builder: (_) => _QuickDialog(
        title: '⚡ 타임어택 설정',
        color: Colors.redAccent,
        fields: [
          _SliderField(
            label: '할인율',
            value: discount.toDouble(),
            min: 5, max: 50, divisions: 9,
            format: (v) => '${v.round()}%',
            onChanged: (v) => discount = v.round(),
          ),
          _SliderField(
            label: '진행 시간',
            value: duration.toDouble(),
            min: 10, max: 120, divisions: 11,
            format: (v) => '${v.round()}분',
            onChanged: (v) => duration = v.round(),
          ),
        ],
        onConfirm: () => service.startFlashSale(
            discountPercent: discount, durationMinutes: duration),
      ),
    );
  }

  void _showLuckyOrderDialog(BuildContext context) {
    int orderNumber = 10;
    String reward = '배달비 무료';
    final rewards = ['배달비 무료', '10% 할인', '음료 서비스', '사장님 선물'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: const Color(0xFF1C2128),
          title: const Text('🍀 럭키 오더 설정',
              style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('몇 번째 주문자에게 혜택을 드릴까요?',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.white54),
                    onPressed: () =>
                        setSt(() => orderNumber = (orderNumber - 5).clamp(5, 50)),
                  ),
                  Text('$orderNumber번째',
                      style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 22,
                          fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.white54),
                    onPressed: () =>
                        setSt(() => orderNumber = (orderNumber + 5).clamp(5, 50)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rewards.map((r) {
                  final selected = r == reward;
                  return GestureDetector(
                    onTap: () => setSt(() => reward = r),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? Colors.greenAccent.withOpacity(0.2)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: selected
                                ? Colors.greenAccent
                                : Colors.white24),
                      ),
                      child: Text(r,
                          style: TextStyle(
                              color:
                                  selected ? Colors.greenAccent : Colors.white70,
                              fontSize: 13)),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('취소',
                    style: TextStyle(color: Colors.white54))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black),
              onPressed: () {
                service.startLuckyOrder(
                    luckyOrderNumber: orderNumber, reward: reward);
                Navigator.pop(ctx);
              },
              child: const Text('시작'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChallengeDialog(BuildContext context) {
    int target = 20;
    showDialog(
      context: context,
      builder: (_) => _QuickDialog(
        title: '🏆 챌린지 설정',
        color: Colors.amber,
        fields: [
          _SliderField(
            label: '오늘 목표 건수',
            value: target.toDouble(),
            min: 5, max: 50, divisions: 9,
            format: (v) => '${v.round()}건',
            onChanged: (v) => target = v.round(),
          ),
        ],
        onConfirm: () => service.startChallenge(
            targetOrders: target, reward: '수수료 1% 감면'),
      ),
    );
  }
}

class _EventOption extends StatelessWidget {
  final String emoji;
  final String title;
  final String desc;
  final Color color;
  final VoidCallback onTap;

  const _EventOption({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(desc,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, color: color, size: 14),
          ],
        ),
      ),
    );
  }
}

// ── 간단 슬라이더 다이얼로그 ──────────────────────────────────────────────────

class _SliderField {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) format;
  final void Function(double) onChanged;

  _SliderField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.format,
    required this.onChanged,
  });
}

class _QuickDialog extends StatefulWidget {
  final String title;
  final Color color;
  final List<_SliderField> fields;
  final VoidCallback onConfirm;

  const _QuickDialog({
    required this.title,
    required this.color,
    required this.fields,
    required this.onConfirm,
  });

  @override
  State<_QuickDialog> createState() => _QuickDialogState();
}

class _QuickDialogState extends State<_QuickDialog> {
  late List<double> _values;

  @override
  void initState() {
    super.initState();
    _values = widget.fields.map((f) => f.value).toList();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C2128),
      title: Text(widget.title,
          style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.fields.length, (i) {
          final f = widget.fields[i];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(f.label,
                      style: TextStyle(
                          color: Colors.grey.shade400, fontSize: 13)),
                  Text(f.format(_values[i]),
                      style: TextStyle(
                          color: widget.color,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: widget.color,
                  thumbColor: widget.color,
                  inactiveTrackColor: Colors.white12,
                  overlayColor: widget.color.withOpacity(0.2),
                ),
                child: Slider(
                  value: _values[i],
                  min: f.min,
                  max: f.max,
                  divisions: f.divisions,
                  onChanged: (v) {
                    setState(() => _values[i] = v);
                    f.onChanged(v);
                  },
                ),
              ),
              const SizedBox(height: 8),
            ],
          );
        }),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소',
                style: TextStyle(color: Colors.white54))),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: widget.color,
              foregroundColor: Colors.black),
          onPressed: () {
            widget.onConfirm();
            Navigator.pop(context);
          },
          child: const Text('이벤트 시작'),
        ),
      ],
    );
  }
}
