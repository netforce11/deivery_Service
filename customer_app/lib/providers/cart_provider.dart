import 'package:flutter/foundation.dart';
import '../models/menu_model.dart';
import '../models/store_model.dart';
import '../utils/delivery_fee_calculator.dart';

class CartItem {
  final MenuModel menu;
  int quantity;
  CartItem({required this.menu, this.quantity = 1});
}

class CartProvider extends ChangeNotifier {
  StoreModel? _store;
  final List<CartItem> _items = [];

  // 배달 거리 (주소 선택 시 설정)
  double? _distanceKm;

  StoreModel? get store => _store;
  List<CartItem> get items => List.unmodifiable(_items);
  double? get distanceKm => _distanceKm;

  int get itemCount => _items.fold(0, (sum, e) => sum + e.quantity);
  int get subtotal => _items.fold(0, (sum, e) => sum + e.menu.price * e.quantity);

  /// 거리 기반 배달비 (거리 미설정 시 기본 3,500원)
  int get deliveryFee => _distanceKm != null
      ? DeliveryFeeCalculator.calculate(_distanceKm!)
      : 3500;

  int get weatherSurcharge =>
      (_store?.weatherSurchargeActive == true) ? (_store!.weatherSurchargeAmount) : 0;

  int get total => subtotal + deliveryFee + weatherSurcharge;

  bool get isLongDistance =>
      _distanceKm != null && DeliveryFeeCalculator.isLongDistance(_distanceKm!);

  String get distanceLabel => _distanceKm != null
      ? '${_distanceKm!.toStringAsFixed(1)}km · ${DeliveryFeeCalculator.label(_distanceKm!)}'
      : '';

  /// 배달 거리 업데이트 (주소 선택 시 호출)
  void setDeliveryDistance(double km) {
    _distanceKm = km;
    notifyListeners();
  }

  void clearDistance() {
    _distanceKm = null;
    notifyListeners();
  }

  bool isDifferentStore(StoreModel newStore) {
    return _store != null && _store!.id != newStore.id && _items.isNotEmpty;
  }

  void addItem(MenuModel menu, StoreModel store) {
    if (isDifferentStore(store)) return;
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
    _distanceKm = null;
    notifyListeners();
  }
}
