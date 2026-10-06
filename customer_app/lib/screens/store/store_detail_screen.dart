import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/store_model.dart';
import '../../models/menu_model.dart';
import '../../models/review_model.dart';
import '../../providers/cart_provider.dart';
import '../../services/store_service.dart';
import '../../services/review_service.dart';

class StoreDetailScreen extends StatefulWidget {
  final StoreModel store;
  const StoreDetailScreen({super.key, required this.store});

  @override
  State<StoreDetailScreen> createState() => _StoreDetailScreenState();
}

class _StoreDetailScreenState extends State<StoreDetailScreen> {
  final StoreService _storeService = StoreService();
  List<MenuModel> _menus = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMenus();
  }

  Future<void> _loadMenus() async {
    try {
      final menus = await _storeService.getMenus(widget.store.id);
      if (mounted) setState(() { _menus = menus; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _addToCart(MenuModel menu) async {
    final cart = context.read<CartProvider>();
    if (cart.isDifferentStore(widget.store)) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('장바구니 초기화'),
          content: Text('다른 가게(${cart.store!.name})의 메뉴가 있습니다.\n새로 담으시겠어요?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('초기화 후 담기'),
            ),
          ],
        ),
      );
      if (ok != true) return;
      cart.clear();
    }
    cart.addItem(menu, widget.store);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${menu.name} 담았어요!'),
          duration: const Duration(seconds: 1),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // 헤더
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.orange, Color(0xFFFF7043)],
                  ),
                ),
                child: const Center(
                  child: Icon(Icons.storefront, size: 80, color: Colors.white38),
                ),
              ),
            ),
          ),
          // 가게 정보
          SliverToBoxAdapter(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(widget.store.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Text('영업중',
                            style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(widget.store.category,
                          style: TextStyle(color: Colors.grey.shade600)),
                      if (widget.store.reviewCount > 0) ...[
                        const SizedBox(width: 10),
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          '${widget.store.avgRating.toStringAsFixed(1)} (${widget.store.reviewCount})',
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.amber,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on, size: 14, color: Colors.grey.shade500),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(widget.store.address,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _infoChip(Icons.delivery_dining, '배달비 3,500원'),
                        _infoChip(Icons.timer, '30~45분'),
                        _infoChip(Icons.phone, widget.store.phone),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 메뉴 헤더
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('메뉴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ),
          // 메뉴 목록
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.orange)),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red, size: 48),
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          setState(() { _loading = true; _error = null; });
                          _loadMenus();
                        },
                        child: const Text('다시 시도'),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else if (_menus.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text('등록된 메뉴가 없습니다', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _MenuCard(menu: _menus[i], onAdd: () => _addToCart(_menus[i])),
                childCount: _menus.length,
              ),
            ),
          // ── 리뷰 섹션 ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _ReviewSection(store: widget.store),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      // 장바구니 버튼
      bottomNavigationBar: cart.itemCount > 0
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/cart'),
                  child: Text(
                    '장바구니 보기 (${cart.itemCount}개)  |  ${_fmt(cart.total)}원',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.orange),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12, color: Colors.orange)),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final MenuModel menu;
  final VoidCallback onAdd;
  const _MenuCard({required this.menu, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final qty = cart.items
        .where((e) => e.menu.id == menu.id)
        .fold(0, (s, e) => s + e.quantity);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(menu.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  if (menu.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(menu.description,
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                  ],
                  const SizedBox(height: 8),
                  Text('${_fmt(menu.price)}원',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)),
                ],
              ),
            ),
            // 수량 조절 또는 담기 버튼
            if (qty == 0)
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: onAdd,
                child: const Text('담기'),
              )
            else
              Row(
                children: [
                  _circleBtn(Icons.remove, () => context.read<CartProvider>().removeItem(menu.id)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('$qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  _circleBtn(Icons.add, onAdd),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _circleBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');

// ── 리뷰 섹션 ─────────────────────────────────────────────────────────────────
class _ReviewSection extends StatefulWidget {
  final StoreModel store;
  const _ReviewSection({required this.store});

  @override
  State<_ReviewSection> createState() => _ReviewSectionState();
}

class _ReviewSectionState extends State<_ReviewSection> {
  final _svc = ReviewService();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Row(
            children: [
              const Text('리뷰',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showWriteReviewSheet(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('리뷰 작성'),
                style: TextButton.styleFrom(foregroundColor: Colors.orange),
              ),
            ],
          ),
        ),
        StreamBuilder<List<ReviewModel>>(
          stream: _svc.storeReviews(widget.store.id),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(color: Colors.orange),
              ));
            }
            final reviews = snap.data ?? [];
            if (reviews.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: Text('아직 리뷰가 없습니다.\n첫 번째 리뷰를 작성해보세요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey)),
                ),
              );
            }
            return Column(
              children: [
                ...reviews.map((r) => _ReviewCard(review: r, storeId: widget.store.id)),
                // 고객 안내 문구
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: Text(
                    '※ 가게 요청 시 수수료(500원) 지불 후 별점 삭제가 가능합니다.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showWriteReviewSheet(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('로그인이 필요합니다')));
      return;
    }

    // 배달 완료된 주문이 있는지 확인
    final ordersSnap = await FirebaseFirestore.instance
        .collection('orders')
        .where('customerId', isEqualTo: uid)
        .where('storeId', isEqualTo: widget.store.id)
        .where('status', isEqualTo: 'delivered')
        .limit(5)
        .get();

    if (ordersSnap.docs.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('배달 완료된 주문이 있어야 리뷰를 작성할 수 있습니다')));
      }
      return;
    }

    // 이미 리뷰 작성한 주문 제외
    String? availableOrderId;
    for (final doc in ordersSnap.docs) {
      final has = await _svc.hasReview(doc.id);
      if (!has) { availableOrderId = doc.id; break; }
    }
    if (availableOrderId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('이미 리뷰를 작성하셨습니다')));
      }
      return;
    }

    final oid = availableOrderId;
    if (context.mounted) {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _WriteReviewSheet(
          store: widget.store,
          orderId: oid,
          reviewSvc: _svc,
        ),
      );
    }
  }
}

// ── 리뷰 카드 ─────────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final String storeId;
  const _ReviewCard({required this.review, required this.storeId});

  @override
  Widget build(BuildContext context) {
    if (!review.isRatingVisible) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.orange.shade100,
                child: Text(
                  review.customerName.isNotEmpty
                      ? review.customerName[0]
                      : '?',
                  style: const TextStyle(
                      color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.customerName,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      _dateStr(review.createdAt),
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ],
                ),
              ),
              _StarDisplay(rating: review.rating),
            ],
          ),
          if (review.isCommentVisible && review.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(review.comment, style: const TextStyle(fontSize: 13)),
            if (review.status == ReviewStatus.pending) ...[
              const SizedBox(height: 6),
              Text('※ 3.5점 미만 리뷰는 24시간 후 댓글이 자동 삭제됩니다.',
                  style: TextStyle(fontSize: 11, color: Colors.orange.shade400)),
            ],
          ] else if (!review.isCommentVisible) ...[
            const SizedBox(height: 6),
            Text('(댓글이 삭제되었습니다)',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
          ],
        ],
      ),
    );
  }

  String _dateStr(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }
}

// ── 별점 표시 위젯 ────────────────────────────────────────────────────────────
class _StarDisplay extends StatelessWidget {
  final double rating;
  const _StarDisplay({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star, color: Colors.amber, size: 16),
        const SizedBox(width: 2),
        Text(rating.toStringAsFixed(1),
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13, color: Colors.amber)),
      ],
    );
  }
}

// ── 리뷰 작성 바텀시트 ────────────────────────────────────────────────────────
class _WriteReviewSheet extends StatefulWidget {
  final StoreModel store;
  final String orderId;
  final ReviewService reviewSvc;

  const _WriteReviewSheet({
    required this.store,
    required this.orderId,
    required this.reviewSvc,
  });

  @override
  State<_WriteReviewSheet> createState() => _WriteReviewSheetState();
}

class _WriteReviewSheetState extends State<_WriteReviewSheet> {
  double _rating = 4.0;
  final _ctrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await widget.reviewSvc.submitReview(
        storeId: widget.store.id,
        orderId: widget.orderId,
        customerName: user?.displayName ?? '익명',
        rating: _rating,
        comment: _ctrl.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('리뷰가 등록되었습니다 🎉')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLow = _rating < 3.5;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(widget.store.name,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('주문하신 음식은 어떠셨나요?',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),

          // 별점 선택 (0.5 단위 슬라이더로 0.1 단위 구현)
          Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (i) {
                    final full = i + 1;
                    return GestureDetector(
                      onTap: () => setState(() => _rating = full.toDouble()),
                      child: Icon(
                        _rating >= full
                            ? Icons.star
                            : _rating >= full - 0.5
                                ? Icons.star_half
                                : Icons.star_border,
                        color: Colors.amber,
                        size: 36,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: _rating,
                  min: 0.5,
                  max: 5.0,
                  divisions: 45,
                  label: _rating.toStringAsFixed(1),
                  activeColor: Colors.amber,
                  onChanged: (v) => setState(
                      () => _rating = (v * 10).round() / 10),
                ),
                Text(
                  '${_rating.toStringAsFixed(1)}점',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber),
                ),
              ],
            ),
          ),

          if (isLow) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 14, color: Colors.orange),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '3.5점 미만 리뷰는 댓글이 24시간 후 자동 삭제됩니다. 별점은 유지됩니다.',
                      style: TextStyle(fontSize: 11, color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          TextField(
            controller: _ctrl,
            maxLength: 200,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: '음식 맛, 포장 상태 등을 알려주세요 (최대 200자)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.orange),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '※ 가게 요청 시 수수료(500원) 지불 후 별점 삭제가 가능합니다.',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Text('리뷰 등록',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
