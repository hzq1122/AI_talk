import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/cart_item.dart';
import '../../providers/cart_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/wechat_colors.dart';

class DeliveryPage extends ConsumerWidget {
  const DeliveryPage({super.key});

  static const _menuItems = [
    _MenuItem('奶茶', [
      _FoodItem('珍珠奶茶', 12.0),
      _FoodItem('芋泥波波奶茶', 15.0),
      _FoodItem('椰椰拿铁', 18.0),
      _FoodItem('杨枝甘露', 16.0),
    ]),
    _MenuItem('咖啡', [
      _FoodItem('美式咖啡', 9.0),
      _FoodItem('生椰拿铁', 16.0),
      _FoodItem('摩卡', 18.0),
      _FoodItem('卡布奇诺', 15.0),
    ]),
    _MenuItem('小吃', [
      _FoodItem('鸡排', 12.0),
      _FoodItem('烤肠', 5.0),
      _FoodItem('薯条', 8.0),
      _FoodItem('炸鸡翅', 15.0),
    ]),
    _MenuItem('快餐', [
      _FoodItem('黄焖鸡米饭', 18.0),
      _FoodItem('蛋炒饭', 12.0),
      _FoodItem('牛肉面', 22.0),
      _FoodItem('麻辣烫', 20.0),
    ]),
    _MenuItem('甜品', [
      _FoodItem('蛋糕', 25.0),
      _FoodItem('冰淇淋', 8.0),
      _FoodItem('华夫饼', 15.0),
      _FoodItem('布丁', 10.0),
    ]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cartAsync = ref.watch(cartProvider);
    final settingsAsync = ref.watch(settingsProvider);
    final balance = settingsAsync.value?.walletBalance ?? 0.0;
    final cartItems = cartAsync.value ?? [];
    final cartTotal =
        cartItems.fold(0.0, (sum, item) => sum + item.total);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('点外卖'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            tooltip: '钱包',
            onPressed: () => _showWalletDialog(context, ref, balance),
          ),
        ],
      ),
      body: Column(
        children: [
          // 钱包余额条
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet,
                    color: Color(0xFFFF6B35), size: 20),
                const SizedBox(width: 8),
                Text('钱包余额',
                    style: TextStyle(
                        color: WeChatColors.textSecondary, fontSize: 13)),
                const Spacer(),
                Text('¥${balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 菜单
          Expanded(
            child: ListView.builder(
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final category = _menuItems[index];
                return _CategorySection(
                  category: category,
                  onAdd: (food) {
                    ref.read(cartProvider.notifier).addItem(CartItem(
                          id: '',
                          name: food.name,
                          price: food.price,
                          shop: '外卖商城',
                        ));
                  },
                );
              },
            ),
          ),
          // 购物车栏
          if (cartItems.isNotEmpty)
            _CartBar(
              itemCount: cartItems.fold(0, (s, i) => s + i.quantity),
              total: cartTotal,
              balance: balance,
              onTap: () => _showCartSheet(context, ref),
              onCheckout: () => _checkout(context, ref, cartTotal, balance),
            ),
        ],
      ),
    );
  }

  void _showWalletDialog(
      BuildContext context, WidgetRef ref, double balance) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('钱包充值'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('当前余额: ¥${balance.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '充值金额',
                prefixText: '¥ ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(ctrl.text.trim());
              if (amount != null && amount > 0) {
                ref
                    .read(settingsProvider.notifier)
                    .setWalletBalance(balance + amount);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('充值'),
          ),
        ],
      ),
    );
  }

  void _showCartSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _CartSheet(ref: ref),
    );
  }

  void _checkout(BuildContext context, WidgetRef ref, double total,
      double balance) {
    if (total > balance) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('余额不足，请先充值'),
            backgroundColor: Colors.red),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认下单'),
        content: Text('共计 ¥${total.toStringAsFixed(2)}，确认支付？'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              ref.read(settingsProvider.notifier).deductBalance(total);
              ref.read(cartProvider.notifier).clearCart();
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('下单成功！外卖正在配送中...')),
              );
            },
            child: const Text('支付'),
          ),
        ],
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final int itemCount;
  final double total;
  final double balance;
  final VoidCallback onTap;
  final VoidCallback onCheckout;

  const _CartBar({
    required this.itemCount,
    required this.total,
    required this.balance,
    required this.onTap,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF3D3D3D),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.shopping_cart,
                    color: Colors.white, size: 28),
                Positioned(
                  right: -8,
                  top: -6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text('$itemCount',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 10)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('¥${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('去结算'),
          ),
        ],
      ),
    );
  }
}

class _CartSheet extends StatelessWidget {
  final WidgetRef ref;
  const _CartSheet({required this.ref});

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider).value ?? [];
    final total = cartItems.fold(0.0, (sum, item) => sum + item.total);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('购物车',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    ref.read(cartProvider.notifier).clearCart();
                    Navigator.of(context).pop();
                  },
                  child: const Text('清空',
                      style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          ConstrainedBox(
            constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.4),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: cartItems.length,
              itemBuilder: (context, index) {
                final item = cartItems[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle:
                      Text('¥${item.price.toStringAsFixed(2)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            size: 20),
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .updateQuantity(
                                item.id, item.quantity - 1),
                      ),
                      Text('${item.quantity}'),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline,
                            size: 20),
                        onPressed: () => ref
                            .read(cartProvider.notifier)
                            .updateQuantity(
                                item.id, item.quantity + 1),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text('合计: ',
                    style: TextStyle(fontSize: 14)),
                Text('¥${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFF6B35))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  final _MenuItem category;
  final void Function(_FoodItem food) onAdd;

  const _CategorySection({
    required this.category,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(category.name,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: WeChatColors.textPrimary)),
        ),
        Container(
          color: Colors.white,
          child: Column(
            children: category.items.map((food) {
              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.restaurant,
                      color: Color(0xFFFF6B35), size: 22),
                ),
                title: Text(food.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('¥${food.price.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFFF6B35))),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => onAdd(food),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          color: Color(0xFFFF6B35),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _MenuItem {
  final String name;
  final List<_FoodItem> items;
  const _MenuItem(this.name, this.items);
}

class _FoodItem {
  final String name;
  final double price;
  const _FoodItem(this.name, this.price);
}
