import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_service.dart';

enum BackupSection {
  apiConfigs,
  contacts,
  messages,
  moments,
  settings,
  presets,
  regexScripts,
  memoryEntries,
}

extension BackupSectionLabel on BackupSection {
  String get label => switch (this) {
        BackupSection.apiConfigs => 'API 配置',
        BackupSection.contacts => '联系人',
        BackupSection.messages => '聊天记录',
        BackupSection.moments => '朋友圈',
        BackupSection.settings => '应用设置',
        BackupSection.presets => '对话预设',
        BackupSection.regexScripts => '正则脚本',
        BackupSection.memoryEntries => '记忆表格',
      };

  String get folderName => switch (this) {
        BackupSection.apiConfigs => 'api',
        BackupSection.contacts => 'contacts',
        BackupSection.messages => 'messages',
        BackupSection.moments => 'moments',
        BackupSection.settings => 'settings',
        BackupSection.presets => 'presets',
        BackupSection.regexScripts => 'regex',
        BackupSection.memoryEntries => 'memory',
      };
}

class BackupService {
  final DatabaseService _dbService = DatabaseService();

  Future<String> exportToZip({
    required Set<BackupSection> sections,
  }) async {
    final db = await _dbService.database;
    final archive = Archive();

    for (final section in sections) {
      final folder = section.folderName;
      switch (section) {
        case BackupSection.apiConfigs:
          final rows = await db.query('api_configs');
          if (rows.isNotEmpty) {
            final data = jsonEncode(rows);
            archive.addFile(ArchiveFile(
                '$folder/api_configs.json', data.length, data.codeUnits));
          }
        case BackupSection.contacts:
          final rows = await db.query('contacts');
          if (rows.isNotEmpty) {
            final data = jsonEncode(rows);
            archive.addFile(ArchiveFile(
                '$folder/contacts.json', data.length, data.codeUnits));
          }
        case BackupSection.messages:
          final contacts = await db.query('contacts');
          for (final c in contacts) {
            final rows = await db.query('messages',
                where: 'contact_id = ?', whereArgs: [c['id']]);
            if (rows.isNotEmpty) {
              final data = jsonEncode(rows);
              final safeId = (c['id'] as String)
                  .replaceAll(RegExp(r'[^\w\-]'), '_');
              archive.addFile(ArchiveFile(
                  '$folder/$safeId.json', data.length, data.codeUnits));
            }
          }
        case BackupSection.moments:
          final rows = await db.query('moments');
          if (rows.isNotEmpty) {
            final data = jsonEncode(rows);
            archive.addFile(ArchiveFile(
                '$folder/moments.json', data.length, data.codeUnits));
          }
        case BackupSection.settings:
          final prefs = await SharedPreferences.getInstance();
          final keys = prefs.getKeys();
          final settings = <String, dynamic>{};
          for (final key in keys) {
            settings[key] = prefs.get(key);
          }
          final data = jsonEncode(settings);
          archive.addFile(ArchiveFile(
              '$folder/settings.json', data.length, data.codeUnits));
        case BackupSection.presets:
          final rows = await db.query('chat_presets');
          if (rows.isNotEmpty) {
            final data = jsonEncode(rows);
            archive.addFile(ArchiveFile(
                '$folder/presets.json', data.length, data.codeUnits));
          }
        case BackupSection.regexScripts:
          final rows = await db.query('regex_scripts');
          if (rows.isNotEmpty) {
            final data = jsonEncode(rows);
            archive.addFile(ArchiveFile(
                '$folder/regex_scripts.json', data.length, data.codeUnits));
          }
        case BackupSection.memoryEntries:
          final rows = await db.query('memory_entries');
          if (rows.isNotEmpty) {
            final data = jsonEncode(rows);
            archive.addFile(ArchiveFile(
                '$folder/memory_entries.json', data.length, data.codeUnits));
          }
      }
    }

    final manifest = {
      'version': '1.0',
      'app': 'talk_ai',
      'exported_at': DateTime.now().toIso8601String(),
      'sections': sections.map((s) => s.folderName).toList(),
    };
    final manifestData = jsonEncode(manifest);
    archive.addFile(ArchiveFile(
        'manifest.json', manifestData.length, manifestData.codeUnits));

    final dir = await getApplicationDocumentsDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final zipPath = '${dir.path}/talk_ai_backup_$timestamp.zip';

    final encoder = ZipEncoder();
    await File(zipPath).writeAsBytes(encoder.encode(archive)!);
    return zipPath;
  }

  Future<bool> importFromZip({
    required String zipPath,
    required Set<BackupSection> sections,
  }) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(bytes);

      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) return false;

      final db = await _dbService.database;

      for (final section in sections) {
        final folder = section.folderName;
        switch (section) {
          case BackupSection.apiConfigs:
            final file = archive.findFile('$folder/api_configs.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('api_configs', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.contacts:
            final file = archive.findFile('$folder/contacts.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('contacts', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.messages:
            for (final f in archive) {
              if (f.name.startsWith('$folder/') && f.name.endsWith('.json')) {
                try {
                  final rows = jsonDecode(utf8.decode(f.content)) as List;
                  for (final row in rows) {
                    await db.insert('messages', row as Map<String, dynamic>,
                        conflictAlgorithm: ConflictAlgorithm.replace);
                  }
                } catch (_) {}
              }
            }
          case BackupSection.moments:
            final file = archive.findFile('$folder/moments.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('moments', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.settings:
            final file = archive.findFile('$folder/settings.json');
            if (file != null) {
              final settings =
                  jsonDecode(utf8.decode(file.content)) as Map<String, dynamic>;
              final prefs = await SharedPreferences.getInstance();
              for (final entry in settings.entries) {
                final v = entry.value;
                if (v is int) {
                  await prefs.setInt(entry.key, v);
                } else if (v is double) {
                  await prefs.setDouble(entry.key, v);
                } else if (v is bool) {
                  await prefs.setBool(entry.key, v);
                } else if (v is String) {
                  await prefs.setString(entry.key, v);
                }
              }
            }
          case BackupSection.presets:
            final file = archive.findFile('$folder/presets.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('chat_presets', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.regexScripts:
            final file = archive.findFile('$folder/regex_scripts.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('regex_scripts', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
          case BackupSection.memoryEntries:
            final file = archive.findFile('$folder/memory_entries.json');
            if (file != null) {
              final rows = jsonDecode(utf8.decode(file.content)) as List;
              for (final row in rows) {
                await db.insert('memory_entries', row as Map<String, dynamic>,
                    conflictAlgorithm: ConflictAlgorithm.replace);
              }
            }
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<BackupSection>> listSections(String zipPath) async {
    try {
      final bytes = await File(zipPath).readAsBytes();
      final decoder = ZipDecoder();
      final archive = decoder.decodeBytes(bytes);

      final manifestFile = archive.findFile('manifest.json');
      if (manifestFile == null) return [];

      final manifest =
          jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
      final sectionNames =
          (manifest['sections'] as List?)?.cast<String>() ?? [];

      return sectionNames
          .map((name) => BackupSection.values
              .firstWhere((s) => s.folderName == name))
          .toList();
    } catch (_) {
      return [];
    }
  }
}
