import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_preset.dart';
import '../services/database/database_service.dart';
import '../services/database/preset_dao.dart';

class PresetNotifier extends AsyncNotifier<List<ChatPreset>> {
  late final PresetDao _dao;

  @override
  Future<List<ChatPreset>> build() async {
    _dao = PresetDao(DatabaseService());
    return _dao.getAll();
  }

  Future<void> add(ChatPreset preset) async {
    final created = await _dao.insert(preset);
    state = AsyncData([...?state.value, created]);
  }

  Future<void> updatePreset(ChatPreset preset) async {
    await _dao.update(preset);
    state = AsyncData(
      state.value?.map((p) => p.id == preset.id ? preset : p).toList() ?? [],
    );
  }

  Future<void> togglePreset(String id) async {
    final presets = state.value ?? [];
    final preset = presets.firstWhere((p) => p.id == id);
    final updated = preset.copyWith(enabled: !preset.enabled);
    await _dao.update(updated);
    state = AsyncData(
      presets.map((p) => p.id == id ? updated : p).toList(),
    );
  }

  Future<void> toggleSegment(
      String presetId, int segmentIndex) async {
    final presets = state.value ?? [];
    final preset = presets.firstWhere((p) => p.id == presetId);
    final newSegments = List<PresetSegment>.from(preset.segments);
    final seg = newSegments[segmentIndex];
    newSegments[segmentIndex] = seg.copyWith(enabled: !seg.enabled);
    final updated = preset.copyWith(segments: newSegments);
    await _dao.update(updated);
    state = AsyncData(
      presets.map((p) => p.id == presetId ? updated : p).toList(),
    );
  }

  Future<void> remove(String id) async {
    await _dao.delete(id);
    state = AsyncData(
      state.value?.where((p) => p.id != id).toList() ?? [],
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _dao.getAll());
  }

  String buildAllEnabledPrompts() {
    final presets = state.value ?? [];
    return presets.map((p) => p.buildPromptText()).where((s) => s.isNotEmpty).join('\n\n');
  }
}

final presetProvider =
    AsyncNotifierProvider<PresetNotifier, List<ChatPreset>>(
        PresetNotifier.new);
