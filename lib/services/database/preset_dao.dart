import 'package:uuid/uuid.dart';
import '../../models/chat_preset.dart';
import 'database_service.dart';

class PresetDao {
  final DatabaseService _db;
  const PresetDao(this._db);
  static const _uuid = Uuid();

  Future<List<ChatPreset>> getAll() async {
    final db = await _db.database;
    final rows = await db.query('chat_presets', orderBy: 'created_at ASC');
    return rows.map(ChatPreset.fromDbRow).toList();
  }

  Future<ChatPreset> insert(ChatPreset preset) async {
    final db = await _db.database;
    final id = preset.id.isEmpty ? _uuid.v4() : preset.id;
    final row = preset.copyWith().toDbRow();
    row['id'] = id;
    await db.insert('chat_presets', row);
    return ChatPreset.fromDbRow(row);
  }

  Future<void> update(ChatPreset preset) async {
    final db = await _db.database;
    await db.update(
      'chat_presets',
      preset.toDbRow(),
      where: 'id = ?',
      whereArgs: [preset.id],
    );
  }

  Future<void> delete(String id) async {
    final db = await _db.database;
    await db.delete('chat_presets', where: 'id = ?', whereArgs: [id]);
  }
}
