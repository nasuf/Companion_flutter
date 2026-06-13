part of 'package:companion_flutter/main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
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
    try {
      final stored = await _sessionStore.read();
      if (stored == null) {
        if (mounted) setState(() => _restoring = false);
        return;
      }

      final api = CompanionApi(baseUrl: stored.baseUrl);
      final loggedIn = await api.getMe(stored.token);
      final session = await api.ensureConversation(loggedIn);
      await _sessionStore.save(baseUrl: api.baseUrl, token: session.token);
      if (!mounted) return;
      setState(() {
        _api = api;
        _session = session;
        _restoring = false;
      });
    } catch (error) {
      debugPrint('[auth-restore] $error');
      await _sessionStore.clear();
      if (mounted) setState(() => _restoring = false);
    }
  }

  void _onAuthenticated(CompanionApi api, AuthSession session) {
    unawaited(_sessionStore.save(baseUrl: api.baseUrl, token: session.token));
    setState(() {
      _api = api;
      _session = session;
    });
  }

  void _onSessionChanged(AuthSession session) {
    final api = _api;
    if (api != null) {
      unawaited(_sessionStore.save(baseUrl: api.baseUrl, token: session.token));
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
    if (session != null && api != null) {
      return MainShell(
        api: api,
        session: session,
        onSessionChanged: _onSessionChanged,
        onLogout: _logout,
      );
    }
    if (_restoring) {
      return const _AuthRestoreSplash();
    }
    return LoginPage(onAuthenticated: _onAuthenticated);
  }
}

class _AuthRestoreSplash extends StatelessWidget {
  const _AuthRestoreSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CupertinoActivityIndicator(radius: 14)),
    );
  }
}
