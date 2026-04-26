import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'router.dart';
import 'theme/wechat_theme.dart';
import 'services/proactive/proactive_service.dart';
import 'services/update/update_service.dart';
import 'services/backup/auto_backup_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final proactive = ProactiveService();
  proactive.init();
  proactive.checkOnAppOpen();

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getBool('check_update_on_startup') ?? false) {
    UpdateService().checkUpdate(); // fire-and-forget
  }

  AutoBackupService().init();

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
