part of 'package:companion_flutter/main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  static const _minimumSplashDuration = Duration(seconds: 2);
  static const _screenTransitionDuration = Duration(milliseconds: 650);

  final _sessionStore = AuthSessionStore();
  AuthSession? _session;
  CompanionApi? _api;
  bool _restoring = true;

  @override
  void initState() {
    super.initState();
    unawaited(_restoreSession());
  }

  Future<void> _restoreSession() async {
    final minimumSplash = Future<void>.delayed(_minimumSplashDuration);
    try {
      final stored = await _sessionStore.read();
      if (stored == null) {
        await minimumSplash;
        if (mounted) setState(() => _restoring = false);
        return;
      }

      final api = CompanionApi(baseUrl: stored.baseUrl);
      final loggedIn = await api.getMe(stored.token);
      final session = await api.ensureConversation(loggedIn);
      await _sessionStore.save(baseUrl: api.baseUrl, token: session.token);
      unawaited(PushNotificationService.instance.configure(api, session));
      await minimumSplash;
      if (!mounted) return;
      setState(() {
        _api = api;
        _session = session;
        _restoring = false;
      });
    } catch (error) {
      debugPrint('[auth-restore] $error');
      await _sessionStore.clear();
      await minimumSplash;
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _onAuthenticated(CompanionApi api, AuthSession session) {
    unawaited(_sessionStore.save(baseUrl: api.baseUrl, token: session.token));
    unawaited(PushNotificationService.instance.configure(api, session));
    setState(() {
      _api = api;
      _session = session;
    });
  }

  void _onSessionChanged(AuthSession session) {
    final api = _api;
    if (api != null) {
      unawaited(_sessionStore.save(baseUrl: api.baseUrl, token: session.token));
      unawaited(PushNotificationService.instance.configure(api, session));
    }
    setState(() => _session = session);
  }

  void _logout() {
    final api = _api;
    final session = _session;
    final agentId = session?.agentId;
    final conversationId = session?.conversationId;
    if (api != null &&
        agentId != null &&
        agentId.isNotEmpty &&
        conversationId != null &&
        conversationId.isNotEmpty) {
      unawaited(
        api.endMusicCoListening(
          agentId: agentId,
          conversationId: conversationId,
          reason: 'user_logout',
        ),
      );
    }
    unawaited(MusicPlaybackController.instance.stop());
    unawaited(PushNotificationService.instance.clear());
    unawaited(_sessionStore.clear());
    setState(() {
      _api = null;
      _session = null;
      _restoring = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    final api = _api;
    late final Widget screen;
    if (session != null && api != null) {
      screen = MainShell(
        key: const ValueKey('main-shell'),
        api: api,
        session: session,
        onSessionChanged: _onSessionChanged,
        onLogout: _logout,
      );
    } else if (_restoring) {
      screen = const _AuthRestoreSplash(key: ValueKey('auth-splash'));
    } else {
      screen = LoginPage(
        key: const ValueKey('login-page'),
        onAuthenticated: _onAuthenticated,
      );
    }

    return AnimatedSwitcher(
      duration: _screenTransitionDuration,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: screen,
    );
  }
}

class _AuthRestoreSplash extends StatelessWidget {
  const _AuthRestoreSplash({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF06C893);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: green,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: ColoredBox(
        color: green,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 390,
                  height: 844,
                  child: Stack(
                    children: [
                      Positioned(
                        left: -91,
                        top: -65,
                        width: 225,
                        height: 225,
                        child: SvgPicture.asset(
                          'assets/login/startup-orb-top.svg',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        left: 168,
                        top: 609,
                        width: 362,
                        height: 362,
                        child: SvgPicture.asset(
                          'assets/login/startup-orb-bottom.svg',
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        left: 75,
                        top: 179,
                        width: 240,
                        height: 240,
                        child: Image.asset(
                          'assets/login/startup-logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      const Positioned(
                        top: 419,
                        left: 0,
                        right: 0,
                        child: Text(
                          '伴生',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            height: 1.25,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 75,
                        top: 704,
                        width: 240,
                        height: 24,
                        child: SvgPicture.asset(
                          'assets/login/startup-divider.svg',
                          fit: BoxFit.fill,
                        ),
                      ),
                      const Positioned(
                        top: 740,
                        left: 0,
                        right: 0,
                        child: Text(
                          '独处时刻，皆有伴生相守',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
