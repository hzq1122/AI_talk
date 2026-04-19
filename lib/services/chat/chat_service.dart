import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart';
import '../database/contact_dao.dart';
import '../database/message_dao.dart';
import '../database/api_config_dao.dart';
import '../database/preset_dao.dart';
import '../api/llm_service.dart';
import '../api/openai_adapter.dart';
import '../api/anthropic_adapter.dart';
import '../api/context_manager.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';

class ChatService {
  late final ContactDao _contactDao;
  late final MessageDao _messageDao;
  late final ApiConfigDao _apiConfigDao;
  late final PresetDao _presetDao;
  final _uuid = const Uuid();
  final _contextManager = const ContextManager(
    strategy: ContextStrategy.slidingWindow,
    maxMessages: 20,
  );

  ChatService() {
    final db = DatabaseService();
    _contactDao = ContactDao(db);
    _messageDao = MessageDao(db);
    _apiConfigDao = ApiConfigDao(db);
    _presetDao = PresetDao(db);
  }

  // ─── 联系人 ───────────────────────────────────────────────────────────────

  Future<List<Contact>> getContacts() => _contactDao.getAll();

  Future<Contact?> getContact(String id) => _contactDao.getById(id);

  Future<Contact> createContact(Contact contact) =>
      _contactDao.insert(contact);

  Future<void> updateContact(Contact contact) =>
      _contactDao.update(contact);

  Future<void> deleteContact(String id) async {
    await _messageDao.deleteByContact(id);
    await _contactDao.delete(id);
  }

  Future<List<Contact>> searchContacts(String query) =>
      _contactDao.search(query);

  // ─── 消息 ─────────────────────────────────────────────────────────────────

  Future<List<Message>> getMessages(String contactId) =>
      _messageDao.getByContact(contactId);

  Future<Message> saveMessage(Message message) async {
    final saved = await _messageDao.insert(message);
    await _contactDao.updateLastMessage(
      message.contactId,
      message.content,
      DateTime.now(),
    );
    return saved;
  }

  Future<void> deleteMessages(String contactId) =>
      _messageDao.deleteByContact(contactId);

  // ─── API 配置 ─────────────────────────────────────────────────────────────

  Future<List<ApiConfig>> getApiConfigs() => _apiConfigDao.getAll();

  Future<ApiConfig> createApiConfig(ApiConfig config) =>
      _apiConfigDao.insert(config);

  Future<void> updateApiConfig(ApiConfig config) =>
      _apiConfigDao.update(config);

  Future<void> deleteApiConfig(String id) => _apiConfigDao.delete(id);

  // ─── AI 对话 ─────────────────────────────────────────────────────────────

  /// 发送用户消息并获取 AI 流式回复（通过回调返回数据，Fire-and-forget 安全）
  Future<void> sendMessage({
    required Contact contact,
    required String userText,
    required void Function(Message userMsg, Message aiMsg) onMessagesCreated,
    required void Function(String content, bool isDone) onAiChunk,
    void Function(String error)? onError,
  }) async {
    // 1. 查找 API 配置
    ApiConfig? config;
    if (contact.apiConfigId != null) {
      config = await _apiConfigDao.getById(contact.apiConfigId!);
    }
    if (config == null) {
      final configs = await _apiConfigDao.getAll();
      if (configs.isEmpty) {
        onError?.call('未配置 API，请先在设置中添加 API 配置');
        return;
      }
      config = configs.first;
    }

    // 2. 插入用户消息
    final userMsg = await _messageDao.insert(Message(
      id: '',
      contactId: contact.id,
      role: MessageRole.user,
      content: userText,
      createdAt: DateTime.now(),
    ));

    // 3. 创建 AI 消息占位
    final aiMsgId = _uuid.v4();
    final aiMsgPlaceholder = await _messageDao.insert(Message(
      id: aiMsgId,
      contactId: contact.id,
      role: MessageRole.assistant,
      content: '',
      isStreaming: true,
      createdAt: DateTime.now().add(const Duration(milliseconds: 1)),
    ));

    onMessagesCreated(userMsg, aiMsgPlaceholder);

    // 4. 获取历史消息并裁剪上下文
    final history = await _messageDao.getRecentByContact(contact.id, 40);
    final contextMessages = _contextManager.trim(
      history.where((m) => !m.isStreaming).toList(),
      config,
    );

    // 5. 构建 system prompt（包含全局提示词 + 预设 + 角色提示词）
    final systemPrompt = await _buildFullSystemPrompt(contact);

    // 6. 选择 Adapter
    final LlmService service = config.provider == LlmProvider.anthropic
        ? AnthropicAdapterImpl()
        : OpenAiAdapterImpl();

    // 7. 流式接收回复
    final buffer = StringBuffer();
    try {
      await for (final chunk in service.sendMessageStream(
        config: config,
        messages: contextMessages,
        systemPrompt: systemPrompt,
      )) {
        buffer.write(chunk);
        await _messageDao.updateContent(aiMsgId, buffer.toString(),
            isStreaming: true);
        onAiChunk(buffer.toString(), false);
      }

      // 8. 完成：更新 DB 并通知 UI
      await _messageDao.updateContent(aiMsgId, buffer.toString(),
          isStreaming: false);
      onAiChunk(buffer.toString(), true);

      await _contactDao.updateLastMessage(
        contact.id,
        buffer.toString(),
        DateTime.now(),
      );
    } catch (e) {
      await _messageDao.updateContent(aiMsgId, '[错误] ${e.toString()}',
          isStreaming: false);
      onError?.call(e.toString());
    }
  }

  Future<void> clearUnread(String contactId) =>
      _contactDao.clearUnread(contactId);

  Future<String?> _buildFullSystemPrompt(Contact contact) async {
    final parts = <String>[];

    // 全局提示词
    final prefs = await SharedPreferences.getInstance();
    final globalEnabled = prefs.getBool('global_prompt_enabled') ?? false;
    if (globalEnabled) {
      final globalText = prefs.getString('global_prompt_text') ??
          '你现在是在聊天，并非在现实，请让你的回复更符合聊天时的状态';
      if (globalText.isNotEmpty) parts.add(globalText);
    }

    // 对话补全预设
    final presets = await _presetDao.getAll();
    for (final preset in presets) {
      final text = preset.buildPromptText();
      if (text.isNotEmpty) parts.add(text);
    }

    // 角色 system prompt
    if (contact.systemPrompt.isNotEmpty) {
      parts.add(contact.systemPrompt);
    }

    return parts.isEmpty ? null : parts.join('\n\n');
  }
}
