import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fluwx/fluwx.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sud_gip_plugin/sud_gip_plugin.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'chat_socket.dart';
import 'companion_api.dart';
import 'models.dart';

part 'src/app/auth_gate.dart';
part 'src/app/auth_session_store.dart';
part 'src/auth/wechat_login_service.dart';
part 'src/screens/agent_create_page.dart';
part 'src/screens/achievement_page.dart';
part 'src/screens/chat/chat_music_station_state.dart';
part 'src/screens/chat/chat_page.dart';
part 'src/screens/checkin_page.dart';
part 'src/screens/checkin/checkin_calendar.dart';
part 'src/screens/checkin/checkin_date_utils.dart';
part 'src/screens/checkin/checkin_editor_controls.dart';
part 'src/screens/checkin/checkin_editor_sheet.dart';
part 'src/screens/checkin/checkin_lunar.dart';
part 'src/screens/checkin/checkin_shared_widgets.dart';
part 'src/screens/checkin/checkin_task_list.dart';
part 'src/screens/capsule_page.dart';
part 'src/screens/game_page.dart';
part 'src/screens/last_will_page.dart';
part 'src/screens/login_page.dart';
part 'src/screens/main_shell.dart';
part 'src/screens/music_page.dart';
part 'src/screens/movie_page.dart';
part 'src/screens/offline_interaction_page.dart';
part 'src/screens/online_interaction_page.dart';
part 'src/screens/placeholder_page.dart';
part 'src/screens/weather_page.dart';
part 'src/services/checkin_notification_service.dart';
part 'src/services/music_playback_controller.dart';
part 'src/theme/app_colors.dart';
part 'src/widgets/achievement_card.dart';
part 'src/widgets/achievement_feedback.dart';
part 'src/widgets/achievement_header.dart';
part 'src/utils/formatting.dart';
part 'src/widgets/chat/chat_header.dart';
part 'src/widgets/chat/chat_sidebar.dart';
part 'src/widgets/chat/composer.dart';
part 'src/widgets/chat/inline_banner.dart';
part 'src/widgets/chat/message_widgets.dart';
part 'src/widgets/chat/panels.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
  await CheckinNotificationService.instance.initialize();
  runApp(const CompanionApp());
}

String get defaultApiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (kReleaseMode) return 'https://banshengcomp.com/api';
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
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
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
