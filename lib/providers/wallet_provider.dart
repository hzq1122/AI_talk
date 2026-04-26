import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/wallet_transaction.dart';
import '../services/database/database_service.dart';
import '../services/database/wallet_transaction_dao.dart';
import '../providers/settings_provider.dart';

class WalletNotifier extends AsyncNotifier<List<WalletTransaction>> {
  late final WalletTransactionDao _dao;

  @override
  Future<List<WalletTransaction>> build() async {
    _dao = WalletTransactionDao(DatabaseService());
    return _dao.getAll();
  }

  Future<void> recharge(double amount) async {
    await _addTransaction(amount, 'recharge', '钱包充值');
    _updateBalance((b) => b + amount);
  }

  Future<void> spend(double amount, String description,
      {String? contactId, String? contactName}) async {
    await _addTransaction(amount, 'spend', description,
        contactId: contactId, contactName: contactName);
    _updateBalance((b) => b - amount);
  }

  Future<void> setCustomBalance(double newBalance) async {
    final oldBalance =
        ref.read(settingsProvider).value?.walletBalance ?? 0;
    final diff = newBalance - oldBalance;
    final type = diff >= 0 ? 'recharge' : 'spend';
    await _addTransaction(
        diff.abs(), type, '手动调整余额 (总 ¥${newBalance.toStringAsFixed(2)})');
    _updateBalance((_) => newBalance);
  }

  Future<void> _addTransaction(double amount, String type, String description,
      {String? contactId, String? contactName}) async {
    final tx = WalletTransaction(
      id: const Uuid().v4(),
      amount: amount,
      type: type,
      description: description,
      contactId: contactId,
      contactName: contactName,
      createdAt: DateTime.now(),
    );
    await _dao.insert(tx);
    state = AsyncData([tx, ...?state.value]);
  }

  void _updateBalance(double Function(double) fn) {
    final notifier = ref.read(settingsProvider.notifier);
    final current = notifier.state.value?.walletBalance ?? 0;
    notifier.setWalletBalance(fn(current).clamp(0, double.infinity));
  }

  Future<void> clearHistory() async {
    await _dao.deleteAll();
    state = const AsyncData([]);
  }
}

final walletProvider = AsyncNotifierProvider<WalletNotifier, List<WalletTransaction>>(
    WalletNotifier.new);
