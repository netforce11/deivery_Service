import 'package:flutter/material.dart';
import '../../models/store_achievement_model.dart';
import '../../services/store_achievement_service.dart';

class StoreAchievementsScreen extends StatelessWidget {
  const StoreAchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final svc = StoreAchievementService();

    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        foregroundColor: Colors.white,
        title: const Text('사장님 보상',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<StoreAchievementModel>>(
        stream: svc.watchHistory(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Colors.amber));
          }
          final all = snap.data ?? [];
          final today = _todayItems(all);
          final past = _pastItems(all);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── 오늘의 달성 ──────────────────────────────────────────────
              if (today.isNotEmpty) ...[
                _sectionTitle('🎉 오늘의 달성', Colors.amber),
                const SizedBox(height: 10),
                ...today.map((a) => _AchievementCard(achievement: a)),
                const SizedBox(height: 20),
              ],

              // ── 달성 없을 때 동기부여 ────────────────────────────────────
              if (today.isEmpty) ...[
                _EmptyToday(),
                const SizedBox(height: 20),
              ],

              // ── 달성 가능한 보상 안내 ────────────────────────────────────
              _sectionTitle('받을 수 있는 보상', Colors.white60),
              const SizedBox(height: 10),
              _RewardGuideCard(),
              const SizedBox(height: 20),

              // ── 최근 30일 이력 ───────────────────────────────────────────
              if (past.isNotEmpty) ...[
                _sectionTitle('지난 달성 이력', Colors.white38),
                const SizedBox(height: 10),
                ...past.take(10).map((a) => _HistoryTile(achievement: a)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text, Color color) => Text(text,
      style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1));

  List<StoreAchievementModel> _todayItems(List<StoreAchievementModel> all) {
    final todayStart = DateTime.now();
    final start = DateTime(todayStart.year, todayStart.month, todayStart.day);
    return all.where((a) => a.earnedAt.isAfter(start)).toList();
  }

  List<StoreAchievementModel> _pastItems(List<StoreAchievementModel> all) {
    final todayStart = DateTime.now();
    final start = DateTime(todayStart.year, todayStart.month, todayStart.day);
    return all.where((a) => a.earnedAt.isBefore(start)).toList();
  }
}

// ── 오늘 달성 카드 ────────────────────────────────────────────────────────────

class _AchievementCard extends StatelessWidget {
  final StoreAchievementModel achievement;
  const _AchievementCard({required this.achievement});

  Color get _color {
    switch (achievement.type) {
      case AchievementType.orderKing:    return Colors.amber;
      case AchievementType.luckyNumber:  return Colors.greenAccent;
      case AchievementType.speedKing:    return Colors.cyanAccent;
      case AchievementType.comebackKing: return Colors.deepOrangeAccent;
      case AchievementType.reviewStar:   return Colors.purpleAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.2), _color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _color.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
              color: _color.withOpacity(0.2), blurRadius: 16, spreadRadius: 1)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(a.type.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a.type.title,
                        style: TextStyle(
                            color: _color,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                    Text(_subtitle(a),
                        style: TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
              ),
              if (a.type == AchievementType.luckyNumber &&
                  a.bonusAmount != null)
                _BonusChip(amount: a.bonusAmount!, paid: a.bonusPaid),
            ],
          ),
          if (a.type == AchievementType.orderKing && a.orderRatio != null) ...[
            const SizedBox(height: 12),
            _OrderKingDetail(ratio: a.orderRatio!, count: a.orderCount ?? 0,
                category: a.category ?? ''),
          ],
          if (a.type == AchievementType.luckyNumber) ...[
            const SizedBox(height: 12),
            _LuckyDetail(achievement: a),
          ],
        ],
      ),
    );
  }

  String _subtitle(StoreAchievementModel a) {
    switch (a.type) {
      case AchievementType.orderKing:
        return '${a.category} 카테고리 · 오늘 ${a.orderCount}건 달성';
      case AchievementType.luckyNumber:
        return '${a.luckyOrderNumber}번째 주문 도착!';
      case AchievementType.speedKing:
        return '평균 조리 ${a.avgMinutes}분 · 카테고리 최단';
      case AchievementType.comebackKing:
        return '재방문율 ${((a.returnRate ?? 0) * 100).round()}%';
      case AchievementType.reviewStar:
        return '오늘 5점 리뷰 ${a.fiveStarCount}개';
    }
  }
}

class _BonusChip extends StatelessWidget {
  final int amount;
  final bool paid;
  const _BonusChip({required this.amount, required this.paid});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: paid ? Colors.grey.shade800 : Colors.greenAccent.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: paid ? Colors.white24 : Colors.greenAccent.withOpacity(0.6)),
      ),
      child: Column(
        children: [
          Text(
            '+${_comma(amount)}원',
            style: TextStyle(
                color: paid ? Colors.white38 : Colors.greenAccent,
                fontSize: 13,
                fontWeight: FontWeight.bold),
          ),
          Text(
            paid ? '지급완료' : '정산예정',
            style: TextStyle(
                color: paid ? Colors.white24 : Colors.greenAccent.withOpacity(0.7),
                fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _OrderKingDetail extends StatelessWidget {
  final double ratio;
  final int count;
  final String category;

  const _OrderKingDetail(
      {required this.ratio, required this.count, required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat('카테고리', category, Colors.white70),
          _Stat('내 주문', '$count건', Colors.amber),
          _Stat('평균 대비', '${ratio.toStringAsFixed(1)}배', Colors.amber),
        ],
      ),
    );
  }
}

class _LuckyDetail extends StatelessWidget {
  final StoreAchievementModel achievement;
  const _LuckyDetail({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final revenue = achievement.dailyRevenue ?? 0;
    final bonus = achievement.bonusAmount ?? 0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('당일 누적 매출',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text('${_comma(revenue)}원',
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('추가 지급 (5%)',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              Text('+${_comma(bonus)}원',
                  style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 15)),
            ],
          ),
          if (revenue < 100000) ...[
            const SizedBox(height: 6),
            Text('* 당일 매출 100만원 미만 가게 한정 지원',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
          ],
        ],
      ),
    );
  }

  String _comma(int n) => n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _Stat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Column(children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 15, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
      ]);
}

// ── 오늘 달성 없을 때 ──────────────────────────────────────────────────────────

class _EmptyToday extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Text('🌅', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 10),
          const Text('오늘 아직 달성한 보상이 없어요',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text('주문이 쌓이면 자동으로 달성돼요',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}

// ── 보상 안내 카드 ────────────────────────────────────────────────────────────

class _RewardGuideCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const items = [
      ('🏅', '주문왕', '카테고리 평균 1.5배 이상 달성 시 자동 부여'),
      ('🍀', '럭키 주문번호', '설정한 주문번호 도착 시 당일 매출 5% 추가 (100만원 미만 가게)'),
      ('⚡', '스피드왕', '조리시간 카테고리 최단 달성 시 부여'),
      ('⭐', '리뷰 스타', '당일 5점 리뷰 카테고리 최다 달성 시 부여'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Text(item.$1, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.$2,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                    Text(item.$3,
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        )).toList(),
      ),
    );
  }
}

// ── 이력 타일 ─────────────────────────────────────────────────────────────────

class _HistoryTile extends StatelessWidget {
  final StoreAchievementModel achievement;
  const _HistoryTile({required this.achievement});

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(a.type.emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(a.type.title,
                style: const TextStyle(
                    color: Colors.white60, fontSize: 13)),
          ),
          if (a.bonusAmount != null)
            Text('+${a.bonusAmount}원',
                style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          Text(_dateLabel(a.earnedAt),
              style: TextStyle(color: Colors.grey.shade700, fontSize: 11)),
        ],
      ),
    );
  }

  String _dateLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt).inDays;
    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${diff}일 전';
  }
}
