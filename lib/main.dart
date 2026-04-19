import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'router.dart';
import 'theme/wechat_theme.dart';
import 'services/proactive/proactive_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final proactive = ProactiveService();
  proactive.init();
  proactive.checkOnAppOpen();
  runApp(const ProviderScope(child: TalkAiApp()));
}

class TalkAiApp extends StatelessWidget {
  const TalkAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Talk AI',
      theme: WeChatTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
