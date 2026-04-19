import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/contact.dart';
import '../../models/api_config.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/api_config_provider.dart';
import '../../theme/wechat_colors.dart';
import '../../widgets/avatar_widget.dart';
import '../../services/character/character_card_service.dart';
import '../../services/character/character_png_service.dart';

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({super.key});

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {
  bool _isSearching = false;
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(filteredContactsProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: '搜索联系人...',
                  border: InputBorder.none,
                ),
                onChanged: (q) =>
                    ref.read(contactSearchQueryProvider.notifier).state = q,
              )
            : const Text('通讯录'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                  ref.read(contactSearchQueryProvider.notifier).state = '';
                }
              });
            },
          ),
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.file_download_outlined),
              tooltip: '导入角色卡',
              onPressed: () => _showImportMenu(context),
            ),
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              tooltip: '新建联系人',
              onPressed: () => _showAddContact(context),
            ),
          ],
        ],
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return _buildEmpty();
          }
          return _buildContactList(contacts);
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.people_outline,
              size: 64, color: WeChatColors.textHint),
          const SizedBox(height: 12),
          const Text('暂无联系人',
              style: TextStyle(color: WeChatColors.textSecondary)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.person_add),
                label: const Text('新建联系人'),
                onPressed: () => _showAddContact(context),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_download_outlined),
                label: const Text('导入角色卡'),
                onPressed: () => _showImportMenu(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactList(List<Contact> contacts) {
    // 按首字母分组
    final grouped = <String, List<Contact>>{};
    for (final c in contacts) {
      final key = _getGroupKey(c.name);
      grouped.putIfAbsent(key, () => []).add(c);
    }
    final keys = grouped.keys.toList()..sort();

    return ListView.builder(
      itemCount: keys.length * 2, // header + items
      itemBuilder: (context, index) {
        final groupIndex = index ~/ 2;
        if (index.isEven) {
          // 分组头
          return Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: WeChatColors.background,
            child: Text(
              keys[groupIndex],
              style: const TextStyle(
                fontSize: 13,
                color: WeChatColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        } else {
          // 联系人列表
          final group = grouped[keys[groupIndex]]!;
          return Column(
            children: group
                .map((c) => _ContactListTile(
                      contact: c,
                      onTap: () => _openContact(c),
                    ))
                .toList(),
          );
        }
      },
    );
  }

  String _getGroupKey(String name) {
    if (name.isEmpty) return '#';
    final first = name[0];
    // 简单判断：A-Z 直接用，其他用 #
    if (RegExp(r'[A-Za-z]').hasMatch(first)) {
      return first.toUpperCase();
    }
    return '#';
  }

  void _openContact(Contact contact) {
    context.push('/chat/${contact.id}', extra: contact);
  }

  Future<void> _showAddContact(BuildContext context) async {
    final configs = ref.read(apiConfigProvider).value ?? [];
    final result = await showDialog<Contact>(
      context: context,
      builder: (ctx) => _EditContactDialog(configs: configs),
    );
    if (result != null) {
      final saved = await ref.read(contactsProvider.notifier).addAndReturn(result);
      if (!mounted) return;
      context.push('/chat/${saved.id}', extra: saved);
    }
  }

  /// 显示导入角色卡菜单（JSON / PNG）
  void _showImportMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.data_object, color: WeChatColors.primary),
              title: const Text('从 JSON 文件导入'),
              subtitle: const Text('支持 SillyTavern V2 角色卡格式'),
              onTap: () {
                Navigator.of(ctx).pop();
                _importFromJson();
              },
            ),
            ListTile(
              leading: const Icon(Icons.image_outlined, color: WeChatColors.primary),
              title: const Text('从 PNG 图片导入'),
              subtitle: const Text('角色卡嵌入 PNG 图片（tEXt chunk）'),
              onTap: () {
                Navigator.of(ctx).pop();
                _importFromPng();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _importFromJson() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: '选择角色卡 JSON 文件',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final contact = await CharacterCardService.fromJsonFile(path);
    if (!mounted) return;
    if (contact == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法解析角色卡，请确认文件格式正确')),
      );
      return;
    }
    await _previewAndSave(contact);
  }

  Future<void> _importFromPng() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['png'],
      dialogTitle: '选择角色卡 PNG 图片',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final contact = await CharacterPngService.fromPngFile(path);
    if (!mounted) return;
    if (contact == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该图片中未找到嵌入的角色卡数据')),
      );
      return;
    }

    // 将 PNG 设为头像路径
    final contactWithAvatar = contact.copyWith(avatar: path);
    await _previewAndSave(contactWithAvatar);
  }

  /// 导入后简单确认，保存后直接进入聊天
  Future<void> _previewAndSave(Contact draft) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('导入角色卡'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvatarWidget(
              imagePath: draft.avatar,
              name: draft.name,
              size: 64,
            ),
            const SizedBox(height: 12),
            Text(draft.name,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w600)),
            if (draft.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                draft.description,
                style: const TextStyle(
                    fontSize: 13, color: WeChatColors.textSecondary),
                textAlign: TextAlign.center,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            if (draft.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: draft.tags
                    .take(5)
                    .map((t) => Chip(
                          label: Text(t, style: const TextStyle(fontSize: 10)),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          padding: EdgeInsets.zero,
                        ))
                    .toList(),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              '导入后可在联系人详情中编辑资料和绑定 API',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('取消')),
          ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('导入并开始聊天')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final saved = await ref.read(contactsProvider.notifier).addAndReturn(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已导入「${saved.name}」')),
    );
    context.push('/chat/${saved.id}', extra: saved);
  }
}

class _ContactListTile extends StatelessWidget {
  final Contact contact;
  final VoidCallback onTap;

  const _ContactListTile({required this.contact, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            AvatarWidget.fromContact(contact, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(contact.name,
                      style: const TextStyle(
                          fontSize: 16, color: WeChatColors.textPrimary)),
                  if (contact.description.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      contact.description,
                      style: const TextStyle(
                          fontSize: 12,
                          color: WeChatColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (contact.tags.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: WeChatColors.primary.withAlpha(26),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  contact.tags.first,
                  style: const TextStyle(
                      fontSize: 10, color: WeChatColors.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 添加/编辑联系人弹窗
class _EditContactDialog extends StatefulWidget {
  final List<ApiConfig> configs;
  final Contact? existing;
  final String? titleOverride;

  const _EditContactDialog({
    required this.configs,
    this.existing,
    this.titleOverride,
  });

  @override
  State<_EditContactDialog> createState() => _EditContactDialogState();
}

class _EditContactDialogState extends State<_EditContactDialog> {
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _descCtrl =
      TextEditingController(text: widget.existing?.description ?? '');
  late final _promptCtrl =
      TextEditingController(text: widget.existing?.systemPrompt ?? '');
  late String? _selectedConfigId = widget.existing?.apiConfigId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.titleOverride ??
        (widget.existing == null ? '新建联系人' : '编辑联系人');

    return AlertDialog(
      title: Text(title),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 角色卡预览标签
            if (widget.existing?.characterCardJson != null)
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: WeChatColors.primary.withAlpha(20),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person_pin,
                        size: 16, color: WeChatColors.primary),
                    const SizedBox(width: 6),
                    const Text('含角色卡数据',
                        style: TextStyle(
                            fontSize: 12, color: WeChatColors.primary)),
                  ],
                ),
              ),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: '名称 *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(labelText: '简介'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptCtrl,
              decoration: const InputDecoration(
                labelText: 'System Prompt',
                hintText: '定义 AI 角色...',
              ),
              maxLines: 4,
            ),
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
            if (_nameCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('名称不能为空')));
              return;
            }
            final contact = Contact(
              id: widget.existing?.id ?? '',
              name: _nameCtrl.text.trim(),
              description: _descCtrl.text.trim(),
              systemPrompt: _promptCtrl.text.trim(),
              apiConfigId: _selectedConfigId,
              tags: widget.existing?.tags ?? [],
              characterCardJson: widget.existing?.characterCardJson,
              avatar: widget.existing?.avatar,
            );
            Navigator.of(context).pop(contact);
          },
          child: const Text('保存'),
        ),
      ],
    );
  }
}
