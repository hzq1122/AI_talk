import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_service.dart';
import '../database/contact_dao.dart';
import '../database/message_dao.dart';
import '../database/api_config_dao.dart';
import '../api/llm_service.dart';
import '../moments/moments_service.dart';
import '../../models/contact.dart';
import '../../models/message.dart';
import '../../models/api_config.dart';
import '../../models/moment.dart';

class ProactiveService {
  static final ProactiveService _instance = ProactiveService._internal();
  factory ProactiveService() => _instance;
  ProactiveService._internal();

  Timer? _timer;
  final _random = Random();
  late final ContactDao _contactDao;
  late final MessageDao _messageDao;
  late final ApiConfigDao _apiConfigDao;
  bool _initialized = false;

  void Function()? onNewMessage;

  void init() {
    if (_initialized) return;
    _initialized = true;
    final db = DatabaseService();
    _contactDao = ContactDao(db);
    _messageDao = MessageDao(db);
    _apiConfigDao = ApiConfigDao(db);
    _timer = Timer.periodic(const Duration(minutes: 5), (_) => _check());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _initialized = false;
  }

  int _checkCount = 0;

  Future<void> _check() async {
    final now = DateTime.now();
    if (now.hour >= 23 || now.hour < 7) return;

    final prefs = await SharedPreferences.getInstance();
    final momentsInterval = prefs.getInt('moments_interval_minutes') ?? 60;
    final checksNeeded = (momentsInterval / 5).round().clamp(1, 288);

    _checkCount++;
    if (_checkCount % checksNeeded == 0) {
      MomentsService().init();
      await MomentsService().generateMomentsForAllContacts();
      await _aiAutoInteractWithMoments();
    }

    final contacts = await _contactDao.getAll();
    final configs = await _apiConfigDao.getAll();
    if (configs.isEmpty) return;

    for (final contact in contacts) {
      if (!contact.proactiveEnabled) continue;
      if (contact.systemPrompt.isEmpty && contact.characterCardJson == null) {
        continue;
      }

      final lastProactive = contact.lastProactiveAt;
      final minHours = 2 + _random.nextInt(7);
      if (lastProactive != null &&
          now.difference(lastProactive).inHours < minHours) {
        continue;
      }

      if (_random.nextDouble() > 0.3) continue;

      await _sendProactiveMessage(contact, configs);
    }
  }

  /// APP 启动时调用：根据上次消息时间差决定是否触发 AI 自动行为
  Future<void> checkOnAppOpen() async {
    if (!_initialized) return;
    final contacts = await _contactDao.getAll();
    final configs = await _apiConfigDao.getAll();
    if (configs.isEmpty) return;

    final now = DateTime.now();
    for (final contact in contacts) {
      if (!contact.proactiveEnabled) continue;
      if (contact.systemPrompt.isEmpty && contact.characterCardJson == null) {
        continue;
      }

      final lastMsgTime = contact.lastMessageAt;
      if (lastMsgTime == null) continue;

      final timeDiff = now.difference(lastMsgTime);

      // 超过2小时未互动，有概率主动发消息
      if (timeDiff.inHours >= 2) {
        final chance = (timeDiff.inHours / 24.0).clamp(0.1, 0.8);
        if (_random.nextDouble() < chance) {
          await _sendProactiveMessage(contact, configs);
        }
      }
    }

    // 也触发朋友圈自动互动
    await _aiAutoInteractWithMoments();
  }

  /// AI 自动对朋友圈进行点赞和评论
  Future<void> _aiAutoInteractWithMoments() async {
    final momentsService = MomentsService();
    momentsService.init();
    final moments = await momentsService.getAllMoments(limit: 10);
    final contacts = await _contactDao.getAll();
    final configs = await _apiConfigDao.getAll();
    if (configs.isEmpty) return;

    for (final moment in moments) {
      final momentAuthor =
          contacts.where((c) => c.id == moment.contactId).firstOrNull;
      if (momentAuthor == null) continue;

      // 其他 AI 联系人对这条朋友圈进行互动
      for (final otherContact in contacts) {
        if (otherContact.id == moment.contactId) continue;
        if (!otherContact.proactiveEnabled) continue;
        if (otherContact.systemPrompt.isEmpty &&
            otherContact.characterCardJson == null) {
          continue;
        }

        // 已经互动过就跳过
        if (moment.likes.contains(otherContact.id)) continue;
        final alreadyCommented = moment.comments
            .any((c) => c.authorId == otherContact.id);
        if (alreadyCommented) continue;

        // 30% 概率点赞
        if (_random.nextDouble() < 0.3) {
          await momentsService.toggleLike(moment.id, otherContact.id);
        }

        // 20% 概率评论
        if (_random.nextDouble() < 0.2) {
          await _aiCommentOnMoment(
              momentsService, moment, otherContact, configs);
        }
      }
    }
  }

  Future<void> _aiCommentOnMoment(MomentsService momentsService,
      Moment moment, Contact commenter, List<ApiConfig> configs) async {
    ApiConfig config = configs.first;
    if (commenter.apiConfigId != null) {
      config = configs
              .where((c) => c.id == commenter.apiConfigId)
              .firstOrNull ??
          config;
    }

    final systemPrompt = '''${commenter.systemPrompt}

你看到朋友圈一条动态: "${moment.content}"
请你以自己的身份写一条评论。
要求：
- 简短自然，1-2句话
- 符合你的角色性格
- 直接输出评论内容''';

    final service = LlmService.fromConfig(config);
    try {
      final reply = await service.sendMessage(
        config: config,
        messages: [
          Message(
            id: 'comment',
            contactId: commenter.id,
            role: MessageRole.user,
            content: '评论这条朋友圈',
          ),
        ],
        systemPrompt: systemPrompt,
      );

      if (reply.trim().isNotEmpty) {
        await momentsService.addComment(
          moment.id,
          MomentComment(
            authorId: commenter.id,
            authorName: commenter.name,
            content: reply.trim(),
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _sendProactiveMessage(
      Contact contact, List<ApiConfig> configs) async {
    ApiConfig? config;
    if (contact.apiConfigId != null) {
      config = configs.where((c) => c.id == contact.apiConfigId).firstOrNull;
    }
    config ??= configs.first;

    final proactiveTypes = [
      '发一条日常问候消息',
      '分享一件你最近经历的有趣的事',
      '随便聊聊最近的心情',
      '分享一个你的想法或感悟',
      '问候对方最近怎么样',
      '分享你正在做的事情',
    ];
    final selectedType = proactiveTypes[_random.nextInt(proactiveTypes.length)];

    final hour = DateTime.now().hour;
    String timeContext;
    if (hour < 9) {
      timeContext = '现在是早上';
    } else if (hour < 12) {
      timeContext = '现在是上午';
    } else if (hour < 14) {
      timeContext = '现在是中午';
    } else if (hour < 18) {
      timeContext = '现在是下午';
    } else {
      timeContext = '现在是晚上';
    }

    final systemPrompt = '''${contact.systemPrompt}

你现在要主动给对方发一条消息。$timeContext。
请你$selectedType。
要求：
- 像真人一样自然，不要太正式
- 简短，1-3句话
- 符合你的角色性格
- 不要用"亲爱的"等过于亲密的称呼（除非角色设定如此）
- 直接输出消息内容，不要加任何前缀''';

    final service = LlmService.fromConfig(config);
    try {
      final dummyMsg = Message(
        id: 'ctx',
        contactId: contact.id,
        role: MessageRole.user,
        content: '（用户暂时不在线）',
      );

      final reply = await service.sendMessage(
        config: config,
        messages: [dummyMsg],
        systemPrompt: systemPrompt,
      );

      if (reply.trim().isEmpty) return;

      await _messageDao.insert(Message(
        id: '',
        contactId: contact.id,
        role: MessageRole.assistant,
        content: reply.trim(),
        createdAt: DateTime.now(),
      ));

      await _contactDao.updateLastMessage(
        contact.id,
        reply.trim(),
        DateTime.now(),
      );
      await _contactDao.incrementUnread(contact.id);

      final db = await DatabaseService().database;
      await db.update(
        'contacts',
        {'last_proactive_at': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [contact.id],
      );

      onNewMessage?.call();
    } catch (_) {}
  }
}
