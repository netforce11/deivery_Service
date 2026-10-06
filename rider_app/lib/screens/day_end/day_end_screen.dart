import 'dart:math';
import 'package:flutter/material.dart';
import '../../models/rider_point_model.dart';

/// 배달 종료 시 하이라이트 화면 — 오늘의 성과를 게임 클리어 화면처럼 보여줌
class DayEndScreen extends StatefulWidget {
  final int todayEarnings;       // 오늘 총 수입 (원)
  final int completedOrders;     // 완료 건수
  final int todayPoints;         // 오늘 획득 포인트
  final int totalPoints;         // 누적 포인트
  final String grade;            // BRONZE / SILVER / GOLD
  final int consecutiveDays;     // 연속 출근일
  final List<PointHistoryEntry> todayHistory; // 오늘 포인트 내역
  final int boosterCharges;      // 남은 부스터 충전 수

  const DayEndScreen({
    super.key,
    required this.todayEarnings,
    required this.completedOrders,
    required this.todayPoints,
    required this.totalPoints,
    required this.grade,
    required this.consecutiveDays,
    required this.todayHistory,
    required this.boosterCharges,
  });

  @override
  State<DayEndScreen> createState() => _DayEndScreenState();
}

class _DayEndScreenState extends State<DayEndScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeCtrl;
  late AnimationController _scaleCtrl;
  late AnimationController _countCtrl;
  late Animation<double> _fade;
  late Animation<double> _scale;

  // 카운트업 애니메이션용 값
  int _displayEarnings = 0;
  int _displayPoints = 0;

  @override
  void initState() {
    super.initState();

    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _countCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500));

    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _scale = CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut);

    _countCtrl.addListener(() {
      setState(() {
        _displayEarnings =
            (widget.todayEarnings * _countCtrl.value).round();
        _displayPoints =
            (widget.todayPoints * _countCtrl.value).round();
      });
    });

    // 순서대로 등장
    Future.delayed(const Duration(milliseconds: 200), () {
      _fadeCtrl.forward();
      _scaleCtrl.forward();
      _countCtrl.forward();
    });
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _scaleCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Color get _gradeColor {
    switch (widget.grade) {
      case 'GOLD':   return const Color(0xFFFFD700);
      case 'SILVER': return const Color(0xFFB0BEC5);
      default:       return const Color(0xFFCD7F32); // BRONZE
    }
  }

  String get _gradeEmoji {
    switch (widget.grade) {
      case 'GOLD':   return '🏆';
      case 'SILVER': return '🥈';
      default:       return '🥉';
    }
  }

  String get _encouragement {
    if (widget.completedOrders >= 20) return '오늘도 완벽한 하루! 🔥';
    if (widget.completedOrders >= 10) return '훌륭한 하루였어요! 💪';
    if (widget.todayPoints >= 5)      return '포인트 착실히 쌓았네요! ⚡';
    if (widget.consecutiveDays >= 7)  return '${widget.consecutiveDays}일 연속 출근! 대단해요!';
    return '오늘도 수고하셨어요! 🙌';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ── 상단 헤더 ──────────────────────────────────────────────
                ScaleTransition(
                  scale: _scale,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 28, horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _gradeColor.withOpacity(0.3),
                          _gradeColor.withOpacity(0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: _gradeColor.withOpacity(0.4), width: 1.5),
                    ),
                    child: Column(
                      children: [
                        Text(_gradeEmoji,
                            style: const TextStyle(fontSize: 48)),
                        const SizedBox(height: 8),
                        Text(
                          '오늘 하루 종료',
                          style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 13,
                              letterSpacing: 2),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _encouragement,
                          style: TextStyle(
                              color: _gradeColor,
                              fontSize: 20,
                              fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ── 수입 / 건수 ────────────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: '오늘 수입',
                        value:
                            '${_numberWithComma(_displayEarnings)}원',
                        icon: Icons.monetization_on_rounded,
                        color: Colors.greenAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: '완료 건수',
                        value: '${widget.completedOrders}건',
                        icon: Icons.check_circle_outline,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // ── 포인트 획득 ────────────────────────────────────────────
                _PointGainCard(
                  todayPoints: _displayPoints,
                  totalPoints: widget.totalPoints,
                  grade: widget.grade,
                  gradeColor: _gradeColor,
                  boosterCharges: widget.boosterCharges,
                ),

                const SizedBox(height: 12),

                // ── 연속 출근 스트릭 ───────────────────────────────────────
                _StreakCard(consecutiveDays: widget.consecutiveDays),

                const SizedBox(height: 12),

                // ── 오늘 포인트 내역 ───────────────────────────────────────
                if (widget.todayHistory.isNotEmpty)
                  _PointHistoryCard(history: widget.todayHistory),

                const SizedBox(height: 24),

                // ── 닫기 버튼 ──────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _gradeColor,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '확인',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _numberWithComma(int n) {
    return n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }
}

// ── 개별 위젯들 ──────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 10),
          Text(label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value,
              style: TextStyle(
                  color: color,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _PointGainCard extends StatelessWidget {
  final int todayPoints;
  final int totalPoints;
  final String grade;
  final Color gradeColor;
  final int boosterCharges;

  const _PointGainCard({
    required this.todayPoints,
    required this.totalPoints,
    required this.grade,
    required this.gradeColor,
    required this.boosterCharges,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bolt, color: Colors.amber, size: 20),
              const SizedBox(width: 6),
              const Text('포인트 성과',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: gradeColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: gradeColor.withOpacity(0.5)),
                ),
                child: Text(
                  grade,
                  style: TextStyle(
                      color: gradeColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _PointPill(
                label: '오늘 획득',
                value: '+$todayPoints pt',
                color: Colors.amber,
              ),
              const SizedBox(width: 12),
              _PointPill(
                label: '누적 포인트',
                value: '$totalPoints pt',
                color: Colors.white70,
              ),
              if (boosterCharges > 0) ...[
                const SizedBox(width: 12),
                _PointPill(
                  label: '부스터',
                  value: '⚡ ${boosterCharges}회',
                  color: Colors.cyanAccent,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PointPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _PointPill(
      {required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 15,
                fontWeight: FontWeight.bold)),
      ],
    );
  }
}

class _StreakCard extends StatelessWidget {
  final int consecutiveDays;

  const _StreakCard({required this.consecutiveDays});

  @override
  Widget build(BuildContext context) {
    final milestone = consecutiveDays % 7;
    final toNext = 7 - milestone;
    final progress = milestone / 7.0;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.deepOrangeAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('연속 출근 스트릭',
                  style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                '$consecutiveDays일째',
                style: const TextStyle(
                    color: Colors.deepOrangeAccent,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 7칸 박스 진행도
          Row(
            children: List.generate(7, (i) {
              final filled = i < (consecutiveDays % 7 == 0 && consecutiveDays > 0
                  ? 7
                  : consecutiveDays % 7);
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  height: 8,
                  decoration: BoxDecoration(
                    color: filled
                        ? Colors.deepOrangeAccent
                        : Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            consecutiveDays % 7 == 0 && consecutiveDays > 0
                ? '🎉 7일 달성! 보너스 포인트 적립!'
                : '7일 연속 보너스까지 앞으로 ${toNext}일',
            style: TextStyle(
                color: consecutiveDays % 7 == 0
                    ? Colors.amber
                    : Colors.grey.shade500,
                fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PointHistoryCard extends StatelessWidget {
  final List<PointHistoryEntry> history;

  const _PointHistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('오늘 획득한 포인트',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          ...history.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle_outline,
                        color: Colors.amber, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.reason.label,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ),
                    Text('+${e.points} pt',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontSize: 13,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
