import '../database/database_service.dart';
import '../../models/wallet_transaction.dart';

class WalletTransactionDao {
  final DatabaseService _db;

  WalletTransactionDao(this._db);

  Future<List<WalletTransaction>> getAll({int limit = 50}) async {
    final db = await _db.database;
    final rows = await db.query(
      'wallet_transactions',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(WalletTransaction.fromDbMap).toList();
  }

  Future<WalletTransaction> insert(WalletTransaction tx) async {
    final db = await _db.database;
    await db.insert('wallet_transactions', tx.toDbMap());
    return tx;
  }

  Future<void> deleteAll() async {
    final db = await _db.database;
    await db.delete('wallet_transactions');
  }
}
