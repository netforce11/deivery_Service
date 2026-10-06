import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/store_model.dart';
import '../../services/order_service.dart';
import '../../services/weather_surcharge_service.dart';
import '../../services/weather_service.dart';
import '../events/store_events_screen.dart';
import '../achievements/store_achievements_screen.dart';

class StoreSettingsScreen extends StatefulWidget {
  final StoreModel store;
  const StoreSettingsScreen({super.key, required this.store});

  @override
  State<StoreSettingsScreen> createState() => _StoreSettingsScreenState();
}

class _StoreSettingsScreenState extends State<StoreSettingsScreen> {
  final _svc = OrderService();
  final _weatherSvc = WeatherSurchargeService();
  late StoreModel _store;
  Timer? _surchargeTimer;

  @override
  void initState() {
    super.initState();
    _store = widget.store;
    _checkSurchargeExpiry();
  }

  @override
  void dispose() {
    _surchargeTimer?.cancel();
    super.dispose();
  }

  /// 할증 만료 체크 및 자동 해제
  void _checkSurchargeExpiry() {
    _surchargeTimer?.cancel();
    if (_store.weatherSurchargeActive && _store.weatherSurchargeExpiry != null) {
      final remaining = _store.weatherSurchargeExpiry!.difference(DateTime.now());
      if (remaining.isNegative) {
        _weatherSvc.deactivateSurcharge();
        setState(() => _store = _store.copyWith(weatherSurchargeActive: false, clearExpiry: true));
      } else {
        _surchargeTimer = Timer(remaining, () async {
          await _weatherSvc.deactivateSurcharge();
          if (mounted) setState(() => _store = _store.copyWith(weatherSurchargeActive: false, clearExpiry: true));
        });
      }
    }
  }

  /// 날씨 확인 후 할증 다이얼로그
  Future<void> _checkWeatherAndShowDialog() async {
    if (!_store.weatherSurchargeEnabled) return;
    final pty = await WeatherService.getCurrentPrecipitation(_store.lat, _store.lng);
    if (!mounted) return;
    if (!WeatherService.isRaining(pty) && !WeatherService.isSnowing(pty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('현재 날씨가 맑아서 할증이 필요하지 않아요'), backgroundColor: Colors.blue),
      );
      return;
    }
    _showWeatherSurchargeDialog(WeatherService.weatherLabel(pty));
  }

  /// 날씨 할증 수락/거절 다이얼로그
  void _showWeatherSurchargeDialog(String weatherLabel) {
    final amount = _store.weatherSurchargeAmount;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            const Text('🌧️ ', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 4),
            Text('현재 $weatherLabel가 내리고 있습니다',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('30분간 라이더 배달비 +${_fmtAmount(amount)}원을 추가하시겠습니까?',
                style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                '⚠️ 수락 후 30분간은 변경이 불가합니다.',
                style: TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('이번엔 괜찮아요', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(context);
              await _weatherSvc.activateSurcharge(amount: amount);
              final expiry = DateTime.now().add(const Duration(minutes: 30));
              if (mounted) {
                setState(() => _store = _store.copyWith(
                  weatherSurchargeActive: true,
                  weatherSurchargeExpiry: expiry,
                ));
                _checkSurchargeExpiry();
              }
            },
            child: const Text('30분 추가할게요'),
          ),
        ],
      ),
    );
  }

  String _fmtAmount(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

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
          // ── 사장님 보상 ────────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.emoji_events_outlined,
            title: '사장님 보상',
            subtitle: '주문왕·럭키 번호 보너스 등 달성 현황',
            subtitleColor: Colors.amber.shade700,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StoreAchievementsScreen())),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const SizedBox(height: 12),

          // ── 이벤트 관리 ────────────────────────────────────────────────────────
          _SectionCard(
            icon: Icons.celebration_outlined,
            title: '이벤트 관리',
            subtitle: '타임어택·럭키오더·챌린지 이벤트 열기',
            subtitleColor: Colors.orange.shade700,
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const StoreEventsScreen())),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
          ),
          const SizedBox(height: 12),

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
          const SizedBox(height: 12),

          // ── 날씨 할증 ──────────────────────────────────────────────────────────
          _WeatherSurchargeCard(
            store: _store,
            weatherSvc: _weatherSvc,
            surchargeTimer: _surchargeTimer,
            onCheckWeather: _checkWeatherAndShowDialog,
            onToggleEnabled: (enabled) async {
              await _weatherSvc.setWeatherSurchargeEnabled(enabled);
            },
            onEditAmount: () async {
              final ctrl = TextEditingController(
                  text: _store.weatherSurchargeAmount.toString());
              final result = await showDialog<int>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('할증 금액 설정'),
                  content: TextField(
                    controller: ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: '금액 (원)', suffix: Text('원')),
                  ),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('취소')),
                    TextButton(
                        onPressed: () {
                          final v = int.tryParse(ctrl.text);
                          if (v != null && v > 0) Navigator.pop(context, v);
                        },
                        child: const Text('저장')),
                  ],
                ),
              );
              if (result != null) await _weatherSvc.setSurchargeAmount(result);
            },
          ),
        ],
      ),
    );
  }
}

// ── 날씨 할증 카드 ────────────────────────────────────────────────────────────
class _WeatherSurchargeCard extends StatefulWidget {
  final StoreModel store;
  final WeatherSurchargeService weatherSvc;
  final Timer? surchargeTimer;
  final VoidCallback onCheckWeather;
  final ValueChanged<bool> onToggleEnabled;
  final VoidCallback onEditAmount;

  const _WeatherSurchargeCard({
    required this.store,
    required this.weatherSvc,
    required this.surchargeTimer,
    required this.onCheckWeather,
    required this.onToggleEnabled,
    required this.onEditAmount,
  });

  @override
  State<_WeatherSurchargeCard> createState() => _WeatherSurchargeCardState();
}

class _WeatherSurchargeCardState extends State<_WeatherSurchargeCard> {
  Timer? _countdownTimer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void didUpdateWidget(_WeatherSurchargeCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    final expiry = widget.store.weatherSurchargeExpiry;
    if (expiry == null || !widget.store.weatherSurchargeActive) return;
    _remaining = expiry.difference(DateTime.now());
    if (_remaining.isNegative) return;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _remaining = expiry.difference(DateTime.now());
        if (_remaining.isNegative) {
          _remaining = Duration.zero;
          _countdownTimer?.cancel();
        }
      });
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  String _fmtCountdown(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.umbrella_outlined,
                      color: Colors.blue, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('날씨 할증',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15)),
                      Text('비/눈 시 라이더 배달비 자동 알림',
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                Switch(
                  value: s.weatherSurchargeEnabled,
                  onChanged: widget.onToggleEnabled,
                  activeColor: Colors.blue,
                ),
              ],
            ),

            if (s.weatherSurchargeEnabled) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // 현재 상태
              if (s.weatherSurchargeActive && _remaining > Duration.zero) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt,
                          color: Colors.orange, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '할증 적용 중 · +${s.weatherSurchargeAmount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}원',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange),
                        ),
                      ),
                      Text(
                        '남은시간 ${_fmtCountdown(_remaining)}',
                        style: TextStyle(
                            fontSize: 12, color: Colors.orange.shade700),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Row(
                  children: [
                    const Icon(Icons.circle,
                        color: Colors.grey, size: 10),
                    const SizedBox(width: 6),
                    Text(
                      '대기 중 · 할증 금액: ${s.weatherSurchargeAmount.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',')}원',
                      style: const TextStyle(
                          color: Colors.grey, fontSize: 13),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: widget.onEditAmount,
                      icon: const Icon(Icons.edit, size: 14),
                      label: const Text('금액 변경',
                          style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 10),

              // 날씨 확인 버튼
              if (!s.weatherSurchargeActive)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: widget.onCheckWeather,
                    icon: const Icon(Icons.cloud_outlined, size: 18),
                    label: const Text('지금 날씨 확인'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blue,
                      side: const BorderSide(color: Colors.blue),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
            ],
          ],
        ),
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
