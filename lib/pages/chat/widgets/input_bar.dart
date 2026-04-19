import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/cart_item.dart';
import '../../../providers/cart_provider.dart';
import '../../../theme/wechat_colors.dart';

class InputBar extends ConsumerStatefulWidget {
  final void Function(String text) onSend;
  final void Function(String type, Map<String, dynamic> metadata)? onSendSpecial;
  final bool enabled;

  const InputBar({
    super.key,
    required this.onSend,
    this.onSendSpecial,
    this.enabled = true,
  });

  @override
  ConsumerState<InputBar> createState() => _InputBarState();
}

class _InputBarState extends ConsumerState<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty || !widget.enabled) return;
    _controller.clear();
    setState(() => _hasText = false);
    widget.onSend(text);
  }

  void _showPlusMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Wrap(
            spacing: 24,
            runSpacing: 16,
            children: [
              _PlusMenuItem(
                icon: Icons.account_balance_wallet,
                label: '转账',
                color: const Color(0xFFFF9500),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showTransferDialog(context);
                },
              ),
              _PlusMenuItem(
                icon: Icons.fastfood_outlined,
                label: '外卖',
                color: const Color(0xFF34C759),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showDeliveryDialog(context);
                },
              ),
              _PlusMenuItem(
                icon: Icons.restaurant_menu,
                label: '点餐',
                color: const Color(0xFFFF6B35),
                onTap: () {
                  Navigator.of(ctx).pop();
                  _showQuickOrderDialog(context);
                },
              ),
              _PlusMenuItem(
                icon: Icons.image_outlined,
                label: '图片',
                color: const Color(0xFF007AFF),
                onTap: () => Navigator.of(ctx).pop(),
              ),
              _PlusMenuItem(
                icon: Icons.location_on_outlined,
                label: '位置',
                color: const Color(0xFF5856D6),
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTransferDialog(BuildContext context) {
    final amountCtrl = TextEditingController();
    final remarkCtrl = TextEditingController(text: '转账');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('微信转账'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '金额',
                prefixText: '¥ ',
                hintText: '0.00',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarkCtrl,
              decoration: const InputDecoration(labelText: '备注'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              final amount = amountCtrl.text.trim();
              if (amount.isEmpty) return;
              Navigator.of(ctx).pop();
              widget.onSendSpecial?.call('transfer', {
                'amount': amount,
                'remark': remarkCtrl.text.trim(),
              });
            },
            child: const Text('转账'),
          ),
        ],
      ),
    );
  }

  void _showDeliveryDialog(BuildContext context) {
    final shopCtrl = TextEditingController();
    final itemsCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('点外卖'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: shopCtrl,
              decoration: const InputDecoration(
                labelText: '店铺名称',
                hintText: '如：瑞幸咖啡',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: itemsCtrl,
              decoration: const InputDecoration(
                labelText: '商品',
                hintText: '如：生椰拿铁 x1',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '总价',
                prefixText: '¥ ',
                hintText: '0.00',
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
              if (shopCtrl.text.trim().isEmpty) return;
              Navigator.of(ctx).pop();
              widget.onSendSpecial?.call('delivery', {
                'shop': shopCtrl.text.trim(),
                'items': itemsCtrl.text.trim(),
                'price': priceCtrl.text.trim(),
              });
            },
            child: const Text('下单'),
          ),
        ],
      ),
    );
  }

  void _showQuickOrderDialog(BuildContext context) {
    final foods = [
      {'name': '珍珠奶茶', 'price': 12.0},
      {'name': '生椰拿铁', 'price': 16.0},
      {'name': '黄焖鸡米饭', 'price': 18.0},
      {'name': '蛋炒饭', 'price': 12.0},
      {'name': '炸鸡翅', 'price': 15.0},
      {'name': '薯条', 'price': 8.0},
    ];
    final selected = <int>{};
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('快速点餐'),
          content: SizedBox(
            width: 300,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('选择要添加到购物车的食品',
                    style: TextStyle(fontSize: 13, color: WeChatColors.textSecondary)),
                const SizedBox(height: 12),
                ...List.generate(foods.length, (i) {
                  final food = foods[i];
                  return CheckboxListTile(
                    title: Text(food['name'] as String),
                    subtitle: Text('¥${(food['price'] as double).toStringAsFixed(0)}'),
                    value: selected.contains(i),
                    activeColor: WeChatColors.primary,
                    onChanged: (v) => setDialogState(() {
                      if (v == true) {
                        selected.add(i);
                      } else {
                        selected.remove(i);
                      }
                    }),
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('取消')),
            ElevatedButton(
              onPressed: selected.isEmpty
                  ? null
                  : () {
                      for (final i in selected) {
                        final food = foods[i];
                        ref.read(cartProvider.notifier).addItem(CartItem(
                              id: '',
                              name: food['name'] as String,
                              price: food['price'] as double,
                              shop: '外卖商城',
                            ));
                      }
                      Navigator.of(ctx).pop();
                      final names = selected
                          .map((i) => foods[i]['name'] as String)
                          .join('、');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已添加 $names 到购物车')),
                      );
                    },
              child: const Text('加入购物车'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F7F7),
        border: Border(top: BorderSide(color: WeChatColors.divider, width: 0.5)),
      ),
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: 8 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // 语音按钮（占位）
            IconButton(
              icon: const Icon(Icons.mic_none, color: WeChatColors.textSecondary),
              onPressed: widget.enabled ? () {} : null,
            ),
            // 文本输入框
            Expanded(
              child: Container(
                constraints: const BoxConstraints(maxHeight: 120),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: WeChatColors.inputBorder),
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  style: const TextStyle(fontSize: 16),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    hintText: '发消息...',
                    hintStyle: TextStyle(color: WeChatColors.textHint),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // 表情按钮（占位）
            IconButton(
              icon: const Icon(Icons.emoji_emotions_outlined,
                  color: WeChatColors.textSecondary),
              onPressed: widget.enabled ? () {} : null,
            ),
            // 发送/加号按钮
            if (_hasText)
              _SendButton(onSend: _send, enabled: widget.enabled)
            else
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: WeChatColors.textSecondary),
                onPressed: widget.enabled ? () => _showPlusMenu(context) : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final VoidCallback onSend;
  final bool enabled;

  const _SendButton({required this.onSend, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onSend : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: enabled ? WeChatColors.primary : WeChatColors.textHint,
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          '发送',
          style: TextStyle(
              color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

class _PlusMenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _PlusMenuItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: WeChatColors.divider),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: WeChatColors.textSecondary)),
          ],
        ),
      ),
    );
  }
}
