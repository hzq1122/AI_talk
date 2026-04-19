import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/messages_provider.dart';
import '../../providers/api_config_provider.dart';
import '../../theme/wechat_colors.dart';
import '../../widgets/avatar_widget.dart';
import '../../services/chat/typing_simulator.dart';
import 'widgets/message_bubble.dart';
import 'widgets/input_bar.dart';
import 'widgets/typing_indicator.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String contactId;
  final Contact? contact;

  const ChatPage({
    super.key,
    required this.contactId,
    this.contact,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _scrollController = ScrollController();
  bool _isSending = false;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
      ref.read(contactsProvider.notifier).clearUnread(widget.contactId);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        final target = _scrollController.position.maxScrollExtent;
        if (animated) {
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        } else {
          _scrollController.jumpTo(target);
        }
      }
    });
  }

  Future<void> _sendMessage(Contact contact, String text) async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
      _isTyping = true;
    });

    final messagesNotifier = ref.read(messagesProvider(widget.contactId).notifier);

    await TypingSimulator.simulateDelay(text);
    if (!mounted) return;
    setState(() => _isTyping = false);

    ref.read(chatServiceProvider).sendMessage(
      contact: contact,
      userText: text,
      onMessagesCreated: (userMsg, aiMsg) {
        messagesNotifier.addMessage(userMsg);
        messagesNotifier.addMessage(aiMsg);
        _scrollToBottom(animated: true);
      },
      onAiChunk: (content, isDone) {
        final msgs = ref.read(messagesProvider(widget.contactId)).value ?? [];
        if (msgs.isNotEmpty) {
          final lastMsg = msgs.last;
          if (lastMsg.role == MessageRole.assistant) {
            messagesNotifier.updateLastMessage(
              lastMsg.id,
              content,
              isStreaming: !isDone,
            );
            _scrollToBottom(animated: false);
          }
        }
        if (isDone) {
          if (mounted) setState(() => _isSending = false);
          ref.read(contactsProvider.notifier).refresh();
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() => _isSending = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('发送失败: $error'), backgroundColor: Colors.red),
          );
        }
      },
    );
  }

  Future<void> _sendSpecialMessage(
      Contact contact, String type, Map<String, dynamic> metadata) async {
    final messagesNotifier =
        ref.read(messagesProvider(widget.contactId).notifier);
    final msgType =
        type == 'transfer' ? MessageType.transfer : MessageType.delivery;
    String content;
    if (type == 'transfer') {
      content = '¥${metadata['amount']}';
    } else {
      content = '${metadata['shop']} - ${metadata['items']}';
    }

    final userMsg = Message(
      id: '',
      contactId: widget.contactId,
      role: MessageRole.user,
      content: content,
      type: msgType,
      metadata: metadata,
      createdAt: DateTime.now(),
    );

    final service = ref.read(chatServiceProvider);
    final saved = await service.saveMessage(userMsg);
    messagesNotifier.addMessage(saved);
    _scrollToBottom(animated: true);
    ref.read(contactsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final contactAsync = ref.watch(contactsProvider).whenData(
          (contacts) => contacts.where((c) => c.id == widget.contactId).firstOrNull,
        );
    final contact = contactAsync.value ?? widget.contact;

    if (contact == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('聊天')),
        body: const Center(child: Text('联系人不存在')),
      );
    }

    final messagesAsync = ref.watch(messagesProvider(widget.contactId));

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AvatarWidget.fromContact(contact, size: 32),
                const SizedBox(width: 8),
                Text(contact.name),
              ],
            ),
            if (_isTyping)
              const Text('对方正在输入...',
                  style: TextStyle(fontSize: 11, color: WeChatColors.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz),
            onPressed: () => _showChatMenu(context, contact),
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('加载失败: $e')),
              data: (messages) {
                if (messages.isEmpty && !_isTyping) {
                  return _buildEmptyChat(contact);
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: messages.length + (_isTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      return MessageBubble(
                        message: messages[index],
                        contact: contact,
                      );
                    }
                    return const TypingIndicator();
                  },
                );
              },
            ),
          ),
          // 输入栏
          InputBar(
            onSend: (text) => _sendMessage(contact, text),
            onSendSpecial: (type, metadata) =>
                _sendSpecialMessage(contact, type, metadata),
            enabled: !_isSending,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyChat(Contact contact) {
    final hasFirstMes = contact.characterCardJson != null;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AvatarWidget.fromContact(contact, size: 64),
          const SizedBox(height: 12),
          Text(contact.name,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w500)),
          if (contact.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                contact.description,
                style: const TextStyle(
                    fontSize: 13, color: WeChatColors.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            hasFirstMes ? '开始对话' : '发送一条消息开始聊天',
            style: const TextStyle(color: WeChatColors.textHint, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showChatMenu(BuildContext context, Contact contact) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('联系人资料'),
              onTap: () {
                ctx.pop();
                context.push('/contact/detail/${contact.id}', extra: contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('编辑联系人'),
              onTap: () {
                ctx.pop();
                _editContact(context, contact);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: const Text('清空聊天记录'),
              onTap: () async {
                ctx.pop();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: const Text('清空记录'),
                    content: const Text('确定清空所有聊天记录？'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.of(d).pop(false),
                          child: const Text('取消')),
                      TextButton(
                          onPressed: () => Navigator.of(d).pop(true),
                          child: const Text('清空',
                              style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref
                      .read(messagesProvider(widget.contactId).notifier)
                      .clearMessages();
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除联系人',
                  style: TextStyle(color: Colors.red)),
              onTap: () {
                ctx.pop();
                _deleteContact(context, contact);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editContact(BuildContext context, Contact contact) async {
    final configs = ref.read(apiConfigProvider).value ?? [];
    final result = await showDialog<Contact>(
      context: context,
      builder: (ctx) => _ChatEditContactDialog(
        contact: contact,
        configs: configs,
      ),
    );
    if (result != null) {
      await ref.read(contactsProvider.notifier).updateContact(result);
    }
  }

  Future<void> _deleteContact(BuildContext context, Contact contact) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除联系人'),
        content: Text('确定删除 "${contact.name}"？相关聊天记录将一并删除。'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('删除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(contactsProvider.notifier).remove(contact.id);
      if (mounted) context.pop();
    }
  }
}

class _ChatEditContactDialog extends StatefulWidget {
  final Contact contact;
  final List<ApiConfig> configs;
  const _ChatEditContactDialog({
    required this.contact,
    required this.configs,
  });

  @override
  State<_ChatEditContactDialog> createState() =>
      _ChatEditContactDialogState();
}

class _ChatEditContactDialogState extends State<_ChatEditContactDialog> {
  late final _nameCtrl = TextEditingController(text: widget.contact.name);
  late final _descCtrl =
      TextEditingController(text: widget.contact.description);
  late final _promptCtrl =
      TextEditingController(text: widget.contact.systemPrompt);
  late String? _selectedConfigId = widget.contact.apiConfigId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('编辑联系人'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: '名称')),
            const SizedBox(height: 12),
            TextField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: '简介'),
                maxLines: 2),
            const SizedBox(height: 12),
            TextField(
                controller: _promptCtrl,
                decoration:
                    const InputDecoration(labelText: 'System Prompt'),
                maxLines: 4),
            if (widget.configs.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String?>(
                initialValue: _selectedConfigId,
                decoration: const InputDecoration(labelText: '绑定 API'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('不绑定')),
                  ...widget.configs.map(
                    (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedConfigId = v),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消')),
        ElevatedButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              widget.contact.copyWith(
                name: _nameCtrl.text.trim(),
                description: _descCtrl.text.trim(),
                systemPrompt: _promptCtrl.text.trim(),
                apiConfigId: _selectedConfigId,
              ),
            );
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
