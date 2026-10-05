import 'package:flutter/foundation.dart';
import '../models/menu_model.dart';
import '../models/store_model.dart';

class CartItem {
  final MenuModel menu;
  int quantity;
  CartItem({required this.menu, this.quantity = 1});
}

class CartProvider extends ChangeNotifier {
  StoreModel? _store;
  final List<CartItem> _items = [];

  StoreModel? get store => _store;
  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, e) => sum + e.quantity);

  int get subtotal => _items.fold(0, (sum, e) => sum + e.menu.price * e.quantity);

  int get deliveryFee => 3500;

  int get total => subtotal + deliveryFee;

  // 다른 가게 메뉴를 담으려 할 때 true 반환 → UI에서 확인 다이얼로그 표시
  bool isDifferentStore(StoreModel newStore) {
    return _store != null && _store!.id != newStore.id && _items.isNotEmpty;
  }

  void addItem(MenuModel menu, StoreModel store) {
    if (isDifferentStore(store)) return; // 호출 전 확인 필수
    _store = store;
    final idx = _items.indexWhere((e) => e.menu.id == menu.id);
    if (idx >= 0) {
      _items[idx].quantity++;
    } else {
      _items.add(CartItem(menu: menu));
    }
    notifyListeners();
  }

  void removeItem(String menuId) {
    final idx = _items.indexWhere((e) => e.menu.id == menuId);
    if (idx < 0) return;
    if (_items[idx].quantity > 1) {
      _items[idx].quantity--;
    } else {
      _items.removeAt(idx);
    }
    if (_items.isEmpty) _store = null;
    notifyListeners();
  }

  void deleteItem(String menuId) {
    _items.removeWhere((e) => e.menu.id == menuId);
    if (_items.isEmpty) _store = null;
    notifyListeners();
  }

  void clear() {
    _items.clear();
    _store = null;
    notifyListeners();
  }
}
