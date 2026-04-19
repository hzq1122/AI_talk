import 'package:uuid/uuid.dart';
import '../../models/cart_item.dart';
import 'database_service.dart';

class CartDao {
  final DatabaseService _db;
  const CartDao(this._db);
  static const _uuid = Uuid();

  Future<List<CartItem>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('cart_items');
    return rows.map(CartItem.fromDbRow).toList();
  }

  Future<CartItem> insert(CartItem item) async {
    final db = await _db.database;
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    final row = item.toDbRow();
    row['id'] = id;
    await db.insert('cart_items', row);
    return CartItem.fromDbRow(row);
  }

  Future<void> updateQuantity(String id, int quantity) async {
    final db = await _db.database;
    await db.update('cart_items', {'quantity': quantity},
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('cart_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    final db = await _db.database;
    await db.delete('cart_items');
  }
}
