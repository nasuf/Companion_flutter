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
import 'package:flutter/services.dart' as services;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:fluwx/fluwx.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sud_gip_plugin/sud_gip_plugin.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'chat_socket.dart';
import 'companion_api.dart';
import 'models.dart';
import 'offline_models.dart';

part 'src/app/auth_gate.dart';
part 'src/app/auth_session_store.dart';
part 'src/auth/wechat_login_service.dart';
part 'src/screens/admin_tools_page.dart';
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
part 'src/screens/daily_share_header.dart';
part 'src/screens/capsule_page.dart';
part 'src/screens/daily_share_page.dart';
part 'src/screens/daily_share_preview.dart';
part 'src/screens/daily_share_widgets.dart';
part 'src/screens/game_page.dart';
part 'src/screens/last_will_page.dart';
part 'src/screens/login_page.dart';
part 'src/screens/main_shell.dart';
part 'src/screens/music_page.dart';
part 'src/screens/movie_page.dart';
part 'src/screens/offline_activity_detail_components.dart';
part 'src/screens/offline_activity_detail_media.dart';
part 'src/screens/offline_activity_detail_sheet.dart';
part 'src/screens/offline_activity_detail_shell.dart';
part 'src/screens/offline_activity_page.dart';
part 'src/screens/offline_gift_page.dart';
part 'src/screens/offline_interaction_page.dart';
part 'src/screens/offline_shared_widgets.dart';
part 'src/screens/online_interaction_page.dart';
part 'src/screens/placeholder_page.dart';
part 'src/screens/store_bundle_view.dart';
part 'src/screens/store_currency_painters.dart';
part 'src/screens/store_data.dart';
part 'src/screens/store_exchange_view.dart';
part 'src/screens/store_item_painters.dart';
part 'src/screens/store_models.dart';
part 'src/screens/store_page.dart';
part 'src/screens/store_recharge_view.dart';
part 'src/screens/store_scene_painters.dart';
part 'src/screens/store_subscription_hero.dart';
part 'src/screens/store_subscription_plan.dart';
part 'src/screens/store_subscription_view.dart';
part 'src/screens/store_widgets.dart';
part 'src/screens/weather_page.dart';
part 'src/services/checkin_notification_service.dart';
part 'src/services/app_notification_service.dart';
part 'src/services/music_playback_controller.dart';
part 'src/services/push_notification_service.dart';
part 'src/theme/app_theme.dart';
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
part 'src/widgets/chat/offline_activity_component_card.dart';
part 'src/widgets/chat/panels.dart';

final RouteObserver<PageRoute<dynamic>> appRouteObserver =
    RouteObserver<PageRoute<dynamic>>();
final AppThemeController appThemeController = AppThemeController();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tzdata.initializeTimeZones();
  tz.setLocalLocation(tz.getLocation('Asia/Shanghai'));
  await appThemeController.restore();
  await CheckinNotificationService.instance.initialize();
  await PushNotificationService.instance.initialize();
  AppNotificationService.instance.initialize();
  runApp(const CompanionApp());
}

String get defaultApiBaseUrl {
  const configured = String.fromEnvironment('API_BASE_URL');
  if (configured.isNotEmpty) return configured;
  if (kReleaseMode) return 'https://banshengcomp.com/api';
  if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  return 'http://localhost:8000';
}

class CompanionApp extends StatefulWidget {
  const CompanionApp({super.key});

  @override
  State<CompanionApp> createState() => _CompanionAppState();
}

class _CompanionAppState extends State<CompanionApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: appThemeController,
      builder: (context, _) {
        final brightness = appThemeController.resolveBrightness(
          WidgetsBinding.instance.platformDispatcher.platformBrightness,
        );
        AppColors.use(brightness);
        return AppThemeScope(
          controller: appThemeController,
          child: AnnotatedRegion<services.SystemUiOverlayStyle>(
            value: AppTheme.systemOverlayStyle(brightness),
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              title: '伴生',
              navigatorObservers: [appRouteObserver],
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: const [Locale('zh', 'CN'), Locale('en', 'US')],
              theme: AppTheme.materialTheme(Brightness.light),
              darkTheme: AppTheme.materialTheme(Brightness.dark),
              themeMode: appThemeController.mode,
              home: const AuthGate(),
            ),
          ),
        );
      },
    );
  }
}

class AppThemeScope extends InheritedNotifier<AppThemeController> {
  const AppThemeScope({
    super.key,
    required AppThemeController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppThemeController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppThemeScope>();
    return scope?.notifier ?? appThemeController;
  }
}

class _AppNavCircleButton extends StatelessWidget {
  const _AppNavCircleButton({required this.icon, required this.onPressed});

  static const double _size = 38;
  static const double _iconSize = 17;

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colors = AppColors.of(context);
    final isDark = AppColors.isDark(context);
    final iconColor = isDark ? colors.accentDeep : colors.accent;
    return CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(_size, _size),
      borderRadius: BorderRadius.circular(_size / 2),
      onPressed: enabled ? onPressed : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 160),
        opacity: enabled ? 1 : 0.48,
        child: Container(
          width: _size,
          height: _size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isDark
                ? colors.surfaceMuted.withValues(alpha: 0.74)
                : Colors.white.withValues(alpha: 0.60),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : Colors.white.withValues(alpha: 0.72),
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: isDark ? 0.70 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Icon(icon, color: iconColor, size: _iconSize),
        ),
      ),
    );
  }
}

class AppTheme {
  const AppTheme._();

  static ThemeData materialTheme(Brightness brightness) {
    final colors = AppColors.paletteFor(brightness);
    final scheme =
        ColorScheme.fromSeed(
          seedColor: colors.accent,
          brightness: brightness,
        ).copyWith(
          primary: colors.accent,
          secondary: colors.accentCyan,
          surface: colors.surface,
          onSurface: colors.text,
          error: colors.danger,
          onError: Colors.white,
        );
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.page,
      fontFamily: '.SF Pro Text',
      cupertinoOverrideTheme: CupertinoThemeData(
        brightness: brightness,
        primaryColor: colors.accent,
        scaffoldBackgroundColor: colors.page,
        textTheme: CupertinoTextThemeData(primaryColor: colors.text),
      ),
      extensions: [colors],
    );
    return base.copyWith(
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: colors.page,
        foregroundColor: colors.text,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: systemOverlayStyle(brightness),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: colors.text,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        contentTextStyle: TextStyle(color: colors.muted, fontSize: 14),
      ),
      dividerTheme: DividerThemeData(color: colors.hairline),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.surfaceMuted,
          disabledForegroundColor: colors.muted,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.text,
          side: BorderSide(color: colors.hairline),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.accent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.input,
        hintStyle: TextStyle(color: colors.muted),
        labelStyle: TextStyle(color: colors.muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: colors.accent, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark ? const Color(0xFFEDF5FF) : colors.text,
        contentTextStyle: TextStyle(
          color: isDark ? const Color(0xFF101820) : Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: colors.text,
        displayColor: colors.text,
      ),
    );
  }

  static services.SystemUiOverlayStyle systemOverlayStyle(
    Brightness brightness,
  ) {
    final colors = AppColors.paletteFor(brightness);
    final darkIcons = brightness == Brightness.light;
    return services.SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: colors.page,
      systemNavigationBarDividerColor: colors.hairline,
      statusBarIconBrightness: darkIcons ? Brightness.dark : Brightness.light,
      statusBarBrightness: darkIcons ? Brightness.light : Brightness.dark,
      systemNavigationBarIconBrightness: darkIcons
          ? Brightness.dark
          : Brightness.light,
    );
  }
}
