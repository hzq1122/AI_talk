import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/backup_provider.dart';
import '../../services/backup/backup_service.dart';
import '../../theme/wechat_colors.dart';

class BackupPage extends ConsumerStatefulWidget {
  const BackupPage({super.key});

  @override
  ConsumerState<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends ConsumerState<BackupPage>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 2, vsync: this);
  final _exportSections = <BackupSection>{...BackupSection.values};
  final _importSections = <BackupSection>{};
  String? _importPath;
  List<BackupSection>? _importSectionsAvailable;

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backupState = ref.watch(backupProvider);

    return Scaffold(
      backgroundColor: WeChatColors.background,
      appBar: AppBar(
        backgroundColor: WeChatColors.appBarBackground,
        title: const Text('备份与恢复'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: WeChatColors.primary,
          unselectedLabelColor: WeChatColors.textSecondary,
          tabs: const [Tab(text: '导出'), Tab(text: '导入')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExportTab(backupState),
          _buildImportTab(backupState),
        ],
      ),
    );
  }

  Widget _buildExportTab(ExportState state) {
    return ListView(
      children: [
        const SizedBox(height: 8),
        _buildSectionHeader('选择导出内容'),
        Container(
          color: Colors.white,
          child: Column(
            children: BackupSection.values.map((section) {
              return CheckboxListTile(
                title: Text(section.label),
                subtitle: Text(section.folderName,
                    style: const TextStyle(
                        fontSize: 12, color: WeChatColors.textHint)),
                value: _exportSections.contains(section),
                activeColor: WeChatColors.primary,
                onChanged: (v) {
                  setState(() {
                    if (v == true) {
                      _exportSections.add(section);
                    } else {
                      _exportSections.remove(section);
                    }
                  });
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              icon: state.isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.archive_outlined),
              label: Text(state.isExporting ? '导出中...' : '导出'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: WeChatColors.primary,
                  foregroundColor: Colors.white),
              onPressed: _exportSections.isEmpty || state.isExporting
                  ? null
                  : () async {
                      final path = await ref
                          .read(backupProvider.notifier)
                          .exportData(_exportSections);
                      if (path != null && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('导出成功'),
                            action: SnackBarAction(
                                label: '分享',
                                onPressed: () => _shareFile(path)),
                          ),
                        );
                      }
                    },
            ),
          ),
        ),
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Text(state.error!, style: const TextStyle(color: Colors.red)),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            '导出为 ZIP 压缩包，内部按板块分文件夹存储（api/、contacts/、messages/ 等），可直接手动编辑',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ),
      ],
    );
  }

  Widget _buildImportTab(ExportState state) {
    return ListView(
      children: [
        const SizedBox(height: 8),
        _buildSectionHeader('选择备份文件'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.folder_open),
              label: Text(_importPath != null ? '已选择备份文件' : '点击选择 ZIP 文件'),
              onPressed: state.isExporting ? null : () => _pickBackupFile(),
            ),
          ),
        ),
        if (_importSectionsAvailable != null) ...[
          _buildSectionHeader('选择导入内容'),
          Container(
            color: Colors.white,
            child: Column(
              children: _importSectionsAvailable!.map((section) {
                return CheckboxListTile(
                  title: Text(section.label),
                  value: _importSections.contains(section),
                  activeColor: WeChatColors.primary,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _importSections.add(section);
                      } else {
                        _importSections.remove(section);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: state.isExporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.restore_outlined),
                label: Text(state.isExporting ? '导入中...' : '导入选中内容'),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _importSections.isEmpty ? Colors.grey : Colors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed:
                    _importSections.isEmpty || state.isExporting
                        ? null
                        : () async {
                            final result = await ref
                                .read(backupProvider.notifier)
                                .importData(_importPath!, _importSections);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text(result ? '导入成功' : '导入失败')),
                              );
                            }
                          },
              ),
            ),
          ),
        ],
        if (state.error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child:
                Text(state.error!, style: const TextStyle(color: Colors.red)),
          ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title,
          style: const TextStyle(
              fontSize: 13,
              color: WeChatColors.textSecondary,
              fontWeight: FontWeight.w500)),
    );
  }

  Future<void> _pickBackupFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;

    final sections = await BackupService().listSections(path);
    setState(() {
      _importPath = path;
      _importSectionsAvailable = sections;
      _importSections.clear();
      _importSections.addAll(sections);
    });
  }

  Future<void> _shareFile(String path) async {
    await Share.shareXFiles([XFile(path)], text: 'Talk AI 备份');
  }
}
