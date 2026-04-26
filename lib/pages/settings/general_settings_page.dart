import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/chat_preset.dart';
import '../../models/regex_script.dart';
import '../../providers/settings_provider.dart';
import '../../providers/preset_provider.dart';
import '../../providers/regex_script_provider.dart';
import '../../theme/wechat_colors.dart';

class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final presetsAsync = ref.watch(presetProvider);
    final regexAsync = ref.watch(regexScriptProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        title: const Text('通用设置'),
      ),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
        data: (settings) {
          final presets = presetsAsync.value ?? [];
          final regexScripts = regexAsync.value ?? [];
          return ListView(
            children: [
              const SizedBox(height: 8),
              // 全局提示词
              _SectionHeader(title: '通用提示词'),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('启用通用提示词'),
                      subtitle: const Text('对所有聊天生效'),
                      value: settings.globalPromptEnabled,
                      activeColor: WeChatColors.primary,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setGlobalPromptEnabled(v),
                    ),
                    if (settings.globalPromptEnabled) ...[
                      const Divider(height: 0, indent: 16),
                      ListTile(
                        title: const Text('编辑提示词'),
                        subtitle: Text(
                          settings.globalPromptText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              color: WeChatColors.textSecondary),
                        ),
                        trailing: const Icon(Icons.chevron_right,
                            color: WeChatColors.textHint),
                        onTap: () =>
                            _editGlobalPrompt(context, ref, settings.globalPromptText),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 对话补全预设
              _SectionHeader(
                title: '对话补全预设',
                trailing: IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  onPressed: () => _importPreset(context, ref),
                  tooltip: '导入预设',
                ),
              ),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    if (presets.isEmpty)
                      const ListTile(
                        leading: Icon(Icons.info_outline,
                            color: WeChatColors.textHint),
                        title: Text('暂无预设'),
                        subtitle: Text('点击右上角导入 JSON 预设文件',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ...presets.map((preset) => _PresetTile(
                          preset: preset,
                          onToggle: () => ref
                              .read(presetProvider.notifier)
                              .togglePreset(preset.id),
                          onTap: () =>
                              _showPresetDetail(context, ref, preset),
                          onDelete: () => ref
                              .read(presetProvider.notifier)
                              .remove(preset.id),
                        )),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 正则脚本
              _SectionHeader(
                title: '正则脚本',
                trailing: IconButton(
                  icon: const Icon(Icons.file_download_outlined, size: 20),
                  onPressed: () => _importRegexScripts(context, ref),
                  tooltip: '导入正则脚本',
                ),
              ),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    if (regexScripts.isEmpty)
                      const ListTile(
                        leading: Icon(Icons.info_outline,
                            color: WeChatColors.textHint),
                        title: Text('暂无正则脚本'),
                        subtitle: Text('导入 SillyTavern 正则包 JSON 文件',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ...regexScripts.map((script) => _RegexScriptTile(
                          script: script,
                          onToggle: () => ref
                              .read(regexScriptProvider.notifier)
                              .toggle(script.id),
                          onDelete: () => ref
                              .read(regexScriptProvider.notifier)
                              .remove(script.id),
                        )),
                    if (regexScripts.isNotEmpty)
                      ListTile(
                        leading: const Icon(Icons.delete_sweep,
                            color: Colors.red, size: 20),
                        title: const Text('清空所有正则脚本',
                            style: TextStyle(color: Colors.red, fontSize: 14)),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('清空正则脚本'),
                              content: const Text('确定删除所有正则脚本？'),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(false),
                                    child: const Text('取消')),
                                TextButton(
                                    onPressed: () => Navigator.of(ctx).pop(true),
                                    child: const Text('清空',
                                        style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            ref.read(regexScriptProvider.notifier).removeAll();
                          }
                        },
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 记忆表格设置
              _SectionHeader(title: '记忆表格'),
              Container(
                color: Colors.white,
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('启用记忆表格'),
                      subtitle: const Text('AI 自动从对话中提取关键信息'),
                      value: settings.memoryEnabled,
                      activeColor: WeChatColors.primary,
                      onChanged: (v) => ref
                          .read(settingsProvider.notifier)
                          .setMemoryEnabled(v),
                    ),
                    if (settings.memoryEnabled) ...[
                      const Divider(height: 0, indent: 16),
                      ListTile(
                        title: const Text('更新频率'),
                        subtitle: Text(
                            '每 ${settings.memoryInterval} 句对话更新一次',
                            style: const TextStyle(fontSize: 13)),
                        trailing: const Icon(Icons.chevron_right,
                            color: WeChatColors.textHint),
                        onTap: () => _editMemoryInterval(
                            context, ref, settings.memoryInterval),
                      ),
                      const Divider(height: 0, indent: 16),
                      SwitchListTile(
                        title: const Text('使用主 API 填表'),
                        subtitle: const Text('关闭后需配置副 API 以节省消耗'),
                        value: settings.memoryUseMainApi,
                        activeColor: WeChatColors.primary,
                        onChanged: (v) => ref
                            .read(settingsProvider.notifier)
                            .setMemoryUseMainApi(v),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // 朋友圈更新间隔
              _SectionHeader(title: '朋友圈'),
              Container(
                color: Colors.white,
                child: ListTile(
                  title: const Text('自动更新间隔'),
                  subtitle: Text(
                      '${settings.momentsIntervalMinutes} 分钟',
                      style: const TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right,
                      color: WeChatColors.textHint),
                  onTap: () =>
                      _editMomentsInterval(context, ref, settings.momentsIntervalMinutes),
                ),
              ),
              const SizedBox(height: 8),
              // 钱包
              _SectionHeader(title: '钱包'),
              Container(
                color: Colors.white,
                child: ListTile(
                  title: const Text('钱包余额'),
                  subtitle: Text(
                      '¥${settings.walletBalance.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 13)),
                  trailing: const Icon(Icons.chevron_right,
                      color: WeChatColors.textHint),
                  onTap: () =>
                      _editWalletBalance(context, ref, settings.walletBalance),
                ),
              ),
              const SizedBox(height: 24),
            ],
          );
        },
      ),
    );
  }

  void _editGlobalPrompt(
      BuildContext context, WidgetRef ref, String current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('编辑通用提示词'),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: const InputDecoration(
            hintText: '输入提示词内容...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              ref
                  .read(settingsProvider.notifier)
                  .setGlobalPromptText(ctrl.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _editMomentsInterval(
      BuildContext context, WidgetRef ref, int current) {
    final intervals = [15, 30, 60, 120, 360, 720, 1440];
    final labels = ['15 分钟', '30 分钟', '1 小时', '2 小时', '6 小时', '12 小时', '24 小时'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择更新间隔',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...List.generate(intervals.length, (i) => ListTile(
                  title: Text(labels[i]),
                  selected: intervals[i] == current,
                  trailing: intervals[i] == current
                      ? const Icon(Icons.check, color: WeChatColors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setMomentsInterval(intervals[i]);
                    Navigator.of(ctx).pop();
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _importPreset(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: '选择预设 JSON 文件',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final content = await File(path).readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      final preset = ChatPreset.fromJson(json);
      if (preset.segments.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('预设文件中没有找到有效的段落')),
          );
        }
        return;
      }
      await ref.read(presetProvider.notifier).add(preset);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入预设「${preset.name}」')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  Future<void> _importRegexScripts(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      dialogTitle: '选择正则脚本 JSON 文件',
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    try {
      final content = await File(path).readAsString();
      final scripts = RegexScript.fromSillyTavernJson(content);
      if (scripts.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('未找到有效的正则脚本')),
          );
        }
        return;
      }
      await ref.read(regexScriptProvider.notifier).importScripts(scripts);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已导入 ${scripts.length} 个正则脚本')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    }
  }

  void _editMemoryInterval(
      BuildContext context, WidgetRef ref, int current) {
    final intervals = [5, 10, 15, 20, 30, 50];
    final labels = ['5 句', '10 句', '15 句', '20 句', '30 句', '50 句'];
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择记忆更新频率',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ...List.generate(intervals.length, (i) => ListTile(
                  title: Text(labels[i]),
                  selected: intervals[i] == current,
                  trailing: intervals[i] == current
                      ? const Icon(Icons.check, color: WeChatColors.primary)
                      : null,
                  onTap: () {
                    ref
                        .read(settingsProvider.notifier)
                        .setMemoryInterval(intervals[i]);
                    Navigator.of(ctx).pop();
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _editWalletBalance(
      BuildContext context, WidgetRef ref, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('自定义钱包余额'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('仅用于测试调整，实际使用请通过钱包充值/支出',
                style: TextStyle(fontSize: 12, color: Colors.orange)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: '余额',
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
              if (amount != null && amount >= 0) {
                ref
                    .read(settingsProvider.notifier)
                    .setWalletBalance(amount);
                Navigator.of(ctx).pop();
              }
            },
            child: const Text('设置'),
          ),
        ],
      ),
    );
  }

  void _showPresetDetail(
      BuildContext context, WidgetRef ref, ChatPreset preset) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(preset.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                  Text(preset.enabled ? '已启用' : '已禁用',
                      style: TextStyle(
                          color: preset.enabled
                              ? WeChatColors.primary
                              : WeChatColors.textHint,
                          fontSize: 13)),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: preset.segments.length,
                itemBuilder: (_, index) {
                  final seg = preset.segments[index];
                  return Column(
                    children: [
                      SwitchListTile(
                        title: Text(seg.label.isNotEmpty
                            ? seg.label
                            : '段落 ${index + 1}'),
                        subtitle: Text(
                          seg.content,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: seg.enabled,
                        activeColor: WeChatColors.primary,
                        onChanged: (_) => ref
                            .read(presetProvider.notifier)
                            .toggleSegment(preset.id, index),
                      ),
                      const Divider(height: 0),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Row(
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 13,
                  color: WeChatColors.textSecondary,
                  fontWeight: FontWeight.w500)),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  final ChatPreset preset;
  final VoidCallback onToggle;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _PresetTile({
    required this.preset,
    required this.onToggle,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final enabledCount =
        preset.segments.where((s) => s.enabled).length;
    return ListTile(
      title: Text(preset.name),
      subtitle: Text(
        '$enabledCount/${preset.segments.length} 段落已启用',
        style: const TextStyle(fontSize: 12),
      ),
      leading: Switch(
        value: preset.enabled,
        activeColor: WeChatColors.primary,
        onChanged: (_) => onToggle(),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_right,
                color: WeChatColors.textHint),
            onPressed: onTap,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline,
                color: WeChatColors.textHint, size: 20),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('删除预设'),
                  content: Text('确定删除「${preset.name}」？'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('取消')),
                    TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: const Text('删除',
                            style: TextStyle(color: Colors.red))),
                  ],
                ),
              );
              if (confirm == true) onDelete();
            },
          ),
        ],
      ),
    );
  }
}

class _RegexScriptTile extends StatelessWidget {
  final RegexScript script;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RegexScriptTile({
    required this.script,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final placements = script.placement
        .map((p) => RegexPlacement.label(p))
        .join(', ');
    return ListTile(
      title: Text(script.scriptName,
          style: TextStyle(
              color: script.disabled
                  ? WeChatColors.textHint
                  : WeChatColors.textPrimary)),
      subtitle: Text(
        placements.isNotEmpty ? '作用: $placements' : '无作用范围',
        style: const TextStyle(fontSize: 12),
      ),
      leading: Switch(
        value: !script.disabled,
        activeColor: WeChatColors.primary,
        onChanged: (_) => onToggle(),
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline,
            color: WeChatColors.textHint, size: 20),
        onPressed: () async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('删除正则脚本'),
              content: Text('确定删除「${script.scriptName}」？'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('取消')),
                TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('删除',
                        style: TextStyle(color: Colors.red))),
              ],
            ),
          );
          if (confirm == true) onDelete();
        },
      ),
    );
  }
}
