import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/api_config_provider.dart';
import '../../providers/contacts_provider.dart';
import '../../providers/settings_provider.dart';
import '../../theme/wechat_colors.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiConfigs = ref.watch(apiConfigProvider).value ?? [];
    final contactsAsync = ref.watch(contactsProvider);
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        title: const Text('我'),
        backgroundColor: WeChatColors.appBarBackground,
      ),
      body: ListView(
        children: [
          // 用户信息
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: WeChatColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child:
                      const Icon(Icons.person, color: Colors.white, size: 36),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Talk AI 用户',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text('已配置 ${apiConfigs.length} 个 API',
                          style: const TextStyle(
                              color: WeChatColors.textSecondary,
                              fontSize: 13)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: WeChatColors.textHint),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // 功能列表
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading:
                      const Icon(Icons.api, color: WeChatColors.primary),
                  title: const Text('API 配置'),
                  subtitle: Text(
                    apiConfigs.isEmpty
                        ? '点击添加 API 配置'
                        : apiConfigs.map((c) => c.name).join('、'),
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: apiConfigs.isEmpty
                      ? const Icon(Icons.warning_amber, color: Colors.orange)
                      : const Icon(Icons.chevron_right,
                          color: WeChatColors.textHint),
                  onTap: () => context.push('/settings/api'),
                ),
                const Divider(height: 0, indent: 56),
                ListTile(
                  leading: const Icon(Icons.tune,
                      color: WeChatColors.primary),
                  title: const Text('通用设置'),
                  subtitle: settingsAsync.when(
                    data: (s) => Text(
                      s.globalPromptEnabled ? '通用提示词已启用' : '通用提示词未启用',
                      style: const TextStyle(fontSize: 12),
                    ),
                    loading: () => const SizedBox(),
                    error: (_, _) => const SizedBox(),
                  ),
                  trailing: const Icon(Icons.chevron_right,
                      color: WeChatColors.textHint),
                  onTap: () => context.push('/settings/general'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // AI 状态诊断面板
          _AiStatusPanel(contactsAsync: contactsAsync),
          const SizedBox(height: 8),
          Container(
            color: Colors.white,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline,
                      color: WeChatColors.textSecondary),
                  title: const Text('关于 Talk AI'),
                  trailing: const Icon(Icons.chevron_right,
                      color: WeChatColors.textHint),
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Talk AI',
      applicationVersion: '1.0.0',
      applicationLegalese: 'AI 驱动的微信风格社交应用\n支持 OpenAI、Anthropic 等多种 LLM',
    );
  }
}

class _AiStatusPanel extends StatelessWidget {
  final AsyncValue contactsAsync;

  const _AiStatusPanel({required this.contactsAsync});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Icon(Icons.monitor_heart_outlined,
                    color: WeChatColors.primary, size: 20),
                SizedBox(width: 8),
                Text('AI 状态诊断',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 8),
          contactsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: _StatusRow(
                icon: Icons.error_outline,
                color: Colors.red,
                label: '加载失败',
                detail: e.toString(),
              ),
            ),
            data: (contacts) {
              final contactList =
                  (contacts as List).cast<dynamic>();
              if (contactList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(16),
                  child: _StatusRow(
                    icon: Icons.info_outline,
                    color: WeChatColors.textHint,
                    label: '暂无联系人',
                    detail: '添加联系人后可查看状态',
                  ),
                );
              }

              final totalContacts = contactList.length;
              final proactiveEnabled =
                  contactList.where((c) => c.proactiveEnabled == true).length;
              final withPrompt = contactList
                  .where((c) =>
                      (c.systemPrompt as String).isNotEmpty ||
                      c.characterCardJson != null)
                  .length;
              final withApi = contactList
                  .where((c) => c.apiConfigId != null)
                  .length;
              final withUnread = contactList
                  .where((c) => (c.unreadCount as int) > 0)
                  .length;

              final readyCount = contactList.where((c) =>
                  c.proactiveEnabled == true &&
                  ((c.systemPrompt as String).isNotEmpty ||
                      c.characterCardJson != null)).length;

              final progress = totalContacts > 0
                  ? readyCount / totalContacts
                  : 0.0;

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: Column(
                  children: [
                    // 整体进度条
                    Row(
                      children: [
                        const Text('自动行为就绪',
                            style: TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: const Color(0xFFE0E0E0),
                              valueColor:
                                  const AlwaysStoppedAnimation(
                                      WeChatColors.primary),
                              minHeight: 8,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                            '$readyCount/$totalContacts',
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _StatusRow(
                      icon: Icons.auto_awesome,
                      color: proactiveEnabled > 0
                          ? WeChatColors.primary
                          : WeChatColors.textHint,
                      label: '主动消息',
                      detail: '$proactiveEnabled/$totalContacts 已启用',
                    ),
                    const SizedBox(height: 6),
                    _StatusRow(
                      icon: Icons.psychology,
                      color: withPrompt > 0
                          ? WeChatColors.primary
                          : Colors.orange,
                      label: '角色设定',
                      detail: withPrompt > 0
                          ? '$withPrompt/$totalContacts 已配置'
                          : '未配置（AI 无法主动发消息）',
                    ),
                    const SizedBox(height: 6),
                    _StatusRow(
                      icon: Icons.api,
                      color: withApi > 0
                          ? WeChatColors.primary
                          : Colors.orange,
                      label: 'API 绑定',
                      detail: '$withApi/$totalContacts 已绑定',
                    ),
                    if (withUnread > 0) ...[
                      const SizedBox(height: 6),
                      _StatusRow(
                        icon: Icons.mark_chat_unread,
                        color: Colors.red,
                        label: '未读消息',
                        detail: '$withUnread 个联系人有未读消息',
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String detail;

  const _StatusRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Text(label,
            style: const TextStyle(fontSize: 13, color: WeChatColors.textPrimary)),
        const Spacer(),
        Text(detail,
            style: const TextStyle(
                fontSize: 12, color: WeChatColors.textSecondary)),
      ],
    );
  }
}
