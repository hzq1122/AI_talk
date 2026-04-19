import 'dart:convert';

class ChatPreset {
  final String id;
  final String name;
  final bool enabled;
  final List<PresetSegment> segments;
  final DateTime? createdAt;

  ChatPreset({
    required this.id,
    required this.name,
    this.enabled = true,
    required this.segments,
    this.createdAt,
  });

  ChatPreset copyWith({
    String? name,
    bool? enabled,
    List<PresetSegment>? segments,
  }) =>
      ChatPreset(
        id: id,
        name: name ?? this.name,
        enabled: enabled ?? this.enabled,
        segments: segments ?? this.segments,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'segments': segments.map((s) => s.toJson()).toList(),
        'createdAt': createdAt?.toIso8601String(),
      };

  factory ChatPreset.fromJson(Map<String, dynamic> json) {
    final segmentsRaw = json['segments'] as List? ?? [];
    return ChatPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Unnamed',
      enabled: json['enabled'] as bool? ?? true,
      segments: segmentsRaw
          .map((s) => PresetSegment.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
    );
  }

  factory ChatPreset.fromDbRow(Map<String, dynamic> row) {
    List<PresetSegment> segments = [];
    if (row['segments'] != null) {
      final decoded = jsonDecode(row['segments'] as String) as List;
      segments = decoded
          .map((s) => PresetSegment.fromJson(s as Map<String, dynamic>))
          .toList();
    }
    return ChatPreset(
      id: row['id'] as String,
      name: row['name'] as String,
      enabled: (row['enabled'] as int) == 1,
      segments: segments,
      createdAt: row['created_at'] != null
          ? DateTime.tryParse(row['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toDbRow() => {
        'id': id,
        'name': name,
        'enabled': enabled ? 1 : 0,
        'segments': jsonEncode(segments.map((s) => s.toJson()).toList()),
        'created_at': (createdAt ?? DateTime.now()).toIso8601String(),
      };

  String buildPromptText() {
    if (!enabled) return '';
    return segments
        .where((s) => s.enabled)
        .map((s) => s.content)
        .join('\n\n');
  }
}

class PresetSegment {
  final String label;
  final String role;
  final String content;
  final bool enabled;

  PresetSegment({
    required this.label,
    this.role = 'system',
    required this.content,
    this.enabled = true,
  });

  PresetSegment copyWith({
    String? label,
    String? role,
    String? content,
    bool? enabled,
  }) =>
      PresetSegment(
        label: label ?? this.label,
        role: role ?? this.role,
        content: content ?? this.content,
        enabled: enabled ?? this.enabled,
      );

  Map<String, dynamic> toJson() => {
        'label': label,
        'role': role,
        'content': content,
        'enabled': enabled,
      };

  factory PresetSegment.fromJson(Map<String, dynamic> json) => PresetSegment(
        label: json['label'] as String? ?? '',
        role: json['role'] as String? ?? 'system',
        content: json['content'] as String? ?? '',
        enabled: json['enabled'] as bool? ?? true,
      );
}
