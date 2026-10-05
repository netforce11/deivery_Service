import 'package:flutter/material.dart';
import '../../models/menu_model.dart';
import '../../models/store_model.dart';
import '../../services/order_service.dart';

class MenuManagementScreen extends StatelessWidget {
  final StoreModel store;
  const MenuManagementScreen({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    final svc = OrderService();

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('메뉴 관리', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(store.name, style: TextStyle(fontSize: 12, color: Colors.indigo.shade100)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '메뉴 추가',
            onPressed: () => _showMenuDialog(context, svc),
          ),
        ],
      ),
      body: StreamBuilder<List<MenuModel>>(
        stream: svc.watchMenus(store.id),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.indigo));
          }
          final menus = snap.data ?? [];
          if (menus.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.restaurant_menu, size: 72, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text('등록된 메뉴가 없어요',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('첫 메뉴 추가하기'),
                    onPressed: () => _showMenuDialog(context, svc),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: menus.length,
            itemBuilder: (_, i) => _MenuCard(
              menu: menus[i],
              svc: svc,
              onEdit: () => _showMenuDialog(context, svc, menu: menus[i]),
              onDelete: () => _confirmDelete(context, svc, menus[i]),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('메뉴 추가'),
        onPressed: () => _showMenuDialog(context, svc),
      ),
    );
  }

  Future<void> _showMenuDialog(BuildContext context, OrderService svc,
      {MenuModel? menu}) async {
    final nameCtrl = TextEditingController(text: menu?.name ?? '');
    final descCtrl = TextEditingController(text: menu?.description ?? '');
    final priceCtrl =
        TextEditingController(text: menu != null ? menu.price.toString() : '');
    String category = menu?.category ?? '메인';
    bool isAvailable = menu?.isAvailable ?? true;
    final formKey = GlobalKey<FormState>();

    final categories = ['메인', '사이드', '음료', '디저트', '세트', '기타'];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(menu == null ? '메뉴 추가' : '메뉴 수정'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '메뉴 이름 *'),
                    validator: (v) => v!.isEmpty ? '메뉴 이름을 입력하세요' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: '설명 (선택)'),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: priceCtrl,
                    decoration: const InputDecoration(labelText: '가격 (원) *'),
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v!.isEmpty) return '가격을 입력하세요';
                      if (int.tryParse(v) == null) return '숫자만 입력하세요';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: '카테고리'),
                    items: categories
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => category = v!),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('판매중'),
                    subtitle: Text(isAvailable ? '고객에게 노출됩니다' : '숨김 처리됩니다',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    value: isAvailable,
                    onChanged: (v) => setState(() => isAvailable = v),
                    activeColor: Colors.indigo,
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo, foregroundColor: Colors.white),
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final data = {
                  'storeId': store.id,
                  'name': nameCtrl.text.trim(),
                  'description': descCtrl.text.trim(),
                  'price': int.parse(priceCtrl.text.trim()),
                  'category': category,
                  'isAvailable': isAvailable,
                };
                if (menu == null) {
                  await svc.addMenu(MenuModel(
                    id: '',
                    storeId: store.id,
                    name: data['name'] as String,
                    description: data['description'] as String,
                    price: data['price'] as int,
                    category: data['category'] as String,
                    isAvailable: data['isAvailable'] as bool,
                  ));
                } else {
                  await svc.updateMenu(menu.id, data);
                }
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(menu == null ? '추가' : '저장'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, OrderService svc, MenuModel menu) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('메뉴 삭제'),
        content: Text('"${menu.name}"을 삭제하시겠어요?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) await svc.deleteMenu(menu.id);
  }
}

// ── 메뉴 카드 ──────────────────────────────────────────────────────────────
class _MenuCard extends StatelessWidget {
  final MenuModel menu;
  final OrderService svc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MenuCard({
    required this.menu,
    required this.svc,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // 카테고리 아이콘
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: menu.isAvailable
                    ? Colors.indigo.shade50
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _categoryIcon(menu.category),
                color: menu.isAvailable ? Colors.indigo : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // 이름 + 설명
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          menu.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: menu.isAvailable
                                ? Colors.black87
                                : Colors.grey,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: menu.isAvailable
                              ? Colors.green.shade50
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          menu.isAvailable ? '판매중' : '숨김',
                          style: TextStyle(
                            fontSize: 11,
                            color: menu.isAvailable
                                ? Colors.green.shade700
                                : Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (menu.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      menu.description,
                      style: TextStyle(
                          color: Colors.grey.shade500, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    '${_fmt(menu.price)}원',
                    style: const TextStyle(
                        color: Colors.indigo,
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                ],
              ),
            ),
            // 액션 버튼
            Column(
              children: [
                Switch(
                  value: menu.isAvailable,
                  onChanged: (v) => svc.toggleMenuAvailable(menu.id, v),
                  activeColor: Colors.indigo,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Colors.indigo),
                      onPressed: onEdit,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      onPressed: onDelete,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case '메인': return Icons.lunch_dining;
      case '사이드': return Icons.tapas;
      case '음료': return Icons.local_drink;
      case '디저트': return Icons.cake;
      case '세트': return Icons.set_meal;
      default: return Icons.restaurant;
    }
  }
}

String _fmt(int n) => n.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
