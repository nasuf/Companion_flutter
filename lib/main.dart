import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:fluwx/fluwx.dart';

import 'chat_socket.dart';
import 'companion_api.dart';
import 'models.dart';

part 'src/app/auth_gate.dart';
part 'src/auth/wechat_login_service.dart';
part 'src/screens/agent_create_page.dart';
part 'src/screens/chat/chat_page.dart';
part 'src/screens/login_page.dart';
part 'src/screens/main_shell.dart';
part 'src/screens/placeholder_page.dart';
part 'src/theme/app_colors.dart';
part 'src/utils/formatting.dart';
part 'src/widgets/chat/chat_header.dart';
part 'src/widgets/chat/chat_sidebar.dart';
part 'src/widgets/chat/composer.dart';
part 'src/widgets/chat/inline_banner.dart';
part 'src/widgets/chat/message_widgets.dart';
part 'src/widgets/chat/panels.dart';

void main() {
  runApp(const CompanionApp());
}

String get defaultApiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://localhost:8000';
}

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '伴生',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.page,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accent,
          brightness: Brightness.light,
        ),
        fontFamily: '.SF Pro Text',
      ),
      home: const AuthGate(),
    );
  }
}
