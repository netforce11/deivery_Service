import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/rider_point_model.dart';
import '../../services/rider_point_service.dart';

class RiderPointsScreen extends StatefulWidget {
  const RiderPointsScreen({super.key});

  @override
  State<RiderPointsScreen> createState() => _RiderPointsScreenState();
}

class _RiderPointsScreenState extends State<RiderPointsScreen>
    with TickerProviderStateMixin {
  final _svc = RiderPointService();
  late AnimationController _boosterPulse;
  Timer? _boosterCountdown;
  Duration _boosterRemaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _boosterPulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _svc.resetDailyIfNeeded();
    _svc.expireBoosterIfNeeded();
  }

  @override
  void dispose() {
    _boosterPulse.dispose();
    _boosterCountdown?.cancel();
    super.dispose();
  }

  void _startBoosterTimer(Duration remaining) {
    _boosterCountdown?.cancel();
    _boosterRemaining = remaining;
    _boosterCountdown = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_boosterRemaining.inSeconds > 0) {
          _boosterRemaining -= const Duration(seconds: 1);
        } else {
          _boosterCountdown?.cancel();
        }
      });
    });
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Color _gradeColor(String grade) {
    switch (grade) {
      case 'GOLD':   return const Color(0xFFFFD700);
      case 'SILVER': return const Color(0xFFB0BEC5);
      default:       return const Color(0xFFCD7F32);
    }
  }

  IconData _gradeIcon(String grade) {
    switch (grade) {
      case 'GOLD':   return Icons.emoji_events;
      case 'SILVER': return Icons.military_tech;
      default:       return Icons.shield_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A2E),
        foregroundColor: Colors.white,
        title: const Text('포인트 & 부스터',
            style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: StreamBuilder<RiderPointModel>(
        stream: _svc.watchPoints(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.amber));
          }
          final p = snap.data!;

          // 부스터 활성 시 카운트다운 시작
          if (p.isBoosterActive && _boosterRemaining == Duration.zero) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startBoosterTimer(p.boosterRemaining);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── 등급 & 총 포인트 카드 ────────────────────────────────
                _GradeCard(points: p, gradeColor: _gradeColor(p.grade),
                    gradeIcon: _gradeIcon(p.grade)),
                const SizedBox(height: 16),

                // ── 부스터 카드 ──────────────────────────────────────────
                _BoosterCard(
                  points: p,
                  boosterRemaining: _boosterRemaining,
                  pulseAnim: _boosterPulse,
                  onActivate: () async {
                    final ok = await _svc.activateBooster();
                    if (!mounted) return;
                    if (ok) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('⚡ 부스터 활성화! 3시간 동안 근거리 콜 우선 배정됩니다'),
                          backgroundColor: Colors.amber,
                        ),
                      );
                      _startBoosterTimer(const Duration(hours: 3));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('부스터 충전이 없거나 이미 활성 중입니다')));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // ── 오늘 일간 포인트 & 미션 ──────────────────────────────
                _DailyMissionCard(points: p),
                const SizedBox(height: 16),

                // ── 포인트 적립 내역 ────────────────────────────────────
                _HistoryCard(history: p.todayHistory),
                const SizedBox(height: 16),

                // ── 업적 배지 ────────────────────────────────────────────
                _BadgeCard(points: p),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ── 등급 & 총 포인트 ─────────────────────────────────────────────────────────
class _GradeCard extends StatelessWidget {
  final RiderPointModel points;
  final Color gradeColor;
  final IconData gradeIcon;
  const _GradeCard({required this.points, required this.gradeColor,
      required this.gradeIcon});

  @override
  Widget build(BuildContext context) {
    final nextBooster = points.pointsToNextBooster;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [gradeColor.withOpacity(0.8), gradeColor.withOpacity(0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gradeColor.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(gradeIcon, color: gradeColor, size: 36),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(points.grade,
                      style: TextStyle(
                          color: gradeColor,
                          fontSize: 22,
                          fontWeight: FontWeight.black,
                          letterSpacing: 2)),
                  Text('연속 ${points.consecutiveDays}일 출근',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12)),
                ],
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${points.totalPoints}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.black)),
                  const Text('총 포인트',
                      style: TextStyle(color: Colors.white60, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 다음 부스터까지 진행 바
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('다음 부스터 충전',
                      style: TextStyle(color: Colors.white70, fontSize: 12)),
                  Text('$nextBooster점 남음',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: 1 - (nextBooster / 100),
                  backgroundColor: Colors.white24,
                  valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                  minHeight: 8,
                ),
              ),
            ],
          ),
          if (points.pointsToNextGrade > 0) ...[
            const SizedBox(height: 10),
            Text(
              '다음 등급까지 ${points.pointsToNextGrade}점',
              style: const TextStyle(color: Colors.white60, fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

// ── 부스터 카드 ───────────────────────────────────────────────────────────────
class _BoosterCard extends StatelessWidget {
  final RiderPointModel points;
  final Duration boosterRemaining;
  final AnimationController pulseAnim;
  final VoidCallback onActivate;

  const _BoosterCard({
    required this.points,
    required this.boosterRemaining,
    required this.pulseAnim,
    required this.onActivate,
  });

  String _fmt(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final active = points.isBoosterActive;
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, __) {
        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: active
                ? Color.lerp(const Color(0xFF1A1A2E),
                    Colors.amber.withOpacity(0.3), pulseAnim.value)
                : const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: active ? Colors.amber : Colors.white24,
              width: active ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 48, height: 48,
                    decoration: BoxDecoration(
                      color: active
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.white12,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.bolt,
                        color: active ? Colors.amber : Colors.white38,
                        size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          active ? '⚡ 부스터 활성 중!' : '부스터',
                          style: TextStyle(
                              color: active ? Colors.amber : Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                        ),
                        Text(
                          active
                              ? '근거리 콜 우선 배정 · ${_fmt(boosterRemaining)} 남음'
                              : '100점마다 1회 충전 · 3시간 근거리 우선 배정',
                          style: TextStyle(
                              color: active
                                  ? Colors.amber.shade200
                                  : Colors.white54,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  if (!active)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.amber.withOpacity(0.5)),
                      ),
                      child: Text(
                        '${points.boosterCharges}회',
                        style: const TextStyle(
                            color: Colors.amber,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              if (!active && points.boosterCharges > 0) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onActivate,
                    icon: const Icon(Icons.bolt, size: 18),
                    label: const Text('부스터 활성화',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
              if (!active && points.boosterCharges == 0) ...[
                const SizedBox(height: 10),
                Text(
                  '충전된 부스터가 없습니다. ${points.pointsToNextBooster}점 더 모아보세요!',
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── 일일 미션 ─────────────────────────────────────────────────────────────────
class _DailyMissionCard extends StatelessWidget {
  final RiderPointModel points;
  const _DailyMissionCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final missions = [
      _Mission('5시간 근무 달성', '오늘 5시간 이상 근무하기', 1,
          points.todayHistory.any((e) => e.reason == PointReason.fiveHourWork)),
      _Mission('취소 없이 하루 마감', '취소/거절 없이 하루 종일 배달', 2,
          points.todayHistory.any((e) => e.reason == PointReason.noCancelDaily)),
      _Mission('피크타임 5건 연속', '11-13시 or 17-20시 연속 5건', 1,
          points.todayHistory.any((e) => e.reason == PointReason.peakTime5)),
      _Mission('고객 친절 달성', '오늘 별점 4.5점 이상 유지', 1,
          points.todayHistory.any((e) => e.reason == PointReason.kindnessDaily)),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in_outlined,
                  color: Colors.lightBlueAccent, size: 20),
              const SizedBox(width: 8),
              const Text('오늘의 미션',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.lightBlueAccent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '오늘 +${points.dailyPoints}점',
                  style: const TextStyle(
                      color: Colors.lightBlueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...missions.map((m) => _MissionRow(mission: m)),
        ],
      ),
    );
  }
}

class _Mission {
  final String title;
  final String desc;
  final int pts;
  final bool done;
  _Mission(this.title, this.desc, this.pts, this.done);
}

class _MissionRow extends StatelessWidget {
  final _Mission mission;
  const _MissionRow({required this.mission});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(
            mission.done ? Icons.check_circle : Icons.radio_button_unchecked,
            color: mission.done ? Colors.greenAccent : Colors.white30,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              mission.title,
              style: TextStyle(
                color: mission.done ? Colors.white60 : Colors.white,
                fontSize: 13,
                decoration: mission.done ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white38,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: mission.done
                  ? Colors.greenAccent.withOpacity(0.15)
                  : Colors.amber.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '+${mission.pts}점',
              style: TextStyle(
                  color: mission.done ? Colors.greenAccent : Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 오늘 적립 내역 ────────────────────────────────────────────────────────────
class _HistoryCard extends StatelessWidget {
  final List<PointHistoryEntry> history;
  const _HistoryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: Colors.purpleAccent, size: 20),
              SizedBox(width: 8),
              Text('오늘 적립 내역',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          if (history.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text('아직 포인트 적립 내역이 없어요',
                    style: TextStyle(color: Colors.white30, fontSize: 13)),
              ),
            )
          else
            ...history.reversed.map((e) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(e.reason.label,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ),
                  Text('+${e.points}점',
                      style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
            )),
        ],
      ),
    );
  }
}

// ── 업적 배지 ─────────────────────────────────────────────────────────────────
class _BadgeCard extends StatelessWidget {
  final RiderPointModel points;
  const _BadgeCard({required this.points});

  @override
  Widget build(BuildContext context) {
    final badges = [
      _Badge('☔ 폭우의 라이더', '우천 배달 10회', points.totalPoints >= 10),
      _Badge('🚗 장거리 전문가', '장거리 협업 5회', points.totalPoints >= 50),
      _Badge('🏆 무결점 라이더', '취소 없이 30일', points.consecutiveDays >= 30),
      _Badge('🗺️ 지역 정복자', '신규 지역 10곳', points.totalPoints >= 80),
      _Badge('⚡ 부스터 마스터', '부스터 10회 사용', points.totalPoints >= 120),
      _Badge('🌟 골드 라이더', '총 300점 달성', points.totalPoints >= 300),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF16213E),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emoji_events_outlined,
                  color: Colors.orangeAccent, size: 20),
              SizedBox(width: 8),
              Text('업적 배지',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 0.85,
            children: badges.map((b) => _BadgeTile(badge: b)).toList(),
          ),
        ],
      ),
    );
  }
}

class _Badge {
  final String emoji;
  final String desc;
  final bool unlocked;
  _Badge(this.emoji, this.desc, this.unlocked);
}

class _BadgeTile extends StatelessWidget {
  final _Badge badge;
  const _BadgeTile({required this.badge});

  @override
  Widget build(BuildContext context) {
    final parts = badge.emoji.split(' ');
    final icon = parts.first;
    final name = parts.skip(1).join(' ');

    return Container(
      decoration: BoxDecoration(
        color: badge.unlocked
            ? Colors.amber.withOpacity(0.15)
            : Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: badge.unlocked
              ? Colors.amber.withOpacity(0.4)
              : Colors.white12,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(icon,
              style: TextStyle(
                  fontSize: 28,
                  color: badge.unlocked ? null : null),
              // 미잠금 시 흑백 효과는 ColorFiltered로
          ),
          const SizedBox(height: 4),
          Text(name,
              style: TextStyle(
                  color: badge.unlocked ? Colors.white : Colors.white24,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          Text(badge.desc,
              style: const TextStyle(color: Colors.white30, fontSize: 9),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
