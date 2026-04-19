import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import '../../models/chat_preset.dart';
import '../../providers/settings_provider.dart';
import '../../providers/preset_provider.dart';
import '../../theme/wechat_colors.dart';

class GeneralSettingsPage extends ConsumerWidget {
  const GeneralSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);
    final presetsAsync = ref.watch(presetProvider);

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
