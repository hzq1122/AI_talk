import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/cart_item.dart';
import '../services/database/database_service.dart';
import '../services/database/cart_dao.dart';

class CartNotifier extends AsyncNotifier<List<CartItem>> {
  late final CartDao _dao;

  @override
  Future<List<CartItem>> build() async {
    _dao = CartDao(DatabaseService());
    return _dao.getAll();
  }

  Future<void> addItem(CartItem item) async {
    final items = state.value ?? [];
    final existing = items.where((i) => i.name == item.name).firstOrNull;
    if (existing != null) {
      final updated =
          existing.copyWith(quantity: existing.quantity + item.quantity);
      await _dao.updateQuantity(existing.id, updated.quantity);
      state = AsyncData(
        items.map((i) => i.id == existing.id ? updated : i).toList(),
      );
    } else {
      final created = await _dao.insert(item);
      state = AsyncData([...items, created]);
    }
  }

  Future<void> updateQuantity(String id, int quantity) async {
    if (quantity <= 0) {
      await removeItem(id);
      return;
    }
    await _dao.updateQuantity(id, quantity);
    state = AsyncData(
      state.value
              ?.map((i) => i.id == id ? i.copyWith(quantity: quantity) : i)
              .toList() ??
          [],
    );
  }

  Future<void> removeItem(String id) async {
    await _dao.delete(id);
    state = AsyncData(
      state.value?.where((i) => i.id != id).toList() ?? [],
    );
  }

  Future<void> clearCart() async {
    await _dao.clear();
    state = const AsyncData([]);
  }

  double get totalPrice =>
      (state.value ?? []).fold(0.0, (sum, item) => sum + item.total);
}

final cartProvider =
    AsyncNotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);
